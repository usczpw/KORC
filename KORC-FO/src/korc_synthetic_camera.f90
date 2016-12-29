MODULE korc_synthetic_camera
	USE korc_types
	USE korc_constants
	USE korc_HDF5
	IMPLICIT NONE

	TYPE, PRIVATE :: CAMERA
		REAL(rp) :: Riw ! Radial position of inner wall
		INTEGER, DIMENSION(2) :: np ! Number of pixels (X,Y)
		REAL(rp), DIMENSION(2) :: sensor_size ! In meters (horizontal,vertical)
		REAL(rp) :: focal_length ! Focal length in meters
		REAL(rp), DIMENSION(2) :: position ! Position of camera (R,Z)
		REAL(rp) :: incline ! Incline of camera in degrees
		REAL(rp) :: horizontal_angle_view ! Horizontal angle of view in radians
		REAL(rp) :: vertical_angle_view ! Vertical angle of view in radians
		REAL(rp), DIMENSION(:), ALLOCATABLE :: pixels_nodes_x ! In meters
		REAL(rp), DIMENSION(:), ALLOCATABLE :: pixels_nodes_y ! In meters
		REAL(rp), DIMENSION(:), ALLOCATABLE :: pixels_edges_x ! In meters
		REAL(rp), DIMENSION(:), ALLOCATABLE :: pixels_edges_y ! In meters

		REAL(rp) :: lambda_min ! Minimum wavelength in cm
		REAL(rp) :: lambda_max ! Maximum wavelength in cm
		INTEGER :: Nlambda
		REAL(rp) :: Dlambda ! In cm
		REAL(rp), DIMENSION(:), ALLOCATABLE :: lambda ! In cm
	END TYPE CAMERA

	TYPE, PRIVATE :: ANGLES
		REAL(rp), DIMENSION(:), ALLOCATABLE :: eta
		REAL(rp), DIMENSION(:), ALLOCATABLE :: beta
		REAL(rp), DIMENSION(:), ALLOCATABLE :: psi

		REAL(rp) :: threshold_angle
		REAL(rp) :: threshold_radius
	END TYPE ANGLES

	TYPE(CAMERA), PRIVATE :: cam
	TYPE(ANGLES), PRIVATE :: ang
	REAL(rp), PRIVATE, PARAMETER :: CGS_C = 1.0E2_rp*C_C
	REAL(rp), PRIVATE, PARAMETER :: CGS_E = 3.0E9_rp*C_E
	REAL(rp), PRIVATE, PARAMETER :: CGS_ME = 1.0E3_rp*C_ME

	PRIVATE :: clockwise_rotation,anticlockwise_rotation,cross,check_if_visible,calculate_rotation_angles,ajyik,&
				zeta,fx,arg,Po,P1,Psyn,chic,psic,&
				save_synthetic_camera_params,save_snapshot
	PUBLIC :: initialize_synthetic_camera,synthetic_camera

	CONTAINS


SUBROUTINE initialize_synthetic_camera(params)
	IMPLICIT NONE
	TYPE(KORC_PARAMS), INTENT(IN) :: params
	REAL(rp) :: Riw ! Radial position of inner wall
	INTEGER, DIMENSION(2) :: num_pixels ! Number of pixels (X,Y)
	REAL(rp), DIMENSION(2) :: sensor_size ! (horizontal,vertical)
	REAL(rp) :: focal_length
	REAL(rp), DIMENSION(2) :: position ! Position of camera (R,Z)
	REAL(rp) :: incline
	REAL(rp) :: lambda_min ! Minimum wavelength in cm
	REAL(rp) :: lambda_max ! Maximum wavelength in cm
	INTEGER :: Nlambda
	REAL(rp) :: xmin, xmax, ymin, ymax, DX, DY
	INTEGER :: ii

	NAMELIST /SyntheticCamera/ Riw,num_pixels,sensor_size,focal_length,position,incline,lambda_min,lambda_max,Nlambda

	if (params%mpi_params%rank .EQ. 0) then
		write(6,'(/,"* * * * * * * * * * * * * * * * * *")')
		write(6,'("*  Initializing synthetic camera  *")')
	end if

	open(unit=default_unit_open,file=TRIM(params%path_to_inputs),status='OLD',form='formatted')
	read(default_unit_open,nml=SyntheticCamera)
	close(default_unit_open)

!	write(*,nml=SyntheticCamera)

	cam%Riw = Riw
	cam%np = num_pixels
	cam%sensor_size = sensor_size
	cam%focal_length = focal_length
	cam%position = position
	cam%incline = C_PI*incline/180.0_rp
	cam%horizontal_angle_view = ATAN2(0.5_rp*cam%sensor_size(1),cam%focal_length)
	cam%vertical_angle_view = ATAN2(0.5_rp*cam%sensor_size(2),cam%focal_length)

	cam%lambda_min = 1.0E2_rp*lambda_min ! In cm
	cam%lambda_max = 1.0E2_rp*lambda_max ! In cm
	cam%Nlambda = Nlambda
	cam%Dlambda = (cam%lambda_max - cam%lambda_min)/REAL(cam%Nlambda,rp)
	ALLOCATE(cam%lambda(cam%Nlambda))
	
	do ii=1_idef,cam%Nlambda
		cam%lambda(ii) = cam%lambda_min + REAL(ii-1_idef,rp)*cam%Dlambda
	end do

	ALLOCATE(cam%pixels_nodes_x(cam%np(1)))
	ALLOCATE(cam%pixels_nodes_y(cam%np(2)))
	ALLOCATE(cam%pixels_edges_x(cam%np(1) + 1))
	ALLOCATE(cam%pixels_edges_y(cam%np(2) + 1))

	xmin = -0.5_rp*cam%sensor_size(1)
	xmax = 0.5_rp*cam%sensor_size(1)
	DX = cam%sensor_size(1)/REAL(cam%np(1),rp)

	do ii=1_idef,cam%np(1)
		cam%pixels_nodes_x(ii) = xmin + 0.5_rp*DX + REAL(ii-1_idef,rp)*DX
	end do

	do ii=1_idef,cam%np(1)+1_idef
		cam%pixels_edges_x(ii) = xmin + REAL(ii-1_idef,rp)*DX
	end do

	ymin = cam%position(2) - 0.5_rp*cam%sensor_size(2)
	ymax = cam%position(2) + 0.5_rp*cam%sensor_size(2)
	DY = cam%sensor_size(2)/REAL(cam%np(2),rp)

	do ii=1_idef,cam%np(2)
		cam%pixels_nodes_y(ii) = ymin + 0.5_rp*DY + REAL(ii-1_idef,rp)*DY
	end do

	do ii=1_idef,cam%np(2)+1_idef
		cam%pixels_edges_y(ii) = ymin + REAL(ii-1_idef,rp)*DY
	end do
	
	! Initialize ang variables
	ALLOCATE(ang%eta(cam%np(1)))
	ALLOCATE(ang%beta(cam%np(1)))
	ALLOCATE(ang%psi(cam%np(2)+1_idef))

	do ii=1_idef,cam%np(1)
		ang%eta(ii) = ABS(ATAN2(cam%pixels_nodes_x(ii),cam%focal_length))
		if (cam%pixels_edges_x(ii) .LT. 0.0_rp) then
			ang%beta(ii) = 0.5_rp*C_PI - cam%incline - ang%eta(ii)
		else
			ang%beta(ii) = 0.5_rp*C_PI - cam%incline + ang%eta(ii)
		end if
	end do

	do ii=1_idef,cam%np(2)+1_idef
		ang%psi(ii) = ATAN2(cam%pixels_edges_y(ii),cam%focal_length)
	end do

	ang%threshold_angle = ATAN2(cam%Riw,-cam%position(1))
	ang%threshold_radius = SQRT(cam%Riw**2 + cam%position(1)**2)

	if (params%mpi_params%rank .EQ. 0) then
		write(6,'("*     Synthetic camera ready!     *")')
		write(6,'("* * * * * * * * * * * * * * * * * *",/)')
	end if

	call save_synthetic_camera_params(params)
END SUBROUTINE initialize_synthetic_camera


! * * * * * * * * * * * * * * * !
! * * * * * FUNCTIONS * * * * * !
! * * * * * * * * * * * * * * * !

FUNCTION cross(a,b)
	REAL(rp), DIMENSION(3), INTENT(IN) :: a
	REAL(rp), DIMENSION(3), INTENT(IN) :: b
	REAL(rp), DIMENSION(3) :: cross

	cross(1) = a(2)*b(3) - a(3)*b(2)
	cross(2) = a(3)*b(1) - a(1)*b(3)
	cross(3) = a(1)*b(2) - a(2)*b(1)
END FUNCTION cross


FUNCTION clockwise_rotation(x,t)
	IMPLICIT NONE
	REAL(rp), DIMENSION(2), INTENT(IN) :: x
	REAL(rp), INTENT(IN) :: t ! Angle in radians
	REAL(rp), DIMENSION(2) :: clockwise_rotation

	clockwise_rotation(1) = x(1)*COS(t) + x(2)*SIN(t)
	clockwise_rotation(2) = -x(1)*SIN(t) + x(2)*COS(t)
END FUNCTION clockwise_rotation


FUNCTION anticlockwise_rotation(x,t)
	IMPLICIT NONE
	REAL(rp), DIMENSION(2), INTENT(IN) :: x
	REAL(rp), INTENT(IN) :: t ! Angle in radians
	REAL(rp), DIMENSION(2) :: anticlockwise_rotation

	anticlockwise_rotation(1) = x(1)*COS(t) - x(2)*SIN(t)
	anticlockwise_rotation(2) = x(1)*SIN(t) + x(2)*COS(t)
END FUNCTION anticlockwise_rotation


FUNCTION besselk(x)
	IMPLICIT NONE
	REAL(rp), DIMENSION(2) :: besselk
	REAL(rp), INTENT(IN) :: x
	REAL(rp) :: vj1, vj2, vy1, vy2, vi1, vi2
	! besselk(1) = K1/3(x)
	! besselk(2) = K2/3(x)

	call ajyik(x,vj1,vj2,vy1,vy2,vi1,vi2,besselk(1),besselk(2))
END FUNCTION besselk


FUNCTION zeta(g,p,k,l)
	IMPLICIT NONE
	REAL(rp) :: zeta
	REAL(rp), INTENT(IN) ::	g
	REAL(rp), INTENT(IN) :: p
	REAL(rp), INTENT(IN) :: k
	REAL(rp), INTENT(IN) :: l

	zeta = (2.0_rp*C_PI/(3.0_rp*l*k*g**3))*(1.0_rp + (g*p)**2)**1.5_rp
END FUNCTION


FUNCTION fx(g,p,x)
	IMPLICIT NONE
	REAL(rp) :: fx
	REAL(rp), INTENT(IN) ::	g
	REAL(rp), INTENT(IN) :: p
	REAL(rp), INTENT(IN) :: x

	fx = g*x/SQRT(1.0_rp + (g*p)**2)
END FUNCTION fx


FUNCTION Po(g,p,k,l)
	IMPLICIT NONE
	REAL(rp) :: Po
	REAL(rp), INTENT(IN) ::	g
	REAL(rp), INTENT(IN) :: p
	REAL(rp), INTENT(IN) :: k
	REAL(rp), INTENT(IN) :: l
	

	Po = -(4.0_rp*C_PI*CGS_C*CGS_E**2/(k*(l*g)**4))*(1.0_rp + (g*p)**2)**2
END FUNCTION Po


FUNCTION arg(g,p,k,l,x)
	IMPLICIT NONE
	REAL(rp) :: arg
	REAL(rp), INTENT(IN) ::	g
	REAL(rp), INTENT(IN) :: p
	REAL(rp), INTENT(IN) :: k
	REAL(rp), INTENT(IN) :: l
	REAL(rp), INTENT(IN) :: x
	REAL(rp) :: A

	A = fx(g,p,x)
	arg = 1.5_rp*zeta(g,p,k,l)*(A + (A**3)/3.0_rp)
END FUNCTION arg


FUNCTION P1(g,p,k,l,x)
	IMPLICIT NONE
	REAL(rp) :: P1
	REAL(rp), INTENT(IN) ::	g
	REAL(rp), INTENT(IN) :: p
	REAL(rp), INTENT(IN) :: k
	REAL(rp), INTENT(IN) :: l
	REAL(rp), INTENT(IN) :: x
	REAL(rp), DIMENSION(2) :: BK
	REAL(rp) :: A

	BK = besselk(zeta(g,p,k,l))
	A = fx(g,p,x)

	P1 = ((g*p)**2)*BK(1)*COS(arg(g,p,k,l,x))/(1.0_rp + (g*p)**2) - 0.5_rp*BK(1)*(1.0_rp + A**2)*COS(arg(g,p,k,l,x))&
		+ A*BK(2)*SIN(arg(g,p,k,l,x))
END FUNCTION P1


FUNCTION Psyn(g,p,k,l,x)
	IMPLICIT NONE
	REAL(rp) :: Psyn
	REAL(rp), INTENT(IN) ::	g
	REAL(rp), INTENT(IN) :: p
	REAL(rp), INTENT(IN) :: k
	REAL(rp), INTENT(IN) :: l
	REAL(rp), INTENT(IN) :: x

	Psyn = Po(g,p,k,l)*P1(g,p,k,l,x)
END FUNCTION Psyn


FUNCTION chic(g,k,l)
	IMPLICIT NONE
	REAL(rp) :: chic
	REAL(rp), INTENT(IN) ::	g
	REAL(rp), INTENT(IN) :: k
	REAL(rp), INTENT(IN) :: l
	REAL(rp) :: D
	REAL(rp) :: xi

	xi = 2.0_rp*C_PI/(3.0_rp*l*k*g**3)
	D = (0.5_rp*(SQRT(4.0_rp + (C_PI/xi)**2) - C_PI/xi))**(1.0_rp/3.0_rp)
	chic = (1.0_rp/D - D)/g
END FUNCTION chic


FUNCTION psic(k,l)
	IMPLICIT NONE
	REAL(rp) :: psic
	REAL(rp), INTENT(IN) :: k
	REAL(rp), INTENT(IN) :: l

	psic = (1.5_rp*k*l/C_PI)**(1.0_rp/3.0_rp)
END FUNCTION psic

! * * * * * * * * * * * * * * * !
! * * * * * FUNCTIONS * * * * * !
! * * * * * * * * * * * * * * * !


SUBROUTINE check_if_visible(X,V,threshold_angle,bool,angle,XC)
	IMPLICIT NONE
	REAL(rp), DIMENSION(3), INTENT(IN) :: X
	REAL(rp), DIMENSION(3), INTENT(IN) :: V
	REAL(rp), INTENT(IN) :: threshold_angle
	LOGICAL, INTENT(OUT) :: bool
	REAL(rp), INTENT(OUT) :: angle
	REAL(rp), DIMENSION(3), OPTIONAL, INTENT(OUT) :: XC
	REAL(rp), DIMENSION(3) :: vec
	REAL(rp) :: a, b, c, ciw, dis, disiw
	REAL(rp) :: sp, sn, s, psi


	a = V(1)**2 + V(2)**2
	b = 2.0_rp*(X(1)*V(1) + X(2)*V(2))
	c = X(1)**2 + X(2)**2 - cam%position(1)**2
	ciw = X(1)**2 + X(2)**2 - cam%Riw**2

	dis = b**2 - 4.0_rp*a*c
	disiw = b**2 - 4.0_rp*a*ciw
	
	if ((dis .LT. 0.0_rp).OR.(disiw .GE. 0.0_rp)) then
		bool = .FALSE. ! The particle is not visible
	else
		sp = 0.5_rp*(-b + SQRT(dis))/a
		sn = 0.5_rp*(-b - SQRT(dis))/a
		s = MAX(sp,sn)
		
		! Rotation angle along z-axis so that v is directed to the camera
		if (PRESENT(XC)) then
			XC(1) = X(1) + s*V(1)
			XC(2) = X(2) + s*V(2)
			XC(3) = X(3) + s*V(3)
			angle = ATAN2(XC(2),XC(1))
		else
			angle = ATAN2(X(2) + s*V(2),X(1) + s*V(1))
		end if
		if (angle.LT.0.0_rp) angle = angle + 2.0_rp*C_PI
	
		vec(1) = cam%position(1)*COS(angle) - X(1)
		vec(2) = cam%position(1)*SIN(angle) - X(2)
		vec(3) = cam%position(2) - X(3)

		vec = vec/SQRT(DOT_PRODUCT(vec,vec))
		
		psi = ACOS(DOT_PRODUCT(vec,V))

		if (psi.LE.threshold_angle) then
			bool = .TRUE. ! The particle is visible
		else
			bool = .FALSE. ! The particle is not visible
		end if
	end if

END SUBROUTINE check_if_visible


SUBROUTINE calculate_rotation_angles(X,bpa,apa)
	IMPLICIT NONE
	REAL(rp), DIMENSION(3), INTENT(IN) :: X
	LOGICAL, DIMENSION(:,:,:), ALLOCATABLE, INTENT(INOUT) :: bpa
	REAL(rp), DIMENSION(:,:,:), ALLOCATABLE, INTENT(INOUT) :: apa
	REAL(rp) :: R, D, psi
	REAL(rp) :: a, b, c, dis, xp, xn
	REAL(rp) :: xtmp, ytmp
	INTEGER :: ii,jj
	! bpa(:,:,1) -- > xp
	! bpa(:,:,2) -- > xn
		
	R = SQRT(SUM(X(1:2)**2))
	D = SQRT( (X(1) - cam%position(1))**2 + X(2) )
	psi = -ATAN2(X(3) - cam%position(2),D)

	bpa = .TRUE.
	
	do ii=1_idef,cam%np(1)
		a = 1.0_rp + TAN(ang%beta(ii))**2
		b = -2.0_rp*TAN(ang%beta(ii))**2*cam%position(1)
		c = (TAN(ang%beta(ii))*cam%position(1))**2 - R**2
		dis = b**2 - 4.0_rp*a*c
		
		if (dis.GT.0.0_rp) then
			do jj=1_idef,cam%np(2)

				if ((psi.GT.ang%psi(jj)).AND.(psi.LE.ang%psi(jj+1_idef))) then
					xp = 0.5_rp*(-b + SQRT(dis))/a
					xn = 0.5_rp*(-b - SQRT(dis))/a

					xtmp = xp - cam%position(1)
					ytmp = SQRT(R**2 - xp**2)

					! Check if particle is behind inner wall
					if ((ATAN2(ytmp,xtmp).GT.ang%threshold_angle).AND.(SQRT(xtmp**2+ytmp**2).GT.ang%threshold_radius)) then
						bpa(ii,jj,1) = .FALSE.
					else
						apa(ii,jj,1) = ATAN2(ytmp,xp)
						if (apa(ii,jj,1).LT.0.0_rp) apa(ii,jj,1) = apa(ii,jj,1)	+ 2.0_rp*C_PI
					end if

					xtmp = xn - cam%position(1)
					ytmp = SQRT(R**2 - xn**2)

					! Check if particle is behind inner wall
					if ((ATAN2(ytmp,xtmp).GT.ang%threshold_angle).AND.(SQRT(xtmp**2+ytmp**2).GT.ang%threshold_radius)) then
						bpa(ii,jj,2) = .FALSE.
					else
						apa(ii,jj,2) = ATAN2(ytmp,xn)
						if (apa(ii,jj,2).LT.0.0_rp) apa(ii,jj,2) = apa(ii,jj,2)	+ 2.0_rp*C_PI
					end if
				else ! Not in pixel (ii,jj)
					bpa(ii,jj,:) = .FALSE.
				end if ! Check if in pixel (ii,jj)

			end do ! NY
		else ! no real solutions
			bpa(ii,:,:) = .FALSE.
		end if ! Checking discriminant
	end do !! NX
END SUBROUTINE calculate_rotation_angles


SUBROUTINE synthetic_camera(params,spp)
	IMPLICIT NONE
	TYPE(KORC_PARAMS), INTENT(IN) :: params
	TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(IN) :: spp
	REAL(rp), DIMENSION(3) :: binorm, n, nperp
	REAL(rp), DIMENSION(3) :: X, V, XC
	LOGICAL, DIMENSION(:,:,:), ALLOCATABLE :: bool_pixel_array
	REAL(rp), DIMENSION(:,:,:), ALLOCATABLE :: angle_pixel_array
	REAL(rp), DIMENSION(:,:,:,:), ALLOCATABLE :: part_pixel
	REAL(rp), DIMENSION(:,:,:,:), ALLOCATABLE :: Psyn_pixel
	REAL(rp) :: q, m, k, u, g, l, threshold_angle
	REAL(rp) :: psi, chi, Psyn_tmp
	LOGICAL :: bool
	REAL(rp) :: angle, clockwise
	INTEGER :: ii,jj,ll,ss,pp

	ALLOCATE(bool_pixel_array(cam%np(1),cam%np(2),2)) ! (NX,NY,2)
	ALLOCATE(angle_pixel_array(cam%np(1),cam%np(2),2)) ! (NX,NY,2)
	ALLOCATE(part_pixel(cam%np(1),cam%np(2),cam%Nlambda,params%num_species))
	ALLOCATE(Psyn_pixel(cam%np(1),cam%np(2),cam%Nlambda,params%num_species))

	part_pixel = 0.0_rp
	Psyn_pixel = 0.0_rp

	do ss=1_idef,params%num_species
		q = ABS(spp(ss)%q)*params%cpp%charge
		m = spp(ss)%m*params%cpp%mass

!$OMP PARALLEL FIRSTPRIVATE(q,m) PRIVATE(binorm,n,nperp,X,XC,V,bool_pixel_array,angle_pixel_array,k,u,g,l,&
!$OMP& threshold_angle,psi,chi,Psyn_tmp,bool,angle,clockwise,ii,jj,ll,pp)&
!$OMP& SHARED(params,spp,ss,Psyn_pixel,part_pixel)
!$OMP DO
		do pp=1_idef,spp(ss)%ppp
			if ( spp(ss)%vars%flag(pp) .EQ. 1_idef ) then
				V = spp(ss)%vars%V(:,pp)*params%cpp%velocity
				X = spp(ss)%vars%X(:,pp)*params%cpp%length
				g = spp(ss)%vars%gamma(pp)

				binorm = cross(V,spp(ss)%vars%E(:,pp)) + cross(V,cross(V,spp(ss)%vars%B(:,pp)))
		
				u = SQRT(DOT_PRODUCT(V,V))
				k = q*SQRT(DOT_PRODUCT(binorm,binorm))/(spp(ss)%vars%gamma(pp)*m*u**3)

				binorm = binorm/SQRT(DOT_PRODUCT(binorm,binorm))

				threshold_angle = (1.5_rp*k*cam%lambda_max/C_PI)**(1.0_rp/3.0_rp) ! In radians

				call check_if_visible(X,V/u,threshold_angle,bool,angle)	
			
				if (bool.EQV..TRUE.) then
					k = k/1.0E2_rp ! Now in cm^-1 (CGS)

					X(1:2) = clockwise_rotation(X(1:2),angle)
					V(1:2) = clockwise_rotation(V(1:2),angle)
					binorm(1:2) = clockwise_rotation(binorm(1:2),angle)

					call calculate_rotation_angles(X,bool_pixel_array,angle_pixel_array)

					clockwise = ATAN2(X(2),X(1))
					if (clockwise.LT.0.0_rp) clockwise = clockwise + 2.0_rp*C_PI


					do ii=1_idef,cam%np(1) ! NX
						do jj=1_idef,cam%np(2) ! NY
							
							if (bool_pixel_array(ii,jj,1)) then
!								part_pixel(ii,jj) = part_pixel(ii,jj) + 1.0_rp

								angle = angle_pixel_array(ii,jj,1) - clockwise

								XC = (/cam%position(1)*COS(angle),-cam%position(1)*SIN(angle),cam%position(2)/)

								n = XC - X
								n = n/SQRT(DOT_PRODUCT(n,n))

								psi = ACOS(DOT_PRODUCT(n,binorm))
								if (psi.GT.0.5_rp*C_PI) psi = psi - 0.5_rp*C_PI
								if (psi.LT.0.5_rp*C_PI) psi = 0.5_rp*C_PI - psi

								nperp = n - DOT_PRODUCT(n,binorm)*binorm
								chi = ABS(ACOS(DOT_PRODUCT(nperp,V/u)))

								do ll=1_idef,cam%Nlambda ! Nlambda
									l = cam%lambda(ll)
									if ((chi.LT.chic(g,k,l)).AND.(psi.LT.psic(k,l))) then
										Psyn_tmp = Psyn(g,psi,k,l,chi)
										if (Psyn_tmp.GT.0.0_rp) then
											Psyn_pixel(ii,jj,ll,ss) = Psyn_pixel(ii,jj,ll,ss) + Psyn_tmp

											part_pixel(ii,jj,ll,ss) = part_pixel(ii,jj,ll,ss) + 1.0_rp
										end if
									end if
								end do ! Nlambda
							end if

							if (bool_pixel_array(ii,jj,2)) then
!								part_pixel(ii,jj) = part_pixel(ii,jj) + 1.0_rp

								angle = angle_pixel_array(ii,jj,2) - clockwise

								XC = (/cam%position(1)*COS(angle),-cam%position(1)*SIN(angle),cam%position(2)/)

								n = XC - X
								n = n/SQRT(DOT_PRODUCT(n,n))

								psi = ACOS(DOT_PRODUCT(n,binorm))
								if (psi.GT.0.5_rp*C_PI) psi = psi - 0.5_rp*C_PI
								if (psi.LT.0.5_rp*C_PI) psi = 0.5_rp*C_PI - psi

								nperp = n - DOT_PRODUCT(n,binorm)*binorm
								chi = ABS(ACOS(DOT_PRODUCT(nperp,V/u)))

								do ll=1_idef,cam%Nlambda ! Nlambda
									l = cam%lambda(ll)
									if ((chi.LT.chic(g,k,l)).AND.(psi.LT.psic(k,l))) then
										Psyn_tmp = Psyn(g,psi,k,l,chi)
										if (Psyn_tmp.GT.0.0_rp) then
											Psyn_pixel(ii,jj,ll,ss) = Psyn_pixel(ii,jj,ll,ss) + Psyn_tmp

											part_pixel(ii,jj,ll,ss) = part_pixel(ii,jj,ll,ss) + 1.0_rp
										end if
									end if
								end do ! Nlambda
							end if

						end do ! NY
					end do ! NX


				end if ! check if bool == TRUE
			end if ! if confined
		end do ! particles
!$OMP END DO
!$OMP END PARALLEL
	end do ! species

	call save_snapshot(params,part_pixel,Psyn_pixel)

!	open(unit=default_unit_write,&
!	file='/home/l8c/Documents/KORC/KORC-FO/Psyn.dat',&
!	status='UNKNOWN',form='formatted')
!	do ii=1_idef,cam%np(1)
!		write(default_unit_write,'(45F25.16)') Psyn_pixel(ii,:)
!	end do
!	close(default_unit_write)

!	open(unit=default_unit_write,&
!	file='/home/l8c/Documents/KORC/KORC-FO/Part.dat',&
!	status='UNKNOWN',form='formatted')
!	do ii=1_idef,cam%np(1)
!		write(default_unit_write,'(45F25.16)') part_pixel(ii,:)
!	end do
!	close(default_unit_write)

	DEALLOCATE(bool_pixel_array)
	DEALLOCATE(angle_pixel_array)
	DEALLOCATE(part_pixel)
    DEALLOCATE(Psyn_pixel)
END SUBROUTINE synthetic_camera


SUBROUTINE save_synthetic_camera_params(params)
	IMPLICIT NONE
	TYPE(KORC_PARAMS), INTENT(IN) :: params
	CHARACTER(MAX_STRING_LENGTH) :: filename
	CHARACTER(MAX_STRING_LENGTH) :: gname
	CHARACTER(MAX_STRING_LENGTH), DIMENSION(:), ALLOCATABLE :: attr_array
	CHARACTER(MAX_STRING_LENGTH) :: dset
	CHARACTER(MAX_STRING_LENGTH) :: attr
	INTEGER(HID_T) :: h5file_id
	INTEGER(HID_T) :: group_id
	CHARACTER(19) :: tmp_str
	INTEGER :: h5error
	REAL(rp) :: units

	if (params%mpi_params%rank .EQ. 0) then
		filename = TRIM(params%path_to_outputs) // "synthetic_camera.h5"
		call h5fcreate_f(TRIM(filename), H5F_ACC_TRUNC_F, h5file_id, h5error)

		gname = "synthetic_camera_params"
		call h5gcreate_f(h5file_id, TRIM(gname), group_id, h5error)

		dset = TRIM(gname) // "/Riw"
		attr = "Radial position of inner wall (m)"
		call save_to_hdf5(h5file_id,dset,cam%Riw,attr)

		dset = TRIM(gname) // "/focal_length"
		attr = "Focal length of the camera (m)"
		call save_to_hdf5(h5file_id,dset,cam%focal_length,attr)

		dset = TRIM(gname) // "/incline"
		attr = "Incline of camera in degrees"
		units = 180.0_rp/C_PI
		call save_to_hdf5(h5file_id,dset,units*cam%incline,attr)

		dset = TRIM(gname) // "/horizontal_angle_view"
		attr = "Horizontal angle of view in degrees"
		units = 180.0_rp/C_PI
		call save_to_hdf5(h5file_id,dset,units*cam%horizontal_angle_view,attr)

		dset = TRIM(gname) // "/vertical_angle_view"
		attr = "Vertical angle of view in degrees"
		units = 180.0_rp/C_PI
		call save_to_hdf5(h5file_id,dset,units*cam%vertical_angle_view,attr)

		dset = TRIM(gname) // "/lambda_min"
		attr = "Minimum wavelength (m)"
		units = 1.0E-2_rp
		call save_to_hdf5(h5file_id,dset,units*cam%lambda_min,attr)

		dset = TRIM(gname) // "/lambda_max"
		attr = "Minimum wavelength (m)"
		units = 1.0E-2_rp
		call save_to_hdf5(h5file_id,dset,units*cam%lambda_max,attr)

		dset = TRIM(gname) // "/Dlambda"
		attr = "Step between finite wavelengths (m)"
		units = 1.0E-2_rp
		call save_to_hdf5(h5file_id,dset,units*cam%Dlambda,attr)

		dset = TRIM(gname) // "/Nlambda"
		attr = "Number of finite wavelengths (m)"
		call save_to_hdf5(h5file_id,dset,cam%Nlambda,attr)

	    dset = TRIM(gname) // "/lambda"
		units = 1.0E7_rp
	    call save_1d_array_to_hdf5(h5file_id,dset,units*cam%lambda)

	    dset = TRIM(gname) // "/num_pixels"
	    call save_1d_array_to_hdf5(h5file_id,dset,cam%np)

	    dset = TRIM(gname) // "/sensor_size"
	    call save_1d_array_to_hdf5(h5file_id,dset,cam%sensor_size)

	    dset = TRIM(gname) // "/position"
	    call save_1d_array_to_hdf5(h5file_id,dset,cam%position)

	    dset = TRIM(gname) // "/pixels_nodes_x"
	    call save_1d_array_to_hdf5(h5file_id,dset,cam%pixels_nodes_x)

	    dset = TRIM(gname) // "/pixels_nodes_y"
	    call save_1d_array_to_hdf5(h5file_id,dset,cam%pixels_nodes_y)

	    dset = TRIM(gname) // "/pixels_edges_x"
	    call save_1d_array_to_hdf5(h5file_id,dset,cam%pixels_edges_x)

	    dset = TRIM(gname) // "/pixels_edges_y"
	    call save_1d_array_to_hdf5(h5file_id,dset,cam%pixels_edges_y)

		call h5gclose_f(group_id, h5error)

		call h5fclose_f(h5file_id, h5error)
	end if

	write(tmp_str,'(I18)') params%mpi_params%rank
	filename = TRIM(params%path_to_outputs) //"synthetic_camera_snapshots_MPI_"// TRIM(ADJUSTL(tmp_str)) //".h5"
	call h5fcreate_f(TRIM(filename), H5F_ACC_TRUNC_F, h5file_id, h5error)
	call h5fclose_f(h5file_id, h5error)
END SUBROUTINE save_synthetic_camera_params


SUBROUTINE save_snapshot(params,part,Psyn)
	IMPLICIT NONE
	TYPE(KORC_PARAMS), INTENT(IN) :: params
	REAL(rp), DIMENSION(:,:,:,:), ALLOCATABLE, INTENT(IN) :: part
	REAL(rp), DIMENSION(:,:,:,:), ALLOCATABLE, INTENT(IN) :: Psyn
	INTEGER, INTENT(IN) :: species
	CHARACTER(MAX_STRING_LENGTH) :: filename
	CHARACTER(MAX_STRING_LENGTH) :: gname
	CHARACTER(MAX_STRING_LENGTH) :: subgname
	CHARACTER(MAX_STRING_LENGTH), DIMENSION(:), ALLOCATABLE :: attr_array
	CHARACTER(MAX_STRING_LENGTH) :: dset
	CHARACTER(MAX_STRING_LENGTH) :: attr
	INTEGER(HID_T) :: h5file_id
	INTEGER(HID_T) :: group_id
	INTEGER(HID_T) :: subgroup_id
	CHARACTER(19) :: tmp_str
	INTEGER :: h5error
	INTEGER :: ss
	REAL(rp) :: units

	write(tmp_str,'(I18)') params%mpi_params%rank
	filename = TRIM(params%path_to_outputs) //"synthetic_camera_snapshots_MPI_"// TRIM(ADJUSTL(tmp_str)) //".h5"
	call h5fopen_f(TRIM(filename), H5F_ACC_RDWR_F, h5file_id, h5error)

    ! Create group 'it'
	write(tmp_str,'(I18)') params%it
	gname = TRIM(ADJUSTL(tmp_str))
	call h5gcreate_f(h5file_id, TRIM(gname), group_id, h5error)
    
	dset = TRIM(gname) // "/time"
	attr = "Simulation time in secs"
	call save_to_hdf5(h5file_id,dset,REAL(params%it,rp)*params%dt*params%cpp%time,attr)

	do ss=1_idef,params%num_species
		write(tmp_str,'(I18)') ss
		subgname = "spp_" // TRIM(ADJUSTL(tmp_str))
		call h5gcreate_f(group_id, TRIM(subgname), subgroup_id, h5error)

		dset = "part_pixel"
		call save_3d_array_to_hdf5(subgroup_id, dset, part(:,:,:,ss))

		dset = "Psyn_pixel"
		call save_3d_array_to_hdf5(subgroup_id, dset, Psyn(:,:,:,ss))


		call h5gclose_f(subgroup_id, h5error)
	end do

	call h5gclose_f(group_id, h5error)

	call h5fclose_f(h5file_id, h5error)
END SUBROUTINE save_snapshot


SUBROUTINE ajyik( x, vj1, vj2, vy1, vy2, vi1, vi2, vk1, vk2 )
!*****************************************************************************80
!
!! AJYIK computes Bessel functions Jv(x), Yv(x), Iv(x), Kv(x).
!
!  Discussion: 
!
!    Compute Bessel functions Jv(x) and Yv(x), and modified Bessel functions 
!    Iv(x) and Kv(x), and their derivatives with v = 1/3, 2/3.
!
!  Licensing:
!
!    This routine is copyrighted by Shanjie Zhang and Jianming Jin.  However, 
!    they give permission to incorporate this routine into a user program 
!    provided that the copyright is acknowledged.
!
!  Modified:
!
!    31 July 2012
!
!  Author:
!
!    Shanjie Zhang, Jianming Jin
!
!  Reference:
!
!    Shanjie Zhang, Jianming Jin,
!    Computation of Special Functions,
!    Wiley, 1996,
!    ISBN: 0-471-11963-6,
!    LC: QA351.C45.
!
!  Parameters:
!
!    Input, real ( kind = 8 ) X, the argument.  X should not be zero.
!
!    Output, real ( kind = 8 ) VJ1, VJ2, VY1, VY2, VI1, VI2, VK1, VK2,
!    the values of J1/3(x), J2/3(x), Y1/3(x), Y2/3(x), I1/3(x), I2/3(x),
!    K1/3(x), K2/3(x).
!
  implicit none

  real ( kind = 8 ) a0
  real ( kind = 8 ) b0
  real ( kind = 8 ) c0
  real ( kind = 8 ) ck
  real ( kind = 8 ) gn
  real ( kind = 8 ) gn1
  real ( kind = 8 ) gn2
  real ( kind = 8 ) gp1
  real ( kind = 8 ) gp2
  integer ( kind = 4 ) k
  integer ( kind = 4 ) k0
  integer ( kind = 4 ) l
  real ( kind = 8 ) pi
  real ( kind = 8 ) pv1
  real ( kind = 8 ) pv2
  real ( kind = 8 ) px
  real ( kind = 8 ) qx
  real ( kind = 8 ) r
  real ( kind = 8 ) rp
  real ( kind = 8 ) rp2
  real ( kind = 8 ) rq
  real ( kind = 8 ) sk
  real ( kind = 8 ) sum_ajyik
  real ( kind = 8 ) uj1
  real ( kind = 8 ) uj2
  real ( kind = 8 ) uu0
  real ( kind = 8 ) vi1
  real ( kind = 8 ) vi2
  real ( kind = 8 ) vil
  real ( kind = 8 ) vj1
  real ( kind = 8 ) vj2
  real ( kind = 8 ) vjl
  real ( kind = 8 ) vk1
  real ( kind = 8 ) vk2
  real ( kind = 8 ) vl
  real ( kind = 8 ) vsl
  real ( kind = 8 ) vv
  real ( kind = 8 ) vv0
  real ( kind = 8 ) vy1
  real ( kind = 8 ) vy2
  real ( kind = 8 ) x
  real ( kind = 8 ) x2
  real ( kind = 8 ) xk

  if ( x == 0.0D+00 ) then
    vj1 = 0.0D+00
    vj2 = 0.0D+00
    vy1 = -1.0D+300
    vy2 = 1.0D+300
    vi1 = 0.0D+00
    vi2 = 0.0D+00
    vk1 = -1.0D+300
    vk2 = -1.0D+300
    return
  end if

  pi = 3.141592653589793D+00
  rp2 = 0.63661977236758D+00
  gp1 = 0.892979511569249D+00
  gp2 = 0.902745292950934D+00
  gn1 = 1.3541179394264D+00
  gn2 = 2.678938534707747D+00
  vv0 = 0.444444444444444D+00
  uu0 = 1.1547005383793D+00
  x2 = x * x

  if ( x < 35.0D+00 ) then
    k0 = 12
  else if ( x < 50.0D+00 ) then
    k0 = 10
  else
    k0 = 8
  end if

  if ( x <= 12.0D+00 ) then

    do l = 1, 2
      vl = l / 3.0D+00
      vjl = 1.0D+00
      r = 1.0D+00
      do k = 1, 40
        r = -0.25D+00 * r * x2 / ( k * ( k + vl ) )
        vjl = vjl + r
        if ( abs ( r ) < 1.0D-15 ) then
          exit
        end if
      end do

      a0 = ( 0.5D+00 * x ) ** vl
      if ( l == 1 ) then
        vj1 = a0 / gp1 * vjl
      else
        vj2 = a0 / gp2 * vjl
      end if

    end do

  else

    do l = 1, 2

      vv = vv0 * l * l
      px = 1.0D+00
      rp = 1.0D+00

      do k = 1, k0
        rp = - 0.78125D-02 * rp &
          * ( vv - ( 4.0D+00 * k - 3.0D+00 ) ** 2 ) &
          * ( vv - ( 4.0D+00 * k - 1.0D+00 ) ** 2 ) &
          / ( k * ( 2.0D+00 * k - 1.0D+00 ) * x2 )
        px = px + rp
      end do

      qx = 1.0D+00
      rq = 1.0D+00
      do k = 1, k0
        rq = - 0.78125D-02 * rq &
          * ( vv - ( 4.0D+00 * k - 1.0D+00 ) ** 2 ) &
          * ( vv - ( 4.0D+00 * k + 1.0D+00 ) ** 2 ) &
          / ( k * ( 2.0D+00 * k + 1.0D+00 ) * x2 )
        qx = qx + rq
      end do

      qx = 0.125D+00 * ( vv - 1.0D+00 ) * qx / x
      xk = x - ( 0.5D+00 * l / 3.0D+00 + 0.25D+00 ) * pi
      a0 = sqrt ( rp2 / x )
      ck = cos ( xk )
      sk = sin ( xk )
      if ( l == 1) then
        vj1 = a0 * ( px * ck - qx * sk )
        vy1 = a0 * ( px * sk + qx * ck )
      else
        vj2 = a0 * ( px * ck - qx * sk )
        vy2 = a0 * ( px * sk + qx * ck )
      end if

    end do

  end if

  if ( x <= 12.0D+00 ) then

    do l = 1, 2

      vl = l / 3.0D+00
      vjl = 1.0D+00
      r = 1.0D+00
      do k = 1, 40
        r = -0.25D+00 * r * x2 / ( k * ( k - vl ) )
        vjl = vjl + r
        if ( abs ( r ) < 1.0D-15 ) then
          exit
        end if
      end do

      b0 = ( 2.0D+00 / x ) ** vl
      if ( l == 1 ) then
        uj1 = b0 * vjl / gn1
      else
         uj2 = b0 * vjl / gn2
      end if

    end do

    pv1 = pi / 3.0D+00
    pv2 = pi / 1.5D+00
    vy1 = uu0 * ( vj1 * cos ( pv1 ) - uj1 )
    vy2 = uu0 * ( vj2 * cos ( pv2 ) - uj2 )

  end if

  if ( x <= 18.0D+00 ) then

    do l = 1, 2
      vl = l / 3.0D+00
      vil = 1.0D+00
      r = 1.0D+00
      do k = 1, 40
        r = 0.25D+00 * r * x2 / ( k * ( k + vl ) )
        vil = vil + r
        if ( abs ( r ) < 1.0D-15 ) then
          exit
        end if
      end do

      a0 = ( 0.5D+00 * x ) ** vl

      if ( l == 1 ) then
        vi1 = a0 / gp1 * vil
      else
        vi2 = a0 / gp2 * vil
      end if

    end do

  else

    c0 = exp ( x ) / sqrt ( 2.0D+00 * pi * x )

    do l = 1, 2
      vv = vv0 * l * l
      vsl = 1.0D+00
      r = 1.0D+00
      do k = 1, k0
        r = - 0.125D+00 * r &
          * ( vv - ( 2.0D+00 * k - 1.0D+00 ) ** 2 ) / ( k * x )
        vsl = vsl + r
      end do
      if ( l == 1 ) then
        vi1 = c0 * vsl
      else
        vi2 = c0 * vsl
      end if
    end do

  end if

  if ( x <= 9.0D+00 ) then

    do l = 1, 2
      vl = l / 3.0D+00
      if ( l == 1 ) then
        gn = gn1
      else
        gn = gn2
      end if
      a0 = ( 2.0D+00 / x ) ** vl / gn
      sum_ajyik = 1.0D+00
      r = 1.0D+00
      do k = 1, 60
        r = 0.25D+00 * r * x2 / ( k * ( k - vl ) )
        sum_ajyik = sum_ajyik + r
        if ( abs ( r ) < 1.0D-15 ) then
          exit
        end if
      end do

      if ( l == 1 ) then
        vk1 = 0.5D+00 * uu0 * pi * ( sum_ajyik * a0 - vi1 )
      else
        vk2 = 0.5D+00 * uu0 * pi * ( sum_ajyik * a0 - vi2 )
      end if

    end do

  else

    c0 = exp ( - x ) * sqrt ( 0.5D+00 * pi / x )

    do l = 1, 2
      vv = vv0 * l * l
      sum_ajyik = 1.0D+00
      r = 1.0D+00
      do k = 1, k0
        r = 0.125D+00 * r * ( vv - ( 2.0D+00 * k - 1.0D+00 ) ** 2 ) / ( k * x )
        sum_ajyik = sum_ajyik + r
      end do
      if ( l == 1 ) then
        vk1 = c0 * sum_ajyik
      else
        vk2 = c0 * sum_ajyik
      end if
    end do

  end if

  return
END SUBROUTINE ajyik



END MODULE korc_synthetic_camera