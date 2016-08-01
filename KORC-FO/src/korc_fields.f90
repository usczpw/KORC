module korc_fields

    use korc_types
	use korc_hpc

    implicit none

	PUBLIC :: analytical_magnetic_field, mean_F_field, check_if_confined

    contains

subroutine analytical_magnetic_field(F,Y,B,flag)
    implicit none
	TYPE(FIELDS), INTENT(IN) :: F
	REAL(rp), DIMENSION(:,:), ALLOCATABLE, INTENT(IN) :: Y ! Y(1,:) = r, Y(2,:) = theta, Y(3,:) = zeta
	REAL(rp), DIMENSION(:,:), ALLOCATABLE, INTENT(INOUT) :: B ! B(1,:) = Bx, B(2,:) = By, B(3,:) = Bz
	INTEGER, DIMENSION(:), ALLOCATABLE, INTENT(IN) :: flag
	REAL(rp) :: Bp, Bt, eta, q
	INTEGER(ip) pp ! Iterator(s)
	INTEGER(ip) :: ss

	ss = SIZE(Y,2)

!$OMP PARALLEL FIRSTPRIVATE(ss) PRIVATE(pp,Bp,Bt,eta,q) SHARED(F,Y,B,flag)
!$OMP DO
	do pp=1,ss
        if ( flag(pp) .EQ. 1_idef ) then
		    eta = Y(1,pp)/F%Ro
            q = F%AB%qo*(1.0_rp + (Y(1,pp)/F%AB%lambda)**2)
            Bp = eta*F%AB%Bo/(q*( 1.0_rp + (Y(1,pp)/F%AB%lambda)**2 ))
		    Bt = F%AB%Bo/( 1.0_rp + eta*cos(Y(2,pp)) )

		    B(1,pp) =  Bt*cos(Y(3,pp)) - Bp*sin(Y(2,pp))*sin(Y(3,pp))
		    B(2,pp) = -Bt*sin(Y(3,pp)) - Bp*sin(Y(2,pp))*cos(Y(3,pp))
		    B(3,pp) = Bp*cos(Y(2,pp))
        end if
	end do
!$OMP END DO
!$OMP END PARALLEL
end subroutine analytical_magnetic_field


subroutine analytical_magnetic_field_sp(F,Y,B,flag)
    implicit none
	TYPE(FIELDS), INTENT(IN) :: F
	REAL(rp), DIMENSION(3), INTENT(IN) :: Y ! Y(1) = r, Y(2) = theta, Y(3) = zeta
	REAL(rp), DIMENSION(3), INTENT(INOUT) :: B ! B(1) = Bx, B(2) = By, B(3) = Bz
	INTEGER, INTENT(IN) :: flag
	REAL(rp) :: Bp, Br, eta

	if ( flag .EQ. 1_idef ) then
		Bp = F%AB%Bpo*( Y(1)/F%AB%lambda )/( 1.0_rp + (Y(1)/F%AB%lambda)**2 )
		eta = Y(1)/F%Ro
		Br = 1.0_rp/( 1.0_rp + eta*cos(Y(2)) )

		B(1) = Br*( F%AB%Bo*cos(Y(3)) - Bp*sin(Y(2))*sin(Y(3)) )
		B(2) = -Br*( F%AB%Bo*sin(Y(3)) + Bp*sin(Y(2))*cos(Y(3)) )
		B(3) = Br*Bp*cos(Y(2))
	end if
end subroutine analytical_magnetic_field_sp


subroutine analytical_electric_field(F,Y,E,flag)
    implicit none
	TYPE(FIELDS), INTENT(IN) :: F
	REAL(rp), DIMENSION(:,:), ALLOCATABLE, INTENT(IN) :: Y ! Y(1,:) = r, Y(2,:) = theta, Y(3,:) = zeta
	REAL(rp), DIMENSION(:,:), ALLOCATABLE, INTENT(INOUT) :: E ! E(1,:) = Ex, E(2,:) = Ey, E(3,:) = Ez
	INTEGER, DIMENSION(:), ALLOCATABLE, INTENT(IN) :: flag
	REAL(rp) :: Ezeta, eta
	INTEGER(ip) pp ! Iterator(s)
	INTEGER(ip) :: ss

	if (abs(F%Eo) > 0) then
		ss = SIZE(Y,2)
!$OMP PARALLEL FIRSTPRIVATE(ss) PRIVATE(pp,Ezeta,eta) SHARED(F,Y,E,flag)
!$OMP DO
		do pp=1,ss
            if ( flag(pp) .EQ. 1_idef ) then
			    eta = Y(1,pp)/F%Ro		
			    Ezeta = F%Eo/( 1.0_rp + eta*cos(Y(2,pp)) )

			    E(1,pp) = Ezeta*cos(Y(3,pp))
			    E(2,pp) = -Ezeta*sin(Y(3,pp))
			    E(3,pp) = 0.0_rp
            end if
		end do
!$OMP END DO
!$OMP END PARALLEL
	end if
end subroutine analytical_electric_field


subroutine analytical_electric_field_sp(F,Y,E,flag)
    implicit none
	TYPE(FIELDS), INTENT(IN) :: F
	REAL(rp), DIMENSION(3), INTENT(IN) :: Y ! Y(1) = r, Y(2) = theta, Y(3) = zeta
	REAL(rp), DIMENSION(3), INTENT(INOUT) :: E ! E(1) = Ex, E(2) = Ey, E(3) = Ez
	INTEGER, INTENT(IN) :: flag
	REAL(rp) :: Ezeta, eta

	if (abs(F%Eo) > 0) then
		if ( flag .EQ. 1_idef ) then
			eta = Y(1)/F%Ro		
			Ezeta = F%Eo/( 1.0_rp + eta*cos(Y(2)) )

			E(1) = Ezeta*cos(Y(3))
			E(2) = -Ezeta*sin(Y(3))
			E(3) = 0.0_rp
		end if
	end if
end subroutine analytical_electric_field_sp


subroutine mean_F_field(F,Fo,op_field)
	implicit none
	TYPE(FIELDS), INTENT(IN) :: F
	REAL(rp), INTENT(OUT) :: Fo
	TYPE(KORC_STRING), INTENT(IN) :: op_field

	if (TRIM(op_field%str) .EQ. 'B') then
		Fo = sum( sqrt(F%B%R**2 + F%B%PHI**2 + F%B%Z**2) )/size(F%B%R)
	else if (TRIM(op_field%str) .EQ. 'E') then
		Fo = sum( sqrt(F%E%R**2 + F%E%PHI**2 + F%E%Z**2) )/size(F%E%R)
	else
		write(6,'("KORC ERROR: Please enter a valid field: mean_F_field")')
		call korc_abort()
	end if
end subroutine mean_F_field

subroutine check_if_confined(F,Y,flag)
    implicit none
	TYPE(FIELDS), INTENT(IN) :: F
	REAL(rp), DIMENSION(:,:), ALLOCATABLE, INTENT(IN) :: Y ! Y(1,:) = r, Y(2,:) = theta, Y(3,:) = zeta
	INTEGER, DIMENSION(:), ALLOCATABLE, INTENT(INOUT) :: flag
	INTEGER(ip) :: pp,ss

    ss = SIZE(Y,2)
!$OMP PARALLEL FIRSTPRIVATE(ss) PRIVATE(pp) SHARED(F,Y,flag)
!$OMP DO
	do pp=1,ss
        if ( flag(pp) .EQ. 1_idef ) then
            if (Y(1,pp) .GT. F%AB%a) then
                flag(pp) = 0_idef
            end if
        end if
	end do
!$OMP END DO
!$OMP END PARALLEL
end subroutine check_if_confined


subroutine check_if_confined_sp(F,Y,flag)
    implicit none
	TYPE(FIELDS), INTENT(IN) :: F
	REAL(rp), DIMENSION(3), INTENT(IN) :: Y ! Y(1) = r, Y(2) = theta, Y(3) = zeta
	INTEGER, INTENT(INOUT) :: flag

	if ( flag .EQ. 1_idef ) then
		if (Y(1) .GT. F%AB%a) then
			flag = 0_idef
		end if
	end if
end subroutine check_if_confined_sp

end module korc_fields
