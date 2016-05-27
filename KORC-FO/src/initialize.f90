module initialize

    use korc_types
    use constants
    use korc_hpc
    use korc_HDF5
    use korc_interp
    use rnd_numbers

    implicit none

	

	PRIVATE :: set_paths, load_korc_params, initialization_sanity_check, unitVectors
	PUBLIC :: initialize_korc_parameters, initialize_particles, initialize_fields

    contains

subroutine set_paths(params)
	implicit none
	INTEGER :: argn
	TYPE(KORC_PARAMS), INTENT(OUT) :: params

	argn = command_argument_count()
	call get_command_argument(1,params%path_to_inputs)
	call get_command_argument(2,params%path_to_outputs)

	write(6,'("* * * * * PATHS * * * * *")')
	write(6,'("The input file is:",A50)') TRIM(params%path_to_inputs)
	write(6,'("The output folder is:",A50)') TRIM(params%path_to_outputs)
end subroutine set_paths


subroutine load_korc_params(params)
	implicit none
	TYPE (KORC_PARAMS), INTENT(INOUT) :: params
	LOGICAL :: restart ! Not used, yet.
	INTEGER(ip) :: t_steps
	REAL(rp) :: dt
	CHARACTER(MAX_STRING_LENGTH) :: magnetic_field_model
	LOGICAL :: poloidal_flux
	CHARACTER(MAX_STRING_LENGTH) :: magnetic_field_filename
	INTEGER(ip) :: output_cadence
	INTEGER :: num_species
	INTEGER :: pic_algorithm

	NAMELIST /input_parameters/ magnetic_field_model,poloidal_flux,&
			magnetic_field_filename,t_steps,dt,output_cadence,num_species,pic_algorithm
	
	open(unit=default_unit_open,file=TRIM(params%path_to_inputs),status='OLD',form='formatted')
	read(default_unit_open,nml=input_parameters)
	close(default_unit_open)

	! params%restart = restart
	params%t_steps = t_steps
	params%output_cadence = output_cadence
	params%num_snapshots = t_steps/output_cadence
	params%dt = dt
	params%num_species = num_species
	params%magnetic_field_model = TRIM(magnetic_field_model)
	params%poloidal_flux = poloidal_flux
	params%magnetic_field_filename = TRIM(magnetic_field_filename)
	params%pic_algorithm = pic_algorithm

	if (params%mpi_params%rank .EQ. 0) then
		write(6,'("* * * * * SIMULATION PARAMETERS * * * * *")')
		write(6,'("Number of time steps: ",I16)') params%t_steps
		write(6,'("Output cadence: ",I16)') params%output_cadence
		write(6,'("Number of outputs: ",I16)') params%num_snapshots
		write(6,'("Time step in fraction of gyro-period: ",F15.10)') params%dt
		write(6,'("Number of electron populations: ",I16)') params%num_species
		write(6,'("Magnetic field model: ",A50)') TRIM(params%magnetic_field_model)
		write(6,'("Using (JFIT) poloidal flux: ", L1)') params%poloidal_flux
		write(6,'("Magnetic field model: ",A100)') TRIM(params%magnetic_field_filename)

	end if	
end subroutine load_korc_params


subroutine initialize_korc_parameters(params)
	use korc_types
	implicit none
	TYPE(KORC_PARAMS), INTENT(OUT) :: params

	call set_paths(params)
	call load_korc_params(params)
end subroutine initialize_korc_parameters


! * * * * * * * * * * * *  * * * * * * * * * * * * * !
! * * * SUBROUTINES FOR INITIALIZING PARTICLES * * * !
! * * * * * * * * * * * *  * * * * * * * * * * * * * !

subroutine initialize_particles(params,EB,ptcls) 
	implicit none
	TYPE(KORC_PARAMS), INTENT(IN) :: params
	TYPE(FIELDS), INTENT(IN) :: EB
	TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(OUT) :: ptcls
	REAL(rp), DIMENSION(:), ALLOCATABLE :: ppp
	REAL(rp), DIMENSION(:), ALLOCATABLE :: q
	REAL(rp), DIMENSION(:), ALLOCATABLE :: m
	REAL(rp), DIMENSION(:), ALLOCATABLE :: Eo
	REAL(rp), DIMENSION(:), ALLOCATABLE :: etao
	REAL(rp), DIMENSION(:), ALLOCATABLE :: Ro
	REAL(rp), DIMENSION(:), ALLOCATABLE :: Zo
	LOGICAL, DIMENSION(:), ALLOCATABLE :: runaway
	REAL(rp), DIMENSION(:), ALLOCATABLE :: Vo
	REAL(rp), DIMENSION(:), ALLOCATABLE :: Vpar
	REAL(rp), DIMENSION(:), ALLOCATABLE :: Vperp
	REAL(rp), DIMENSION(:,:), ALLOCATABLE :: b
	REAL(rp), DIMENSION(:,:), ALLOCATABLE :: a
	REAL(rp), DIMENSION(:,:), ALLOCATABLE :: Xo
	REAL(rp), DIMENSION(:), ALLOCATABLE :: angle, radius ! temporary vars
	REAL(rp), DIMENSION(:), ALLOCATABLE :: r ! temporary variable
	INTEGER :: ii,jj ! Iterator

	NAMELIST /plasma_species/ ppp, q, m, Eo, etao, runaway, Ro, Zo, r

	! Allocate array containing variables of particles for each species
	ALLOCATE(ptcls(params%num_species))

	ALLOCATE(ppp(params%num_species))
	ALLOCATE(q(params%num_species))
	ALLOCATE(m(params%num_species))
	ALLOCATE(Eo(params%num_species))
	ALLOCATE(etao(params%num_species))
	ALLOCATE(runaway(params%num_species))
	ALLOCATE(Ro(params%num_species))
	ALLOCATE(Zo(params%num_species))

	ALLOCATE(r(params%num_species))

	open(unit=default_unit_open,file=TRIM(params%path_to_inputs),status='OLD',form='formatted')
	read(default_unit_open,nml=plasma_species)
	close(default_unit_open)

	do ii=1,params%num_species
		ptcls(ii)%Eo = Eo(ii)
		ptcls(ii)%etao = etao(ii)
		ptcls(ii)%runaway = runaway(ii)
		ptcls(ii)%q = q(ii)*C_E
		ptcls(ii)%m = m(ii)*C_ME
		ptcls(ii)%ppp = ppp(ii)

		ptcls(ii)%gammao =  ptcls(ii)%Eo*C_E/(ptcls(ii)%m*C_C**2)

		ALLOCATE( ptcls(ii)%vars%X(3,ptcls(ii)%ppp) )
		ALLOCATE( ptcls(ii)%vars%V(3,ptcls(ii)%ppp) )
		ALLOCATE( ptcls(ii)%vars%Rgc(3,ptcls(ii)%ppp) )
		ALLOCATE( ptcls(ii)%vars%Y(3,ptcls(ii)%ppp) )
		ALLOCATE( ptcls(ii)%vars%E(3,ptcls(ii)%ppp) )
		ALLOCATE( ptcls(ii)%vars%B(3,ptcls(ii)%ppp) )
		ALLOCATE( ptcls(ii)%vars%gamma(ptcls(ii)%ppp) )
		ALLOCATE( ptcls(ii)%vars%eta(ptcls(ii)%ppp) )
		ALLOCATE( ptcls(ii)%vars%mu(ptcls(ii)%ppp) )
		ALLOCATE( ptcls(ii)%vars%kappa(ptcls(ii)%ppp) )
		ALLOCATE( ptcls(ii)%vars%tau(ptcls(ii)%ppp) )

		ALLOCATE( Xo(3,ptcls(ii)%ppp) )
		ALLOCATE( Vo(ptcls(ii)%ppp) )
		ALLOCATE( Vpar(ptcls(ii)%ppp) )
		ALLOCATE( Vperp(ptcls(ii)%ppp) )
		ALLOCATE( b(3,ptcls(ii)%ppp) )
		ALLOCATE( a(3,ptcls(ii)%ppp) )
		
		ALLOCATE( angle(ptcls(ii)%ppp) )
		ALLOCATE( radius(ptcls(ii)%ppp) )

		! Initialize to zero
		ptcls(ii)%vars%X = 0.0_rp
		ptcls(ii)%vars%V = 0.0_rp
		ptcls(ii)%vars%Rgc = 0.0_rp
		ptcls(ii)%vars%Y = 0.0_rp
		ptcls(ii)%vars%E = 0.0_rp
		ptcls(ii)%vars%B = 0.0_rp
		ptcls(ii)%vars%gamma = 0.0_rp
		ptcls(ii)%vars%eta = 0.0_rp
		ptcls(ii)%vars%mu = 0.0_rp
		ptcls(ii)%vars%kappa = 0.0_rp
		ptcls(ii)%vars%tau = 0.0_rp

		! Initial condition of uniformly distributed particles on a disk in the xz-plane
		! A unique velocity direction
		call init_random_seed()
		call RANDOM_NUMBER(angle)
		angle = 2*C_PI*angle

		! Uniform distribution on a disk at a fixed azimuthal angle		
		call init_random_seed()
		call RANDOM_NUMBER(radius)
		radius = r(ii)*radius
		
		Xo(1,:) = Ro(ii) + sqrt(radius)*cos(angle)
		Xo(2,:) = 0.0_rp
		Xo(3,:) = Zo(ii) + sqrt(radius)*sin(angle)

		ptcls(ii)%vars%X(1,:) = Xo(1,:)
		ptcls(ii)%vars%X(2,:) = Xo(2,:)
		ptcls(ii)%vars%X(3,:) = Xo(3,:)

		! Monoenergetic distribution
		ptcls(ii)%vars%gamma(:) = ptcls(ii)%Eo*C_E/(ptcls(ii)%m*C_C**2)

		Vo = C_C*sqrt( 1.0_rp - 1.0_rp/(ptcls(ii)%vars%gamma(:)**2) )
		Vpar = Vo*cos( C_PI*ptcls(ii)%etao/180_rp )
		Vperp = Vo*sin( C_PI*ptcls(ii)%etao/180_rp )

		call unitVectors(params,Xo,EB,b,a)

		do jj=1,ptcls(ii)%ppp
			ptcls(ii)%vars%V(:,jj) = Vpar(jj)*b(:,jj) + Vperp*a(:,jj)
		end do

		DEALLOCATE(angle)
		DEALLOCATE(radius)
		DEALLOCATE(Xo)
		DEALLOCATE(Vo)
		DEALLOCATE(Vpar)
		DEALLOCATE(Vperp)
		DEALLOCATE(b)
		DEALLOCATE(a)
	end do

	DEALLOCATE(ppp)
	DEALLOCATE(q)
	DEALLOCATE(m)
	DEALLOCATE(Eo)
	DEALLOCATE(etao)
	DEALLOCATE(runaway)
	DEALLOCATE(Ro)
	DEALLOCATE(Zo)

	DEALLOCATE(r)
end subroutine initialize_particles

! * * * * * * * * * * * *  * * * * * * * * * * * * * !
! * * * SUBROUTINES FOR INITIALIZING PARTICLES * * * !
! * * * * * * * * * * * *  * * * * * * * * * * * * * !

subroutine initialize_communications(params)
	implicit none
	TYPE(KORC_PARAMS), INTENT(INOUT) :: params

!$OMP PARALLEL
	params%num_omp_threads = OMP_GET_NUM_THREADS()
!$OMP END PARALLEL

	call initialize_mpi(params)

	call initialization_sanity_check(params) 
end subroutine initialize_communications


subroutine initialization_sanity_check(params)
	implicit none
	TYPE(KORC_PARAMS), INTENT(IN) :: params
	CHARACTER(MAX_STRING_LENGTH) :: env_variable
	INTEGER :: ierr
	LOGICAL :: flag = .FALSE.

	if (params%mpi_params%rank .EQ. 0) then
		write(6,'("* * * SANITY CHECK * * *")')
	end if

	call GET_ENVIRONMENT_VARIABLE("OMP_PLACES",env_variable)
!	call GET_ENVIRONMENT_VARIABLE("GOMP_CPU_AFFINITY",env_variable)
	write(6,*) TRIM(env_variable)

!$OMP PARALLEL SHARED(params) PRIVATE(ierr, flag)
	call MPI_INITIALIZED(flag, ierr)
	write(6,'("MPI: ",I3," OMP/of: ",I3," / ",I3," Procs: ",I3," Init: ",l1)') &
	params%mpi_params%rank_topo,OMP_GET_THREAD_NUM(),OMP_GET_NUM_THREADS(),OMP_GET_NUM_PROCS(),flag
!$OMP END PARALLEL
end subroutine initialization_sanity_check


subroutine initialize_fields(params,EB)
	implicit none
	TYPE(KORC_PARAMS), INTENT(IN) :: params
	TYPE(FIELDS), INTENT(OUT) :: EB
	TYPE(KORC_STRING) :: field
	REAL(rp) :: Bo
	REAL(rp) :: minor_radius
	REAL(rp) :: major_radius
	REAL(rp) :: q_factor_at_separatrix
	REAL(rp) :: free_param

	NAMELIST /analytic_mag_field_params/ Bo,minor_radius,major_radius,&
			q_factor_at_separatrix,free_param

	if (params%magnetic_field_model .EQ. 'ANALYTICAL') then
		! Load the parameters of the analytical magnetic field
		open(unit=default_unit_open,file=TRIM(params%path_to_inputs),status='OLD',form='formatted')
		read(default_unit_open,nml=analytic_mag_field_params)
		close(default_unit_open)

		EB%AB%Bo = Bo
		EB%AB%a = minor_radius
		EB%AB%Ro = major_radius
		EB%AB%qa = q_factor_at_separatrix
		EB%AB%co = free_param
		EB%AB%lambda = EB%AB%a / EB%AB%co
		EB%AB%Bpo = (EB%AB%a/EB%AB%Ro)*(EB%AB%Bo/EB%AB%qa)*(1+EB%AB%co**2)/EB%AB%co;

		EB%Bo = EB%AB%Bo
	else if (params%magnetic_field_model .EQ. 'EXTERNAL') then
		! Load the magnetic field from an external HDF5 file
        call load_dim_data_from_hdf5(params,EB%dims)

       	call ALLOCATE_FIELDS_ARRAYS(EB,params%poloidal_flux)

        call load_field_data_from_hdf5(params,EB)

!		open(unit=default_unit_write,file='/home/l8c/Documents/KORC/KORC-FO/temp_file.dat',status='UNKNOWN',form='formatted')
!		write(default_unit_write,'(150(F15.10))') EB%B%R(:,1,:)
!		write(default_unit_write,'(65(F15.10))') EB%PSIp
!		close(default_unit_write)	

		if (.NOT. params%poloidal_flux) then
			field%str = 'B'
			call mean_F_field(EB,EB%Bo,field)
		end if
	else
		write(6,'("ERROR: when initializing fields!")')
		call korc_abort()
	end if
end subroutine initialize_fields


end module initialize
