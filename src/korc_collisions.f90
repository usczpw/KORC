module korc_collisions
  use korc_types
  use korc_constants
  use korc_HDF5
  use korc_interp
  use korc_profiles
  use korc_fields

#ifdef PARALLEL_RANDOM

  use korc_random

#endif

  IMPLICIT NONE

  CHARACTER(LEN=*), PRIVATE, PARAMETER 	:: MODEL1 = 'SINGLE_SPECIES'
  CHARACTER(LEN=*), PRIVATE, PARAMETER 	:: MODEL2 = 'MULTIPLE_SPECIES'
  REAL(rp), PRIVATE, PARAMETER 			:: infinity = HUGE(1.0_rp)

  TYPE, PRIVATE :: PARAMS_MS
     INTEGER 					:: num_impurity_species
     REAL(rp) 					:: Te
     ! Background electron temperature in eV
     REAL(rp) 					:: ne
     ! Background electron density in 1/m^3
     REAL(rp) 					:: nH
     ! Background proton density in 1/m^3
     REAL(rp) 					:: nef
     ! Free electron density in 1/m^3
     REAL(rp), DIMENSION(:), ALLOCATABLE        :: neb
     ! Bound electron density in 1/m^3
     REAL(rp), DIMENSION(:), ALLOCATABLE        :: Zi
     ! Atomic number of (majority) background ions
     REAL(rp), DIMENSION(:), ALLOCATABLE        :: Zo
     ! Full nuclear charge of each impurity: Z=1 for D, Z=10 for Ne
     REAL(rp), DIMENSION(:), ALLOCATABLE        :: Zj
     ! Atomic number of each impurity: Z=1 for D, Z=10 for Ne
     REAL(rp), DIMENSION(:), ALLOCATABLE        :: nz
     ! Impurity densities
     REAL(rp), DIMENSION(:), ALLOCATABLE        :: IZj,aZj
     ! Ionization energy of impurity in eV
     REAL(rp), DIMENSION(:), ALLOCATABLE        :: Ee_IZj
     ! me*c^2/IZj dimensionless parameter

     REAL(rp) 					:: rD
     ! Debye length
     REAL(rp) 					:: re
     ! Classical electron radius


     REAL(rp), DIMENSION(11) :: aNe=(/111._rp,100._rp,90._rp,80._rp, &
          71._rp,62._rp,52._rp,40._rp,24._rp,23._rp,0._rp/)
     REAL(rp), DIMENSION(19) :: aAr=(/96._rp,90._rp,84._rp,78._rp,72._rp, &
          65._rp,59._rp,53._rp,47._rp,44._rp,41._rp,38._rp,25._rp,32._rp, &
          27._rp,21._rp,13._rp,13._rp,0._rp/)


     REAL(rp), DIMENSION(11) :: INe=(/137.2_rp,165.2_rp,196.9_rp,235.2_rp, &
          282.8_rp,352.6_rp,475.0_rp,696.8_rp,1409.2_rp,1498.4_rp,huge(1._rp)/)
     REAL(rp), DIMENSION(19) :: IAr=(/188.5_rp,219.4_rp,253.8_rp,293.4_rp, &
          339.1_rp,394.5_rp,463.4_rp,568.0_rp,728.0_rp,795.9_rp,879.8_rp, &
          989.9_rp,1138.1_rp,1369.5_rp,1791.2_rp,2497.0_rp,4677.2_rp, &
          4838.2_rp,huge(1._rp)/)
     
  END TYPE PARAMS_MS

  TYPE, PRIVATE :: PARAMS_SS
     REAL(rp) 			:: Te
     ! Electron temperature
     REAL(rp) 			:: Ti
     ! Ion temperature
     REAL(rp) 			:: ne
     ! Background electron density
     REAL(rp) 			:: Zeff
     ! Effective atomic number of ions
     REAL(rp) 			:: rD
     ! Debye radius
     REAL(rp) 			:: re
     ! Classical electron radius
     REAL(rp) 			:: CoulombLogee,CoulombLogei
     ! Coulomb logarithm
     REAL(rp) 			:: CLog1, CLog2,CLog0_1, CLog0_2
     REAL(rp) 			:: VTe
     ! Thermal velocity of background electrons
     REAL(rp) 			:: VTeo
     REAL(rp) 			:: delta
     ! delta parameter
     REAL(rp) 			:: deltao
     REAL(rp) 			:: Gammac
     ! Collisional Gamma factor
     REAL(rp) 			:: Gammaco
     ! Collisional gamma factor normalized for SDE for dp
     REAL(rp) 			:: Tau
     ! Collisional time of relativistic particles
     REAL(rp) 			:: Tauc
     ! Collisional time of thermal particles
     REAL(rp) 			:: taur
     ! radiation timescale
     REAL(rp) 			:: Ec
     ! Critical electric field
     REAL(rp) 			:: ED
     ! Dreicer electric field
     REAL(rp) 			:: dTau
     ! Subcycling time step in collisional time units (Tau)
     INTEGER(ip)		:: subcycling_iterations

     REAL(rp), DIMENSION(3) 	:: x = (/1.0_rp,0.0_rp,0.0_rp/)
     REAL(rp), DIMENSION(3) 	:: y = (/0.0_rp,1.0_rp,0.0_rp/)
     REAL(rp), DIMENSION(3) 	:: z = (/0.0_rp,0.0_rp,1.0_rp/)

     TYPE(PROFILES) 			   :: P

     REAL(rp), DIMENSION(:,:), ALLOCATABLE :: rnd_num
     INTEGER 				   :: rnd_num_count
     INTEGER 				   :: rnd_dim = 40000000_idef
  END TYPE PARAMS_SS

  TYPE(PARAMS_MS), PRIVATE :: cparams_ms
  TYPE(PARAMS_SS), PRIVATE :: cparams_ss

  PUBLIC :: initialize_collision_params,&
       normalize_collisions_params,&
       collision_force,&
       deallocate_collisions_params,&
       save_collision_params,&    
       include_CoulombCollisions_GC_p,&
       include_CoulombCollisions_FO_p,&
       check_collisions_params,&
       define_collisions_time_step
  PRIVATE :: load_params_ms,&
       load_params_ss,&
       normalize_params_ms,&
       normalize_params_ss,&
       save_params_ms,&
       save_params_ss,&
       deallocate_params_ms,&
       cross,&
       CA,&
       CB_ee,&
       CB_ei,&
       CF,&
       fun,&
       nu_S,&
       nu_par,&
       nu_D,&
       Gammac_wu,&
       CLog_wu,&
       VTe_wu,&
       Gammacee,&
       CLog,&
       VTe,&
       CA_SD,&
       CB_ee_SD,&
       CB_ei_SD,&
       CF_SD,&
       delta,&
       unitVectorsC,&
       unitVectors_p

contains

  ! * * * * * * * * * * * *  * * * * * * * * * * * * * !
  ! * SUBROUTINES FOR INITIALIZING COLLISIONS PARAMS * !
  ! * * * * * * * * * * * *  * * * * * * * * * * * * * !


  subroutine load_params_ms(params)
    TYPE(KORC_PARAMS), INTENT(IN) 	:: params
    REAL(rp) 				:: Te
    ! Background electron temperature in eV
    REAL(rp) 				:: ne
    ! Background electron density in 1/m^3
    INTEGER 				:: num_impurity_species
    REAL(rp), DIMENSION(10) 		:: Zo
    ! Full nuclear charge of each impurity: Z=1 for D, Z=10 for Ne
    REAL(rp), DIMENSION(10) 		:: Zj
    ! Atomic number of each impurity: Z=1 for D, Z=10 for Ne
    REAL(rp), DIMENSION(10) 		:: nz
    ! Impurity densities
    REAL(rp), DIMENSION(10) 		:: IZj
    ! Ionization energy of impurity in eV
    REAL(rp), DIMENSION(10) 		:: aZj
    INTEGER :: i

    NAMELIST /CollisionParamsMultipleSpecies/ num_impurity_species,Te,ne, &
         Zo,Zj,nz,IZj


    open(unit=default_unit_open,file=TRIM(params%path_to_inputs), &
         status='OLD',form='formatted')
    read(default_unit_open,nml=CollisionParamsMultipleSpecies)
    close(default_unit_open)

    cparams_ms%num_impurity_species = num_impurity_species

    ALLOCATE(cparams_ms%Zj(cparams_ms%num_impurity_species))
    ALLOCATE(cparams_ms%Zo(cparams_ms%num_impurity_species))
    ALLOCATE(cparams_ms%nz(cparams_ms%num_impurity_species))
    ALLOCATE(cparams_ms%neb(cparams_ms%num_impurity_species))
    ALLOCATE(cparams_ms%IZj(cparams_ms%num_impurity_species))
    ALLOCATE(cparams_ms%aZj(cparams_ms%num_impurity_species))
    ALLOCATE(cparams_ms%Ee_IZj(cparams_ms%num_impurity_species))

    cparams_ms%Te = Te*C_E
    cparams_ms%ne = ne
    cparams_ms%nH = ne

    cparams_ms%Zj = Zj(1:cparams_ms%num_impurity_species)
    cparams_ms%Zo = Zo(1:cparams_ms%num_impurity_species)
    cparams_ms%nz = nz(1:cparams_ms%num_impurity_species)

    do i=1,cparams_ms%num_impurity_species
       if (int(cparams_ms%Zo(i)).eq.10) then
          cparams_ms%IZj(i) = C_E*cparams_ms%INe(int(cparams_ms%Zj(i)+1))
          cparams_ms%aZj(i) = cparams_ms%aNe(int(cparams_ms%Zj(i)+1))
       else if (int(cparams_ms%Zo(i)).eq.18) then
          cparams_ms%IZj(i) = C_E*cparams_ms%IAr(int(cparams_ms%Zj(i)+1))
          cparams_ms%aZj(i) = cparams_ms%aAr(int(cparams_ms%Zj(i)+1))
       else
          write(6,'("Atomic number not defined!")')
          exit
       end if
    end do

    cparams_ms%nef = ne + sum(cparams_ms%Zj*cparams_ms%nz)
    cparams_ms%neb = (cparams_ms%Zo-cparams_ms%Zj)*cparams_ms%nz

    cparams_ms%rD = SQRT( C_E0*cparams_ms%Te/(cparams_ms%ne*C_E**2) )
    cparams_ms%re = C_RE
    cparams_ms%Ee_IZj = C_ME*C_C**2/cparams_ms%IZj

    write(6,'("Number of impurity species: ",I16)')& 
         cparams_ms%num_impurity_species
    do i=1,cparams_ms%num_impurity_species
       if (cparams_ms%Zo(i).eq.10) then
          write(6,'("Ne with charge state: ",I16)') int(cparams_ms%Zj(i))
          write(6,'("Mean excitation energy I (eV)",E17.10)') &
               cparams_ms%IZj(i)/C_E
          write(6,'("Effective ion length scale a (a_0)",E17.10)') &
               cparams_ms%aZj(i)
       else if (cparams_ms%Zo(i).eq.18) then
          write(6,'("Ar with charge state: ",I16)') int(cparams_ms%Zj(i))
          write(6,'("Mean excitation energy I (eV)",E17.10)') &
               cparams_ms%IZj(i)/C_E
          write(6,'("Effective ion length scale a (a_0)",E17.10)') &
               cparams_ms%aZj(i)
       end if
    end do
    
  end subroutine load_params_ms


  subroutine load_params_ss(params)
    TYPE(KORC_PARAMS), INTENT(IN) 	:: params
    REAL(rp) 				:: Te
    ! Electron temperature
    REAL(rp) 				:: Ti
    ! Ion temperature
    REAL(rp) 				:: ne
    ! Background electron density
    REAL(rp) 				:: Zeff
    ! Effective atomic number of ions
    REAL(rp) 				:: dTau
    ! Subcycling time step in collisional time units (Tau)
    CHARACTER(MAX_STRING_LENGTH) 	:: ne_profile
    CHARACTER(MAX_STRING_LENGTH) 	:: Te_profile
    CHARACTER(MAX_STRING_LENGTH) 	:: Zeff_profile
    CHARACTER(MAX_STRING_LENGTH) 	:: filename
    REAL(rp) 				:: radius_profile
    REAL(rp) 				:: neo
    REAL(rp) 				:: Teo
    REAL(rp) 				:: Zeffo
    REAL(rp) 				:: n_ne
    REAL(rp) 				:: n_Te
    REAL(rp) 				:: n_Zeff
    REAL(rp), DIMENSION(4) 		:: a_ne
    REAL(rp), DIMENSION(4) 		:: a_Te
    REAL(rp), DIMENSION(4) 		:: a_Zeff
    LOGICAL 				:: axisymmetric
    REAL(rp)  ::  n_REr0
    REAL(rp)  ::  n_tauion
    REAL(rp)  ::  n_lamfront
    REAL(rp)  ::  n_lamback

    NAMELIST /CollisionParamsSingleSpecies/ Te, Ti, ne, Zeff, dTau

    NAMELIST /plasmaProfiles/ radius_profile,ne_profile,neo,n_ne,a_ne,&
         Te_profile,Teo,n_Te,a_Te,n_REr0,n_tauion,n_lamfront,n_lamback, &
         Zeff_profile,Zeffo,n_Zeff,a_Zeff,filename,axisymmetric


    open(unit=default_unit_open,file=TRIM(params%path_to_inputs), &
         status='OLD',form='formatted')
    read(default_unit_open,nml=CollisionParamsSingleSpecies)
    close(default_unit_open)

    cparams_ss%Te = Te*C_E
    cparams_ss%Ti = Ti*C_E
    cparams_ss%ne = ne
    cparams_ss%Zeff = Zeff
    cparams_ss%dTau = dTau

    cparams_ss%rD = SQRT(C_E0*cparams_ss%Te/(cparams_ss%ne*C_E**2*(1.0_rp + &
         cparams_ss%Te/cparams_ss%Ti)))

    cparams_ss%re = C_E**2/(4.0_rp*C_PI*C_E0*C_ME*C_C**2)
    cparams_ss%CoulombLogee = CLogee_wu(params,cparams_ss%ne,cparams_ss%Te)
    cparams_ss%CoulombLogei = CLogei_wu(params,cparams_ss%ne,cparams_ss%Te)
    
    cparams_ss%VTe = VTe_wu(cparams_ss%Te)
    cparams_ss%delta = cparams_ss%VTe/C_C
    cparams_ss%Gammaco = C_E**4/(4.0_rp*C_PI*C_E0**2)
    cparams_ss%Gammac = Gammac_wu(params,cparams_ss%ne,cparams_ss%Te)

    
    cparams_ss%Tauc = C_ME**2*cparams_ss%VTe**3/cparams_ss%Gammac
    cparams_ss%Tau = C_ME**2*C_C**3/cparams_ss%Gammac

    cparams_ss%Ec = C_ME*C_C/(C_E*cparams_ss%Tau)
    cparams_ss%ED = cparams_ss%ne*C_E**3*cparams_ss%CoulombLogee/ &
         (4.0_rp*C_PI*C_E0**2*cparams_ss%Te)

    cparams_ss%taur=6*C_PI*C_E0*(C_ME*C_C)**3/C_E**4
    
    !	ALLOCATE(cparams_ss%rnd_num(3,cparams_ss%rnd_dim))
    !	call RANDOM_NUMBER(cparams_ss%rnd_num)
    cparams_ss%rnd_num_count = 1_idef

    open(unit=default_unit_open,file=TRIM(params%path_to_inputs), &
         status='OLD',form='formatted')
    read(default_unit_open,nml=plasmaProfiles)
    close(default_unit_open)

    cparams_ss%P%a = radius_profile
    cparams_ss%P%ne_profile = TRIM(ne_profile)
    cparams_ss%P%neo = neo
    cparams_ss%P%n_ne = n_ne
    cparams_ss%P%a_ne = a_ne

    cparams_ss%P%Te_profile = TRIM(Te_profile)
    cparams_ss%P%Teo = Teo*C_E
    cparams_ss%P%n_Te = n_Te
    cparams_ss%P%a_Te = a_Te

    cparams_ss%P%Zeff_profile = TRIM(Zeff_profile)
    cparams_ss%P%Zeffo = Zeffo
    cparams_ss%P%n_Zeff = n_Zeff
    cparams_ss%P%a_Zeff = a_Zeff
  end subroutine load_params_ss


  subroutine initialize_collision_params(params)
    TYPE(KORC_PARAMS), INTENT(IN) :: params

    if (params%collisions) then

       write(6,'(/,"* * * * * * * INITIALIZING COLLISIONS * * * * * * *")')
       
       SELECT CASE (TRIM(params%collisions_model))
       CASE (MODEL1)
          call load_params_ss(params)
          
          SELECT CASE(TRIM(params%bound_electron_model))
          CASE ('NO_BOUND')
             call load_params_ms(params)
          CASE('HESSLOW')
             call load_params_ms(params)
          CASE('ROSENBLUTH')
             call load_params_ms(params)
          CASE DEFAULT
             write(6,'("Default case")')
          END SELECT
          
       CASE (MODEL2)
          call load_params_ms(params)
       CASE DEFAULT
          write(6,'("Default case")')
       END SELECT

       write(6,'("* * * * * * * * * * * * * * * * * * * * * * * * * *",/)')
       
    end if

    
  end subroutine initialize_collision_params


  subroutine normalize_params_ms(params)
    TYPE(KORC_PARAMS), INTENT(IN) :: params

    cparams_ms%Te = cparams_ms%Te/params%cpp%temperature
    cparams_ms%ne = cparams_ms%ne/params%cpp%density
    cparams_ms%nH = cparams_ms%nH/params%cpp%density
    cparams_ms%nef = cparams_ms%nef/params%cpp%density
    cparams_ms%neb = cparams_ms%neb/params%cpp%density
    if (ALLOCATED(cparams_ms%nz)) cparams_ms%nz = cparams_ms%nz/ &
         params%cpp%density
    if (ALLOCATED(cparams_ms%IZj)) cparams_ms%IZj = cparams_ms%IZj/ &
         params%cpp%energy
    cparams_ms%rD = cparams_ms%rD/params%cpp%length
    cparams_ms%re = cparams_ms%re/params%cpp%length
  end subroutine normalize_params_ms


  subroutine normalize_params_ss(params)
    !! Calculate constant quantities used in various functions within
    !! this module
    TYPE(KORC_PARAMS), INTENT(IN) :: params

    cparams_ss%Clog1 = -1.15_rp*LOG10(1.0E-6_rp*params%cpp%density)
    cparams_ss%Clog2 = 2.3_rp*LOG10(params%cpp%temperature/C_E)
    cparams_ss%Clog0_1 = -LOG(1.0E-20_rp*params%cpp%density)/2._rp
    cparams_ss%Clog0_2 = LOG(1.0E-3 *params%cpp%temperature/C_E)
    cparams_ss%Gammaco = cparams_ss%Gammaco*params%cpp%density* &
         params%cpp%time/(params%cpp%mass**2*params%cpp%velocity**3)
    cparams_ss%VTeo = SQRT(params%cpp%temperature/C_ME)/params%cpp%velocity
    cparams_ss%deltao = params%cpp%velocity/C_C

    cparams_ss%Te = cparams_ss%Te/params%cpp%temperature
    cparams_ss%Ti = cparams_ss%Ti/params%cpp%temperature
    cparams_ss%ne = cparams_ss%ne/params%cpp%density
    cparams_ss%rD = cparams_ss%rD/params%cpp%length
    cparams_ss%re = cparams_ss%re/params%cpp%length
    cparams_ss%VTe = cparams_ss%VTe/params%cpp%velocity
    cparams_ss%Gammac = cparams_ss%Gammac*params%cpp%time/ &
         (params%cpp%mass**2*params%cpp%velocity**3)
    cparams_ss%Tau = cparams_ss%Tau/params%cpp%time
    cparams_ss%Tauc = cparams_ss%Tauc/params%cpp%time
    cparams_ss%Ec = cparams_ss%Ec/params%cpp%Eo
    cparams_ss%ED = cparams_ss%ED/params%cpp%Eo

    cparams_ss%taur=cparams_ss%taur/params%cpp%time
    
    cparams_ss%P%a = cparams_ss%P%a/params%cpp%length
    cparams_ss%P%neo = cparams_ss%P%neo/params%cpp%density
    cparams_ss%P%Teo = cparams_ss%P%Teo/params%cpp%temperature
  end subroutine normalize_params_ss


  subroutine normalize_collisions_params(params)
    TYPE(KORC_PARAMS), INTENT(IN) :: params

    if (params%collisions) then
       SELECT CASE (TRIM(params%collisions_model))
       CASE (MODEL1)
          call normalize_params_ss(params)

          SELECT CASE(TRIM(params%bound_electron_model))
          CASE ('NO_BOUND')
             call normalize_params_ms(params)
          CASE('HESSLOW')
             call normalize_params_ms(params)
          CASE('ROSENBLUTH')
             call normalize_params_ms(params)
          CASE DEFAULT
             write(6,'("Default case")')
          END SELECT
             
       CASE (MODEL2)
          call normalize_params_ms(params)
       CASE DEFAULT
          write(6,'("Default case")')
       END SELECT
    end if
  end subroutine normalize_collisions_params


  subroutine collision_force(spp,U,Fcoll)
    !! For multiple-species collisions
    !! J. R. Martin-Solis et al. PoP 22, 092512 (2015)
    !! if (params%collisions .AND. (TRIM(params%collisions_model) .EQ.
    !! 'MULTIPLE_SPECIES')) then call collision_force(spp(ii),U_os,Fcoll)
    !!	U_RC = U_RC + a*Fcoll/spp(ii)%q end if

    TYPE(SPECIES), INTENT(IN) 		:: spp
    REAL(rp), DIMENSION(3), INTENT(IN) 	:: U
    REAL(rp), DIMENSION(3), INTENT(OUT) :: Fcoll
    REAL(rp), DIMENSION(3) 		:: V
    REAL(rp), DIMENSION(3) 		:: Fcolle
    REAL(rp), DIMENSION(3) 		:: Fcolli
    REAL(rp) 				:: gamma
    REAL(rp) 				:: tmp
    REAL(rp) 				:: ae
    REAL(rp) 				:: ai
    REAL(rp) 				:: Clog_ef
    REAL(rp) 				:: Clog_eb
    REAL(rp) 				:: Clog_eH
    REAL(rp) 				:: Clog_eZj
    REAL(rp) 				:: Clog_eZo
    INTEGER 				:: ppi

    gamma = SQRT(1.0_rp + DOT_PRODUCT(U,U))
    V = U/gamma

    tmp = (gamma - 1.0_rp)*SQRT(gamma + 1.0_rp)
    Clog_ef = log(0.5_rp*tmp*(cparams_ms%rD/cparams_ms%re)/gamma)
    ae = cparams_ms%nef*Clog_ef
    do ppi=1_idef,cparams_ms%num_impurity_species
       Clog_eb = log(tmp*cparams_ms%Ee_IZj(ppi))
       ae = ae + cparams_ms%neb(ppi)*Clog_eb
    end do

    tmp = (gamma**2 - 1.0_rp)/gamma
    Clog_eH = log( tmp*(cparams_ms%rD/cparams_ms%re) )
    ai = cparams_ms%nH*Clog_eH
    do ppi=1_idef,cparams_ms%num_impurity_species
       Clog_eZj = log( cparams_ms%rD/(cparams_ms%Zj(ppi)* &
            cparams_ms%re*cparams_ms%Ee_IZj(ppi)) )
       Clog_eZo = log(tmp*cparams_ms%Ee_IZj(ppi))
       ai = ai + &
            cparams_ms%nz(ppi)*(Clog_eZj*cparams_ms%Zj(ppi)**2 + &
            Clog_eZo*cparams_ms%Zo(ppi)**2)
    end do

    tmp = gamma*(gamma + 1.0_rp)/(SQRT(DOT_PRODUCT(U,U))**3)
    Fcolle = -4.0_rp*C_PI*ae*spp%m*(cparams_ms%re**2)*tmp*U

    tmp = gamma/(SQRT(DOT_PRODUCT(U,U))**3)
    Fcolli = -4.0_rp*C_PI*ai*spp%m*(cparams_ms%re**2)*tmp*U

    Fcoll = Fcolle + Fcolli
  end subroutine collision_force


  subroutine define_collisions_time_step(params)
    TYPE(KORC_PARAMS), INTENT(IN) 	:: params
    INTEGER(ip) 			:: iterations
    REAL(rp) 				:: E
    REAL(rp) 				:: v
    REAL(rp) 				:: Tau
    REAL(rp), DIMENSION(3) 		:: nu
    REAL(rp) 				:: num_collisions_in_simulation


    if (params%collisions) then
       E = C_ME*C_C**2 + params%minimum_particle_energy*params%cpp%energy
       v = SQRT(1.0_rp - (C_ME*C_C**2/E)**2)
       nu = (/nu_S(params,v),nu_D(params,v),nu_par(v)/)
       Tau = MINVAL( 1.0_rp/nu )

!       write(6,'("collision freqencies ",F25.12)') nu
       
       cparams_ss%subcycling_iterations = FLOOR(cparams_ss%dTau*Tau/ &
            params%dt,ip) + 1_ip

       num_collisions_in_simulation = params%simulation_time/Tau

       if (params%mpi_params%rank .EQ. 0) then
          write(6,'("* * * * * * * * * * * * * * SUBCYCLING FOR  &
               COLLISIONS * * * * * * * * * * * * * *")')

         write(6,'("Slowing down freqency (CF): ",E17.10)') &
               nu(1)/params%cpp%time
          write(6,'("Pitch angle scattering freqency (CB): ",E17.10)') &
               nu(2)/params%cpp%time
          write(6,'("Speed diffusion freqency (CA): ",E17.10)') &
               nu(3)/params%cpp%time
          
          write(6,'("The shorter collisional time in the simulations  &
               is: ",E217.10," s")') Tau*params%cpp%time
          write(6,'("Number of KORC iterations per collision: ",I16)')  &
               cparams_ss%subcycling_iterations
          write(6,'("Number of collisions in simulated time: ",E17.10)')  &
               num_collisions_in_simulation
          write(6,'("* * * * * * * * * * * * * * * * * * * * * * * * * * &
               * * * * * * * * * * * * * * *",/)')
       end if
    end if
  end subroutine define_collisions_time_step


  ! * * * * * * * * * * * *  * * * * * * * * * * * * * * * * * * * !
  ! * FUNCTIONS OF COLLISION OPERATOR FOR SINGLE-SPECIES PLASMAS * !
  ! * * * * * * * * * * * *  * * * * * * * * * * * * * * * * * * * !

  ! *_wu functions have physical units!
  
  function VTe_wu(Te)
    REAL(rp), INTENT(IN) 	:: Te
    !! In Joules
    REAL(rp) 			:: VTe_wu

    VTe_wu = SQRT(2.0_rp*Te/C_ME)
  end function VTe_wu


  function VTe(Te)
    !! Dimensionless temperature
    REAL(rp), INTENT(IN) 	:: Te
    REAL(rp) 				:: VTe

    VTe = SQRT(2.0_rp*Te)*cparams_ss%VTeo
  end function VTe


  function Gammac_wu(params,ne,Te)
    !! With units
    TYPE(KORC_PARAMS), INTENT(IN) 	:: params
    REAL(rp), INTENT(IN) 	:: ne
    REAL(rp), INTENT(IN) 	:: Te ! In Joules
    REAL(rp) 				:: Gammac_wu

    Gammac_wu = ne*CLogee_wu(params,ne,Te)*cparams_ss%Gammaco
  end function Gammac_wu


  function Gammacee(v,ne,Te)
    !! Dimensionless ne and Te
    REAL(rp), INTENT(IN) 	:: v
    REAL(rp), INTENT(IN) 	:: ne
    REAL(rp), INTENT(IN) 	:: Te
    REAL(rp) 				:: Gammacee

    Gammacee = ne*CLogee(v,ne,Te)*cparams_ss%Gammaco
  end function Gammacee

  function CLog_wu(ne,Te)
    !! With units
    REAL(rp), INTENT(IN) 	:: ne
    !! ne is in m^-3 and below is converted to cm^-3
    REAL(rp), INTENT(IN) 	:: Te ! In Joules
    REAL(rp) 				:: CLog_wu

    CLog_wu = 25.3_rp - 1.15_rp*LOG10(1E-6_rp*ne) + 2.3_rp*LOG10(Te/C_E)
    
  end function CLog_wu

  function CLog0_wu(ne,Te)
    !! With units
    REAL(rp), INTENT(IN) 	:: ne
    !! ne is in m^-3 and below is converted to cm^-3
    REAL(rp), INTENT(IN) 	:: Te ! In Joules
    REAL(rp) 				:: CLog0_wu

    CLog0_wu = 14.9_rp - LOG(1E-20_rp*ne)/2._rp + LOG(1E-3_rp*Te/C_E)
    
  end function CLog0_wu

  function CLogee_wu(params,ne,Te)
    
    !! With units
    TYPE(KORC_PARAMS), INTENT(IN) 	:: params
    REAL(rp), INTENT(IN) 	:: ne
    !! ne is in m^-3 and below is converted to cm^-3
    REAL(rp), INTENT(IN) 	:: Te ! In Joules
    REAL(rp) 				:: CLogee_wu
    REAL(rp)  :: k=5._rp
    
    CLogee_wu = CLog0_wu(ne,Te)+ &
         log(1+(2*(params%minimum_particle_g-1)/ &
         (VTe_wu(Te)/C_C)**2)**(k/2._rp))/k
  end function CLogee_wu

  function CLogei_wu(params,ne,Te)
    
    !! With units
    TYPE(KORC_PARAMS), INTENT(IN) 	:: params
    REAL(rp), INTENT(IN) 	:: ne
    !! ne is in m^-3 and below is converted to cm^-3
    REAL(rp), INTENT(IN) 	:: Te ! In Joules
    REAL(rp) 				:: CLogei_wu
    REAL(rp)  :: k=5._rp
    REAL(rp)  :: p

    p=sqrt(params%minimum_particle_g**2-1)
    
    CLogei_wu = CLog0_wu(ne,Te)+ &
         log(1+(2*p/(VTe_wu(Te)/C_C))**k)/k
  end function CLogei_wu
  
  function CLog(ne,Te) ! Dimensionless ne and Te
    REAL(rp), INTENT(IN) 	:: ne
    REAL(rp), INTENT(IN) 	:: Te
    REAL(rp) 				:: CLog

    CLog = 25.3_rp - 1.15_rp*LOG10(ne) + 2.3_rp*LOG10(Te) + &
         cparams_ss%CLog1 + cparams_ss%CLog2
  end function CLog

  function CLog0(ne,Te) ! Dimensionless ne and Te
    REAL(rp), INTENT(IN) 	:: ne
    REAL(rp), INTENT(IN) 	:: Te
    REAL(rp) 				:: CLog0

    CLog0 = 14.9_rp - LOG(ne)/2._rp + LOG(Te) + &
         cparams_ss%CLog0_1 + cparams_ss%CLog0_2
  end function CLog0
  
  function CLogee(v,ne,Te)
    
    REAL(rp), INTENT(IN) 	:: v
    REAL(rp), INTENT(IN) 	:: ne
    !! ne is in m^-3 and below is converted to cm^-3
    REAL(rp), INTENT(IN) 	:: Te ! In Joules
    REAL(rp) 				:: CLogee
    REAL(rp)  :: k=5._rp
    REAL(rp)  :: gam

    gam=1/sqrt(1-v**2)
    
    CLogee = CLog0(ne,Te)+ &
         log(1+(2*(gam-1)/VTe(Te)**2)**(k/2._rp))/k
  end function CLogee

  function CLogei(v,ne,Te)
    
    REAL(rp), INTENT(IN) 	:: v
    REAL(rp), INTENT(IN) 	:: ne
    !! ne is in m^-3 and below is converted to cm^-3
    REAL(rp), INTENT(IN) 	:: Te ! In Joules
    REAL(rp) 				:: CLogei
    REAL(rp)  :: k=5._rp
    REAL(rp)  :: gam,p

    gam=1/sqrt(1-v**2)
    p=gam*v
    
    CLogei = CLog0(ne,Te)+log(1+(2*p/VTe(Te))**k)/k
  end function CLogei
  
  function delta(Te)
    REAL(rp), INTENT(IN) 	:: Te
    REAL(rp) 				:: delta

    delta = VTe(Te)*cparams_ss%deltao
  end function delta


  function psi(x)
    REAL(rp), INTENT(IN) 	:: x
    REAL(rp) 				:: psi

    psi = 0.5_rp*(ERF(x) - 2.0_rp*x*EXP(-x**2)/SQRT(C_PI))/x**2
  end function psi


  function CA(v)
    REAL(rp), INTENT(IN) 	:: v
    REAL(rp) 				:: CA
    REAL(rp) 				:: x

    x = v/cparams_ss%VTe
    CA  = cparams_ss%Gammac*psi(x)/v
  end function CA


  function CA_SD(v,ne,Te)
    REAL(rp), INTENT(IN) 	:: v
    REAL(rp), INTENT(IN) 	:: ne
    REAL(rp), INTENT(IN) 	:: Te
    REAL(rp) 				:: CA_SD
    REAL(rp) 				:: x

    x = v/VTe(Te)
    CA_SD  = Gammacee(v,ne,Te)*psi(x)/v

!    write(6,'("ne, "E17.10)') ne
!    write(6,'("Te, "E17.10)') Te
    
!    write(6,'("x, "E17.10)') x
!    write(6,'("psi, "E17.10)') psi(x)
!    write(6,'("Gammac, "E17.10)') Gammac(ne,Te)
    
  end function CA_SD
  
  function dCA_SD(v,me,ne,Te)
    REAL(rp), INTENT(IN) 	:: v
    REAL(rp), INTENT(IN) 	:: me
    REAL(rp), INTENT(IN) 	:: ne
    REAL(rp), INTENT(IN) 	:: Te
    REAL(rp) 				:: dCA_SD
    REAL(rp) 				:: x
    real(rp)  :: gam

    gam=1/sqrt(1-v**2)
    x = v/VTe(Te)
    dCA_SD  = Gammacee(v,ne,Te)*((2*(gam*v)**2-1)*psi(x)+ &
         2.0_rp*x*EXP(-x**2)/SQRT(C_PI))/(gam**3*me*v**2)
  end function dCA_SD
  
  function CF(params,v)
    TYPE(KORC_PARAMS), INTENT(IN) 	:: params
    REAL(rp), INTENT(IN) 	:: v
    REAL(rp) 				:: CF
    REAL(rp) 				:: CF_temp
    REAL(rp) 				:: x
    INTEGER :: i
    REAL(rp)  :: k=5._rp

    x = v/cparams_ss%VTe
    CF  = cparams_ss%Gammac*psi(x)/cparams_ss%Te

    if (params%bound_electron_model.eq.'HESSLOW') then
       CF_temp=CF
       do i=1,cparams_ms%num_impurity_species
          CF_temp=CF_temp+CF*cparams_ms%nz(i)/cparams_ms%ne* &
               (cparams_ms%Zo(i)-cparams_ms%Zj(i))/ &
               CLogee(v,cparams_ss%ne,cparams_ss%Te)* &
               (log(1+h_j(i,v)**k)/k-v**2) 
       end do
       CF=CF_temp
       
    else if (params%bound_electron_model.eq.'ROSENBLUTH') then
       CF_temp=CF
       do i=1,cparams_ms%num_impurity_species
          CF_temp=CF_temp+CF*cparams_ms%nz(i)/cparams_ms%ne* &
               (cparams_ms%Zo(i)-cparams_ms%Zj(i))/2._rp
       end do
       CF=CF_temp
       
    end if
    
  end function CF


  function CF_SD(params,v,ne,Te)
    TYPE(KORC_PARAMS), INTENT(IN) 	:: params
    REAL(rp), INTENT(IN) 	:: v
    REAL(rp), INTENT(IN) 	:: ne
    REAL(rp), INTENT(IN) 	:: Te
    REAL(rp) 				:: CF_SD
    REAL(rp) 				:: CF_temp
    REAL(rp) 				:: x
    INTEGER :: i
    REAL(rp)  :: k=5._rp

    x = v/VTe(Te)
    CF_SD  = Gammacee(v,ne,Te)*psi(x)/Te

    if (params%bound_electron_model.eq.'HESSLOW') then
       CF_temp=CF_SD
       do i=1,cparams_ms%num_impurity_species
          CF_temp=CF_temp+CF_SD*cparams_ms%nz(i)/cparams_ms%ne* &
               (cparams_ms%Zo(i)-cparams_ms%Zj(i))/ &
               CLogee(v,ne,Te)*(log(1+h_j(i,v)**k)/k-v**2) 
       end do
       CF_SD=CF_temp
       
    else if (params%bound_electron_model.eq.'ROSENBLUTH') then
       CF_temp=CF_SD
       do i=1,cparams_ms%num_impurity_species
          CF_temp=CF_temp+CF_SD*cparams_ms%nz(i)/cparams_ms%ne* &
               (cparams_ms%Zo(i)-cparams_ms%Zj(i))/2._rp
       end do
       CF_SD=CF_temp
       
    end if
    
  end function CF_SD

  function CB_ee(v)
    REAL(rp), INTENT(IN) 	:: v
    REAL(rp) 				:: CB_ee
    REAL(rp) 				:: x

    x = v/cparams_ss%VTe
    CB_ee  = (0.5_rp*cparams_ss%Gammac/v)*(ERF(x) - &
         psi(x) + 0.5_rp*cparams_ss%delta**4*x**2 )
  end function CB_ee

  function CB_ei(params,v)
    TYPE(KORC_PARAMS), INTENT(IN) 	:: params
    REAL(rp), INTENT(IN) 	:: v
    REAL(rp) 				:: CB_ei
    REAL(rp) 				:: CB_ei_temp
    REAL(rp) 				:: x
    INTEGER :: i

    x = v/cparams_ss%VTe
    CB_ei  = (0.5_rp*cparams_ss%Gammac/v)*(cparams_ss%Zeff* &
         CLogei(v,cparams_ss%ne,cparams_ss%Te)/ &
         CLogee(v,cparams_ss%ne,cparams_ss%Te))


    if (params%bound_electron_model.eq.'HESSLOW') then
       CB_ei_temp=CB_ei
       do i=1,cparams_ms%num_impurity_species
          CB_ei_temp=CB_ei_temp+CB_ei*cparams_ms%nz(i)/(cparams_ms%ne* &
               cparams_ss%Zeff*CLogei(v,cparams_ss%ne,cparams_ss%Te))* &
               g_j(i,v)
       end do
       CB_ei=CB_ei_temp
       
    else if (params%bound_electron_model.eq.'ROSENBLUTH') then
       CB_ei_temp=CB_ei
       do i=1,cparams_ms%num_impurity_species
          CB_ei_temp=CB_ei_temp+CB_ei*cparams_ms%nz(i)/cparams_ms%ne* &
               (cparams_ms%Zo(i)-cparams_ms%Zj(i))/2._rp
       end do
       CB_ei=CB_ei_temp
       
    end if
    
  end function CB_ei

  function CB_ee_SD(v,ne,Te,Zeff)
    REAL(rp), INTENT(IN) 	:: v
    REAL(rp), INTENT(IN) 	:: ne
    REAL(rp), INTENT(IN) 	:: Te
    REAL(rp), INTENT(IN) 	:: Zeff
    REAL(rp) 				:: CB_ee_SD
    REAL(rp) 				:: x

    x = v/VTe(Te)
    CB_ee_SD  = (0.5_rp*Gammacee(v,ne,Te)/v)* &
         (ERF(x) - psi(x) + &
         0.5_rp*delta(Te)**4*x**2 )
  end function CB_ee_SD

  function CB_ei_SD(params,v,ne,Te,Zeff)
    TYPE(KORC_PARAMS), INTENT(IN) 	:: params
    REAL(rp), INTENT(IN) 	:: v
    REAL(rp), INTENT(IN) 	:: ne
    REAL(rp), INTENT(IN) 	:: Te
    REAL(rp), INTENT(IN) 	:: Zeff
    REAL(rp) 				:: CB_ei_SD
    REAL(rp) 				:: CB_ei_temp
    REAL(rp) 				:: x
    INTEGER :: i

    x = v/VTe(Te)
    CB_ei_SD  = (0.5_rp*Gammacee(v,ne,Te)/v)* &
         (Zeff*CLogei(v,ne,Te)/CLogee(v,ne,Te))

    if (params%bound_electron_model.eq.'HESSLOW') then
       CB_ei_temp=CB_ei_SD
       do i=1,cparams_ms%num_impurity_species
          CB_ei_temp=CB_ei_temp+CB_ei_SD*cparams_ms%nz(i)/(cparams_ms%ne* &
               Zeff*CLogei(v,ne,Te))*g_j(i,v)
       end do
       CB_ei_SD=CB_ei_temp
       
    else if (params%bound_electron_model.eq.'ROSENBLUTH') then
       CB_ei_temp=CB_ei_SD
       do i=1,cparams_ms%num_impurity_species
          CB_ei_temp=CB_ei_temp+CB_ei_SD*cparams_ms%nz(i)/cparams_ms%ne* &
               (cparams_ms%Zo(i)-cparams_ms%Zj(i))/2._rp
       end do
       CB_ei_SD=CB_ei_temp
       
    end if
    
  end function CB_ei_SD

  function nu_S(params,v)
    ! Slowing down collision frequency
    TYPE(KORC_PARAMS), INTENT(IN) 	:: params
    REAL(rp), INTENT(IN) 	:: v
      ! Normalised particle speed
    REAL(rp) 				:: nu_S
    REAL(rp) 				:: nu_S_temp
    REAL(rp) 				:: p
    
    p = v/SQRT(1.0_rp - v**2)
    nu_S = 2.0_rp*CF(params,v)/p
        
  end function nu_S

  function h_j(i,v)
    INTEGER, INTENT(IN) 	:: i
    REAL(rp), INTENT(IN) 	:: v   
    REAL(rp)  :: gam
    REAL(rp)  :: p
    REAL(rp)  :: h_j

    gam=1/sqrt(1-v**2)
    p=v*gam
    
    h_j=p*sqrt(gam-1)/cparams_ms%IZj(i)
    
  end function h_j

  function g_j(i,v)
    INTEGER, INTENT(IN) 	:: i
    REAL(rp), INTENT(IN) 	:: v   
    REAL(rp)  :: gam
    REAL(rp)  :: p
    REAL(rp)  :: g_j

    gam=1/sqrt(1-v**2)
    p=v*gam
    
    g_j=2._rp/3._rp*((cparams_ms%Zo(i)**2-cparams_ms%Zj(i)**2)* &
         log((p*cparams_ms%aZj(i))**(3._rp/2._rp)+1)- &
         (cparams_ms%Zo(i)-cparams_ms%Zj(i))**2* &
         (p*cparams_ms%aZj(i))**(3._rp/2._rp)/ &
         ((p*cparams_ms%aZj(i))**(3._rp/2._rp)+1))
    
  end function g_j

  function nu_D(params,v)
    ! perpendicular diffusion (pitch angle scattering) collision frequency
    REAL(rp), INTENT(IN) 	:: v
    TYPE(KORC_PARAMS), INTENT(IN) 	:: params
      ! Normalised particle speed
    REAL(rp) 				:: nu_D
    REAL(rp) 				:: p

    p = v/SQRT(1.0_rp - v**2)
    nu_D = 2.0_rp*(CB_ee(v)+CB_ei(params,v))/p**2
  end function nu_D


  function nu_par(v)
    ! parallel (speed diffusion) collision frequency
    REAL(rp), INTENT(IN) 	:: v
      ! Normalised particle speed
    REAL(rp) 				:: nu_par
    REAL(rp) 				:: p

    p = v/SQRT(1.0_rp - v**2)
    nu_par = 2.0_rp*CA(v)/p**2
  end function nu_par


  function fun(v)
    REAL(rp), INTENT(IN) 	:: v
    REAL(rp) 				:: fun
    REAL(rp) 				:: x

    x = v/cparams_ss%VTe
    fun = 2.0_rp*( 1.0_rp/x + x )*EXP(-x**2)/SQRT(C_PI) - ERF(x)/x**2 - psi(v)
  end function fun


  function cross(a,b)
    REAL(rp), DIMENSION(3), INTENT(IN) 	:: a
    REAL(rp), DIMENSION(3), INTENT(IN) 	:: b
    REAL(rp), DIMENSION(3) 				:: cross

    cross(1) = a(2)*b(3) - a(3)*b(2)
    cross(2) = a(3)*b(1) - a(1)*b(3)
    cross(3) = a(1)*b(2) - a(2)*b(1)
  end function cross

  subroutine unitVectorsC(B,b1,b2,b3)
    REAL(rp), DIMENSION(3), INTENT(IN) 	:: B
    REAL(rp), DIMENSION(3), INTENT(OUT) :: b1
    REAL(rp), DIMENSION(3), INTENT(OUT) :: b2
    REAL(rp), DIMENSION(3), INTENT(OUT) :: b3

    b1 = B/SQRT(DOT_PRODUCT(B,B))

    b2 = cross(b1,(/0.0_rp,0.0_rp,1.0_rp/))
    b2 = b2/SQRT(DOT_PRODUCT(b2,b2))

    b3 = cross(b1,b2)
    b3 = b3/SQRT(DOT_PRODUCT(b3,b3))
  end subroutine unitVectorsC

  subroutine unitVectors_p(b_unit_X,b_unit_Y,b_unit_Z,b1_X,b1_Y,b1_Z, &
            b2_X,b2_Y,b2_Z,b3_X,b3_Y,b3_Z)
    REAL(rp), DIMENSION(8), INTENT(IN) 	:: b_unit_X,b_unit_Y,b_unit_Z
    REAL(rp), DIMENSION(8), INTENT(OUT) :: b1_X,b1_Y,b1_Z
    REAL(rp), DIMENSION(8), INTENT(OUT) :: b2_X,b2_Y,b2_Z
    REAL(rp), DIMENSION(8), INTENT(OUT) :: b3_X,b3_Y,b3_Z
    REAL(rp), DIMENSION(8) :: b2mag,b3mag
    integer(ip) :: cc

    !$OMP SIMD 
!    !$OMP& aligned(b1_X,b1_Y,b1_Z,b_unit_X,b_unit_Y,b_unit_Z, &
!    !$OMP& b2_X,b2_Y,b2_Z,b2mag,b3_X,b3_Y,b3_Z,b3mag)
    do cc=1_idef,8_idef
       b1_X(cc) = b_unit_X(cc)
       b1_Y(cc) = b_unit_Y(cc)
       b1_Z(cc) = b_unit_Z(cc)

       b2_X(cc) = b1_Y(cc)
       b2_Y(cc) = -b1_X(cc)
       b2_Z(cc) = 0._rp

       b2mag(cc)=sqrt(b2_X(cc)*b2_X(cc)+b2_Y(cc)*b2_Y(cc)+b2_Z(cc)*b2_Z(cc))

       b2_X(cc) = b2_X(cc)/b2mag(cc)
       b2_Y(cc) = b2_Y(cc)/b2mag(cc)
       b2_Z(cc) = b2_Z(cc)/b2mag(cc)

       b3_X(cc)=b1_Y(cc)*b2_Z(cc)-b1_Z(cc)*b2_Y(cc)
       b3_Y(cc)=b1_Z(cc)*b2_X(cc)-b1_X(cc)*b2_Z(cc)
       b3_Z(cc)=b1_X(cc)*b2_Y(cc)-b1_Y(cc)*b2_X(cc)

       b3mag(cc)=sqrt(b3_X(cc)*b3_X(cc)+b3_Y(cc)*b3_Y(cc)+b3_Z(cc)*b3_Z(cc))

       b3_X(cc) = b3_X(cc)/b3mag(cc)
       b3_Y(cc) = b3_Y(cc)/b3mag(cc)
       b3_Z(cc) = b3_Z(cc)/b3mag(cc)
    end do
    !$OMP END SIMD
    
  end subroutine unitVectors_p

  subroutine check_collisions_params(spp)
#ifdef PARALLEL_RANDOM
    USE omp_lib
#endif
    TYPE(SPECIES), INTENT(IN) :: spp
    INTEGER aux

    aux = cparams_ss%rnd_num_count + 2_idef*INT(spp%ppp,idef)

    if (aux.GE.cparams_ss%rnd_dim) then
#ifdef PARALLEL_RANDOM
       cparams_ss%rnd_num = get_random()
#else
       call RANDOM_NUMBER(cparams_ss%rnd_num)
#endif
       cparams_ss%rnd_num_count = 1_idef
    end if
  end subroutine check_collisions_params

  ! * * * * * * * * * * * *  * * * * * * * * * * * * * * * * * * * !
  ! * FUNCTIONS OF COLLISION OPERATOR FOR SINGLE-SPECIES PLASMAS * !
  ! * * * * * * * * * * * *  * * * * * * * * * * * * * * * * * * * !




  subroutine include_CoulombCollisions_FO_p(tt,params,X_X,X_Y,X_Z, &
       U_X,U_Y,U_Z,B_X,B_Y,B_Z,me,P,flag)
    !! This subroutine performs a Stochastic collision process consistent
    !! with the Fokker-Planck model for relativitic electron colliding with
    !! a thermal (Maxwellian) plasma. The collision operator is in spherical
    !! coordinates of the form found in Papp et al., NF (2011). CA
    !! corresponds to the parallel (speed diffusion) process, CF corresponds
    !! to a slowing down (momentum loss) process, and CB corresponds to a
    !! perpendicular diffusion process. Ordering of the processes are
    !! $$ \sqrt{CB}\gg CB \gg CF \sim \sqrt{CA} \gg CA,$$
    !! and only the dominant terms are kept.
    TYPE(PROFILES), INTENT(IN)                                 :: P
    TYPE(KORC_PARAMS), INTENT(IN) 		:: params
    REAL(rp), DIMENSION(8), INTENT(IN) 	:: X_X,X_Y,X_Z
    REAL(rp), DIMENSION(8)  	:: Y_R,Y_PHI,Y_Z
    REAL(rp), DIMENSION(8), INTENT(INOUT) 	:: U_X,U_Y,U_Z

    REAL(rp), DIMENSION(8) 			:: ne,Te,Zeff
    INTEGER(is), DIMENSION(8), INTENT(IN) 			:: flag
    REAL(rp), INTENT(IN)  :: me

    INTEGER(ip), INTENT(IN) 			:: tt

    REAL(rp), DIMENSION(8), INTENT(IN) 		:: B_X,B_Y,B_Z

    REAL(rp), DIMENSION(8) 		:: b_unit_X,b_unit_Y,b_unit_Z
    REAL(rp), DIMENSION(8) 		:: b1_X,b1_Y,b1_Z
    REAL(rp), DIMENSION(8) 		:: b2_X,b2_Y,b2_Z
    REAL(rp), DIMENSION(8) 		:: b3_X,b3_Y,b3_Z
    REAL(rp), DIMENSION(8) 		:: Bmag

    
    REAL(rp), DIMENSION(8,3) 			:: dW
    !! 3D Weiner process
    REAL(rp), DIMENSION(8,3) 			:: rnd1

    REAL(rp) 					:: dt,time
    REAL(rp), DIMENSION(8) 					:: um
    REAL(rp), DIMENSION(8) 					:: dpm
    REAL(rp), DIMENSION(8) 					:: vm
    REAL(rp), DIMENSION(8) 					:: pm

    REAL(rp),DIMENSION(8) 			:: Ub_X,Ub_Y,Ub_Z
    REAL(rp), DIMENSION(8) 			:: xi
    REAL(rp), DIMENSION(8) 			:: dxi
    REAL(rp), DIMENSION(8)  			:: phi
    REAL(rp), DIMENSION(8)  			:: dphi
    !! speed of particle
    REAL(rp),DIMENSION(8) 					:: CAL
    REAL(rp),DIMENSION(8) 					:: dCAL
    REAL(rp),DIMENSION(8) 					:: CFL
    REAL(rp),DIMENSION(8) 					:: CBL

    integer(ip) :: cc

    if (MODULO(params%it+tt,cparams_ss%subcycling_iterations) .EQ. 0_ip) then
       dt = REAL(cparams_ss%subcycling_iterations,rp)*params%dt
       time=(params%it+tt)*params%dt
       ! subcylcling iterations a fraction of fastest collision frequency,
       ! where fraction set by dTau in namelist &CollisionParamsSingleSpecies

       call cart_to_cyl_p(X_X,X_Y,X_Z,Y_R,Y_PHI,Y_Z)

       if (params%profile_model.eq.'ANALYTICAL') then
          call analytical_profiles_p(time,params,Y_R,Y_Z,P,ne,Te,Zeff)
       else  if (params%profile_model.eq.'EXTERNAL') then          
          call interp_FOcollision_p(Y_R,Y_PHI,Y_Z,ne,Te,Zeff)
       end if
          
       !$OMP SIMD
!       !$OMP& aligned(um,pm,vm,U_X,U_Y,U_Z,Bmag,B_X,B_Y,B_Z, &
!       !$OMP& b_unit_X,b_unit_Y,b_unit_Z,xi)
       do cc=1_idef,8_idef

          um(cc) = SQRT(U_X(cc)*U_X(cc)+U_Y(cc)*U_Y(cc)+U_Z(cc)*U_Z(cc))
          pm(cc)=me*um(cc)
          vm(cc) = um(cc)/SQRT(1.0_rp + um(cc)*um(cc))
          ! um is gamma times v, this solves for v
          
          Bmag(cc)= SQRT(B_X(cc)*B_X(cc)+B_Y(cc)*B_Y(cc)+B_Z(cc)*B_Z(cc))

          b_unit_X(cc)=B_X(cc)/Bmag(cc)
          b_unit_Y(cc)=B_Y(cc)/Bmag(cc)
          b_unit_Z(cc)=B_Z(cc)/Bmag(cc)

          xi(cc)=(U_X(cc)*b_unit_X(cc)+U_Y(cc)*b_unit_Y(cc)+ &
               U_Z(cc)*b_unit_Z(cc))/um(cc)
          
          ! pitch angle in b_unit reference frame
       end do
       !$OMP END SIMD

!       write(6,'("vm: ",E17.10)') vm
!       write(6,'("xi: ",E17.10)') xi
       
       call unitVectors_p(b_unit_X,b_unit_Y,b_unit_Z,b1_X,b1_Y,b1_Z, &
            b2_X,b2_Y,b2_Z,b3_X,b3_Y,b3_Z)
          ! b1=b_unit, (b1,b2,b3) is right-handed

       !$OMP SIMD
!       !$OMP& aligned(phi,U_X,U_Y,U_Z,b3_X,b3_Y,b3_Z,b2_X,b2_Y,b2_Z)
       do cc=1_idef,8_idef
          phi(cc) = atan2((U_X(cc)*b3_X(cc)+U_Y(cc)*b3_Y(cc)+ &
               U_Z(cc)*b3_Z(cc)), &
               (U_X(cc)*b2_X(cc)+U_Y(cc)*b2_Y(cc)+U_Z(cc)*b2_Z(cc)))
          ! azimuthal angle in b_unit refernce frame
       end do
       !$OMP END SIMD

!       write(6,'("phi: ",E17.10)') phi
       
       !$OMP SIMD
!       !$OMP& aligned(rnd1,dW,CAL,dCAL,CFL,CBL,vm,ne,Te,Zeff,dpm, &
!       !$OMP& flag,dxi,xi,pm,dphi,um,Ub_X,Ub_Y,Ub_Z,U_X,U_Y,U_Z, &
!       !$OMP& b1_X,b1_Y,b1_Z,b2_X,b2_Y,b2_Z,b3_X,b3_Y,b3_Z)
       do cc=1_idef,8_idef
          
#ifdef PARALLEL_RANDOM
          ! uses C library to generate normal_distribution random variables,
          ! preserving parallelization where Fortran random number generator
          ! does not
          rnd1(cc,1) = get_random()
          rnd1(cc,2) = get_random()
          rnd1(cc,3) = get_random()
#else
          call RANDOM_NUMBER(rnd1)
#endif

          dW(cc,1) = SQRT(3*dt)*(-1+2*rnd1(cc,1))     
          dW(cc,2) = SQRT(3*dt)*(-1+2*rnd1(cc,2))
          dW(cc,3) = SQRT(3*dt)*(-1+2*rnd1(cc,3)) 
          ! 3D Weiner process 

          CAL(cc) = CA_SD(vm(cc),ne(cc),Te(cc))
          dCAL(cc)= dCA_SD(vm(cc),me,ne(cc),Te(cc))
          CFL(cc) = CF_SD(params,vm(cc),ne(cc),Te(cc))
          CBL(cc) = (CB_ee_SD(vm(cc),ne(cc),Te(cc),Zeff(cc))+ &
               CB_ei_SD(params,vm(cc),ne(cc),Te(cc),Zeff(cc)))


          dpm(cc)=REAL(flag(cc))*((-CFL(cc)+dCAL(cc))*dt+ &
               sqrt(2.0_rp*CAL(cc))*dW(cc,1))
          dxi(cc)=REAL(flag(cc))*(-2*xi(cc)*CBL(cc)/(pm(cc)*pm(cc))*dt- &
               sqrt(2.0_rp*CBL(cc)*(1-xi(cc)*xi(cc)))/pm(cc)*dW(cc,2))
          dphi(cc)=REAL(flag(cc))*(sqrt(2*CBL(cc))/(pm(cc)* &
               sqrt(1-xi(cc)*xi(cc)))*dW(cc,3))

          pm(cc)=pm(cc)+dpm(cc)
          xi(cc)=xi(cc)+dxi(cc)
          phi(cc)=phi(cc)+dphi(cc)

!          if (pm(cc)<0) pm(cc)=-pm(cc)

          ! Keep xi between [-1,1]
          if (xi(cc)>1) then
             xi(cc)=1-mod(xi(cc),1._rp)
          else if (xi(cc)<-1) then
             xi(cc)=-1-mod(xi(cc),-1._rp)             
          endif

          ! Keep phi between [0,pi]
!          if (phi(cc)>C_PI) then
!             phi(cc)=C_PI-mod(phi(cc),C_PI)
!          else if (phi(cc)<0) then
!             phi(cc)=mod(-phi(cc),C_PI)             
!          endif
          
          um(cc)=pm(cc)/me

          Ub_X(cc)=um(cc)*xi(cc)
          Ub_Y(cc)=um(cc)*sqrt(1-xi(cc)*xi(cc))*cos(phi(cc))
          Ub_Z(cc)=um(cc)*sqrt(1-xi(cc)*xi(cc))*sin(phi(cc))

          U_X(cc) = Ub_X(cc)*b1_X(cc)+Ub_Y(cc)*b2_X(cc)+Ub_Z(cc)*b3_X(cc)
          U_Y(cc) = Ub_X(cc)*b1_Y(cc)+Ub_Y(cc)*b2_Y(cc)+Ub_Z(cc)*b3_Y(cc)
          U_Z(cc) = Ub_X(cc)*b1_Z(cc)+Ub_Y(cc)*b2_Z(cc)+Ub_Z(cc)*b3_Z(cc)

       end do
       !$OMP END SIMD
       
!       if (tt .EQ. 1_ip) then
!          write(6,'("CA: ",E17.10)') CAL(1)
!          write(6,'("dCA: ",E17.10)') dCAL(1)
!          write(6,'("CF ",E17.10)') CFL(1)
!          write(6,'("CB: ",E17.10)') CBL(1)
!       end if

       
       do cc=1_idef,8_idef
          if (pm(cc).lt.0) then
             write(6,'("Momentum less than zero")')
             stop
          end if
       end do
       
    end if
  end subroutine include_CoulombCollisions_FO_p
  


  subroutine include_CoulombCollisions_GC_p(tt,params,Y_R,Y_PHI,Y_Z, &
       Ppll,Pmu,me,flag,P,R0,B0,lam,q0,EF0)

    TYPE(PROFILES), INTENT(IN)                                 :: P    
    TYPE(KORC_PARAMS), INTENT(IN) 		:: params
    REAL(rp), DIMENSION(8), INTENT(INOUT) 	:: Ppll
    REAL(rp), DIMENSION(8), INTENT(INOUT) 	:: Pmu
    REAL(rp), DIMENSION(8) 			:: Bmag
    REAL(rp), DIMENSION(8) 			:: E_R,E_PHI,E_Z
    REAL(rp), DIMENSION(8) 			:: B_R,B_PHI,B_Z
    REAL(rp), INTENT(IN) 			:: R0,B0,lam,q0,EF0
    REAL(rp), DIMENSION(8), INTENT(IN) 			:: Y_R,Y_PHI,Y_Z
    INTEGER(is), DIMENSION(8), INTENT(INOUT) 			:: flag
    REAL(rp), INTENT(IN) 			:: me
    REAL(rp), DIMENSION(8) 			:: ne,Te,Zeff
    REAL(rp), DIMENSION(8,2) 			:: dW
    REAL(rp), DIMENSION(8,2) 			:: rnd1
    REAL(rp) 					:: dt,time
    REAL(rp), DIMENSION(8) 					:: pm
    REAL(rp), DIMENSION(8)  					:: dp
    REAL(rp), DIMENSION(8)  					:: xi
    REAL(rp), DIMENSION(8)  					:: dxi
    REAL(rp), DIMENSION(8)  					:: v,gam
    !! speed of particle
    REAL(rp), DIMENSION(8) 					:: CAL
    REAL(rp) , DIMENSION(8)					:: dCAL
    REAL(rp), DIMENSION(8) 					:: CFL
    REAL(rp), DIMENSION(8) 					:: CBL
    integer(ip) :: cc
    integer(ip),INTENT(IN) :: tt

    
    if (MODULO(params%it+tt,cparams_ss%subcycling_iterations) .EQ. 0_ip) then
       dt = REAL(cparams_ss%subcycling_iterations,rp)*params%dt       
       time=(params%it+tt)*params%dt

       if (params%profile_model.eq.'ANALYTICAL') then
          call analytical_profiles_p(time,params,Y_R,Y_Z,P,ne,Te,Zeff)
          
          call analytical_fields_Bmag_p(R0,B0,lam,q0,EF0,Y_R,Y_PHI,Y_Z, &
               Bmag,E_PHI)

       else if (params%profile_model.eq.'EXTERNAL') then
       
          call interp_collision_p(Y_R,Y_PHI,Y_Z,B_R,B_PHI,B_Z,E_R,E_PHI,E_Z, &
               ne,Te,Zeff,flag)   

          !$OMP SIMD
!          !$OMP& aligned(Bmag,B_R,B_PHI,B_Z)
          do cc=1_idef,8_idef

             Bmag(cc)=sqrt(B_R(cc)*B_R(cc)+B_PHI(cc)*B_PHI(cc)+B_Z(cc)*B_Z(cc))

          end do
          !$OMP END SIMD

       end if
             
!       write(6,'("ne: "E17.10)') ne(1)
!       write(6,'("Te: "E17.10)') Te(1)
!       write(6,'("Bmag: "E17.10)') Bmag(1)
       
       !$OMP SIMD
!       !$OMP& aligned (pm,xi,v,Ppll,Bmag,Pmu)
       do cc=1_idef,8_idef
          ! Transform p_pll,mu to P,eta
          pm(cc) = SQRT(Ppll(cc)*Ppll(cc)+2*me*Bmag(cc)*Pmu(cc))
          xi(cc) = Ppll(cc)/pm(cc)

          gam(cc) = sqrt(1+pm(cc)*pm(cc))
          
          v(cc) = pm(cc)/gam(cc)
          ! normalized speed (v_K=v_P/c)
       end do
       !$OMP END SIMD

          
!       write(6,'("v: ",E17.10)') v
!       write(6,'("xi: ",E17.10)') xi

       !$OMP SIMD
!       !$OMP& aligned(rnd1,dW,CAL,dCAL,CFL,CBL,v,ne,Te,Zeff,dp, &
!       !$OMP& flag,dxi,xi,pm,Ppll,Pmu,Bmag)
       do cc=1_idef,8_idef
       
#ifdef PARALLEL_RANDOM
          rnd1(cc,1) = get_random()
          rnd1(cc,2) = get_random()
          !       rnd1(:,1) = get_random_mkl()
          !       rnd1(:,2) = get_random_mkl()
#else
          call RANDOM_NUMBER(rnd1)
#endif

          dW(cc,1) = SQRT(3*dt)*(-1+2*rnd1(cc,1))     
          dW(cc,2) = SQRT(3*dt)*(-1+2*rnd1(cc,2))     

          CAL(cc) = CA_SD(v(cc),ne(cc),Te(cc))
          dCAL(cc)= dCA_SD(v(cc),me,ne(cc),Te(cc))
          CFL(cc) = CF_SD(params,v(cc),ne(cc),Te(cc))
          CBL(cc) = (CB_ee_SD(v(cc),ne(cc),Te(cc),Zeff(cc))+ &
               CB_ei_SD(params,v(cc),ne(cc),Te(cc),Zeff(cc)))
          
          
          dp(cc)=REAL(flag(cc))*((-CFL(cc)+dCAL(cc)+E_PHI(cc)*xi(cc))*dt+ &
               sqrt(2.0_rp*CAL(cc))*dW(cc,1))

          dxi(cc)=REAL(flag(cc))*(-2*xi(cc)*CBL(cc)/(pm(cc)*pm(cc)+ &
               E_PHI(cc)*(1-xi(cc)*xi(cc))/pm(cc))*dt- &
               sqrt(2.0_rp*CBL(cc)*(1-xi(cc)*xi(cc)))/pm(cc)*dW(cc,2))

          if (params%radiation) then
             if(params%GC_rad_model.eq.'SDE') then
                dp(cc)=dp(cc)-gam(cc)*pm(cc)*(1-xi(cc)*xi(cc))/ &
                     (cparams_ss%taur/(Bmag(cc)*params%cpp%Bo)**2)*dt
                dxi(cc)=dxi(cc)+xi(cc)*(1-xi(cc)*xi(cc))/ &
                     ((cparams_ss%taur/(Bmag(cc)*params%cpp%Bo)**2)*gam(cc))*dt
                
             end if
          end if

       
          pm(cc)=pm(cc)+dp(cc)
          xi(cc)=xi(cc)+dxi(cc)

!          if (pm(cc)<0) pm(cc)=-pm(cc)

          ! Keep xi between [-1,1]
          if (xi(cc)>1) then
             xi(cc)=1-mod(xi(cc),1._rp)
          else if (xi(cc)<-1) then
             xi(cc)=-1-mod(xi(cc),-1._rp)             
          endif

          ! Transform P,xi to p_pll,mu
          Ppll(cc)=pm(cc)*xi(cc)
          Pmu(cc)=(pm(cc)*pm(cc)-Ppll(cc)*Ppll(cc))/(2*me*Bmag(cc))
       end do
       !$OMP END SIMD

       do cc=1_idef,8_idef
          if (pm(cc).lt.1._rp) then
!             write(6,'("Momentum less than zero")')
!             stop
             flag(cc)=0_ip
          end if
       end do

!       if (tt .EQ. 1_ip) then
!          write(6,'("dp_rad: ",E17.10)') &
!               -gam(1)*pm(1)*(1-xi(1)*xi(1))/ &
!               (cparams_ss%taur/Bmag(1)**2)*dt
!          write(6,'("dxi_rad: ",E17.10)') &
!               xi(1)*(1-xi(1)*xi(1))/ &
!               ((cparams_ss%taur/Bmag(1)**2)*gam(1))*dt
!       end if
       
!       if (tt .EQ. 1_ip) then
!          write(6,'("CA: ",E17.10)') CAL(1)
!          write(6,'("dCA: ",E17.10)') dCAL(1)
!          write(6,'("CF ",E17.10)') CFL(1)
!          write(6,'("CB: ",E17.10)') CBL(1)
!       end if
       
    end if
    
  end subroutine include_CoulombCollisions_GC_p
  
  subroutine save_params_ms(params)
    TYPE(KORC_PARAMS), INTENT(IN) 			:: params
    CHARACTER(MAX_STRING_LENGTH) 			:: filename
    CHARACTER(MAX_STRING_LENGTH) 			:: gname
    CHARACTER(MAX_STRING_LENGTH), DIMENSION(:), ALLOCATABLE :: attr_array
    CHARACTER(MAX_STRING_LENGTH) 			:: dset
    CHARACTER(MAX_STRING_LENGTH) 			:: attr
    INTEGER(HID_T) 					:: h5file_id
    INTEGER(HID_T) 					:: group_id
    INTEGER 						:: h5error
    REAL(rp) 						:: units

    if (params%mpi_params%rank .EQ. 0) then
       filename = TRIM(params%path_to_outputs) // "simulation_parameters.h5"
       call h5fopen_f(TRIM(filename), H5F_ACC_RDWR_F, h5file_id, h5error)

       gname = "collisions_ms"
       call h5gcreate_f(h5file_id, TRIM(gname), group_id, h5error)

       ALLOCATE(attr_array(cparams_ms%num_impurity_species))

       dset = TRIM(gname) // "/model"
       call save_string_parameter(h5file_id,dset,(/params%collisions_model/))

       dset = TRIM(gname) // "/num_impurity_species"
       attr = "Number of impurity species"
       call save_to_hdf5(h5file_id,dset,cparams_ms%num_impurity_species,attr)

       dset = TRIM(gname) // "/Te"
       attr = "Background electron temperature in eV"
       units = params%cpp%temperature/C_E
       call save_to_hdf5(h5file_id,dset,units*cparams_ms%Te,attr)

       dset = TRIM(gname) // "/ne"
       attr = "Background electron density in m^-3"
       units = params%cpp%density
       call save_to_hdf5(h5file_id,dset,units*cparams_ms%ne,attr)

       dset = TRIM(gname) // "/nH"
       attr = "Background proton density in m^-3"
       units = params%cpp%density
       call save_to_hdf5(h5file_id,dset,units*cparams_ms%nH,attr)

       dset = TRIM(gname) // "/nef"
       attr = "Free electron density in m^-3"
       units = params%cpp%density
       call save_to_hdf5(h5file_id,dset,units*cparams_ms%nef,attr)

       dset = TRIM(gname) // "/neb"
       attr_array(1) = "Bound electron density per impurity in m^-3"
       units = params%cpp%density
       call save_1d_array_to_hdf5(h5file_id,dset,units*cparams_ms%neb, &
            attr_array)

       dset = TRIM(gname) // "/Zo"
       attr_array(1) = "Full nuclear charge of impurities"
       call save_1d_array_to_hdf5(h5file_id,dset,cparams_ms%Zo,attr_array)

       dset = TRIM(gname) // "/Zj"
       attr_array(1) = "Average charge state of impurities"
       call save_1d_array_to_hdf5(h5file_id,dset,cparams_ms%Zj,attr_array)

       dset = TRIM(gname) // "/nz"
       attr_array(1) = "Density of impurities in m^-3"
       units = params%cpp%density
       call save_1d_array_to_hdf5(h5file_id,dset,units*cparams_ms%nz,attr_array)

       dset = TRIM(gname) // "/IZj"
       attr_array(1) = " Ionization energy of impurities in eV"
       units = params%cpp%energy/C_E
       call save_1d_array_to_hdf5(h5file_id,dset,units*cparams_ms%IZj, &
            attr_array)

       dset = TRIM(gname) // "/rD"
       attr = "Debye length in m"
       units = params%cpp%length
       call save_to_hdf5(h5file_id,dset,units*cparams_ms%rD,attr)

       dset = TRIM(gname) // "/re"
       attr = "Classical electron radius in m"
       units = params%cpp%length
       call save_to_hdf5(h5file_id,dset,units*cparams_ms%re,attr)

       DEALLOCATE(attr_array)

       call h5gclose_f(group_id, h5error)

       call h5fclose_f(h5file_id, h5error)
    end if
  end subroutine save_params_ms


  subroutine save_params_ss(params)
    TYPE(KORC_PARAMS), INTENT(IN) 				:: params
    CHARACTER(MAX_STRING_LENGTH) 				:: filename
    CHARACTER(MAX_STRING_LENGTH) 				:: gname
    CHARACTER(MAX_STRING_LENGTH) 				:: subgname
    CHARACTER(MAX_STRING_LENGTH), DIMENSION(:), ALLOCATABLE :: attr_array
    CHARACTER(MAX_STRING_LENGTH) 				:: dset
    CHARACTER(MAX_STRING_LENGTH) 				:: attr
    INTEGER(HID_T) 						:: h5file_id
    INTEGER(HID_T) 						:: group_id
    INTEGER(HID_T) 						:: subgroup_id
    INTEGER 							:: h5error
    REAL(rp) 							:: units


    if (params%mpi_params%rank .EQ. 0) then
       filename = TRIM(params%path_to_outputs) // "simulation_parameters.h5"
       call h5fopen_f(TRIM(filename), H5F_ACC_RDWR_F, h5file_id, h5error)

       gname = "collisions_ss"
       call h5gcreate_f(h5file_id, TRIM(gname), group_id, h5error)

       ALLOCATE(attr_array(cparams_ms%num_impurity_species))

       dset = TRIM(gname) // "/collisions_model"
       call save_string_parameter(h5file_id,dset,(/params%collisions_model/))

       dset = TRIM(gname) // "/Te"
       attr = "Background electron temperature in eV"
       units = params%cpp%temperature/C_E
       call save_to_hdf5(h5file_id,dset,units*cparams_ss%Te,attr)

       dset = TRIM(gname) // "/Ti"
       attr = "Background ion temperature in eV"
       units = params%cpp%temperature/C_E
       call save_to_hdf5(h5file_id,dset,units*cparams_ss%Ti,attr)

       dset = TRIM(gname) // "/ne"
       attr = "Background electron density in m^-3"
       units = params%cpp%density
       call save_to_hdf5(h5file_id,dset,units*cparams_ss%ne,attr)

       dset = TRIM(gname) // "/Zeff"
       attr = "Effective nuclear charge of impurities"
       call save_to_hdf5(h5file_id,dset,cparams_ss%Zeff,attr)

       dset = TRIM(gname) // "/rD"
       attr = "Debye length in m"
       units = params%cpp%length
       call save_to_hdf5(h5file_id,dset,units*cparams_ss%rD,attr)

       dset = TRIM(gname) // "/re"
       attr = "Classical electron radius in m"
       units = params%cpp%length
       call save_to_hdf5(h5file_id,dset,units*cparams_ss%re,attr)

       dset = TRIM(gname) // "/Clogee"
       attr = "Coulomb logarithm"
       call save_to_hdf5(h5file_id,dset,cparams_ss%CoulombLogee,attr)

       dset = TRIM(gname) // "/Clogei"
       attr = "Coulomb logarithm"
       call save_to_hdf5(h5file_id,dset,cparams_ss%CoulombLogei,attr)
       
       dset = TRIM(gname) // "/VTe"
       attr = "Background electron temperature"
       units = params%cpp%velocity
       call save_to_hdf5(h5file_id,dset,units*cparams_ss%VTe,attr)

       dset = TRIM(gname) // "/delta"
       attr = "Delta parameter VTe/C"
       call save_to_hdf5(h5file_id,dset,cparams_ss%delta,attr)

       dset = TRIM(gname) // "/Gamma"
       attr = "Gamma coefficient"
       units = (params%cpp%mass**2*params%cpp%velocity**3)/params%cpp%time
       call save_to_hdf5(h5file_id,dset,units*cparams_ss%Gammac,attr)

       dset = TRIM(gname) // "/Tau"
       attr = "Relativistic collisional time in s"
       units = params%cpp%time
       call save_to_hdf5(h5file_id,dset,units*cparams_ss%Tau,attr)

       dset = TRIM(gname) // "/Tauc"
       attr = "Thermal collisional time in s"
       units = params%cpp%time
       call save_to_hdf5(h5file_id,dset,units*cparams_ss%Tauc,attr)

       dset = TRIM(gname) // "/dTau"
       attr = "Subcycling time step in s"
       units = params%cpp%time
       call save_to_hdf5(h5file_id,dset,units*cparams_ss%dTau* &
            cparams_ss%Tau,attr)

       dset = TRIM(gname) // "/subcycling_iterations"
       attr = "KORC iterations per collision"
       call save_to_hdf5(h5file_id,dset,cparams_ss%subcycling_iterations,attr)

       dset = TRIM(gname) // "/Ec"
       attr = "Critical electric field"
       units = params%cpp%Eo
       call save_to_hdf5(h5file_id,dset,units*cparams_ss%Ec,attr)

       dset = TRIM(gname) // "/ED"
       attr = "Dreicer electric field"
       units = params%cpp%Eo
       call save_to_hdf5(h5file_id,dset,units*cparams_ss%ED,attr)

       call h5gclose_f(group_id, h5error)

       call h5fclose_f(h5file_id, h5error)
    end if
  end subroutine save_params_ss


  subroutine save_collision_params(params)
    TYPE(KORC_PARAMS), INTENT(IN) :: params

    if (.NOT.(params%restart.OR.params%proceed)) then

       if (params%collisions) then
          SELECT CASE (TRIM(params%collisions_model))
          CASE (MODEL1)
             call save_params_ss(params)

             SELECT CASE(TRIM(params%bound_electron_model))
             CASE ('NO_BOUND')
                call save_params_ms(params)
             CASE('HESSLOW')
                call save_params_ms(params)
             CASE('ROSENBLUTH')
                call save_params_ms(params)
             CASE DEFAULT
                write(6,'("Default case")')
             END SELECT
             
          CASE (MODEL2)
             call save_params_ms(params)
          CASE DEFAULT
             write(6,'("Default case")')
          END SELECT
       end if

    end if
  end subroutine save_collision_params


  subroutine deallocate_params_ms()
    if (ALLOCATED(cparams_ms%Zj)) DEALLOCATE(cparams_ms%Zj)
    if (ALLOCATED(cparams_ms%Zo)) DEALLOCATE(cparams_ms%Zo)
    if (ALLOCATED(cparams_ms%nz)) DEALLOCATE(cparams_ms%nz)
    if (ALLOCATED(cparams_ms%neb)) DEALLOCATE(cparams_ms%neb)
    if (ALLOCATED(cparams_ms%IZj)) DEALLOCATE(cparams_ms%IZj)
    if (ALLOCATED(cparams_ms%Zj)) DEALLOCATE(cparams_ms%Ee_IZj)
  end subroutine deallocate_params_ms


  subroutine deallocate_collisions_params(params)
    TYPE(KORC_PARAMS), INTENT(IN) :: params

    if (params%collisions) then
       SELECT CASE (TRIM(params%collisions_model))
       CASE (MODEL1)
          !				write(6,'("Something to be done")')

          SELECT CASE(TRIM(params%bound_electron_model))
          CASE ('NO_BOUND')
             call deallocate_params_ms()
          CASE('HESSLOW')
             call deallocate_params_ms()
          CASE('ROSENBLUTH')
             call deallocate_params_ms()
          CASE DEFAULT
             write(6,'("Default case")')
          END SELECT
          
       CASE (MODEL2)
          call deallocate_params_ms()
       CASE DEFAULT
          write(6,'("Default case")')
       END SELECT
    end if
  end subroutine deallocate_collisions_params

end module korc_collisions
