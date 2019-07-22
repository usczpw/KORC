module korc_ppusher
  !! @note Module with subroutines for advancing the particles' position and
  !! velocity in the simulations. @endnote
  use korc_types
  use korc_constants
  use korc_fields
  use korc_profiles
  use korc_interp
  use korc_collisions
  use korc_hpc

  IMPLICIT NONE

  REAL(rp), PRIVATE :: E0
  !! Dimensionless vacuum permittivity \(\epsilon_0 \times (m_{ch}^2
  !! v_{ch}^3/q_{ch}^3 B_{ch})\), see [[korc_units]].

  PRIVATE :: cross,&
       radiation_force,&
       radiation_force_p,&
       GCEoM,&
       GCEoM_p,&
       aux_fields
  PUBLIC :: initialize_particle_pusher,&
       advance_particles_position,&
       advance_particles_velocity,&
       advance_FOeqn_vars,&
       advance_FOinterp_vars,&
       advance_GCeqn_vars,&
       advance_GCinterp_vars,&
       advance_GC_vars_slow,&
       GC_init,&
       FO_init,&
       adv_GCeqn_top,&
       adv_GCinterp_top

contains



  subroutine initialize_particle_pusher(params)
    !! @note This subroutine initializes all the variables needed for advancing
    !! the particles' position and velocity. @endnote
    !! This subroutine is specially useful when we need to define or initialize
    !! values of parameters used to calculate derived quantities.
    !! The intent of this subroutine is to work as a constructor of the module.
    TYPE(KORC_PARAMS), INTENT(IN)  :: params
    !! Core KORC simulation parameters.

    E0 = C_E0*(params%cpp%mass**2*params%cpp%velocity**3)/ &
         (params%cpp%charge**3*params%cpp%Bo)
  end subroutine initialize_particle_pusher


  pure function cross(a,b)
    !! @note Function that calculates and returns the cross product
    !! \(\mathbf{a}\times \mathbf{b}\). These vectors are in Cartesian
    !! coordinates. @endnote
    !! @note Notice that all the variables in this subroutine have been
    !! normalized using the characteristic scales in [[korc_units]]. @endnote
    REAL(rp), DIMENSION(3), INTENT(IN) :: a
    !! Vector \(\mathbf{a}\).
    REAL(rp), DIMENSION(3), INTENT(IN) :: b
    !! Vector \(\mathbf{b}\).
    REAL(rp), DIMENSION(3)             :: cross
    !!Value of \(\mathbf{a}\times \mathbf{b}\)

    cross(1) = a(2)*b(3) - a(3)*b(2)
    cross(2) = a(3)*b(1) - a(1)*b(3)
    cross(3) = a(1)*b(2) - a(2)*b(1)
  end function cross


  subroutine radiation_force(spp,U,E,B,Frad)
    !! @note Subroutine that calculates the synchrotron radiation reaction
    !! force. @endnote
    !! This subroutine calculates the synchrotron radiation reaction
    !! force [Carbajal et al. PoP <b>24</b>, 042512 (2017)] using the derivation
    !! of Landau-Lifshiftz of the Lorentz-Abraham-Dirac radiation reaction
    !! force:
    !!
    !! $$\mathbf{F}_R(\mathbf{x},\mathbf{v}) = \frac{q^3}{6\pi\epsilon_0 m
    !! c^3}\left[ \mathbf{F}_1 + \mathbf{F}_2 + \mathbf{F}_3\right],$$
    !! $$\mathbf{F}_1 = \gamma \left( \frac{D \mathbf{E}}{Dt} + \mathbf{v}\times
    !! \frac{D \mathbf{B}}{Dt} \right),$$
    !! $$\mathbf{F}_2 = \frac{q}{m}\left( \frac{(\mathbf{E}\cdot\mathbf{v})}
    !! {c^2}\mathbf{E} + (\mathbf{E} + \mathbf{v}\times \mathbf{B})\times
    !! \mathbf{B} \right),$$
    !! $$\mathbf{F}_3 = -\frac{q\gamma^2}{mc^2} \left( (\mathbf{E} +
    !! \mathbf{v}\times \mathbf{B})^2 -  \frac{(\mathbf{E}\cdot\mathbf{v})^2}
    !! {c^2}\right)\mathbf{v},$$
    !!
    !! where \(\gamma = 1/\sqrt{1 - v^2/c^2}\) is the relativistic factor,
    !! \(D/Dt = \partial/\partial t + \mathbf{v}\cdot\nabla\), \(q\) and \(m\)
    !! are the charge and mass of the particle, and \(\epsilon_0\) is the vacuum
    !! permittivity. For relativistic electrons we have \(F_1 \ll F_2\) and
    !! \(F_1 \ll F_3\), therefore \(\mathbf{F}_1\) is not calculated here.
    !!
    !! @note Notice that all the variables in this subroutine have been
    !! normalized using the characteristic scales in [[korc_units]]. @endnote
    TYPE(SPECIES), INTENT(IN)              :: spp
    !!An instance of the derived type SPECIES containing all the parameters
    !! and simulation variables of the different species in the simulation.
    REAL(rp), DIMENSION(3), INTENT(IN)     :: U
    !! \(\mathbf{u} = \gamma \mathbf{v}\), where \(\mathbf{v}\) is the
    !! particle's velocity.
    REAL(rp), DIMENSION(3), INTENT(IN)     :: E
    !! Electric field \(\mathbf{E}\) seen by each particle. This is given
    !! in Cartesian coordinates.
    REAL(rp), DIMENSION(3), INTENT(IN)     :: B
    !! Magnetic field \(\mathbf{B}\) seen by each particle. This is given
    !! in Cartesian coordinates.
    REAL(rp), DIMENSION(3), INTENT(OUT)    :: Frad
    !! The calculated synchrotron radiation reaction force \(\mathbf{F}_R\).
    REAL(rp), DIMENSION(3)                 :: F1
    !! The component \(\mathbf{F}_1\) of \(\mathbf{F}_R\).
    REAL(rp), DIMENSION(3)                 :: F2
    !! The component \(\mathbf{F}_2\) of \(\mathbf{F}_R\).
    REAL(rp), DIMENSION(3)                 :: F3
    !! The component \(\mathbf{F}_3\) of \(\mathbf{F}_R\).
    REAL(rp), DIMENSION(3)                 :: V
    !! The particle's velocity \(\mathbf{v}\).
    REAL(rp), DIMENSION(3)                 :: vec
    !! An auxiliary 3-D vector.
    REAL(rp)                               :: g
    !! The relativistic \(\gamma\) factor of the particle.
    REAL(rp)                               :: tmp

    g = SQRT(1.0_rp + DOT_PRODUCT(U,U))
    V = U/g

    tmp = spp%q**4/(6.0_rp*C_PI*E0*spp%m**2)

    F2 = tmp*( DOT_PRODUCT(E,V)*E + cross(E,B) + cross(B,cross(B,V)) )
    vec = E + cross(V,B)
    F3 = (tmp*g**2)*( DOT_PRODUCT(E,V)**2 - DOT_PRODUCT(vec,vec) )*V

    Frad = F2 + F3
  end subroutine radiation_force

  subroutine radiation_force_p(q_cache,m_cache,U_X,U_Y,U_Z,E_X,E_Y,E_Z, &
       B_X,B_Y,B_Z,Frad_X,Frad_Y,Frad_Z)

    REAL(rp), INTENT(IN)                       :: m_cache,q_cache
    
    REAL(rp), DIMENSION(8), INTENT(IN)     :: U_X,U_Y,U_Z
    !! \(\mathbf{u} = \gamma \mathbf{v}\), where \(\mathbf{v}\) is the
    !! particle's velocity.
    REAL(rp), DIMENSION(8), INTENT(IN)     :: E_X,E_Y,E_Z
    !! Electric field \(\mathbf{E}\) seen by each particle. This is given
    !! in Cartesian coordinates.
    REAL(rp), DIMENSION(8), INTENT(IN)     :: B_X,B_Y,B_Z
    !! Magnetic field \(\mathbf{B}\) seen by each particle. This is given
    !! in Cartesian coordinates.
    REAL(rp), DIMENSION(8), INTENT(OUT)    :: Frad_X,Frad_Y,Frad_Z
    !! The calculated synchrotron radiation reaction force \(\mathbf{F}_R\).
    REAL(rp), DIMENSION(3)                 :: F1
    !! The component \(\mathbf{F}_1\) of \(\mathbf{F}_R\).
    REAL(rp), DIMENSION(8)                 :: F2_X,F2_Y,F2_Z
    !! The component \(\mathbf{F}_2\) of \(\mathbf{F}_R\).
    REAL(rp), DIMENSION(8)                 :: F3_X,F3_Y,F3_Z
    !! The component \(\mathbf{F}_3\) of \(\mathbf{F}_R\).
    REAL(rp), DIMENSION(8)                 :: V_X,V_Y,V_Z
    !! The particle's velocity \(\mathbf{v}\).
    REAL(rp), DIMENSION(8)                 :: vec_X,vec_Y,vec_Z
    REAL(rp), DIMENSION(8)                 :: cross_EB_X,cross_EB_Y,cross_EB_Z
    REAL(rp), DIMENSION(8)                 :: cross_BV_X,cross_BV_Y,cross_BV_Z
    REAL(rp), DIMENSION(8)                 :: cross_BBV_X,cross_BBV_Y,cross_BBV_Z
    REAL(rp), DIMENSION(8)                 :: dot_EV,dot_vecvec
    !! An auxiliary 3-D vector.
    REAL(rp),DIMENSION(8)                               :: g
    !! The relativistic \(\gamma\) factor of the particle.
    REAL(rp)                               :: tmp
    INTEGER :: cc

    !$OMP SIMD
    do cc=1_idef,8_idef
       g(cc) = SQRT(1.0_rp + U_X(cc)*U_X(cc)+ U_Y(cc)*U_Y(cc)+ U_Z(cc)*U_Z(cc))
       
       V_X(cc) = U_X(cc)/g(cc)
       V_Y(cc) = U_Y(cc)/g(cc)
       V_Z(cc) = U_Z(cc)/g(cc)

       tmp = q_cache**4/(6.0_rp*C_PI*E0*m_cache**2)

       cross_EB_X(cc)=E_Y(cc)*B_Z(cc)-E_Z(cc)*B_Y(cc)
       cross_EB_Y(cc)=E_Z(cc)*B_X(cc)-E_X(cc)*B_Z(cc)
       cross_EB_Z(cc)=E_X(cc)*B_Y(cc)-E_Y(cc)*B_X(cc)

       dot_EV(cc)=E_X(cc)*V_X(cc)+E_Y(cc)*V_Y(cc)+E_Z(cc)*V_Z(cc)

       cross_BV_X(cc)=B_Y(cc)*V_Z(cc)-B_Z(cc)*V_Y(cc)
       cross_BV_Y(cc)=B_Z(cc)*V_X(cc)-B_X(cc)*V_Z(cc)
       cross_BV_Z(cc)=B_X(cc)*V_Y(cc)-B_Y(cc)*V_X(cc)

       cross_BBV_X(cc)=B_Y(cc)*cross_BV_Z(cc)-B_Z(cc)*cross_BV_Y(cc)
       cross_BBV_Y(cc)=B_Z(cc)*cross_BV_X(cc)-B_X(cc)*cross_BV_Z(cc)
       cross_BBV_Z(cc)=B_X(cc)*cross_BV_Y(cc)-B_Y(cc)*cross_BV_X(cc)
       
       F2_X(cc) = tmp*( dot_EV(cc)*E_X(cc) + cross_EB_X(cc) + cross_BBV_X(cc) )
       F2_Y(cc) = tmp*( dot_EV(cc)*E_Y(cc) + cross_EB_Y(cc) + cross_BBV_Y(cc) )
       F2_Z(cc) = tmp*( dot_EV(cc)*E_Z(cc) + cross_EB_Z(cc) + cross_BBV_Z(cc) )
       
       vec_X(cc) = E_X(cc) - cross_BV_X(cc)
       vec_Y(cc) = E_Y(cc) - cross_BV_Y(cc)
       vec_Z(cc) = E_Z(cc) - cross_BV_Z(cc)

       dot_vecvec(cc)=vec_X(cc)*vec_X(cc)+vec_Y(cc)*vec_Y(cc)+vec_Z(cc)*vec_Z(cc)
       
       F3_X(cc) = (tmp*g(cc)**2)*( dot_EV(cc)**2 - dot_vecvec(cc) )*V_X(cc)
       F3_Y(cc) = (tmp*g(cc)**2)*( dot_EV(cc)**2 - dot_vecvec(cc) )*V_Y(cc)
       F3_Z(cc) = (tmp*g(cc)**2)*( dot_EV(cc)**2 - dot_vecvec(cc) )*V_Z(cc)

       Frad_X(cc) = F2_X(cc) + F3_X(cc)
       Frad_Y(cc) = F2_Y(cc) + F3_Y(cc)
       Frad_Z(cc) = F2_Z(cc) + F3_Z(cc)
       
    end do
    !$OMP END SIMD
    
  end subroutine radiation_force_p

  subroutine advance_particles_velocity(params,F,P,spp,dt,bool,init)
    !! @note Subroutine for advancing the particles' velocity. @endnote
    !! We are using the modified relativistic leapfrog method of J.-L. Vay,
    !! PoP <b>15</b>, 056701 (2008) for advancing the particles'
    !! position and velocity. For including the synchrotron radiation reaction
    !! force we used the scheme in Tamburini et al., New J. Phys. <b>12</b>,
    !! 123005 (2010). A comprehensive description of this can be found in
    !! Carbajal et al., PoP <b>24</b>, 042512 (2017). The discretized equations
    !! of motion to advance the change in the position and
    !! momentum due to the Lorentz force are:
    !!
    !! $$\frac{\mathbf{x}^{i+1/2} - \mathbf{x}^{i-1/2}}{\Delta t}  =
    !! \mathbf{v}^i$$
    !! $$\frac{\mathbf{p}^{i+1}_L - \mathbf{p}^{i}}{\Delta t} =
    !! q \left(  \mathbf{E}^{i+1/2}+ \frac{\mathbf{v}^i + \mathbf{v}^{i+1}_L}{2}
    !! \times \mathbf{B}^{i+1/2} \right),$$
    !!
    !! where \(\Delta t\) is the time step, \(q\) denotes the charge,
    !! \(\mathbf{p}^j = m \gamma^j \mathbf{v}^j\), and \(\gamma^j =
    !! 1/\sqrt{1 + v^{j2}/c^2}\).
    !! Here \(i\) and \(i+1\) indicate integer time leves, while \(i-1/2\)
    !! and \(i+1/2\) indicate half-time steps.
    !! The evolution of the relativistic \(\gamma\) factor is given by
    !! \(\gamma^{i+1} = \sqrt{1 + \left(p_L^{i+1}/mc \right)^2} = \sqrt{1 +
    !! \mathbf{p}_L^{i+1}\cdot \mathbf{p}'/m^2c^2}\), which can be combined
    !! with the above equations to produce:
    !!
    !! $$\mathbf{p}^{i+1}_L = s\left[ \mathbf{p}' + (\mathbf{p}'\cdot\mathbf{t})
    !! \mathbf{t} + \mathbf{p}'\times \mathbf{t} \right]$$
    !! $$\gamma^{i+1} = \sqrt{\frac{\sigma + \sqrt{\sigma^2 + 4(\tau^2 +
    !! p^{*2})}}{2}},$$
    !!
    !! where we have defined \(\mathbf{p}' = \mathbf{p}^i + q\Delta t \left(
    !! \mathbf{E}^{i+1/2} + \frac{\mathbf{v}^i}{2} \times \mathbf{B}^{i+1/2}
    !! \right)\), \(\mathbf{\tau} = (q\Delta t/2)\mathbf{B}^{i+1/2}\),
    !! \(\mathbf{t} = {\mathbf \tau}/\gamma^{i+1}\), \(p^{*} = \mathbf{p}'\cdot
    !! \mathbf{\tau}/mc\), \(\sigma = \gamma'^2 - \tau^2\), \(\gamma' = \sqrt{1
    !! + p'^2/m^2c^2}\), and \(s = 1/(1+t^2)\).
    !! The discretized equation of motion to advance the change in the momentum
    !! due to the radiation reaction force force is
    !!
    !! $$\frac{\mathbf{p}^{i+1}_R - \mathbf{p}^{i}}{\Delta t} = \mathbf{F}_R(
    !! \mathbf{x}^{i+1/2},\mathbf{p}^{i+1/2}),$$
    !!
    !! where \(\mathbf{p}^{i+1/2} = (\mathbf{p}^{i+1}_L + \mathbf{p}^i)/2\).
    !! Finally, using  \(\mathbf{p}^{i+1}_L\) and \(\mathbf{p}^{i+1}_R\), the
    !! momentum at time level \(i+1\) is given by
    !!
    !! $$\mathbf{p}^{i+1}  = \mathbf{p}^{i+1}_L + \mathbf{p}^{i+1}_R -
    !! \mathbf{p}^i.$$
    !!
    !! Collisions are included by solving the stochastic differential equation
    !! in a Cartesian coordinate system where \(\mathbf{p}\) is parallel to
    !! \(\hat{e}_z :  \mathbf{p} = \mathbf{A}dt + \hat{\sigma}\cdot
    !! d\mathbf{W}\),
    !! where \(\mathbf{A} = p \nu_s\hat{b}\), \(\hat{b}=\mathbf{B}/B\) with
    !! \(\mathbf{B}\) the magnetic field, and \(\nu_s\) the collision frequency
    !! that corresponds to the drag force due to collisions.
    !! \(\hat{\sigma}\) is a diagonal 3x3 matrix with elements
    !! \(\hat{\sigma}_{11} = p\sqrt{\nu_{\parallel}}\), and \(\hat{\sigma}_{22}
    !! = \hat{\sigma}_{33} = p\sqrt{\nu_{D}}\), with \(\nu_\parallel\) and
    !! \(\nu_D\)
    !! the collisional frequencies producing diffusive transport along and
    !! across the direction of \(\mathbf{p}\), respectively.
    !! @note Notice that all the variables in this subroutine have been
    !! normalized using the characteristic scales in [[korc_units]]. @endnote
    TYPE(KORC_PARAMS), INTENT(IN)                              :: params
    !! Core KORC simulation parameters.
    TYPE(FIELDS), INTENT(IN)                                   :: F
    !! An instance of the KORC derived type FIELDS.
    TYPE(PROFILES), INTENT(IN)                                 :: P
    !! An instance of the KORC derived type PROFILES.
    TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT)    :: spp
    !! An instance of the derived type SPECIES containing all the parameters
    !! and simulation variables of the different species in the simulation.
    LOGICAL, INTENT(IN)                                        :: bool
    !! Logical variable used to indicate if we calculate or not quantities
    !! listed in the outputs list.
    REAL(rp), INTENT(IN)                                       :: dt
    !! Time step used in the leapfrog step (\(\Delta t\)).
    REAL(rp)                                                   :: Prad
    !! Total radiated power of each particle.
    REAL(rp)                                                   :: B
    !! Magnitude of the magnetic field seen by each particle .
    REAL(rp)                                                   :: v
    !! Speed of each particle.
    REAL(rp)                                                   :: vpar
    !! Parallel velocity \(v_\parallel = \mathbf{v}\cdot \hat{b}\).
    REAL(rp)                                                   :: vperp
    !! Perpendicular velocity \(v_\parallel = |\mathbf{v} - (\mathbf{v}\cdot
    !! \hat{b})\hat{b}|\).
    REAL(rp)                                                   :: tmp
    !! Temporary variable used for various computations.
    REAL(rp)                                                   :: a
    !! This variable is used to simplify notation in the code, and
    !! is given by \(a=q\Delta t/m\),
    REAL(rp)                                                   :: gp
    !! This variable is \(\gamma' = \sqrt{1 + p'^2/m^2c^2}\) in the
    !! above equations.
    REAL(rp)                                                   :: sigma
    !! This variable is \(\sigma = \gamma'^2 - \tau^2\) in the above equations.
    REAL(rp)                                                   :: us
    !! This variable is \(u^{*} = p^{*}/m\) where \( p^{*} =
    !! \mathbf{p}'\cdot \mathbf{\tau}/mc\).
    !! Variable 'u^*' in Vay, J.-L. PoP (2008).
    REAL(rp)                                                   :: g
    !! Relativistic factor \(\gamma\).
    REAL(rp)                                                   :: s
    !! This variable is \(s = 1/(1+t^2)\) in the equations above.
    !! Variable 's' in Vay, J.-L. PoP (2008).
    REAL(rp), DIMENSION(3)                                     :: U_L
    !! This variable is \(\mathbf{u}_L = \mathbf{p}_L/m\) where
    !! \(\mathbf{p}^{i+1}_L = s\left[ \mathbf{p}' + (\mathbf{p}'
    !! \cdot\mathbf{t})\mathbf{t} + \mathbf{p}'\times \mathbf{t} \right]\).
    REAL(rp), DIMENSION(3)                                     :: U_hs
    !! Is \(\mathbf{u}=\mathbf{p}/m\) at half-time step (\(i+1/2\)) in
    !! the absence of radiation losses or collisions. \(\mathbf{u}^{i+1/2} =
    !! \mathbf{u}^i + \frac{q\Delta t}{2m}\left( \mathbf{E}^{i+1/2} +
    !! \mathbf{v}^i\times \mathbf{B}^{i+1/2} \right)\).
    REAL(rp), DIMENSION(3)                                     :: tau
    !! This variable is \(\mathbf{\tau} = (q\Delta t/2)\mathbf{B}^{i+1/2}\).
    REAL(rp), DIMENSION(3)                                     :: up
    !! This variable is \(\mathbf{u}'= \mathbf{p}'/m\), where \(\mathbf{p}'
    !! = \mathbf{p}^i + q\Delta t \left( \mathbf{E}^{i+1/2} +
    !! \frac{\mathbf{v}^i}{2} \times \mathbf{B}^{i+1/2} \right)\).
    REAL(rp), DIMENSION(3)                                     :: t
    !! This variable is \(\mathbf{t} = {\mathbf \tau}/\gamma^{i+1}\).
    REAL(rp), DIMENSION(3)                                     :: U
    !! This variable is \(\mathbf{u}^{i+1}= \mathbf{p}^{i+1}/m\).
    REAL(rp), DIMENSION(3)                                     :: U_RC
    !! This variable is \(\mathbf{u}^{i+1}_R= \mathbf{p}^{i+1}_R/m\)
    REAL(rp), DIMENSION(3)                                     :: U_os
    !! This variable is \(\mathbf{u}^{i+1/2}= \mathbf{p}^{i+1/2}/m\) when
    !! radiation losses are included. Here, \(\mathbf{p}^{i+1/2} =
    !! (\mathbf{p}^{i+1}_L + \mathbf{p}^i)/2\)
    REAL(rp), DIMENSION(3)                                     :: Frad
    !! Synchrotron radiation reaction force of each particle.
    REAL(rp), DIMENSION(3)                                     :: vec
    !! Auxiliary vector used in various computations.
    REAL(rp), DIMENSION(3)                                     :: b_unit
    !! Unitary vector pointing along the local magnetic field \(\hat{b}\).
    INTEGER                                                    :: ii
    !! Species iterator.
    INTEGER                                                    :: pp
    !! Particles iterator.
    LOGICAL                                                    :: ss_collisions
    !! Logical variable that indicates if collisions are included in
    !! the simulation.
    LOGICAL, INTENT(IN)                                        :: init
    !! Logical variable used to indicate if this is the initial timestep.


    ! Determine whether we are using a single-species collision model
    ss_collisions = (TRIM(params%collisions_model) .EQ. 'SINGLE_SPECIES')

    do ii = 1_idef,params%num_species

       call get_fields(params,spp(ii)%vars,F)
       !! Calls [[get_fields]] in [[korc_fields]].
       ! Interpolates fields at local particles' position and keeps in
       ! spp%vars. Fields in (R,\(\phi\),Z) coordinates.

       call get_profiles(params,spp(ii)%vars,P,F)
       !! Calls [[get_profiles]] in [[korc_profiles]].
       ! Interpolates profiles at local particles' position and keeps in
       ! spp%vars. 

       !      write(6,'("Density of particle 1: ",E17.10)') spp(ii)%vars%ne(1)* &
       !           params%cpp%density

       a = spp(ii)%q*dt/spp(ii)%m

       !$OMP PARALLEL DO SHARED(params,ii,spp,ss_collisions) &
       !$OMP& FIRSTPRIVATE(a,dt,bool) PRIVATE(pp,U,U_L,U_hs,tau,up,gp, &
       !$OMP& sigma,us,g,t,s,Frad,U_RC,U_os,tmp,b_unit,B,vpar,v,vperp,vec,Prad)
       ! Call OpenMP to advance the velocity of individual particles on each
       ! MPI process.
       do pp=1_idef,spp(ii)%ppp
          if ( spp(ii)%vars%flag(pp) .EQ. 1_is ) then

             U = spp(ii)%vars%g(pp)*spp(ii)%vars%V(pp,:)

             ! Magnitude of magnetic field
             B = SQRT( DOT_PRODUCT(spp(ii)%vars%B(pp,:),spp(ii)%vars%B(pp,:)))

             U_L = U
             U_RC = U

             ! LEAP-FROG SCHEME FOR LORENTZ FORCE !
             U_hs = U_L + 0.5_rp*a*( spp(ii)%vars%E(pp,:) + &
                  cross(spp(ii)%vars%V(pp,:),spp(ii)%vars%B(pp,:)) )

             tau = 0.5_rp*dt*spp(ii)%q*spp(ii)%vars%B(pp,:)/spp(ii)%m

             up = U_hs + 0.5_rp*a*spp(ii)%vars%E(pp,:)

             gp = SQRT( 1.0_rp + DOT_PRODUCT(up,up) )

             sigma = gp**2 - DOT_PRODUCT(tau,tau)

             us = DOT_PRODUCT(up,tau)

             ! variable 'u^*' in Vay, J.-L. PoP (2008)
             g = SQRT( 0.5_rp*(sigma + SQRT(sigma**2 + &
                  4.0_rp*(DOT_PRODUCT(tau,tau) + us**2))) )

             t = tau/g
             s = 1.0_rp/(1.0_rp + DOT_PRODUCT(t,t))
             ! variable 's' in Vay, J.-L. PoP (2008)

             U_L = s*(up + DOT_PRODUCT(up,t)*t + cross(up,t))
             ! LEAP-FROG SCHEME FOR LORENTZ FORCE !

             ! Splitting operator for including radiation
             U_os = 0.5_rp*(U_L + U)

             if (params%radiation) then
                !! Calls [[radiation_force]] in [[korc_ppusher]].
                call radiation_force(spp(ii),U_os,spp(ii)%vars%E(pp,:), &
                     spp(ii)%vars%B(pp,:),Frad)
                U_RC = U_RC + a*Frad/spp(ii)%q
             end if
             ! Splitting operator for including radiation

             if (.not.(params%FokPlan)) U = U_L + U_RC - U

             ! Stochastic differential equations for including collisions
             if (params%collisions .AND. ss_collisions .and. .not.(init)) then
                !! Calls [[include_CoulombCollisions]] in [[korc_collisions]].
                b_unit = spp(ii)%vars%B(pp,:)/B

                call include_CoulombCollisions(params,U,spp(ii)%m, &
                     spp(ii)%vars%flag(pp),spp(ii)%vars%ne(pp), &
                     spp(ii)%vars%Te(pp),spp(ii)%vars%Zeff(pp),b_unit)
             end if
             ! Stochastic differential equations for including collisions

             if (params%radiation .OR. params%collisions) then
                g = SQRT( 1.0_rp + DOT_PRODUCT(U,U) )
             end if

             spp(ii)%vars%V(pp,:) = U/g
             spp(ii)%vars%g(pp) = g

             if (g.LT.params%minimum_particle_g) then
                spp(ii)%vars%flag(pp) = 0_is
             end if

             if (bool) then
                ! Parallel unit vector
                b_unit = spp(ii)%vars%B(pp,:)/B

                v = SQRT(DOT_PRODUCT(spp(ii)%vars%V(pp,:),spp(ii)%vars%V(pp,:)))
                if (v.GT.korc_zero) then
                   ! Parallel and perpendicular components of velocity
                   vpar = DOT_PRODUCT(spp(ii)%vars%V(pp,:), b_unit)
                   vperp =  DOT_PRODUCT(spp(ii)%vars%V(pp,:), &
                        spp(ii)%vars%V(pp,:)) &
                        - vpar**2
                   if ( vperp .GE. korc_zero ) then
                      vperp = SQRT( vperp )
                   else
                      vperp = 0.0_rp
                   end if

                   ! Pitch angle
                   spp(ii)%vars%eta(pp) = 180.0_rp*MODULO(ATAN2(vperp,vpar), &
                        2.0_rp*C_PI)/C_PI

                   ! Magnetic moment
                   spp(ii)%vars%mu(pp) = 0.5_rp*spp(ii)%m*g**2*vperp**2/B
                   ! See Northrop's book (The adiabatic motion of charged
                   ! particles)

                   ! Radiated power
                   tmp = spp(ii)%q**4/(6.0_rp*C_PI*E0*spp(ii)%m**2)
                   vec = spp(ii)%vars%E(pp,:) + cross(spp(ii)%vars%V(pp,:), &
                        spp(ii)%vars%B(pp,:))

                   spp(ii)%vars%Prad(pp) = tmp*( DOT_PRODUCT(spp(ii)% &
                        vars%E(pp,:), &
                        spp(ii)%vars%E(pp,:)) + &
                        DOT_PRODUCT(cross(spp(ii)%vars%V(pp,:), &
                        spp(ii)%vars%B(pp,:)),spp(ii)%vars%E(pp,:))+ &
                        spp(ii)%vars%g(pp)**2* &
                        (DOT_PRODUCT(spp(ii)%vars%E(pp,:), &
                        spp(ii)%vars%V(pp,:))**2 - DOT_PRODUCT(vec,vec)) )

                   ! Input power due to electric field
                   spp(ii)%vars%Pin(pp) = spp(ii)%q*DOT_PRODUCT( &
                        spp(ii)%vars%E(pp,:),spp(ii)%vars%V(pp,:))
                else
                   spp(ii)%vars%eta(pp) = 0.0_rp
                   spp(ii)%vars%mu(pp) = 0.0_rp
                   spp(ii)%vars%Prad(pp) = 0.0_rp
                   spp(ii)%vars%Pin(pp) = 0.0_rp
                end if
             end if !if outputting data
          end if ! if particle in domain, i.e. spp%vars%flag==1
       end do ! loop over particles on an mpi process
       !$OMP END PARALLEL DO

    end do
  end subroutine advance_particles_velocity


  subroutine FO_init(params,F,spp,output,step)
    TYPE(KORC_PARAMS), INTENT(IN)                              :: params
    !! Core KORC simulation parameters.
    TYPE(FIELDS), INTENT(IN)                                   :: F
    !! An instance of the KORC derived type FIELDS.
    TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT)    :: spp
    !! An instance of the derived type SPECIES containing all the parameters
    !! and simulation variables of the different species in the simulation.

    REAL(rp)                                      :: dt
    !! Time step used in the leapfrog step (\(\Delta t\)).
    REAL(rp)                                                   :: Prad
    !! Total radiated power of each particle.

    REAL(rp)                                  :: Bmag1
    !! Magnitude of the magnetic field seen by each particle .
    REAL(rp)                                                   :: v
    !! Speed of each particle.
    REAL(rp)                                                   :: vpar
    !! Parallel velocity \(v_\parallel = \mathbf{v}\cdot \hat{b}\).
    REAL(rp)                                                   :: vperp
    !! Perpendicular velocity \(v_\parallel = |\mathbf{v} - (\mathbf{v}\cdot
    !! \hat{b})\hat{b}|\).
    REAL(rp)                                                   :: tmp
    !! Temporary variable used for various computations.
    REAL(rp)                                                   :: a
    !! This variable is used to simplify notation in the code, and
    !! is given by \(a=q\Delta t/m\),

    REAL(rp), DIMENSION(3)                       :: Frad
    !! Synchrotron radiation reaction force of each particle.
    REAL(rp), DIMENSION(3)                       :: vec
    !! Auxiliary vector used in various computations.
    REAL(rp), DIMENSION(3)                       :: b_unit
    !! Unitary vector pointing along the local magnetic field \(\hat{b}\).
    INTEGER                                      :: ii
    !! Species iterator.
    INTEGER                                      :: pp
    !! Particles iterator.
    INTEGER                                      :: cc
    !! Chunk iterator.

    LOGICAL,intent(in) :: output
    LOGICAL,intent(in) :: step   
    
    INTEGER ,DIMENSION(8)                                     :: flag_cache


    do ii = 1_idef,params%num_species

       if(output) then
       
          call get_fields(params,spp(ii)%vars,F)
          !! Calls [[get_fields]] in [[korc_fields]].
          ! Interpolates fields at local particles' position and keeps in
          ! spp%vars. Fields in (R,\(\phi\),Z) coordinates.

          !$OMP PARALLEL DO DEFAULT(none) SHARED(ii,spp) &
          !$OMP& FIRSTPRIVATE(E0) &
          !$OMP& PRIVATE(pp,b_unit,Bmag1,vpar,v,vperp,vec,tmp)
          do pp=1_idef,spp(ii)%ppp

             Bmag1 = SQRT(DOT_PRODUCT(spp(ii)%vars%B(pp,:), &
                  spp(ii)%vars%B(pp,:)))

             ! Parallel unit vector
             b_unit = spp(ii)%vars%B(pp,:)/Bmag1

             v = SQRT(DOT_PRODUCT(spp(ii)%vars%V(pp,:),spp(ii)%vars%V(pp,:)))
             if (v.GT.korc_zero) then
                ! Parallel and perpendicular components of velocity
                vpar = DOT_PRODUCT(spp(ii)%vars%V(pp,:), b_unit)
                vperp =  DOT_PRODUCT(spp(ii)%vars%V(pp,:), &
                     spp(ii)%vars%V(pp,:)) &
                     - vpar**2
                if ( vperp .GE. korc_zero ) then
                   vperp = SQRT( vperp )
                else
                   vperp = 0.0_rp
                end if

                ! Pitch angle
                spp(ii)%vars%eta(pp) = 180.0_rp*MODULO(ATAN2(vperp,vpar), &
                     2.0_rp*C_PI)/C_PI

                ! Magnetic moment
                spp(ii)%vars%mu(pp) = 0.5_rp*spp(ii)%m* &
                     spp(ii)%vars%g(pp)**2*vperp**2/Bmag1
                ! See Northrop's book (The adiabatic motion of charged
                ! particles)

                ! Radiated power
                tmp = spp(ii)%q**4/(6.0_rp*C_PI*E0*spp(ii)%m**2)
                vec = spp(ii)%vars%E(pp,:) + cross(spp(ii)%vars%V(pp,:), &
                     spp(ii)%vars%B(pp,:))

                spp(ii)%vars%Prad(pp) = tmp*( DOT_PRODUCT(spp(ii)% &
                     vars%E(pp,:), &
                     spp(ii)%vars%E(pp,:)) + &
                     DOT_PRODUCT(cross(spp(ii)%vars%V(pp,:), &
                     spp(ii)%vars%B(pp,:)),spp(ii)%vars%E(pp,:))+ &
                     spp(ii)%vars%g(pp)**2* &
                     (DOT_PRODUCT(spp(ii)%vars%E(pp,:), &
                     spp(ii)%vars%V(pp,:))**2 - DOT_PRODUCT(vec,vec)) )

                ! Input power due to electric field
                spp(ii)%vars%Pin(pp) = spp(ii)%q*DOT_PRODUCT( &
                     spp(ii)%vars%E(pp,:),spp(ii)%vars%V(pp,:))
             else
                spp(ii)%vars%eta(pp) = 0.0_rp
                spp(ii)%vars%mu(pp) = 0.0_rp
                spp(ii)%vars%Prad(pp) = 0.0_rp
                spp(ii)%vars%Pin(pp) = 0.0_rp
             end if


          end do ! loop over particles on an mpi process
          !$OMP END PARALLEL DO

       end if !(if output)

       if(step.and.(.not.params%FokPlan)) then
          dt=0.5_rp*params%dt
          
          !$OMP PARALLEL DO FIRSTPRIVATE(dt) PRIVATE(pp,cc) &
          !$OMP& SHARED(ii,spp,params)
          do pp=1_idef,spp(ii)%ppp,8

             !$OMP SIMD
             do cc=1_idef,8
                spp(ii)%vars%X(pp-1+cc,1) = spp(ii)%vars%X(pp-1+cc,1) + &
                     dt*spp(ii)%vars%V(pp-1+cc,1)
                spp(ii)%vars%X(pp-1+cc,2) = spp(ii)%vars%X(pp-1+cc,2) + &
                     dt*spp(ii)%vars%V(pp-1+cc,2)
                spp(ii)%vars%X(pp-1+cc,3) = spp(ii)%vars%X(pp-1+cc,3) + &
                     dt*spp(ii)%vars%V(pp-1+cc,3)
             end do
             !$OMP END SIMD
             
          end do
          !$OMP END PARALLEL DO

       end if !(if step)

    end do ! over species

  end subroutine FO_init

  subroutine adv_FOeqn_top(params,F,P,spp)
    
    TYPE(KORC_PARAMS), INTENT(INOUT)                           :: params
    !! Core KORC simulation parameters.
    TYPE(FIELDS), INTENT(IN)                                   :: F
    !! An instance of the KORC derived type FIELDS.
    TYPE(PROFILES), INTENT(IN)                                 :: P
    !! An instance of the KORC derived type PROFILES.
    TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT)    :: spp
    !! An instance of the derived type SPECIES containing all the parameters
    !! and simulation variables of the different species in the simulation.
    REAL(rp), DIMENSION(8)               :: Bmag
    REAL(rp), DIMENSION(8)               :: b_unit_X,b_unit_Y,b_unit_Z
    REAL(rp), DIMENSION(8)               :: v,vpar,vperp
    REAL(rp), DIMENSION(8)               :: tmp
    REAL(rp), DIMENSION(8)               :: g
    REAL(rp), DIMENSION(8)               :: cross_X,cross_Y,cross_Z
    REAL(rp), DIMENSION(8)               :: vec_X,vec_Y,vec_Z
    REAL(rp),DIMENSION(8) :: X_X,X_Y,X_Z
    REAL(rp),DIMENSION(8) :: V_X,V_Y,V_Z
    REAL(rp),DIMENSION(8) :: B_X,B_Y,B_Z
    REAL(rp),DIMENSION(8) :: E_X,E_Y,E_Z
    INTEGER(is),DIMENSION(8) :: flag_cache

    REAL(rp) :: B0,EF0,R0,q0,lam,ar
    REAL(rp) :: a,m_cache,q_cache
    REAL(rp) :: ne0,Te0,Zeff0


    
    INTEGER                                                    :: ii
    !! Species iterator.
    INTEGER                                                    :: pp
    !! Particles iterator.
    INTEGER                                                    :: cc
    !! Chunk iterator.
    INTEGER(ip)                                                    :: tt
    !! time iterator.
 

    do ii = 1_idef,params%num_species      

       m_cache=spp(ii)%m
       q_cache=spp(ii)%q
       a = q_cache*params%dt/m_cache
       
       B0=F%AB%Bo
       EF0=F%Eo
       lam=F%AB%lambda
       R0=F%AB%Ro
       q0=F%AB%qo
       ar=F%AB%a


       
       !$OMP PARALLEL DO default(none) &
       !$OMP& FIRSTPRIVATE(E0,a,m_cache,q_cache,B0,EF0,lam,R0,q0,ar)&
       !$OMP& shared(params,ii,spp,P) &
       !$OMP& PRIVATE(pp,tt,Bmag,cc,X_X,X_Y,X_Z,V_X,V_Y,V_Z,B_X,B_Y,B_Z, &
       !$OMP& E_X,E_Y,E_Z,b_unit_X,b_unit_Y,b_unit_Z,v,vpar,vperp,tmp, &
       !$OMP& cross_X,cross_Y,cross_Z,vec_X,vec_Y,vec_Z,g,flag_cache)
       do pp=1_idef,spp(ii)%ppp,8

          !$OMP SIMD
          do cc=1_idef,8_idef
             X_X(cc)=spp(ii)%vars%X(pp-1+cc,1)
             X_Y(cc)=spp(ii)%vars%X(pp-1+cc,2)
             X_Z(cc)=spp(ii)%vars%X(pp-1+cc,3)

             V_X(cc)=spp(ii)%vars%V(pp-1+cc,1)
             V_Y(cc)=spp(ii)%vars%V(pp-1+cc,2)
             V_Z(cc)=spp(ii)%vars%V(pp-1+cc,3)

             g(cc)=spp(ii)%vars%g(pp-1+cc)
             flag_cache(cc)=spp(ii)%vars%flag(pp-1+cc)
          end do
          !$OMP END SIMD

          if (.not.params%FokPlan) then
             do tt=1_ip,params%t_skip

                call analytical_fields_p(B0,EF0,R0,q0,lam,ar,X_X,X_Y,X_Z, &
                     B_X,B_Y,B_Z,E_X,E_Y,E_Z,flag_cache)

                call advance_FOeqn_vars(tt,a,q_cache,m_cache,params, &
                     X_X,X_Y,X_Z,V_X,V_Y,V_Z,B_X,B_Y,B_Z,E_X,E_Y,E_Z, &
                     P,g,flag_cache)
             end do !timestep iterator

             !$OMP SIMD
             do cc=1_idef,8_idef
                spp(ii)%vars%X(pp-1+cc,1)=X_X(cc)
                spp(ii)%vars%X(pp-1+cc,2)=X_Y(cc)
                spp(ii)%vars%X(pp-1+cc,3)=X_Z(cc)

                spp(ii)%vars%V(pp-1+cc,1)=V_X(cc)
                spp(ii)%vars%V(pp-1+cc,2)=V_Y(cc)
                spp(ii)%vars%V(pp-1+cc,3)=V_Z(cc)

                spp(ii)%vars%g(pp-1+cc) = g(cc)
                
                spp(ii)%vars%flag(pp-1+cc) = flag_cache(cc)

                spp(ii)%vars%B(pp-1+cc,1) = B_X(cc)
                spp(ii)%vars%B(pp-1+cc,2) = B_Y(cc)
                spp(ii)%vars%B(pp-1+cc,3) = B_Z(cc)

                spp(ii)%vars%E(pp-1+cc,1) = E_X(cc)
                spp(ii)%vars%E(pp-1+cc,2) = E_Y(cc)
                spp(ii)%vars%E(pp-1+cc,3) = E_Z(cc)
             end do
             !$OMP END SIMD

          else

             !$OMP SIMD
             do cc=1_idef,8_idef
                B_X(cc)=spp(ii)%vars%B(pp-1+cc,1)
                B_Y(cc)=spp(ii)%vars%B(pp-1+cc,2)
                B_Z(cc)=spp(ii)%vars%B(pp-1+cc,3)

                E_X(cc)=spp(ii)%vars%E(pp-1+cc,1)
                E_Y(cc)=spp(ii)%vars%E(pp-1+cc,2)
                E_Z(cc)=spp(ii)%vars%E(pp-1+cc,3)
             end do
             !$OMP END SIMD
             
             call advance_FP3Deqn_vars(params,X_X,X_Y,X_Z,V_X,V_Y,V_Z, &
                  g,m_cache,B0,lam,R0,q0,EF0,B_X,B_Y,B_Z,E_X,E_Y,E_Z, &
                  P,flag_cache)

             !$OMP SIMD
             do cc=1_idef,8_idef

                spp(ii)%vars%V(pp-1+cc,1)=V_X(cc)
                spp(ii)%vars%V(pp-1+cc,2)=V_Y(cc)
                spp(ii)%vars%V(pp-1+cc,3)=V_Z(cc)

                spp(ii)%vars%g(pp-1+cc) = g(cc)

             end do
             !$OMP END SIMD
             
          end if
          
          !$OMP SIMD
          do cc=1_idef,8_idef
             !Derived output data
             Bmag(cc) = SQRT(B_X(cc)*B_X(cc)+B_Y(cc)*B_Y(cc)+B_Z(cc)*B_Z(cc))

             ! Parallel unit vector
             b_unit_X(cc) = B_X(cc)/Bmag(cc)
             b_unit_Y(cc) = B_Y(cc)/Bmag(cc)
             b_unit_Z(cc) = B_Z(cc)/Bmag(cc)

             v(cc) = SQRT(V_X(cc)*V_X(cc)+V_Y(cc)*V_Y(cc)+V_Z(cc)*V_Z(cc))
             if (v(cc).GT.korc_zero) then
                ! Parallel and perpendicular components of velocity
                vpar(cc) = (V_X(cc)*b_unit_X(cc)+V_Y(cc)*b_unit_Y(cc)+ &
                     V_Z(cc)*b_unit_Z(cc))
                
                vperp(cc) =  v(cc)**2 - vpar(cc)**2
                if ( vperp(cc) .GE. korc_zero ) then
                   vperp(cc) = SQRT( vperp(cc) )
                else
                   vperp(cc) = 0.0_rp
                end if

                ! Pitch angle
                spp(ii)%vars%eta(pp-1+cc) = 180.0_rp* &
                     MODULO(ATAN2(vperp(cc),vpar(cc)),2.0_rp*C_PI)/C_PI

                ! Magnetic moment
                spp(ii)%vars%mu(pp-1+cc) = 0.5_rp*m_cache* &
                     g(cc)**2*vperp(cc)**2/Bmag(cc)
                ! See Northrop's book (The adiabatic motion of charged
                ! particles)

                ! Radiated power
                tmp(cc) = q_cache**4/(6.0_rp*C_PI*E0*m_cache**2)

                cross_X(cc) = V_Y(cc)*B_Z(cc)-V_Z(cc)*B_Y(cc)
                cross_Y(cc) = V_Z(cc)*B_X(cc)-V_X(cc)*B_Z(cc)
                cross_Z(cc) = V_X(cc)*B_Y(cc)-V_Y(cc)*B_X(cc)
                
                vec_X(cc) = E_X(cc) + cross_X(cc)
                vec_Y(cc) = E_Y(cc) + cross_Y(cc)
                vec_Z(cc) = E_Z(cc) + cross_Z(cc)

                spp(ii)%vars%Prad(pp-1+cc) = tmp(cc)* &
                     ( E_X(cc)*E_X(cc)+E_Y(cc)*E_Y(cc)+E_Z(cc)*E_Z(cc) + &
                     cross_X(cc)*E_X(cc)+cross_Y(cc)*E_Y(cc)+ &
                     cross_Z(cc)*E_Z(cc) + g(cc)**2* &
                     ((E_X(cc)*V_X(cc)+E_Y(cc)*V_Y(cc)+E_Z(cc)*V_Z(cc))**2 &
                     - vec_X(cc)*vec_X(cc)-vec_Y(cc)*vec_Y(cc)- &
                     vec_Z(cc)*vec_Z(cc)) )

                ! Input power due to electric field
                spp(ii)%vars%Pin(pp-1+cc) = q_cache*(E_X(cc)*V_X(cc)+ &
                     E_Y(cc)*V_Y(cc)+E_Z(cc)*V_Z(cc))
             else
                spp(ii)%vars%eta(pp-1+cc) = 0.0_rp
                spp(ii)%vars%mu(pp-1+cc) = 0.0_rp
                spp(ii)%vars%Prad(pp-1+cc) = 0.0_rp
                spp(ii)%vars%Pin(pp-1+cc) = 0.0_rp
             end if

          end do
          !$OMP END SIMD

             
       end do !particle chunk iterator
       !$OMP END PARALLEL DO
       
    end do !species iterator
    
  end subroutine adv_FOeqn_top
  
  subroutine advance_FOeqn_vars(tt,a,q_cache,m_cache,params,X_X,X_Y,X_Z, &
       V_X,V_Y,V_Z,B_X,B_Y,B_Z,E_X,E_Y,E_Z,P,g,flag_cache)
    TYPE(PROFILES), INTENT(IN)                                 :: P
    TYPE(KORC_PARAMS), INTENT(IN)                              :: params
    !! Core KORC simulation parameters.

    INTEGER(ip), INTENT(IN)                                       :: tt
    !! Time step used in the leapfrog step (\(\Delta t\)).
    REAL(rp)                                      :: dt
    !! Time step used in the leapfrog step (\(\Delta t\)).
    REAL(rp), INTENT(IN)                       :: m_cache,q_cache
    !! Time step used in the leapfrog step (\(\Delta t\)).

    REAL(rp),DIMENSION(8)                                  :: Bmag



    REAL(rp),INTENT(in)                                       :: a
    !! This variable is used to simplify notation in the code, and
    !! is given by \(a=q\Delta t/m\),
    REAL(rp),DIMENSION(8)                                    :: sigma
    !! This variable is \(\sigma = \gamma'^2 - \tau^2\) in the above equations.
    REAL(rp),DIMENSION(8)                               :: us
    !! This variable is \(u^{*} = p^{*}/m\) where \( p^{*} =
    !! \mathbf{p}'\cdot \mathbf{\tau}/mc\).
    !! Variable 'u^*' in Vay, J.-L. PoP (2008).
    REAL(rp),DIMENSION(8),INTENT(INOUT)                 :: g
    REAL(rp),DIMENSION(8) :: gp,g0
    !! Relativistic factor \(\gamma\).
    REAL(rp),DIMENSION(8)                                 :: s
    !! This variable is \(s = 1/(1+t^2)\) in the equations above.
    !! Variable 's' in Vay, J.-L. PoP (2008).
    REAL(rp),DIMENSION(8)                            :: U_hs_X,U_hs_Y,U_hs_Z
    !! Is \(\mathbf{u}=\mathbf{p}/m\) at half-time step (\(i+1/2\)) in
    !! the absence of radiation losses or collisions. \(\mathbf{u}^{i+1/2} =
    !! \mathbf{u}^i + \frac{q\Delta t}{2m}\left( \mathbf{E}^{i+1/2} +
    !! \mathbf{v}^i\times \mathbf{B}^{i+1/2} \right)\).
    REAL(rp),DIMENSION(8)                           :: tau_X,tau_Y,tau_Z
    !! This variable is \(\mathbf{\tau} = (q\Delta t/2)\mathbf{B}^{i+1/2}\).
    REAL(rp),DIMENSION(8)                            :: up_X,up_Y,up_Z
    !! This variable is \(\mathbf{u}'= \mathbf{p}'/m\), where \(\mathbf{p}'
    !! = \mathbf{p}^i + q\Delta t \left( \mathbf{E}^{i+1/2} +
    !! \frac{\mathbf{v}^i}{2} \times \mathbf{B}^{i+1/2} \right)\).
    REAL(rp),DIMENSION(8)                                     :: t_X,t_Y,t_Z
    !! This variable is \(\mathbf{t} = {\mathbf \tau}/\gamma^{i+1}\).
    REAL(rp),DIMENSION(8),INTENT(INOUT)                     :: X_X,X_Y,X_Z
    REAL(rp),DIMENSION(8),INTENT(INOUT)                      :: V_X,V_Y,V_Z
    REAL(rp),DIMENSION(8),INTENT(IN)                      :: B_X,B_Y,B_Z
    REAL(rp),DIMENSION(8),INTENT(IN)                     :: E_X,E_Y,E_Z
    REAL(rp),DIMENSION(8)                     :: U_L_X,U_L_Y,U_L_Z
    REAL(rp),DIMENSION(8)                     :: U_X,U_Y,U_Z
    REAL(rp),DIMENSION(8)                     :: U_RC_X,U_RC_Y,U_RC_Z
    REAL(rp),DIMENSION(8)                     :: U_os_X,U_os_Y,U_os_Z
    !! This variable is \(\mathbf{u}^{i+1}= \mathbf{p}^{i+1}/m\).
    REAL(rp),DIMENSION(8)                          :: cross_X,cross_Y,cross_Z

    REAL(rp), DIMENSION(8)                       :: Frad_X,Frad_Y,Frad_Z
    !! Synchrotron radiation reaction force of each particle.

    REAL(rp),DIMENSION(8) :: ne,Te,Zeff,Y_R,Y_PHI,Y_Z

    INTEGER                                      :: cc
    !! Chunk iterator.

    INTEGER(is),DIMENSION(8),intent(in)             :: flag_cache

    dt=params%dt
    
    
    !$OMP SIMD
    do cc=1_idef,8

       g0(cc)=g(cc)
       
       U_X(cc) = g(cc)*V_X(cc)
       U_Y(cc) = g(cc)*V_Y(cc)
       U_Z(cc) = g(cc)*V_Z(cc)
       

       ! Magnitude of magnetic field
       Bmag(cc) = SQRT(B_X(cc)*B_X(cc)+B_Y(cc)*B_Y(cc)+B_Z(cc)*B_Z(cc))

       U_L_X(cc)=U_X(cc)
       U_L_Y(cc)=U_Y(cc)
       U_L_Z(cc)=U_Z(cc)

       U_RC_X(cc)=U_X(cc)
       U_RC_Y(cc)=U_Y(cc)
       U_RC_Z(cc)=U_Z(cc)
       
       ! LEAP-FROG SCHEME FOR LORENTZ FORCE !

       cross_X(cc)=V_Y(cc)*B_Z(cc)-V_Z(cc)*B_Y(cc)
       cross_Y(cc)=V_Z(cc)*B_X(cc)-V_X(cc)*B_Z(cc)
       cross_Z(cc)=V_X(cc)*B_Y(cc)-V_Y(cc)*B_X(cc)


       
       U_hs_X(cc) = U_L_X(cc) + 0.5_rp*a*(E_X(cc) +cross_X(cc))
       U_hs_Y(cc) = U_L_Y(cc) + 0.5_rp*a*(E_Y(cc) +cross_Y(cc))
       U_hs_Z(cc) = U_L_Z(cc) + 0.5_rp*a*(E_Z(cc) +cross_Z(cc))


       
       tau_X(cc) = 0.5_rp*a*B_X(cc)
       tau_Y(cc) = 0.5_rp*a*B_Y(cc)
       tau_Z(cc) = 0.5_rp*a*B_Z(cc)


       
       up_X(cc) = U_hs_X(cc) + 0.5_rp*a*E_X(cc)
       up_Y(cc) = U_hs_Y(cc) + 0.5_rp*a*E_Y(cc)
       up_Z(cc) = U_hs_Z(cc) + 0.5_rp*a*E_Z(cc)

       gp(cc) = SQRT( 1.0_rp + up_X(cc)*up_X(cc)+up_Y(cc)*up_Y(cc)+ &
            up_Z(cc)*up_Z(cc) )

       sigma(cc) = gp(cc)*gp(cc) - (tau_X(cc)*tau_X(cc)+ &
            tau_Y(cc)*tau_Y(cc)+tau_Z(cc)*tau_Z(cc))

       us(cc) = up_X(cc)*tau_X(cc)+up_Y(cc)*tau_Y(cc)+ &
            up_Z(cc)*tau_Z(cc)

       ! variable 'u^*' in Vay, J.-L. PoP (2008)
       g(cc) = SQRT( 0.5_rp*(sigma(cc) + SQRT(sigma(cc)*sigma(cc) + &
            4.0_rp*(tau_X(cc)*tau_X(cc)+tau_Y(cc)*tau_Y(cc)+ &
            tau_Z(cc)*tau_Z(cc) + us(cc)*us(cc)))) )

       t_X(cc) = tau_X(cc)/g(cc)
       t_Y(cc) = tau_Y(cc)/g(cc)
       t_Z(cc) = tau_Z(cc)/g(cc)

       
       s(cc) = 1.0_rp/(1.0_rp + t_X(cc)*t_X(cc)+t_Y(cc)*t_Y(cc)+ &
            t_Z(cc)*t_Z(cc))
       ! variable 's' in Vay, J.-L. PoP (2008)

       cross_X(cc)=up_Y(cc)*t_Z(cc)-up_Z(cc)*t_Y(cc)
       cross_Y(cc)=up_Z(cc)*t_X(cc)-up_X(cc)*t_Z(cc)
       cross_Z(cc)=up_X(cc)*t_Y(cc)-up_Y(cc)*t_X(cc)

       U_L_X(cc) = s(cc)*(up_X(cc) + (up_X(cc)*t_X(cc)+ &
            up_Y(cc)*t_Y(cc)+up_Z(cc)*t_Z(cc))*t_X(cc) + cross_X(cc))
       U_L_Y(cc) = s(cc)*(up_Y(cc) + (up_X(cc)*t_X(cc)+ &
            up_Y(cc)*t_Y(cc)+up_Z(cc)*t_Z(cc))*t_Y(cc) + cross_Y(cc))
       U_L_Z(cc) = s(cc)*(up_Z(cc) + (up_X(cc)*t_X(cc)+ &
            up_Y(cc)*t_Y(cc)+up_Z(cc)*t_Z(cc))*t_Z(cc) + cross_Z(cc))
       ! LEAP-FROG SCHEME FOR LORENTZ FORCE !      

       U_os_X(cc) = 0.5_rp*(U_L_X(cc) + U_X(cc))
       U_os_Y(cc) = 0.5_rp*(U_L_Y(cc) + U_Y(cc))
       U_os_Z(cc) = 0.5_rp*(U_L_Z(cc) + U_Z(cc))
       ! Splitting operator for including radiation

       if (params%radiation) then
          !! Calls [[radiation_force]] in [[korc_ppusher]].
          call radiation_force_p(q_cache,m_cache,U_os_X,U_os_Y,U_os_Z, &
               E_X,E_Y,E_Z,B_Z,B_Y,B_Z,Frad_X,Frad_Y,Frad_Z)
          U_RC_X(cc) = U_RC_X(cc) + a*Frad_X(cc)/q_cache
          U_RC_Y(cc) = U_RC_Y(cc) + a*Frad_Y(cc)/q_cache
          U_RC_Z(cc) = U_RC_Z(cc) + a*Frad_Z(cc)/q_cache
       end if
       ! Splitting operator for including radiation

       U_X(cc) = U_L_X(cc) + U_RC_X(cc) - U_X(cc)
       U_Y(cc) = U_L_Y(cc) + U_RC_Y(cc) - U_Y(cc)
       U_Z(cc) = U_L_Z(cc) + U_RC_Z(cc) - U_Z(cc)
       
    end do
    !$OMP END SIMD
   

    if (params%collisions) then

       call include_CoulombCollisions_FOeqn_p(tt,params,X_X,X_Y,X_Z, &
            U_X,U_Y,U_Z,B_X,B_Y,B_Z,m_cache,P,flag_cache)
          
    end if

    if (params%radiation.or.params%collisions) then

       !$OMP SIMD
       do cc=1_idef,8_idef
          g(cc)=sqrt(1._rp+U_X(cc)*U_X(cc)+U_Y(cc)*U_Y(cc)+U_Z(cc)*U_Z(cc))
       end do
       !$OMP END SIMD
       
    end if
    
    !$OMP SIMD
    do cc=1_idef,8_idef

       if (flag_cache(cc).eq.0_is) then
          g(cc)=g0(cc)
       else
          V_X(cc) = U_X(cc)/g(cc)
          V_Y(cc) = U_Y(cc)/g(cc)
          V_Z(cc) = U_Z(cc)/g(cc)
       end if

       X_X(cc) = X_X(cc) + dt*V_X(cc)*REAL(flag_cache(cc))
       X_Y(cc) = X_Y(cc) + dt*V_Y(cc)*REAL(flag_cache(cc))
       X_Z(cc) = X_Z(cc) + dt*V_Z(cc)*REAL(flag_cache(cc))
    end do
    !$OMP END SIMD
    
  end subroutine advance_FOeqn_vars

  subroutine advance_FP3Deqn_vars(params,X_X,X_Y,X_Z,V_X,V_Y,V_Z,g, &
       m_cache,B0,lam,R0,q0,EF0,B_X,B_Y,B_Z,E_X,E_Y,E_Z, &
       P,flag_cache)
    TYPE(PROFILES), INTENT(IN)                                 :: P
    TYPE(KORC_PARAMS), INTENT(INOUT)                              :: params
    !! Core KORC simulation parameters.
    INTEGER                                                    :: cc
    !! Chunk iterator.
    INTEGER(ip)                                                    :: tt
    !! time iterator.
    REAL(rp),DIMENSION(8), INTENT(IN)  :: X_X,X_Y,X_Z
    REAL(rp),DIMENSION(8), INTENT(IN)  :: E_X,E_Y,E_Z
    REAL(rp),DIMENSION(8), INTENT(IN)  :: B_X,B_Y,B_Z
    INTEGER(is),DIMENSION(8), INTENT(IN)  :: flag_cache
    REAL(rp),DIMENSION(8) :: U_X,U_Y,U_Z
    REAL(rp),DIMENSION(8), INTENT(INOUT)  :: V_X,V_Y,V_Z
    REAL(rp),DIMENSION(8),INTENT(INOUT) :: g
    REAL(rp),intent(in) :: B0,EF0,R0,q0,lam,m_cache
    


!    call analytical_fields_p(B0,EF0,R0,q0,lam,X_X,X_Y,X_Z, &
!         B_X,B_Y,B_Z,E_X,E_Y,E_Z)

    !$OMP SIMD
    do cc=1_idef,8_idef
       U_X(cc)=V_X(cc)*g(cc)
       U_Y(cc)=V_Y(cc)*g(cc)
       U_Z(cc)=V_Z(cc)*g(cc)
    end do
    !$OMP END SIMD
    
    do tt=1_ip,params%t_skip
          
       call include_CoulombCollisions_FOeqn_p(tt,params,X_X,X_Y,X_Z, &
            U_X,U_Y,U_Z,B_X,B_Y,B_Z,m_cache,P,flag_cache)
       
    end do

    !$OMP SIMD
    do cc=1_idef,8_idef

       g(cc)=sqrt(1._rp+U_X(cc)*U_X(cc)+U_Y(cc)*U_Y(cc)+U_Z(cc)*U_Z(cc))
          
       V_X(cc)=U_X(cc)/g(cc)
       V_Y(cc)=U_Y(cc)/g(cc)
       V_Z(cc)=U_Z(cc)/g(cc)
    end do
    !$OMP END SIMD

  end subroutine advance_FP3Deqn_vars
  
  subroutine adv_FOinterp_top(params,F,P,spp)  
    TYPE(KORC_PARAMS), INTENT(INOUT)                           :: params
    !! Core KORC simulation parameters.
    TYPE(FIELDS), INTENT(IN)                                   :: F
    !! An instance of the KORC derived type FIELDS.
    TYPE(PROFILES), INTENT(IN)                                 :: P
    !! An instance of the KORC derived type PROFILES.
    TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT)    :: spp
    !! An instance of the derived type SPECIES containing all the parameters
    !! and simulation variables of the different species in the simulation.
    REAL(rp), DIMENSION(8)               :: Bmag
    REAL(rp), DIMENSION(8)               :: b_unit_X,b_unit_Y,b_unit_Z
    REAL(rp), DIMENSION(8)               :: v,vpar,vperp
    REAL(rp), DIMENSION(8)               :: tmp
    REAL(rp), DIMENSION(8)               :: g
    REAL(rp), DIMENSION(8)               :: cross_X,cross_Y,cross_Z
    REAL(rp), DIMENSION(8)               :: vec_X,vec_Y,vec_Z
    REAL(rp),DIMENSION(8) :: X_X,X_Y,X_Z
    REAL(rp),DIMENSION(8) :: Y_R,Y_PHI,Y_Z
    REAL(rp),DIMENSION(8) :: V_X,V_Y,V_Z
    REAL(rp),DIMENSION(8) :: B_X,B_Y,B_Z
    REAL(rp),DIMENSION(8) :: E_X,E_Y,E_Z
    INTEGER(is),DIMENSION(8) :: flag_cache
    REAL(rp) :: a,m_cache,q_cache    
    INTEGER                                                    :: ii
    !! Species iterator.
    INTEGER                                                    :: pp
    !! Particles iterator.
    INTEGER                                                    :: cc
    !! Chunk iterator.
    INTEGER(ip)                                                    :: tt
    !! time iterator.
 

    do ii = 1_idef,params%num_species      

       m_cache=spp(ii)%m
       q_cache=spp(ii)%q
       a = q_cache*params%dt/m_cache
       
       
       !$OMP PARALLEL DO default(none) &
       !$OMP& FIRSTPRIVATE(a,m_cache,q_cache) &
       !$OMP& shared(params,ii,spp) &
       !$OMP& PRIVATE(E0,pp,tt,Bmag,cc,X_X,X_Y,X_Z,V_X,V_Y,V_Z,B_X,B_Y,B_Z, &
       !$OMP& E_X,E_Y,E_Z,b_unit_X,b_unit_Y,b_unit_Z,v,vpar,vperp,tmp, &
       !$OMP& cross_X,cross_Y,cross_Z,vec_X,vec_Y,vec_Z,g, &
       !$OMP& Y_R,Y_PHI,Y_Z,flag_cache)
       do pp=1_idef,spp(ii)%ppp,8

          !$OMP SIMD
          do cc=1_idef,8_idef
             X_X(cc)=spp(ii)%vars%X(pp-1+cc,1)
             X_Y(cc)=spp(ii)%vars%X(pp-1+cc,2)
             X_Z(cc)=spp(ii)%vars%X(pp-1+cc,3)

             V_X(cc)=spp(ii)%vars%V(pp-1+cc,1)
             V_Y(cc)=spp(ii)%vars%V(pp-1+cc,2)
             V_Z(cc)=spp(ii)%vars%V(pp-1+cc,3)

             g(cc)=spp(ii)%vars%g(pp-1+cc)
             
             flag_cache(cc)=spp(ii)%vars%flag(pp-1+cc)
          end do
          !$OMP END SIMD

          if (.not.params%FokPlan) then
             do tt=1_ip,params%t_skip

                call cart_to_cyl_p(X_X,X_Y,X_Z,Y_R,Y_PHI,Y_Z)
                
                call interp_FOfields_p(Y_R,Y_PHI,Y_Z,B_X,B_Y,B_Z, &
                     E_X,E_Y,E_Z,flag_cache)             

                call advance_FOinterp_vars(tt,a,q_cache,m_cache,params,X_X,X_Y,X_Z, &
                     V_X,V_Y,V_Z,B_X,B_Y,B_Z,E_X,E_Y,E_Z,g,flag_cache)
             end do !timestep iterator

             !$OMP SIMD
             do cc=1_idef,8_idef
                spp(ii)%vars%X(pp-1+cc,1)=X_X(cc)
                spp(ii)%vars%X(pp-1+cc,2)=X_Y(cc)
                spp(ii)%vars%X(pp-1+cc,3)=X_Z(cc)

                spp(ii)%vars%V(pp-1+cc,1)=V_X(cc)
                spp(ii)%vars%V(pp-1+cc,2)=V_Y(cc)
                spp(ii)%vars%V(pp-1+cc,3)=V_Z(cc)

                spp(ii)%vars%g(pp-1+cc) = g(cc)
                spp(ii)%vars%flag(pp-1+cc) = flag_cache(cc)

                spp(ii)%vars%B(pp-1+cc,1) = B_X(cc)
                spp(ii)%vars%B(pp-1+cc,2) = B_Y(cc)
                spp(ii)%vars%B(pp-1+cc,3) = B_Z(cc)

                spp(ii)%vars%E(pp-1+cc,1) = E_X(cc)
                spp(ii)%vars%E(pp-1+cc,2) = E_Y(cc)
                spp(ii)%vars%E(pp-1+cc,3) = E_Z(cc)
             end do
             !$OMP END SIMD

          else
             !$OMP SIMD
             do cc=1_idef,8_idef
                B_X(cc)=spp(ii)%vars%B(pp-1+cc,1)
                B_Y(cc)=spp(ii)%vars%B(pp-1+cc,2)
                B_Z(cc)=spp(ii)%vars%B(pp-1+cc,3)

                E_X(cc)=spp(ii)%vars%E(pp-1+cc,1)
                E_Y(cc)=spp(ii)%vars%E(pp-1+cc,2)
                E_Z(cc)=spp(ii)%vars%E(pp-1+cc,3)
             end do
             !$OMP END SIMD
             
             call advance_FP3Dinterp_vars(params,X_X,X_Y,X_Z,V_X,V_Y,V_Z, &
                  g,m_cache,B_X,B_Y,B_Z,E_X,E_Y,E_Z,flag_cache)

             !$OMP SIMD
             do cc=1_idef,8_idef

                spp(ii)%vars%V(pp-1+cc,1)=V_X(cc)
                spp(ii)%vars%V(pp-1+cc,2)=V_Y(cc)
                spp(ii)%vars%V(pp-1+cc,3)=V_Z(cc)

                spp(ii)%vars%g(pp-1+cc) = g(cc)

             end do
             !$OMP END SIMD
          end if

          !$OMP SIMD
          do cc=1_idef,8_idef
             !Derived output data
             Bmag(cc) = SQRT(B_X(cc)*B_X(cc)+B_Y(cc)*B_Y(cc)+B_Z(cc)*B_Z(cc))

             ! Parallel unit vector
             b_unit_X(cc) = B_X(cc)/Bmag(cc)
             b_unit_Y(cc) = B_Y(cc)/Bmag(cc)
             b_unit_Z(cc) = B_Z(cc)/Bmag(cc)

             v(cc) = SQRT(V_X(cc)*V_X(cc)+V_Y(cc)*V_Y(cc)+V_Z(cc)*V_Z(cc))
             if (v(cc).GT.korc_zero) then
                ! Parallel and perpendicular components of velocity
                vpar(cc) = (V_X(cc)*b_unit_X(cc)+V_Y(cc)*b_unit_Y(cc)+ &
                     V_Z(cc)*b_unit_Z(cc))
                
                vperp(cc) =  v(cc)**2 - vpar(cc)**2
                if ( vperp(cc) .GE. korc_zero ) then
                   vperp(cc) = SQRT( vperp(cc) )
                else
                   vperp(cc) = 0.0_rp
                end if

                ! Pitch angle
                spp(ii)%vars%eta(pp-1+cc) = 180.0_rp* &
                     MODULO(ATAN2(vperp(cc),vpar(cc)),2.0_rp*C_PI)/C_PI

                ! Magnetic moment
                spp(ii)%vars%mu(pp-1+cc) = 0.5_rp*m_cache* &
                     g(cc)**2*vperp(cc)**2/Bmag(cc)
                ! See Northrop's book (The adiabatic motion of charged
                ! particles)

                ! Radiated power
                tmp(cc) = q_cache**4/(6.0_rp*C_PI*E0*m_cache**2)

                cross_X(cc) = V_Y(cc)*B_Z(cc)-V_Z(cc)*B_Y(cc)
                cross_Y(cc) = V_Z(cc)*B_X(cc)-V_X(cc)*B_Z(cc)
                cross_Z(cc) = V_X(cc)*B_Y(cc)-V_Y(cc)*B_X(cc)
                
                vec_X(cc) = E_X(cc) + cross_X(cc)
                vec_Y(cc) = E_Y(cc) + cross_Y(cc)
                vec_Z(cc) = E_Z(cc) + cross_Z(cc)

                spp(ii)%vars%Prad(pp-1+cc) = tmp(cc)* &
                     ( E_X(cc)*E_X(cc)+E_Y(cc)*E_Y(cc)+E_Z(cc)*E_Z(cc) + &
                     cross_X(cc)*E_X(cc)+cross_Y(cc)*E_Y(cc)+ &
                     cross_Z(cc)*E_Z(cc) + g(cc)**2* &
                     ((E_X(cc)*V_X(cc)+E_Y(cc)*V_Y(cc)+E_Z(cc)*V_Z(cc))**2 &
                     - vec_X(cc)*vec_X(cc)+vec_Y(cc)*vec_Y(cc)+ &
                     vec_Z(cc)*vec_Z(cc)) )

                ! Input power due to electric field
                spp(ii)%vars%Pin(pp-1+cc) = q_cache*(E_X(cc)*V_X(cc)+ &
                     E_Y(cc)*V_Y(cc)+E_Z(cc)*V_Z(cc))
             else
                spp(ii)%vars%eta(pp-1+cc) = 0.0_rp
                spp(ii)%vars%mu(pp-1+cc) = 0.0_rp
                spp(ii)%vars%Prad(pp-1+cc) = 0.0_rp
                spp(ii)%vars%Pin(pp-1+cc) = 0.0_rp
             end if

          end do
          !$OMP END SIMD

             
       end do !particle chunk iterator
       !$OMP END PARALLEL DO
       
    end do !species iterator
    
  end subroutine adv_FOinterp_top
  
  subroutine advance_FOinterp_vars(tt,a,q_cache,m_cache,params,X_X,X_Y,X_Z, &
       V_X,V_Y,V_Z,B_X,B_Y,B_Z,E_X,E_Y,E_Z,g,flag_cache)
    TYPE(KORC_PARAMS), INTENT(IN)                              :: params
    !! Core KORC simulation parameters.

    INTEGER(ip), INTENT(IN)                                       :: tt
    !! Time step used in the leapfrog step (\(\Delta t\)).
    REAL(rp)                                      :: dt
    !! Time step used in the leapfrog step (\(\Delta t\)).
    REAL(rp), INTENT(IN)                                       :: m_cache,q_cache
    !! Time step used in the leapfrog step (\(\Delta t\)).

    REAL(rp),DIMENSION(8)                                  :: Bmag



    REAL(rp),INTENT(in)                                       :: a
    !! This variable is used to simplify notation in the code, and
    !! is given by \(a=q\Delta t/m\),
    REAL(rp),DIMENSION(8)                                    :: sigma
    !! This variable is \(\sigma = \gamma'^2 - \tau^2\) in the above equations.
    REAL(rp),DIMENSION(8)                               :: us
    !! This variable is \(u^{*} = p^{*}/m\) where \( p^{*} =
    !! \mathbf{p}'\cdot \mathbf{\tau}/mc\).
    !! Variable 'u^*' in Vay, J.-L. PoP (2008).
    REAL(rp),DIMENSION(8),INTENT(INOUT)                 :: g
    REAL(rp),DIMENSION(8) :: gp,g0
    !! Relativistic factor \(\gamma\).
    REAL(rp),DIMENSION(8)                                 :: s
    !! This variable is \(s = 1/(1+t^2)\) in the equations above.
    !! Variable 's' in Vay, J.-L. PoP (2008).
    REAL(rp),DIMENSION(8)                            :: U_hs_X,U_hs_Y,U_hs_Z
    !! Is \(\mathbf{u}=\mathbf{p}/m\) at half-time step (\(i+1/2\)) in
    !! the absence of radiation losses or collisions. \(\mathbf{u}^{i+1/2} =
    !! \mathbf{u}^i + \frac{q\Delta t}{2m}\left( \mathbf{E}^{i+1/2} +
    !! \mathbf{v}^i\times \mathbf{B}^{i+1/2} \right)\).
    REAL(rp),DIMENSION(8)                           :: tau_X,tau_Y,tau_Z
    !! This variable is \(\mathbf{\tau} = (q\Delta t/2)\mathbf{B}^{i+1/2}\).
    REAL(rp),DIMENSION(8)                            :: up_X,up_Y,up_Z
    !! This variable is \(\mathbf{u}'= \mathbf{p}'/m\), where \(\mathbf{p}'
    !! = \mathbf{p}^i + q\Delta t \left( \mathbf{E}^{i+1/2} +
    !! \frac{\mathbf{v}^i}{2} \times \mathbf{B}^{i+1/2} \right)\).
    REAL(rp),DIMENSION(8)                                     :: t_X,t_Y,t_Z
    !! This variable is \(\mathbf{t} = {\mathbf \tau}/\gamma^{i+1}\).
    REAL(rp),DIMENSION(8),INTENT(INOUT)                     :: X_X,X_Y,X_Z
    REAL(rp),DIMENSION(8)                    :: Y_R,Y_PHI,Y_Z
    REAL(rp),DIMENSION(8),INTENT(INOUT)                      :: V_X,V_Y,V_Z
    REAL(rp),DIMENSION(8),INTENT(IN)                      :: B_X,B_Y,B_Z
    REAL(rp),DIMENSION(8),INTENT(IN)                     :: E_X,E_Y,E_Z
    REAL(rp),DIMENSION(8)                     :: U_L_X,U_L_Y,U_L_Z
    REAL(rp),DIMENSION(8)                     :: U_X,U_Y,U_Z
    REAL(rp),DIMENSION(8)                     :: U_RC_X,U_RC_Y,U_RC_Z
    REAL(rp),DIMENSION(8)                     :: U_os_X,U_os_Y,U_os_Z
    !! This variable is \(\mathbf{u}^{i+1}= \mathbf{p}^{i+1}/m\).
    REAL(rp),DIMENSION(8)                          :: cross_X,cross_Y,cross_Z

    REAL(rp), DIMENSION(8)                       :: Frad_X,Frad_Y,Frad_Z
    !! Synchrotron radiation reaction force of each particle.

    REAL(rp),DIMENSION(8) :: ne,Te,Zeff

    INTEGER                                      :: cc
    !! Chunk iterator.

    INTEGER(is) ,DIMENSION(8),intent(inout)                   :: flag_cache

    dt=params%dt
    
    
    !$OMP SIMD
    do cc=1_idef,8

       g0(cc)=g(cc)
       
       U_X(cc) = g(cc)*V_X(cc)
       U_Y(cc) = g(cc)*V_Y(cc)
       U_Z(cc) = g(cc)*V_Z(cc)
       

       ! Magnitude of magnetic field
       Bmag(cc) = SQRT(B_X(cc)*B_X(cc)+B_Y(cc)*B_Y(cc)+B_Z(cc)*B_Z(cc))

       U_L_X(cc)=U_X(cc)
       U_L_Y(cc)=U_Y(cc)
       U_L_Z(cc)=U_Z(cc)

       U_RC_X(cc)=U_X(cc)
       U_RC_Y(cc)=U_Y(cc)
       U_RC_Z(cc)=U_Z(cc)

       ! LEAP-FROG SCHEME FOR LORENTZ FORCE !

       cross_X(cc)=V_Y(cc)*B_Z(cc)-V_Z(cc)*B_Y(cc)
       cross_Y(cc)=V_Z(cc)*B_X(cc)-V_X(cc)*B_Z(cc)
       cross_Z(cc)=V_X(cc)*B_Y(cc)-V_Y(cc)*B_X(cc)


       
       U_hs_X(cc) = U_L_X(cc) + 0.5_rp*a*(E_X(cc) +cross_X(cc))
       U_hs_Y(cc) = U_L_Y(cc) + 0.5_rp*a*(E_Y(cc) +cross_Y(cc))
       U_hs_Z(cc) = U_L_Z(cc) + 0.5_rp*a*(E_Z(cc) +cross_Z(cc))


       
       tau_X(cc) = 0.5_rp*a*B_X(cc)
       tau_Y(cc) = 0.5_rp*a*B_Y(cc)
       tau_Z(cc) = 0.5_rp*a*B_Z(cc)


       
       up_X(cc) = U_hs_X(cc) + 0.5_rp*a*E_X(cc)
       up_Y(cc) = U_hs_Y(cc) + 0.5_rp*a*E_Y(cc)
       up_Z(cc) = U_hs_Z(cc) + 0.5_rp*a*E_Z(cc)

       gp(cc) = SQRT( 1.0_rp + up_X(cc)*up_X(cc)+up_Y(cc)*up_Y(cc)+ &
            up_Z(cc)*up_Z(cc) )

       sigma(cc) = gp(cc)*gp(cc) - (tau_X(cc)*tau_X(cc)+ &
            tau_Y(cc)*tau_Y(cc)+tau_Z(cc)*tau_Z(cc))

       us(cc) = up_X(cc)*tau_X(cc)+up_Y(cc)*tau_Y(cc)+ &
            up_Z(cc)*tau_Z(cc)

       ! variable 'u^*' in Vay, J.-L. PoP (2008)
       g(cc) = SQRT( 0.5_rp*(sigma(cc) + SQRT(sigma(cc)*sigma(cc) + &
            4.0_rp*(tau_X(cc)*tau_X(cc)+tau_Y(cc)*tau_Y(cc)+ &
            tau_Z(cc)*tau_Z(cc) + us(cc)*us(cc)))) )

       t_X(cc) = tau_X(cc)/g(cc)
       t_Y(cc) = tau_Y(cc)/g(cc)
       t_Z(cc) = tau_Z(cc)/g(cc)

       
       s(cc) = 1.0_rp/(1.0_rp + t_X(cc)*t_X(cc)+t_Y(cc)*t_Y(cc)+ &
            t_Z(cc)*t_Z(cc))
       ! variable 's' in Vay, J.-L. PoP (2008)

       cross_X(cc)=up_Y(cc)*t_Z(cc)-up_Z(cc)*t_Y(cc)
       cross_Y(cc)=up_Z(cc)*t_X(cc)-up_X(cc)*t_Z(cc)
       cross_Z(cc)=up_X(cc)*t_Y(cc)-up_Y(cc)*t_X(cc)

       U_L_X(cc) = s(cc)*(up_X(cc) + (up_X(cc)*t_X(cc)+ &
            up_Y(cc)*t_Y(cc)+up_Z(cc)*t_Z(cc))*t_X(cc) + cross_X(cc))
       U_L_Y(cc) = s(cc)*(up_Y(cc) + (up_X(cc)*t_X(cc)+ &
            up_Y(cc)*t_Y(cc)+up_Z(cc)*t_Z(cc))*t_Y(cc) + cross_Y(cc))
       U_L_Z(cc) = s(cc)*(up_Z(cc) + (up_X(cc)*t_X(cc)+ &
            up_Y(cc)*t_Y(cc)+up_Z(cc)*t_Z(cc))*t_Z(cc) + cross_Z(cc))
       ! LEAP-FROG SCHEME FOR LORENTZ FORCE !

       U_os_X(cc) = 0.5_rp*(U_L_X(cc) + U_X(cc))
       U_os_Y(cc) = 0.5_rp*(U_L_Y(cc) + U_Y(cc))
       U_os_Z(cc) = 0.5_rp*(U_L_Z(cc) + U_Z(cc))
       ! Splitting operator for including radiation

       if (params%radiation) then
          !! Calls [[radiation_force]] in [[korc_ppusher]].
          call radiation_force_p(q_cache,m_cache,U_os_X,U_os_Y,U_os_Z, &
               E_X,E_Y,E_Z,B_Z,B_Y,B_Z,Frad_X,Frad_Y,Frad_Z)
          U_RC_X(cc) = U_RC_X(cc) + a*Frad_X(cc)/q_cache
          U_RC_Y(cc) = U_RC_Y(cc) + a*Frad_Y(cc)/q_cache
          U_RC_Z(cc) = U_RC_Z(cc) + a*Frad_Z(cc)/q_cache
       end if
       ! Splitting operator for including radiation

       U_X(cc) = U_L_X(cc) + U_RC_X(cc) - U_X(cc)
       U_Y(cc) = U_L_Y(cc) + U_RC_Y(cc) - U_Y(cc)
       U_Z(cc) = U_L_Z(cc) + U_RC_Z(cc) - U_Z(cc)
       
    end do
    !$OMP END SIMD
   
    if (params%collisions) then
       
       call include_CoulombCollisions_FOinterp_p(tt,params,X_X,X_Y,X_Z, &
            U_X,U_Y,U_Z,B_X,B_Y,B_Z,m_cache,flag_cache)
       
    end if

    if (params%radiation.or.params%collisions) then

       !$OMP SIMD
       do cc=1_idef,8_idef
          g(cc)=sqrt(1._rp+U_X(cc)*U_X(cc)+U_Y(cc)*U_Y(cc)+U_Z(cc)*U_Z(cc))
       end do
       !$OMP END SIMD
       
    end if
    
    !$OMP SIMD
    do cc=1_idef,8_idef
       
       if (flag_cache(cc).eq.0_is) then
          g(cc)=g0(cc)
       else
          V_X(cc) = U_X(cc)/g(cc)
          V_Y(cc) = U_Y(cc)/g(cc)
          V_Z(cc) = U_Z(cc)/g(cc)
       end if

       X_X(cc) = X_X(cc) + dt*V_X(cc)*REAL(flag_cache(cc))
       X_Y(cc) = X_Y(cc) + dt*V_Y(cc)*REAL(flag_cache(cc))
       X_Z(cc) = X_Z(cc) + dt*V_Z(cc)*REAL(flag_cache(cc))
       
    end do
    !$OMP END SIMD
    
  end subroutine advance_FOinterp_vars

  subroutine advance_FP3Dinterp_vars(params,X_X,X_Y,X_Z,V_X,V_Y,V_Z,g, &
       m_cache,B_X,B_Y,B_Z,E_X,E_Y,E_Z,flag_cache)    
    TYPE(KORC_PARAMS), INTENT(INOUT)                              :: params
    !! Core KORC simulation parameters.
    INTEGER                                                    :: cc
    !! Chunk iterator.
    INTEGER(ip)                                                    :: tt
    !! time iterator.
    REAL(rp),DIMENSION(8), INTENT(IN)  :: X_X,X_Y,X_Z
    REAL(rp),DIMENSION(8)  :: Y_R,Y_PHI,Y_Z
    REAL(rp),DIMENSION(8), INTENT(IN)  :: E_X,E_Y,E_Z
    REAL(rp),DIMENSION(8), INTENT(IN)  :: B_X,B_Y,B_Z
    REAL(rp),DIMENSION(8) :: U_X,U_Y,U_Z
    REAL(rp),DIMENSION(8), INTENT(INOUT)  :: V_X,V_Y,V_Z
    REAL(rp),DIMENSION(8) :: ne,Te,Zeff
    REAL(rp),DIMENSION(8),INTENT(INOUT) :: g
    INTEGER(is),DIMENSION(8),INTENT(IN) :: flag_cache
    REAL(rp),intent(in) :: m_cache
    
      
    
    !$OMP SIMD
    do cc=1_idef,8_idef
       U_X(cc)=V_X(cc)*g(cc)
       U_Y(cc)=V_Y(cc)*g(cc)
       U_Z(cc)=V_Z(cc)*g(cc)
    end do
    !$OMP END SIMD
    
    do tt=1_ip,params%t_skip
          
       call include_CoulombCollisions_FOinterp_p(tt,params,X_X,X_Y,X_Z, &
            U_X,U_Y,U_Z,B_X,B_Y,B_Z,m_cache,flag_cache)
       
    end do

    !$OMP SIMD
    do cc=1_idef,8_idef

       g(cc)=sqrt(1._rp+U_X(cc)*U_X(cc)+U_Y(cc)*U_Y(cc)+U_Z(cc)*U_Z(cc))
          
       V_X(cc)=U_X(cc)/g(cc)
       V_Y(cc)=U_Y(cc)/g(cc)
       V_Z(cc)=U_Z(cc)/g(cc)
    end do
    !$OMP END SIMD

  end subroutine advance_FP3Dinterp_vars
  
  subroutine advance_particles_position(params,F,spp,dt)
    !! @note Subroutine to advance particles' position. @endnote
    !! This subroutine advances the particles position using the information
    !! of the updated velocity.
    !!
    !! $$\frac{\mathbf{x}^{i+1/2} - \mathbf{x}^{i-1/2}}{\Delta t}  =
    !! \mathbf{v}^i$$
    !!
    !! @note Notice that all the variables in this subroutine have been
    !! normalized using the characteristic scales in [[korc_units]]. @endnote
    TYPE(KORC_PARAMS), INTENT(IN)                              :: params
    !! Core KORC simulation parameters.
    TYPE(FIELDS), INTENT(IN)                                   :: F
    !! An instance of the KORC derived type FIELDS.
    TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT)    :: spp
    !! An instance of the derived type SPECIES containing all the parameters
    !! and simulation variables of the different species in the simulation.
    REAL(rp), INTENT(IN)                                       :: dt
    !! Time step used in the leapfrog step (\(\Delta t\)).
    INTEGER                                                    :: ii
    !! Species iterator.
    INTEGER                                                    :: pp
    !! Particles iterator.

    do ii=1_idef,params%num_species
       !$OMP PARALLEL DO FIRSTPRIVATE(dt) PRIVATE(pp) SHARED(ii,spp,params)
       do pp=1_idef,spp(ii)%ppp          

          if ( spp(ii)%vars%flag(pp) .EQ. 1_is ) then


             spp(ii)%vars%X(pp,:) = spp(ii)%vars%X(pp,:) + &
                  dt*spp(ii)%vars%V(pp,:)

          end if
       end do
       !$OMP END PARALLEL DO

       !spp(ii)%vars%X = MERGE(spp(ii)%vars%X + dt*spp(ii)%vars%V, &
       !     spp(ii)%vars%X,SPREAD(spp(ii)%vars%flag,1,3).EQ.1_idef)
    end do

  end subroutine advance_particles_position

  subroutine GC_init(params,F,spp)
    !! @note Subroutine to advance GC variables \(({\bf X},p_\parallel)\)
    !! @endnote
    !! Comment this section further with evolution equations, numerical
    !! methods, and descriptions of both.
    TYPE(KORC_PARAMS), INTENT(INOUT)                           :: params
    !! Core KORC simulation parameters.
    TYPE(FIELDS), INTENT(IN)                                   :: F
    !! An instance of the KORC derived type FIELDS.

    TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT)    :: spp
    !! An instance of the derived type SPECIES containing all the parameters
    !! and simulation variables of the different species in the simulation.

    INTEGER                                                    :: ii
    !! Species iterator.
    INTEGER                                                    :: pp
    !! Particles iterator.
    INTEGER                                                    :: cc
    !! Chunk iterator.
    REAL(rp)               :: Bmag1,pmag
    REAL(rp)               :: Bmagc
    REAL(rp)               :: rm
    REAL(rp),DIMENSION(:,:),ALLOCATABLE               :: RAphi
    REAL(rp), DIMENSION(3) :: bhat
    REAL(rp), DIMENSION(3) :: bhatc
    REAL(rp),DIMENSION(:),ALLOCATABLE               :: RVphi

!    write(6,'("eta",E17.10)') spp(ii)%vars%eta(pp)
!    write(6,'("gam",E17.10)') spp(ii)%vars%g(pp)

    do ii = 1_idef,params%num_species


       if (spp(1)%spatial_distribution.eq.'TRACER') then
          call get_fields(params,spp(ii)%vars,F)
          !! Calls [[get_fields]] in [[korc_fields]].
          ! Interpolates fields at local particles' position and keeps in
          ! spp%vars. Fields in (R,\(\phi\),Z) coordinates. 

          ALLOCATE(RAphi(spp(ii)%ppp,2))
          ALLOCATE(RVphi(spp(ii)%ppp))
          RAphi=0.0_rp

          call cart_to_cyl(spp(ii)%vars%X,spp(ii)%vars%Y)

          !$OMP PARALLEL DO SHARED(params,ii,spp,F,RAphi,RVphi) &
          !$OMP&  PRIVATE(pp,Bmag1,bhat,rm)
          ! Call OpenMP to calculate p_par and mu for each particle and
          ! put into spp%vars%V
          do pp=1_idef,spp(ii)%ppp
             if ( spp(ii)%vars%flag(pp) .EQ. 1_is ) then

                RVphi(pp)=(-sin(spp(ii)%vars%Y(pp,2))*spp(ii)%vars%V(pp,1)+ &
                     cos(spp(ii)%vars%Y(pp,2))*spp(ii)%vars%V(pp,2))* &
                     spp(ii)%vars%Y(pp,1)

                Bmag1 = SQRT(spp(ii)%vars%B(pp,1)*spp(ii)%vars%B(pp,1)+ &
                     spp(ii)%vars%B(pp,2)*spp(ii)%vars%B(pp,2)+ &
                     spp(ii)%vars%B(pp,3)*spp(ii)%vars%B(pp,3))

                !             write(6,'("pp: ",I16)') pp
                !             write(6,'("Bmag: ",E17.10)') Bmag


                bhat = spp(ii)%vars%B(pp,:)/Bmag1

                if (params%plasma_model.eq.'ANALYTICAL') then
                   rm=sqrt((spp(ii)%vars%Y(pp,1)-F%AB%Ro)**2+ &
                        (spp(ii)%vars%Y(pp,3))**2)

                   RAphi(pp,1)=-F%AB%lambda**2*F%AB%Bo/(2*F%AB%qo)* &
                        log(1+(rm/F%AB%lambda)**2)
                end if

                !             write(6,'("bhat: ",E17.10)') bhat 
                !             write(6,'("V: ",E17.10)') spp(ii)%vars%V(pp,:)


                spp(ii)%vars%X(pp,:)=spp(ii)%vars%X(pp,:)- &
                     spp(ii)%m*spp(ii)%vars%g(pp)* &
                     cross(bhat,spp(ii)%vars%V(pp,:))/(spp(ii)%q*Bmag1)

                ! transforming from particle location to associated
                ! GC location

             end if ! if particle in domain, i.e. spp%vars%flag==1
          end do ! loop over particles on an mpi process
          !$OMP END PARALLEL DO

          call cart_to_cyl(spp(ii)%vars%X,spp(ii)%vars%Y)

          !$OMP PARALLEL DO SHARED(params,ii,spp,F,RAphi,RVphi) &
          !$OMP&  PRIVATE(pp,rm)
          ! Call OpenMP to calculate p_par and mu for each particle and
          ! put into spp%vars%V
          do pp=1_idef,spp(ii)%ppp
             if ( spp(ii)%vars%flag(pp) .EQ. 1_is ) then

                if (params%plasma_model.eq.'ANALYTICAL') then
                   rm=sqrt((spp(ii)%vars%Y(pp,1)-F%AB%Ro)**2+ &
                        (spp(ii)%vars%Y(pp,3))**2)
                   RAphi(pp,2)=-F%AB%lambda**2*F%AB%Bo/(2*F%AB%qo)* &
                        log(1+(rm/F%AB%lambda)**2)
                end if

                spp(ii)%vars%V(pp,1)=(spp(ii)%m*spp(ii)%vars%g(pp)* &
                     RVphi(pp)+spp(ii)%q*(RAphi(pp,1)-RAphi(pp,2)))/ &
                     spp(ii)%vars%Y(pp,1)
                !GC ppar              

             end if ! if particle in domain, i.e. spp%vars%flag==1
          end do ! loop over particles on an mpi process
          !$OMP END PARALLEL DO

          call get_fields(params,spp(ii)%vars,F)

          !$OMP PARALLEL DO SHARED(ii,spp) PRIVATE(pp,Bmagc,bhatc)
          ! Call OpenMP to calculate p_par and mu for each particle and
          ! put into spp%vars%V
          do pp=1_idef,spp(ii)%ppp
             if ( spp(ii)%vars%flag(pp) .EQ. 1_is ) then

                Bmagc = SQRT( DOT_PRODUCT(spp(ii)%vars%B(pp,:), &
                     spp(ii)%vars%B(pp,:)))

                bhatc = spp(ii)%vars%B(pp,:)/Bmagc

                spp(ii)%vars%V(pp,1)=spp(ii)%vars%V(pp,1)/ &
                     bhatc(2)
                !GC ppar

                spp(ii)%vars%V(pp,2)=spp(ii)%m/(2*Bmagc)*(spp(ii)%vars%g(pp)**2- &
                     (1+(spp(ii)%vars%V(pp,1)/spp(ii)%m)**2))           
                !GC mu


             end if ! if particle in domain, i.e. spp%vars%flag==1
          end do ! loop over particles on an mpi process
          !$OMP END PARALLEL DO

          params%GC_coords=.TRUE.
          DEALLOCATE(RAphi)
          DEALLOCATE(RVphi)

          !Preparing Output Data
          call get_fields(params,spp(ii)%vars,F)



          !$OMP PARALLEL DO SHARED(ii,spp) PRIVATE(pp,Bmag1)
          ! Call OpenMP to calculate p_par and mu for each particle and
          ! put into spp%vars%V
          do pp=1_idef,spp(ii)%ppp
             if ( spp(ii)%vars%flag(pp) .EQ. 1_is ) then

                Bmag1 = SQRT( DOT_PRODUCT(spp(ii)%vars%B(pp,:), &
                     spp(ii)%vars%B(pp,:)))

                spp(ii)%vars%g(pp)=sqrt(1+(spp(ii)%vars%V(pp,1))**2+ &
                     2*spp(ii)%vars%V(pp,2)*Bmag1)

                spp(ii)%vars%eta(pp) = atan2(sqrt(2*spp(ii)%m*Bmag1* &
                     spp(ii)%vars%V(pp,2)),spp(ii)%vars%V(pp,1))*180.0_rp/C_PI

!                             write(6,'("BR",E17.10)') spp(ii)%vars%B(pp,1)
!                             write(6,'("BPHI",E17.10)') spp(ii)%vars%B(pp,2)
!                             write(6,'("BZ",E17.10)') spp(ii)%vars%B(pp,3)

                !             write(6,'("ppll",E17.10)') spp(ii)%vars%V(pp,1)
                !             write(6,'("pperp",E17.10)') sqrt(2*spp(ii)%m*Bmag1* &
                !                  spp(ii)%vars%V(pp,2))

                !             write(6,'("eta",E17.10)') spp(ii)%vars%eta(pp)
                !             write(6,'("gam",E17.10)') spp(ii)%vars%g(pp)


             end if ! if particle in domain, i.e. spp%vars%flag==1
          end do ! loop over particles on an mpi process
          !$OMP END PARALLEL DO                
       else


          params%GC_coords=.TRUE.
          call get_fields(params,spp(ii)%vars,F)

          
          !$OMP PARALLEL DO SHARED(ii,spp) PRIVATE(pp,Bmag1)

          do pp=1_idef,spp(ii)%ppp
             if ( spp(ii)%vars%flag(pp) .EQ. 1_is ) then

!                write(6,'("BR: ",E17.10)') spp(ii)%vars%B(pp,1)
!                write(6,'("BPHI: ",E17.10)') spp(ii)%vars%B(pp,2)
!                write(6,'("BZ: ",E17.10)') spp(ii)%vars%B(pp,3)
                
                Bmag1 = SQRT( DOT_PRODUCT(spp(ii)%vars%B(pp,:), &
                     spp(ii)%vars%B(pp,:)))

                pmag=sqrt(spp(ii)%vars%g(pp)**2-1)
                
                spp(ii)%vars%V(pp,1)=pmag*cos(deg2rad(spp(ii)%vars%eta(pp)))

                spp(ii)%vars%V(pp,2)=(pmag* &
                     sin(deg2rad(spp(ii)%vars%eta(pp))))**2/ &
                     (2*spp(ii)%m*Bmag1)
                
                !    write(6,'("BR",E17.10)') spp(ii)%vars%B(pp,1)
                !    write(6,'("BPHI",E17.10)') spp(ii)%vars%B(pp,2)
                !    write(6,'("BZ",E17.10)') spp(ii)%vars%B(pp,3)

                !write(6,'("ppll",E17.10)') spp(ii)%vars%V(pp,1)
                !write(6,'("mu",E17.10)') spp(ii)%vars%V(pp,2)

                !     write(6,'("eta",E17.10)') spp(ii)%vars%eta(pp)
                !     write(6,'("gam",E17.10)') spp(ii)%vars%g(pp)


             end if ! if particle in domain, i.e. spp%vars%flag==1
          end do ! loop over particles on an mpi process
          !$OMP END PARALLEL DO  
          
       end if

    end do ! loop over particle species
    
  end subroutine GC_init

  FUNCTION deg2rad(x)
    REAL(rp), INTENT(IN) :: x
    REAL(rp) :: deg2rad

    deg2rad = C_PI*x/180.0_rp
  END FUNCTION deg2rad

  FUNCTION rad2deg(x)
    REAL(rp), INTENT(IN) :: x
    REAL(rp) :: rad2deg

    rad2deg = x*180.0_rp/C_PI
  END FUNCTION rad2deg
  
  subroutine adv_GCeqn_top(params,F,P,spp)
    
    TYPE(KORC_PARAMS), INTENT(INOUT)                           :: params
    !! Core KORC simulation parameters.
    TYPE(FIELDS), INTENT(IN)                                   :: F
    !! An instance of the KORC derived type FIELDS.
    TYPE(PROFILES), INTENT(IN)                                 :: P
    !! An instance of the KORC derived type PROFILES.
    TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT)    :: spp
    !! An instance of the derived type SPECIES containing all the parameters
    !! and simulation variables of the different species in the simulation.
    REAL(rp), DIMENSION(8)               :: Bmag
    REAL(rp),DIMENSION(8) :: Y_R,Y_PHI,Y_Z
    REAL(rp),DIMENSION(8) :: B_R,B_PHI,B_Z,E_PHI
    REAL(rp),DIMENSION(8) :: V_PLL,V_MU
    REAL(rp) :: B0,EF0,R0,q0,lam,ar,m_cache,q_cache,ne0,Te0,Zeff0
    INTEGER(is),DIMENSION(8)  :: flag_cache

    LOGICAL                                                    :: ss_collisions
    !! Logical variable that indicates if collisions are included in
    !! the simulation.
    
    INTEGER                                                    :: ii
    !! Species iterator.
    INTEGER                                                    :: pp
    !! Particles iterator.
    INTEGER                                                    :: cc
    !! Chunk iterator.
    INTEGER(ip)                                                    :: tt
    !! time iterator.
 

    do ii = 1_idef,params%num_species      

       q_cache=spp(ii)%q
       m_cache=spp(ii)%m

       B0=F%AB%Bo
       EF0=F%Eo
       lam=F%AB%lambda
       R0=F%AB%Ro
       q0=F%AB%qo
       ar=F%AB%a

       
       !$OMP PARALLEL DO default(none) &
       !$OMP& FIRSTPRIVATE(E0,q_cache,m_cache,B0,EF0,lam,R0,q0,ar, &
       !$OMP& ne0,Te0,Zeff0) &
       !$OMP& shared(F,P,params,ii,spp) &
       !$OMP& PRIVATE(pp,tt,Bmag,cc,Y_R,Y_PHI,Y_Z,V_PLL,V_MU,flag_cache, &
       !$OMP& B_R,B_PHI,B_Z,E_PHI)
       do pp=1_idef,spp(ii)%ppp,8

          !$OMP SIMD
          do cc=1_idef,8_idef
             Y_R(cc)=spp(ii)%vars%Y(pp-1+cc,1)
             Y_PHI(cc)=spp(ii)%vars%Y(pp-1+cc,2)
             Y_Z(cc)=spp(ii)%vars%Y(pp-1+cc,3)

             V_PLL(cc)=spp(ii)%vars%V(pp-1+cc,1)
             V_MU(cc)=spp(ii)%vars%V(pp-1+cc,2)

             flag_cache(cc)=spp(ii)%vars%flag(pp-1+cc)
          end do
          !$OMP END SIMD
          
          if (.not.params%FokPlan) then       
             do tt=1_ip,params%t_skip
                call advance_GCeqn_vars(tt,params,Y_R,Y_PHI, &
                     Y_Z,V_PLL,V_MU,flag_cache,q_cache,m_cache, &
                     B0,lam,R0,q0,ar,EF0,B_R,B_PHI,B_Z,P)
             end do !timestep iterator

             !$OMP SIMD
             do cc=1_idef,8_idef
                spp(ii)%vars%Y(pp-1+cc,1)=Y_R(cc)
                spp(ii)%vars%Y(pp-1+cc,2)=Y_PHI(cc)
                spp(ii)%vars%Y(pp-1+cc,3)=Y_Z(cc)
                
                spp(ii)%vars%V(pp-1+cc,1)=V_PLL(cc)
                spp(ii)%vars%V(pp-1+cc,2)=V_MU(cc)
                
                spp(ii)%vars%flag(pp-1+cc)=flag_cache(cc)

                spp(ii)%vars%B(pp-1+cc,1) = B_R(cc)
                spp(ii)%vars%B(pp-1+cc,2) = B_PHI(cc)
                spp(ii)%vars%B(pp-1+cc,3) = B_Z(cc)
             end do
             !$OMP END SIMD
             
          else
             call advance_FPeqn_vars(params,Y_R,Y_PHI, &
                  Y_Z,V_PLL,V_MU,flag_cache,m_cache,B0,lam,R0,q0,EF0, &
                  P)

             !$OMP SIMD
             do cc=1_idef,8_idef
                spp(ii)%vars%V(pp-1+cc,1)=V_PLL(cc)
                spp(ii)%vars%V(pp-1+cc,2)=V_MU(cc)

                spp(ii)%vars%flag(pp-1+cc)=flag_cache(cc)
             end do
             !$OMP END SIMD
             
          end if
                  
          
          call analytical_fields_Bmag_p(R0,B0,lam,q0,EF0,Y_R,Y_PHI,Y_Z, &
               Bmag,E_PHI)

          !$OMP SIMD
          do cc=1_idef,8_idef
             spp(ii)%vars%g(pp-1+cc)=sqrt(1+V_PLL(cc)**2+ &
                  2*V_MU(cc)*Bmag(cc)*m_cache)

             spp(ii)%vars%eta(pp-1+cc) = rad2deg(atan2(sqrt(2*m_cache* &
                  Bmag(cc)*spp(ii)%vars%V(pp-1+cc,2)), &
                  spp(ii)%vars%V(pp-1+cc,1)))
          end do
          !$OMP END SIMD
             
       end do !particle chunk iterator
       !$OMP END PARALLEL DO
       
    end do !species iterator
    
  end subroutine adv_GCeqn_top

  subroutine advance_GCeqn_vars(tt,params,Y_R,Y_PHI,Y_Z,V_PLL,V_MU,flag_cache, &
       q_cache,m_cache,B0,lam,R0,q0,ar,EF0,B_R,B_PHI,B_Z,P)
    !! @note Subroutine to advance GC variables \(({\bf X},p_\parallel)\)
    !! @endnote
    !! Comment this section further with evolution equations, numerical
    !! methods, and descriptions of both.
    TYPE(KORC_PARAMS), INTENT(INOUT)                              :: params
    !! Core KORC simulation parameters.
    TYPE(PROFILES), INTENT(IN)                                 :: P
    !! An instance of the KORC derived type PROFILES.
    REAL(rp)                                      :: dt
    !! Time step used in the leapfrog step (\(\Delta t\)).

    INTEGER                                                    :: cc
    !! Chunk iterator.
    INTEGER(ip)                                                    :: tt
    !! time iterator.

    REAL(rp) :: a1 = 1./5._rp
    REAL(rp) :: a21 = 3./40._rp,a22=9./40._rp
    REAL(rp) :: a31 = 3./10._rp,a32=-9./10._rp,a33=6./5._rp
    REAL(rp) :: a41 = -11./54._rp,a42=5./2._rp,a43=-70./27._rp,a44=35./27._rp
    REAL(rp) :: a51 = 1631./55296._rp,a52=175./512._rp,a53=575./13824._rp,a54=44275./110592._rp,a55=253./4096._rp
    REAL(rp) :: b1=37./378._rp,b2=0._rp,b3=250./621._rp,b4=125./594._rp,b5=0._rp,b6=512./1771._rp

    REAL(rp),DIMENSION(8) :: k1_R,k1_PHI,k1_Z,k1_PLL
    REAL(rp),DIMENSION(8) :: k2_R,k2_PHI,k2_Z,k2_PLL
    REAL(rp),DIMENSION(8) :: k3_R,k3_PHI,k3_Z,k3_PLL
    REAL(rp),DIMENSION(8) :: k4_R,k4_PHI,k4_Z,k4_PLL
    REAL(rp),DIMENSION(8) :: k5_R,k5_PHI,k5_Z,k5_PLL
    REAL(rp),DIMENSION(8) :: k6_R,k6_PHI,k6_Z,k6_PLL
    REAL(rp),DIMENSION(8) :: Y0_R,Y0_PHI,Y0_Z
    REAL(rp),DIMENSION(8),INTENT(INOUT) :: Y_R,Y_PHI,Y_Z
    REAL(rp),DIMENSION(8),INTENT(OUT) :: B_R,B_PHI,B_Z
    REAL(rp),DIMENSION(8) :: curlb_R,curlb_PHI,curlb_Z,gradB_R,gradB_PHI,gradB_Z
    REAL(rp),DIMENSION(8),INTENT(INOUT) :: V_PLL,V_MU
    REAL(rp),DIMENSION(8) :: RHS_R,RHS_PHI,RHS_Z,RHS_PLL,V0,E_PHI,E_Z,E_R
    REAL(rp),DIMENSION(8) :: Bmag,ne,Te,Zeff
    INTEGER(is),dimension(8), intent(inout) :: flag_cache
    
    REAL(rp),intent(IN) :: B0,EF0,R0,q0,lam,ar
    REAL(rp),intent(IN) :: q_cache,m_cache


    
    dt=params%dt
        
    !$OMP SIMD
    do cc=1_idef,8_idef
       Y0_R(cc)=Y_R(cc)
       Y0_PHI(cc)=Y_PHI(cc)
       Y0_Z(cc)=Y_Z(cc)
       V0(cc)=V_PLL(cc)
    end do
    !$OMP END SIMD

    call analytical_fields_GC_p(R0,B0,lam,q0,EF0,Y_R,Y_PHI, &
         Y_Z,B_R,B_PHI,B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z, &
         gradB_R,gradB_PHI,gradB_Z)

    write(6,'("ER:",E17.10)') E_R
    write(6,'("EPHI:",E17.10)') E_PHI
    write(6,'("EZ:",E17.10)') E_Z
    

    call GCEoM_p(params,RHS_R,RHS_PHI,RHS_Z,RHS_PLL,B_R,B_PHI, &
         B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R, &
         gradB_PHI,gradB_Z,V_PLL,V_MU,Y_R,q_cache,m_cache) 

    !$OMP SIMD
    do cc=1_idef,8
       k1_R(cc)=dt*RHS_R(cc)              
       k1_PHI(cc)=dt*RHS_PHI(cc)    
       k1_Z(cc)=dt*RHS_Z(cc)    
       k1_PLL(cc)=dt*RHS_PLL(cc)    

       Y_R(cc)=Y0_R(cc)+a1*k1_R(cc)
       Y_PHI(cc)=Y0_PHI(cc)+a1*k1_PHI(cc)
       Y_Z(cc)=Y0_Z(cc)+a1*k1_Z(cc)
       V_PLL(cc)=V0(cc)   +a1*k1_PLL(cc)
    end do
    !$OMP END SIMD

!    write(6,'("k1R: ",E17.10)') k1_R(1)
!    write(6,'("k1PHI: ",E17.10)') k1_PHI(1)
!    write(6,'("k1Z: ",E17.10)') k1_Z(1)
!    write(6,'("k1PLL: ",E17.10)') k1_PLL(1) 
    
    call analytical_fields_GC_p(R0,B0,lam,q0,EF0,Y_R,Y_PHI, &
         Y_Z,B_R,B_PHI,B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z, &
         gradB_R,gradB_PHI,gradB_Z)


    call GCEoM_p(params,RHS_R,RHS_PHI,RHS_Z,RHS_PLL,B_R,B_PHI, &
         B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R, &
         gradB_PHI,gradB_Z,V_PLL,V_MU,Y_R,q_cache,m_cache) 

    !$OMP SIMD
    do cc=1_idef,8
       k2_R(cc)=dt*RHS_R(cc)    
       k2_PHI(cc)=dt*RHS_PHI (cc)   
       k2_Z(cc)=dt*RHS_Z(cc)   
       k2_PLL(cc)=dt*RHS_PLL(cc)

       Y_R(cc)=Y0_R(cc)+a21*k1_R(cc)+a22*k2_R(cc)
       Y_PHI(cc)=Y0_PHI(cc)+a21*k1_PHI(cc)+a22*k2_PHI(cc)
       Y_Z(cc)=Y0_Z(cc)+a21*k1_Z(cc)+a22*k2_Z(cc)
       V_PLL(cc)=V0(cc)   +a21*k1_PLL(cc)+a22*k2_PLL(cc)
    end do
    !$OMP END SIMD

    call analytical_fields_GC_p(R0,B0,lam,q0,EF0,Y_R,Y_PHI, &
         Y_Z,B_R,B_PHI,B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z, &
         gradB_R,gradB_PHI,gradB_Z)


    call GCEoM_p(params,RHS_R,RHS_PHI,RHS_Z,RHS_PLL,B_R,B_PHI, &
         B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R, &
         gradB_PHI,gradB_Z,V_PLL,V_MU,Y_R,q_cache,m_cache)

    !$OMP SIMD
    do cc=1_idef,8
       k3_R(cc)=dt*RHS_R(cc)   
       k3_PHI(cc)=dt*RHS_PHI(cc)    
       k3_Z(cc)=dt*RHS_Z(cc)    
       k3_PLL(cc)=dt*RHS_PLL(cc)

       Y_R(cc)=Y0_R(cc)+a31*k1_R(cc)+a32*k2_R(cc)+a33*k3_R(cc)
       Y_PHI(cc)=Y0_PHI(cc)+a31*k1_PHI(cc)+a32*k2_PHI(cc)+ &
            a33*k3_PHI(cc)
       Y_Z(cc)=Y0_Z(cc)+a31*k1_Z(cc)+a32*k2_Z(cc)+a33*k3_Z(cc)
       V_PLL(cc)=V0(cc)   +a31*k1_PLL(cc)+a32*k2_PLL(cc)+a33*k3_PLL(cc)
    end do
    !$OMP END SIMD

    call analytical_fields_GC_p(R0,B0,lam,q0,EF0,Y_R,Y_PHI, &
         Y_Z,B_R,B_PHI,B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z, &
         gradB_R,gradB_PHI,gradB_Z)


    call GCEoM_p(params,RHS_R,RHS_PHI,RHS_Z,RHS_PLL,B_R,B_PHI, &
         B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R, &
         gradB_PHI,gradB_Z,V_PLL,V_MU,Y_R,q_cache,m_cache)     

    !$OMP SIMD
    do cc=1_idef,8
       k4_R(cc)=dt*RHS_R(cc)   
       k4_PHI(cc)=dt*RHS_PHI(cc)    
       k4_Z(cc)=dt*RHS_Z(cc)    
       k4_PLL(cc)=dt*RHS_PLL(cc)

       Y_R(cc)=Y0_R(cc)+a41*k1_R(cc)+a42*k2_R(cc)+a43*k3_R(cc)+ &
            a44*k4_R(cc)
       Y_PHI(cc)=Y0_PHI(cc)+a41*k1_PHI(cc)+a42*k2_PHI(cc)+ &
            a43*k3_PHI(cc)+a44*k4_PHI(cc)
       Y_Z(cc)=Y0_Z(cc)+a41*k1_Z(cc)+a42*k2_Z(cc)+a43*k3_Z(cc)+ &
            a44*k4_Z(cc)
       V_PLL(cc)=V0(cc)   +a41*k1_PLL(cc)+a42*k2_PLL(cc)+ &
            a43*k3_PLL(cc)+a44*k4_PLL(cc)
    end do
    !$OMP END SIMD


    call analytical_fields_GC_p(R0,B0,lam,q0,EF0,Y_R,Y_PHI, &
         Y_Z,B_R,B_PHI,B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z, &
         gradB_R,gradB_PHI,gradB_Z)


    call GCEoM_p(params,RHS_R,RHS_PHI,RHS_Z,RHS_PLL,B_R,B_PHI, &
         B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R, &
         gradB_PHI,gradB_Z,V_PLL,V_MU,Y_R,q_cache,m_cache)   

    !$OMP SIMD
    do cc=1_idef,8
       k5_R(cc)=dt*RHS_R(cc)    
       k5_PHI(cc)=dt*RHS_PHI(cc)    
       k5_Z(cc)=dt*RHS_Z(cc)    
       k5_PLL(cc)=dt*RHS_PLL(cc)

       Y_R(cc)=Y0_R(cc)+a51*k1_R(cc)+a52*k2_R(cc)+a53*k3_R(cc)+ &
            a54*k4_R(cc)+a55*k5_R(cc)
       Y_PHI(cc)=Y0_PHI(cc)+a51*k1_PHI(cc)+a52*k2_PHI(cc)+ &
            a53*k3_PHI(cc)+a54*k4_PHI(cc)+a55*k5_PHI(cc)
       Y_Z(cc)=Y0_Z(cc)+a51*k1_Z(cc)+a52*k2_Z(cc)+a53*k3_Z(cc)+ &
            a54*k4_Z(cc)+a55*k5_Z(cc)
       V_PLL(cc)=V0(cc)   +a51*k1_PLL(cc)+a52*k2_PLL(cc)+ &
            a53*k3_PLL(cc)+a54*k4_PLL(cc)+a55*k5_PLL(cc)
    end do
    !$OMP END SIMD


    call analytical_fields_GC_p(R0,B0,lam,q0,EF0,Y_R,Y_PHI, &
         Y_Z,B_R,B_PHI,B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z, &
         gradB_R,gradB_PHI,gradB_Z)


    call GCEoM_p(params,RHS_R,RHS_PHI,RHS_Z,RHS_PLL,B_R,B_PHI, &
         B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R, &
         gradB_PHI,gradB_Z,V_PLL,V_MU,Y_R,q_cache,m_cache)         

    !$OMP SIMD
    do cc=1_idef,8
       k6_R(cc)=dt*RHS_R(cc)    
       k6_PHI(cc)=dt*RHS_PHI(cc)    
       k6_Z(cc)=dt*RHS_Z(cc)    
       k6_PLL(cc)=dt*RHS_PLL(cc)

       Y_R(cc)=Y0_R(cc)+b1*k1_R(cc)+b2*k2_R(cc)+ &
            b3*k3_R(cc)+b4*k4_R(cc)+b5*k5_R(cc)+b6*k6_R(cc)
       Y_PHI(cc)=Y0_PHI(cc)+b1*k1_PHI(cc)+b2*k2_PHI(cc)+ &
            b3*k3_PHI(cc)+b4*k4_PHI(cc)+b5*k5_PHI(cc)+b6*k6_PHI(cc)
       Y_Z(cc)=Y0_Z(cc)+b1*k1_Z(cc)+b2*k2_Z(cc)+ &
            b3*k3_Z(cc)+b4*k4_Z(cc)+b5*k5_Z(cc)+b6*k6_Z(cc)
       V_PLL(cc)=V0(cc)+b1*k1_PLL(cc)+b2*k2_PLL(cc)+ &
            b3*k3_PLL(cc)+b4*k4_PLL(cc)+b5*k5_PLL(cc)+b6*k6_PLL(cc) 
    end do
    !$OMP END SIMD

    call cyl_check_if_confined_p(ar,R0,Y_R,Y_Z,flag_cache)

    !$OMP SIMD
    do cc=1_idef,8

       if (flag_cache(cc).eq.0_is) then
          Y_R(cc)=Y0_R(cc)
          Y_PHI(cc)=Y0_PHI(cc)
          Y_Z(cc)=Y0_Z(cc)
          V_PLL(cc)=V0(cc)
       end if          
 
    end do
    !$OMP END SIMD
    
    if (params%collisions) then

       call include_CoulombCollisions_GCeqn_p(tt,params,Y_R,Y_PHI,Y_Z, &
            V_PLL,V_MU,m_cache,flag_cache,P,R0,B0,lam,q0,EF0)

    end if


  end subroutine advance_GCeqn_vars

  subroutine advance_FPeqn_vars(params,Y_R,Y_PHI,Y_Z,V_PLL,V_MU,flag_cache, &
       m_cache,B0,lam,R0,q0,EF0,P)

    TYPE(PROFILES), INTENT(IN)                                 :: P    
    TYPE(KORC_PARAMS), INTENT(INOUT)                              :: params
    !! Core KORC simulation parameters.

    INTEGER                                                    :: cc
    !! Chunk iterator.
    INTEGER(ip)                                                    :: tt
    !! time iterator.


    REAL(rp),DIMENSION(8), INTENT(INOUT)  :: Y_R,Y_PHI,Y_Z
    REAL(rp),DIMENSION(8) :: E_R,E_PHI,E_Z
    REAL(rp),DIMENSION(8), INTENT(INOUT)  :: V_PLL,V_MU
    INTEGER(is),DIMENSION(8), INTENT(INOUT)  :: flag_cache
    REAL(rp),DIMENSION(8) :: Bmag,ne,Te,Zeff

    REAL(rp),intent(in) :: B0,EF0,R0,q0,lam,m_cache
          

    do tt=1_ip,params%t_skip
       
       call include_CoulombCollisions_GCeqn_p(tt,params,Y_R,Y_PHI,Y_Z, &
            V_PLL,V_MU,m_cache,flag_cache,P,R0,B0,lam,q0,EF0)

    end do


  end subroutine advance_FPeqn_vars


  subroutine adv_GCinterp_top(params,spp)
    
    TYPE(KORC_PARAMS), INTENT(INOUT)                           :: params
    !! Core KORC simulation parameters.
    TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT)    :: spp
    !! An instance of the derived type SPECIES containing all the parameters
    !! and simulation variables of the different species in the simulation.
    REAL(rp), DIMENSION(8)               :: Bmag
    REAL(rp),DIMENSION(8) :: Y_R,Y_PHI,Y_Z
    REAL(rp),DIMENSION(8) :: B_R,B_PHI,B_Z
    REAL(rp),DIMENSION(8) :: E_R,E_PHI,E_Z
    REAL(rp),DIMENSION(8) :: ne,Te,Zeff    
    REAL(rp),DIMENSION(8) :: V_PLL,V_MU
    INTEGER(is),DIMENSION(8) :: flag_cache
    REAL(rp) :: m_cache,q_cache

    
    INTEGER                                                    :: ii
    !! Species iterator.
    INTEGER                                                    :: pp
    !! Particles iterator.
    INTEGER                                                    :: cc
    !! Chunk iterator.
    INTEGER(ip)                                                    :: tt
    !! time iterator.
 

    do ii = 1_idef,params%num_species      

       q_cache=spp(ii)%q
       m_cache=spp(ii)%m

       
       !$OMP PARALLEL DO default(none) &
       !$OMP& FIRSTPRIVATE(q_cache,m_cache) &
       !$OMP& shared(params,ii,spp) &
       !$OMP& PRIVATE(pp,tt,Bmag,cc,Y_R,Y_PHI,Y_Z,V_PLL,V_MU,B_R,B_PHI,B_Z, &
       !$OMP& flag_cache)
       do pp=1_idef,spp(ii)%ppp,8

          !$OMP SIMD
          do cc=1_idef,8_idef
             Y_R(cc)=spp(ii)%vars%Y(pp-1+cc,1)
             Y_PHI(cc)=spp(ii)%vars%Y(pp-1+cc,2)
             Y_Z(cc)=spp(ii)%vars%Y(pp-1+cc,3)

             V_PLL(cc)=spp(ii)%vars%V(pp-1+cc,1)
             V_MU(cc)=spp(ii)%vars%V(pp-1+cc,2)

             flag_cache(cc)=spp(ii)%vars%flag(pp-1+cc)           
          end do
          !$OMP END SIMD
          
          if (.not.params%FokPlan) then       
             do tt=1_ip,params%t_skip
                call advance_GCinterp_vars(tt,params,Y_R,Y_PHI, &
                  Y_Z,V_PLL,V_MU,q_cache,m_cache,flag_cache)
             end do !timestep iterator

             !$OMP SIMD
             do cc=1_idef,8_idef
                spp(ii)%vars%Y(pp-1+cc,1)=Y_R(cc)
                spp(ii)%vars%Y(pp-1+cc,2)=Y_PHI(cc)
                spp(ii)%vars%Y(pp-1+cc,3)=Y_Z(cc)
                spp(ii)%vars%V(pp-1+cc,1)=V_PLL(cc)
                spp(ii)%vars%V(pp-1+cc,2)=V_MU(cc)

                spp(ii)%vars%flag(pp-1+cc)=flag_cache(cc)   
             end do
             !$OMP END SIMD
             
          else
             call advance_FPinterp_vars(params,Y_R,Y_PHI, &
                  Y_Z,V_PLL,V_MU,m_cache,flag_cache)

             !$OMP SIMD
             do cc=1_idef,8_idef
                spp(ii)%vars%V(pp-1+cc,1)=V_PLL(cc)
                spp(ii)%vars%V(pp-1+cc,2)=V_MU(cc)

                spp(ii)%vars%flag(pp-1+cc)=flag_cache(cc)   
             end do
             !$OMP END SIMD
             
          end if
                            
          call interp_bmag_p(Y_R,Y_PHI,Y_Z,B_R,B_PHI,B_Z)

!          write(6,'("BR: ",E17.10)') B_R(1)
!          write(6,'("BPHI: ",E17.10)') B_PHI(1)
!          write(6,'("BZ: ",E17.10)') B_Z(1) 
          
          !$OMP SIMD
          do cc=1_idef,8
             Bmag(cc)=sqrt(B_R(cc)*B_R(cc)+B_PHI(cc)*B_PHI(cc)+B_Z(cc)*B_Z(cc))
          end do
          !$OMP END SIMD

          !$OMP SIMD
          do cc=1_idef,8_idef
             spp(ii)%vars%g(pp-1+cc)=sqrt(1+V_PLL(cc)**2+ &
                  2*V_MU(cc)*Bmag(cc))

             spp(ii)%vars%eta(pp-1+cc) = atan2(sqrt(2*m_cache*Bmag(cc)* &
                  spp(ii)%vars%V(pp-1+cc,2)),spp(ii)%vars%V(pp-1+cc,1))* &
                  180.0_rp/C_PI
          end do
          !$OMP END SIMD
             
       end do !particle chunk iterator
       !$OMP END PARALLEL DO
       
    end do !species iterator
    
  end subroutine adv_GCinterp_top
  
  subroutine advance_GCinterp_vars(tt,params,Y_R,Y_PHI,Y_Z,V_PLL,V_MU, &
       q_cache,m_cache,flag_cache)
    !! @note Subroutine to advance GC variables \(({\bf X},p_\parallel)\)
    !! @endnote
    !! Comment this section further with evolution equations, numerical
    !! methods, and descriptions of both.
    TYPE(KORC_PARAMS), INTENT(INOUT)                              :: params
    !! Core KORC simulation parameters.

    REAL(rp)                                      :: dt
    !! Time step used in the leapfrog step (\(\Delta t\)).

    INTEGER                                                    :: cc
    !! Chunk iterator.
    INTEGER(ip),intent(in)                                      :: tt
    !! time iterator.
    

    REAL(rp),DIMENSION(8)               :: Bmag
    REAL(rp)              :: a1 = 1./5._rp
    REAL(rp) :: a21 = 3./40._rp,a22=9./40._rp
    REAL(rp) :: a31 = 3./10._rp,a32=-9./10._rp,a33=6./5._rp
    REAL(rp) :: a41 = -11./54._rp,a42=5./2._rp,a43=-70./27._rp,a44=35./27._rp
    REAL(rp) :: a51 = 1631./55296._rp,a52=175./512._rp,a53=575./13824._rp,a54=44275./110592._rp,a55=253./4096._rp
    REAL(rp) :: b1=37./378._rp,b2=0._rp,b3=250./621._rp,b4=125./594._rp,b5=0._rp,b6=512./1771._rp

    REAL(rp),DIMENSION(8) :: k1_R,k1_PHI,k1_Z,k1_PLL
    REAL(rp),DIMENSION(8) :: k2_R,k2_PHI,k2_Z,k2_PLL
    REAL(rp),DIMENSION(8) :: k3_R,k3_PHI,k3_Z,k3_PLL
    REAL(rp),DIMENSION(8) :: k4_R,k4_PHI,k4_Z,k4_PLL
    REAL(rp),DIMENSION(8) :: k5_R,k5_PHI,k5_Z,k5_PLL
    REAL(rp),DIMENSION(8) :: k6_R,k6_PHI,k6_Z,k6_PLL
    REAL(rp),DIMENSION(8) :: Y0_R,Y0_PHI,Y0_Z
    REAL(rp),DIMENSION(8),INTENT(INOUT) :: Y_R,Y_PHI,Y_Z
    REAL(rp),DIMENSION(8) :: B_R,B_PHI,B_Z,E_R
    REAL(rp),DIMENSION(8) :: curlb_R,curlb_PHI,curlb_Z,gradB_R,gradB_PHI,gradB_Z
    REAL(rp),DIMENSION(8),INTENT(INOUT) :: V_PLL,V_MU
    REAL(rp),DIMENSION(8) :: RHS_R,RHS_PHI,RHS_Z,RHS_PLL,V0,E_PHI,E_Z
    REAL(rp),DIMENSION(8) :: ne,Te,Zeff

    INTEGER(is),DIMENSION(8),intent(INOUT) :: flag_cache
    REAL(rp),intent(IN)  :: q_cache,m_cache

    dt=params%dt

    !$OMP SIMD
    do cc=1_idef,8_idef

       Y0_R(cc)=Y_R(cc)
       Y0_PHI(cc)=Y_PHI(cc)
       Y0_Z(cc)=Y_Z(cc)
       V0(cc)=V_PLL(cc)
    end do
    !$OMP END SIMD

    call interp_fields_p(Y_R,Y_PHI,Y_Z,B_R,B_PHI,B_Z,E_R,E_PHI, &
         E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R,gradB_PHI,gradB_Z,flag_cache)

    call GCEoM_p(params,RHS_R,RHS_PHI,RHS_Z,RHS_PLL,B_R,B_PHI, &
         B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R, &
         gradB_PHI,gradB_Z,V_PLL,V_MU,Y_R,q_cache,m_cache) 

    !$OMP SIMD
    do cc=1_idef,8
       k1_R(cc)=dt*RHS_R(cc)              
       k1_PHI(cc)=dt*RHS_PHI(cc)    
       k1_Z(cc)=dt*RHS_Z(cc)    
       k1_PLL(cc)=dt*RHS_PLL(cc)    
       
       Y_R(cc)=Y0_R(cc)+a1*k1_R(cc)
       Y_PHI(cc)=Y0_PHI(cc)+a1*k1_PHI(cc)
       Y_Z(cc)=Y0_Z(cc)+a1*k1_Z(cc)
       V_PLL(cc)=V0(cc)   +a1*k1_PLL(cc)
    end do
    !$OMP END SIMD

    call interp_fields_p(Y_R,Y_PHI,Y_Z,B_R,B_PHI,B_Z,E_R,E_PHI, &
         E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R,gradB_PHI,gradB_Z,flag_cache)


    call GCEoM_p(params,RHS_R,RHS_PHI,RHS_Z,RHS_PLL,B_R,B_PHI, &
         B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R, &
         gradB_PHI,gradB_Z,V_PLL,V_MU,Y_R,q_cache,m_cache) 

    !$OMP SIMD
    do cc=1_idef,8
       k2_R(cc)=dt*RHS_R(cc)    
       k2_PHI(cc)=dt*RHS_PHI (cc)   
       k2_Z(cc)=dt*RHS_Z(cc)   
       k2_PLL(cc)=dt*RHS_PLL(cc)

       Y_R(cc)=Y0_R(cc)+a21*k1_R(cc)+a22*k2_R(cc)
       Y_PHI(cc)=Y0_PHI(cc)+a21*k1_PHI(cc)+a22*k2_PHI(cc)
       Y_Z(cc)=Y0_Z(cc)+a21*k1_Z(cc)+a22*k2_Z(cc)
       V_PLL(cc)=V0(cc)   +a21*k1_PLL(cc)+a22*k2_PLL(cc)
    end do
    !$OMP END SIMD

    call interp_fields_p(Y_R,Y_PHI,Y_Z,B_R,B_PHI,B_Z,E_R,E_PHI, &
         E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R,gradB_PHI,gradB_Z,flag_cache)


    call GCEoM_p(params,RHS_R,RHS_PHI,RHS_Z,RHS_PLL,B_R,B_PHI, &
         B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R, &
         gradB_PHI,gradB_Z,V_PLL,V_MU,Y_R,q_cache,m_cache)

    !$OMP SIMD
    do cc=1_idef,8
       k3_R(cc)=dt*RHS_R(cc)   
       k3_PHI(cc)=dt*RHS_PHI(cc)    
       k3_Z(cc)=dt*RHS_Z(cc)    
       k3_PLL(cc)=dt*RHS_PLL(cc)

       Y_R(cc)=Y0_R(cc)+a31*k1_R(cc)+a32*k2_R(cc)+a33*k3_R(cc)
       Y_PHI(cc)=Y0_PHI(cc)+a31*k1_PHI(cc)+a32*k2_PHI(cc)+ &
            a33*k3_PHI(cc)
       Y_Z(cc)=Y0_Z(cc)+a31*k1_Z(cc)+a32*k2_Z(cc)+a33*k3_Z(cc)
       V_PLL(cc)=V0(cc)   +a31*k1_PLL(cc)+a32*k2_PLL(cc)+a33*k3_PLL(cc)
    end do
    !$OMP END SIMD

    call interp_fields_p(Y_R,Y_PHI,Y_Z,B_R,B_PHI,B_Z,E_R,E_PHI, &
         E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R,gradB_PHI,gradB_Z,flag_cache)

    call GCEoM_p(params,RHS_R,RHS_PHI,RHS_Z,RHS_PLL,B_R,B_PHI, &
         B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R, &
         gradB_PHI,gradB_Z,V_PLL,V_MU,Y_R,q_cache,m_cache)     

    !$OMP SIMD
    do cc=1_idef,8
       k4_R(cc)=dt*RHS_R(cc)   
       k4_PHI(cc)=dt*RHS_PHI(cc)    
       k4_Z(cc)=dt*RHS_Z(cc)    
       k4_PLL(cc)=dt*RHS_PLL(cc)

       Y_R(cc)=Y0_R(cc)+a41*k1_R(cc)+a42*k2_R(cc)+a43*k3_R(cc)+ &
            a44*k4_R(cc)
       Y_PHI(cc)=Y0_PHI(cc)+a41*k1_PHI(cc)+a42*k2_PHI(cc)+ &
            a43*k3_PHI(cc)+a44*k4_PHI(cc)
       Y_Z(cc)=Y0_Z(cc)+a41*k1_Z(cc)+a42*k2_Z(cc)+a43*k3_Z(cc)+ &
            a44*k4_Z(cc)
       V_PLL(cc)=V0(cc)   +a41*k1_PLL(cc)+a42*k2_PLL(cc)+ &
            a43*k3_PLL(cc)+a44*k4_PLL(cc)
    end do
    !$OMP END SIMD


    call interp_fields_p(Y_R,Y_PHI,Y_Z,B_R,B_PHI,B_Z,E_R,E_PHI, &
         E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R,gradB_PHI,gradB_Z,flag_cache)


    call GCEoM_p(params,RHS_R,RHS_PHI,RHS_Z,RHS_PLL,B_R,B_PHI, &
         B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R, &
         gradB_PHI,gradB_Z,V_PLL,V_MU,Y_R,q_cache,m_cache)   

    !$OMP SIMD
    do cc=1_idef,8
       k5_R(cc)=dt*RHS_R(cc)    
       k5_PHI(cc)=dt*RHS_PHI(cc)    
       k5_Z(cc)=dt*RHS_Z(cc)    
       k5_PLL(cc)=dt*RHS_PLL(cc)

       Y_R(cc)=Y0_R(cc)+a51*k1_R(cc)+a52*k2_R(cc)+a53*k3_R(cc)+ &
            a54*k4_R(cc)+a55*k5_R(cc)
       Y_PHI(cc)=Y0_PHI(cc)+a51*k1_PHI(cc)+a52*k2_PHI(cc)+ &
            a53*k3_PHI(cc)+a54*k4_PHI(cc)+a55*k5_PHI(cc)
       Y_Z(cc)=Y0_Z(cc)+a51*k1_Z(cc)+a52*k2_Z(cc)+a53*k3_Z(cc)+ &
            a54*k4_Z(cc)+a55*k5_Z(cc)
       V_PLL(cc)=V0(cc)   +a51*k1_PLL(cc)+a52*k2_PLL(cc)+ &
            a53*k3_PLL(cc)+a54*k4_PLL(cc)+a55*k5_PLL(cc)
    end do
    !$OMP END SIMD

    call interp_fields_p(Y_R,Y_PHI,Y_Z,B_R,B_PHI,B_Z,E_R,E_PHI, &
         E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R,gradB_PHI,gradB_Z,flag_cache)

    call GCEoM_p(params,RHS_R,RHS_PHI,RHS_Z,RHS_PLL,B_R,B_PHI, &
         B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R, &
         gradB_PHI,gradB_Z,V_PLL,V_MU,Y_R,q_cache,m_cache)         

    !$OMP SIMD
    do cc=1_idef,8
       k6_R(cc)=dt*RHS_R(cc)    
       k6_PHI(cc)=dt*RHS_PHI(cc)    
       k6_Z(cc)=dt*RHS_Z(cc)    
       k6_PLL(cc)=dt*RHS_PLL(cc)


       Y_R(cc)=Y0_R(cc)+b1*k1_R(cc)+b2*k2_R(cc)+ &
            b3*k3_R(cc)+b4*k4_R(cc)+b5*k5_R(cc)+b6*k6_R(cc)
       Y_PHI(cc)=Y0_PHI(cc)+b1*k1_PHI(cc)+b2*k2_PHI(cc)+ &
            b3*k3_PHI(cc)+b4*k4_PHI(cc)+b5*k5_PHI(cc)+b6*k6_PHI(cc)
       Y_Z(cc)=Y0_Z(cc)+b1*k1_Z(cc)+b2*k2_Z(cc)+ &
            b3*k3_Z(cc)+b4*k4_Z(cc)+b5*k5_Z(cc)+b6*k6_Z(cc)
       V_PLL(cc)=V0(cc)+b1*k1_PLL(cc)+b2*k2_PLL(cc)+ &
            b3*k3_PLL(cc)+b4*k4_PLL(cc)+b5*k5_PLL(cc)+b6*k6_PLL(cc)
    end do
    !$OMP END SIMD

    !$OMP SIMD
    do cc=1_idef,8

       if (flag_cache(cc).eq.0_is) then
          Y_R(cc)=Y0_R(cc)
          Y_PHI(cc)=Y0_PHI(cc)
          Y_Z(cc)=Y0_Z(cc)
          V_PLL(cc)=V0(cc)
       end if          
 
    end do
    !$OMP END SIMD
    
    if (params%collisions) then
       
       call include_CoulombCollisions_GCinterp_p(tt,params, &
            Y_R,Y_PHI,Y_Z,V_PLL,V_MU,m_cache,flag_cache)

    end if


  end subroutine advance_GCinterp_vars

  subroutine advance_FPinterp_vars(params,Y_R,Y_PHI,Y_Z,V_PLL,V_MU, &
       m_cache,flag_cache)    
    TYPE(KORC_PARAMS), INTENT(INOUT)                              :: params
    !! Core KORC simulation parameters.
    INTEGER                                                    :: cc
    !! Chunk iterator.
    INTEGER(ip)                                                    :: tt
    !! time iterator.
    REAL(rp),DIMENSION(8), INTENT(IN)  :: Y_R,Y_PHI,Y_Z
    REAL(rp),DIMENSION(8) :: E_R,E_PHI,E_Z
    REAL(rp),DIMENSION(8) :: B_R,B_PHI,B_Z
    REAL(rp),DIMENSION(8), INTENT(INOUT)  :: V_PLL,V_MU
    REAL(rp),DIMENSION(8) :: Bmag,ne,Te,Zeff
    REAL(rp),intent(in) :: m_cache
    INTEGER(is),DIMENSION(8),intent(INOUT) :: flag_cache


    do tt=1_ip,params%t_skip
       call include_CoulombCollisions_GCinterp_p(tt,params, &
            Y_R,Y_PHI,Y_Z,V_PLL,V_MU,m_cache,flag_cache)
    end do

  end subroutine advance_FPinterp_vars

  
  subroutine advance_GC_vars_slow(params,F,P,spp,dt,output,init)
    !! @note Subroutine to advance GC variables \(({\bf X},p_\parallel)\)
    !! @endnote
    !! Comment this section further with evolution equations, numerical
    !! methods, and descriptions of both.
    TYPE(KORC_PARAMS), INTENT(INOUT)                              :: params
    !! Core KORC simulation parameters.
    TYPE(FIELDS), INTENT(IN)                                   :: F
    !! An instance of the KORC derived type FIELDS.
    TYPE(PROFILES), INTENT(IN)                                 :: P
    !! An instance of the KORC derived type PROFILES.
    TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT)    :: spp
    !! An instance of the derived type SPECIES containing all the parameters
    !! and simulation variables of the different species in the simulation.
    REAL(rp), INTENT(IN)                                       :: dt
    !! Time step used in the leapfrog step (\(\Delta t\)).
    LOGICAL, INTENT(IN)                                        :: output
    !! Logical variable used to indicate if we calculate or not quantities
    !! listed in the outputs list.
    LOGICAL, INTENT(IN)                                        :: init
    !! Logical variable used to indicate if this is the initial timestep.
    INTEGER                                                    :: ii
    !! Species iterator.
    INTEGER                                                    :: pp
    !! Particles iterator.
    REAL(rp)               :: Bmag
    REAL(rp)               :: Bmagc
    REAL(rp)               :: rm
    REAL(rp),DIMENSION(:,:),ALLOCATABLE               :: RAphi
    REAL(rp), DIMENSION(3) :: bhat
    REAL(rp), DIMENSION(3) :: bhatc
    REAL(rp),DIMENSION(:),ALLOCATABLE               :: RVphi
    REAL(rp)              :: a1 = 1./5._rp
    REAL(rp),DIMENSION(2) :: a2 = (/3./40._rp,9./40._rp/)
    REAL(rp),DIMENSION(3) :: a3 = (/3./10._rp,-9./10._rp,6./5._rp/)
    REAL(rp),DIMENSION(4) :: a4 = (/-11./54._rp,5./2._rp,-70./27._rp,35./27._rp/)
    REAL(rp),DIMENSION(5) :: a5 = (/1631./55296._rp,175./512._rp,575./13824._rp,44275./110592._rp,253./4096._rp/)
    REAL(rp),DIMENSION(6) :: b=(/37./378._rp,0._rp,250./621._rp,125./594._rp,0._rp,512./1771._rp/)
    LOGICAL                                                    :: ss_collisions
    !! Logical variable that indicates if collisions are included in
    !! the simulation.

    ! Determine whether we are using a single-species collision model
    ss_collisions = (TRIM(params%collisions_model) .EQ. 'SINGLE_SPECIES')

    do ii = 1_idef,params%num_species

       call get_fields(params,spp(ii)%vars,F)
       !! Calls [[get_fields]] in [[korc_fields]].
       ! Interpolates fields at local particles' position and keeps in
       ! spp%vars. Fields in (R,\(\phi\),Z) coordinates.


       if (init) then

          ALLOCATE(RAphi(spp(ii)%ppp,2))
          ALLOCATE(RVphi(spp(ii)%ppp))
          RAphi=0.0_rp

          call cart_to_cyl(spp(ii)%vars%X,spp(ii)%vars%Y)

          !$OMP PARALLEL DO SHARED(params,ii,spp,F,RAphi,RVphi) &
          !$OMP&  PRIVATE(pp,Bmag,bhat,rm)
          ! Call OpenMP to calculate p_par and mu for each particle and
          ! put into spp%vars%V
          do pp=1_idef,spp(ii)%ppp
             if ( spp(ii)%vars%flag(pp) .EQ. 1_is ) then

                RVphi(pp)=(-sin(spp(ii)%vars%Y(pp,2))*spp(ii)%vars%V(pp,1)+ &
                     cos(spp(ii)%vars%Y(pp,2))*spp(ii)%vars%V(pp,2))* &
                     spp(ii)%vars%Y(pp,1)

                Bmag = SQRT(spp(ii)%vars%B(pp,1)*spp(ii)%vars%B(pp,1)+ &
                     spp(ii)%vars%B(pp,2)*spp(ii)%vars%B(pp,2)+ &
                     spp(ii)%vars%B(pp,3)*spp(ii)%vars%B(pp,3))

                !             write(6,'("pp: ",I16)') pp
                !             write(6,'("Bmag: ",E17.10)') Bmag


                bhat = spp(ii)%vars%B(pp,:)/Bmag

                if (params%plasma_model.eq.'ANALYTICAL') then
                   rm=sqrt((spp(ii)%vars%Y(pp,1)-F%AB%Ro)**2+ &
                        (spp(ii)%vars%Y(pp,3))**2)

                   RAphi(pp,1)=-F%AB%lambda**2*F%AB%Bo/(2*F%AB%qo)* &
                        log(1+(rm/F%AB%lambda)**2)
                end if

                !             write(6,'("bhat: ",E17.10)') bhat 
                !             write(6,'("V: ",E17.10)') spp(ii)%vars%V(pp,:)


                spp(ii)%vars%X(pp,:)=spp(ii)%vars%X(pp,:)- &
                     spp(ii)%m*spp(ii)%vars%g(pp)* &
                     cross(bhat,spp(ii)%vars%V(pp,:))/(spp(ii)%q*Bmag)

                ! transforming from particle location to associated
                ! GC location

             end if ! if particle in domain, i.e. spp%vars%flag==1
          end do ! loop over particles on an mpi process
          !$OMP END PARALLEL DO

          call cart_to_cyl(spp(ii)%vars%X,spp(ii)%vars%Y)

          !$OMP PARALLEL DO SHARED(params,ii,spp,F,RAphi,RVphi) &
          !$OMP&  PRIVATE(pp,rm)
          ! Call OpenMP to calculate p_par and mu for each particle and
          ! put into spp%vars%V
          do pp=1_idef,spp(ii)%ppp
             if ( spp(ii)%vars%flag(pp) .EQ. 1_is ) then

                if (params%plasma_model.eq.'ANALYTICAL') then
                   rm=sqrt((spp(ii)%vars%Y(pp,1)-F%AB%Ro)**2+ &
                        (spp(ii)%vars%Y(pp,3))**2)
                   RAphi(pp,2)=-F%AB%lambda**2*F%AB%Bo/(2*F%AB%qo)* &
                        log(1+(rm/F%AB%lambda)**2)
                end if

                spp(ii)%vars%V(pp,1)=(spp(ii)%m*spp(ii)%vars%g(pp)* &
                     RVphi(pp)+spp(ii)%q*(RAphi(pp,1)-RAphi(pp,2)))/ &
                     spp(ii)%vars%Y(pp,1)
                !GC ppar              

             end if ! if particle in domain, i.e. spp%vars%flag==1
          end do ! loop over particles on an mpi process
          !$OMP END PARALLEL DO

          call get_fields(params,spp(ii)%vars,F)

          !$OMP PARALLEL DO SHARED(ii,spp) PRIVATE(pp,Bmagc,bhatc)
          ! Call OpenMP to calculate p_par and mu for each particle and
          ! put into spp%vars%V
          do pp=1_idef,spp(ii)%ppp
             if ( spp(ii)%vars%flag(pp) .EQ. 1_is ) then

                Bmagc = SQRT( DOT_PRODUCT(spp(ii)%vars%B(pp,:), &
                     spp(ii)%vars%B(pp,:)))

                bhatc = spp(ii)%vars%B(pp,:)/Bmagc

                spp(ii)%vars%V(pp,1)=spp(ii)%vars%V(pp,1)/ &
                     bhatc(2)
                !GC ppar

                spp(ii)%vars%V(pp,2)=spp(ii)%m/(2*Bmagc)*(spp(ii)%vars%g(pp)**2- &
                     (1+(spp(ii)%vars%V(pp,1)/spp(ii)%m)**2))           
                !GC mu


             end if ! if particle in domain, i.e. spp%vars%flag==1
          end do ! loop over particles on an mpi process
          !$OMP END PARALLEL DO

          params%GC_coords=.TRUE.
          DEALLOCATE(RAphi)
          DEALLOCATE(RVphi)

       end if


       if (.not.params%FokPlan) then

          !$OMP PARALLEL
          !$OMP WORKSHARE

          spp(ii)%vars%Y0(:,:)=spp(ii)%vars%Y(:,:)
          spp(ii)%vars%V0=spp(ii)%vars%V(:,1)

          !$OMP END WORKSHARE
          !$OMP END PARALLEL

          !            write(6,'("Y0: ",E17.10)') spp(ii)%vars%Y0(1,:)

          call GCEoM(params,spp(ii))

          !            write(6,'("RHS: ",E17.10)') spp(ii)%vars%RHS(1,:)

          !$OMP PARALLEL
          !$OMP WORKSHARE

          spp(ii)%vars%k1(:,:)=dt*spp(ii)%vars%RHS(:,:)    

          spp(ii)%vars%Y(:,1)=spp(ii)%vars%Y0(:,1)+a1*spp(ii)%vars%k1(:,1)
          spp(ii)%vars%Y(:,2)=spp(ii)%vars%Y0(:,2)+a1*spp(ii)%vars%k1(:,2)
          spp(ii)%vars%Y(:,3)=spp(ii)%vars%Y0(:,3)+a1*spp(ii)%vars%k1(:,3)
          spp(ii)%vars%V(:,1)=spp(ii)%vars%V0(:)+a1*spp(ii)%vars%k1(:,4)

          !$OMP END WORKSHARE
          !$OMP END PARALLEL

          !           write(6,'("Y: ",E17.10)') spp(ii)%vars%Y(1,:)

          call get_fields(params,spp(ii)%vars,F)

          !       write(6,'("B: ",E17.10)') spp(ii)%vars%B(1,:)

          call GCEoM(params,spp(ii))

          !$OMP PARALLEL
          !$OMP WORKSHARE

          spp(ii)%vars%k2(:,:)=dt*spp(ii)%vars%RHS(:,:)

          spp(ii)%vars%Y(:,1)=spp(ii)%vars%Y0(:,1)+ &
               a2(1)*spp(ii)%vars%k1(:,1)+ &
               a2(2)*spp(ii)%vars%k2(:,1)
          spp(ii)%vars%Y(:,2)=spp(ii)%vars%Y0(:,2)+ &
               a2(1)*spp(ii)%vars%k1(:,2)+ &
               a2(2)*spp(ii)%vars%k2(:,2)
          spp(ii)%vars%Y(:,3)=spp(ii)%vars%Y0(:,3)+ &
               a2(1)*spp(ii)%vars%k1(:,3)+ &
               a2(2)*spp(ii)%vars%k2(:,3)
          spp(ii)%vars%V(:,1)=spp(ii)%vars%V0(:)+ &
               a2(1)*spp(ii)%vars%k1(:,4)+ &
               a2(2)*spp(ii)%vars%k2(:,4)

          !$OMP END WORKSHARE
          !$OMP END PARALLEL

          call get_fields(params,spp(ii)%vars,F)

          call GCEoM(params,spp(ii))


          !$OMP PARALLEL
          !$OMP WORKSHARE

          spp(ii)%vars%k3(:,:)=dt*spp(ii)%vars%RHS(:,:)

          spp(ii)%vars%Y(:,1)=spp(ii)%vars%Y0(:,1)+ &
               a3(1)*spp(ii)%vars%k1(:,1)+ &
               a3(2)*spp(ii)%vars%k2(:,1)+ &
               a3(3)*spp(ii)%vars%k3(:,1)
          spp(ii)%vars%Y(:,2)=spp(ii)%vars%Y0(:,2)+ &
               a3(1)*spp(ii)%vars%k1(:,2)+ &
               a3(2)*spp(ii)%vars%k2(:,2)+ &
               a3(3)*spp(ii)%vars%k3(:,2)
          spp(ii)%vars%Y(:,3)=spp(ii)%vars%Y0(:,3)+ &
               a3(1)*spp(ii)%vars%k1(:,3)+ &
               a3(2)*spp(ii)%vars%k2(:,3)+ &
               a3(3)*spp(ii)%vars%k3(:,3)
          spp(ii)%vars%V(:,1)=spp(ii)%vars%V0(:)+ &
               a3(1)*spp(ii)%vars%k1(:,4)+ &
               a3(2)*spp(ii)%vars%k2(:,4)+ &
               a3(3)*spp(ii)%vars%k3(:,4)

          !$OMP END WORKSHARE
          !$OMP END PARALLEL

          call get_fields(params,spp(ii)%vars,F)

          call GCEoM(params,spp(ii))

          !$OMP PARALLEL
          !$OMP WORKSHARE

          spp(ii)%vars%k4(:,:)=dt*spp(ii)%vars%RHS(:,:)

          spp(ii)%vars%Y(:,1)=spp(ii)%vars%Y0(:,1)+ &
               a4(1)*spp(ii)%vars%k1(:,1)+ &
               a4(2)*spp(ii)%vars%k2(:,1)+ &
               a4(3)*spp(ii)%vars%k3(:,1)+ &
               a4(4)*spp(ii)%vars%k4(:,1)
          spp(ii)%vars%Y(:,2)=spp(ii)%vars%Y0(:,2)+ &
               a4(1)*spp(ii)%vars%k1(:,2)+ &
               a4(2)*spp(ii)%vars%k2(:,2)+ &
               a4(3)*spp(ii)%vars%k3(:,2)+ &
               a4(4)*spp(ii)%vars%k4(:,2)
          spp(ii)%vars%Y(:,3)=spp(ii)%vars%Y0(:,3)+ &
               a4(1)*spp(ii)%vars%k1(:,3)+ &
               a4(2)*spp(ii)%vars%k2(:,3)+ &
               a4(3)*spp(ii)%vars%k3(:,3)+ &
               a4(4)*spp(ii)%vars%k4(:,3)
          spp(ii)%vars%V(:,1)=spp(ii)%vars%V0(:)+ &
               a4(1)*spp(ii)%vars%k1(:,4)+ &
               a4(2)*spp(ii)%vars%k2(:,4)+ &
               a4(3)*spp(ii)%vars%k3(:,4)+ &
               a4(4)*spp(ii)%vars%k4(:,4)

          !$OMP END WORKSHARE
          !$OMP END PARALLEL

          call get_fields(params,spp(ii)%vars,F)

          call GCEoM(params,spp(ii))

          !$OMP PARALLEL
          !$OMP WORKSHARE

          spp(ii)%vars%k5(:,:)=dt*spp(ii)%vars%RHS(:,:)

          spp(ii)%vars%Y(:,1)=spp(ii)%vars%Y0(:,1)+ &
               a5(1)*spp(ii)%vars%k1(:,1)+ &
               a5(2)*spp(ii)%vars%k2(:,1)+ &
               a5(3)*spp(ii)%vars%k3(:,1)+ &
               a5(4)*spp(ii)%vars%k4(:,1)+ &
               a5(5)*spp(ii)%vars%k5(:,1)
          spp(ii)%vars%Y(:,2)=spp(ii)%vars%Y0(:,2)+ &
               a5(1)*spp(ii)%vars%k1(:,2)+ &
               a5(2)*spp(ii)%vars%k2(:,2)+ &
               a5(3)*spp(ii)%vars%k3(:,2)+ &
               a5(4)*spp(ii)%vars%k4(:,2)+ &
               a5(5)*spp(ii)%vars%k5(:,2)
          spp(ii)%vars%Y(:,3)=spp(ii)%vars%Y0(:,3)+ &
               a5(1)*spp(ii)%vars%k1(:,3)+ &
               a5(2)*spp(ii)%vars%k2(:,3)+ &
               a5(3)*spp(ii)%vars%k3(:,3)+ &
               a5(4)*spp(ii)%vars%k4(:,3)+ &
               a5(5)*spp(ii)%vars%k5(:,3)
          spp(ii)%vars%V(:,1)=spp(ii)%vars%V0(:)+ &
               a5(1)*spp(ii)%vars%k1(:,4)+ &
               a5(2)*spp(ii)%vars%k2(:,4)+ &
               a5(3)*spp(ii)%vars%k3(:,4)+ &
               a5(4)*spp(ii)%vars%k4(:,4)+ &
               a5(5)*spp(ii)%vars%k5(:,4)

          !$OMP END WORKSHARE
          !$OMP END PARALLEL         

          call get_fields(params,spp(ii)%vars,F)

          call GCEoM(params,spp(ii))

          !$OMP PARALLEL
          !$OMP WORKSHARE

          spp(ii)%vars%k6(:,:)=dt*spp(ii)%vars%RHS(:,:)

          spp(ii)%vars%Y(:,1)=spp(ii)%vars%Y0(:,1)+ &
               b(1)*spp(ii)%vars%k1(:,1)+ &
               b(2)*spp(ii)%vars%k2(:,1)+ &
               b(3)*spp(ii)%vars%k3(:,1)+ &
               b(4)*spp(ii)%vars%k4(:,1)+ &
               b(5)*spp(ii)%vars%k5(:,1)+ &
               b(6)*spp(ii)%vars%k6(:,1)
          spp(ii)%vars%Y(:,2)=spp(ii)%vars%Y0(:,2)+ &
               b(1)*spp(ii)%vars%k1(:,2)+ &
               b(2)*spp(ii)%vars%k2(:,2)+ &
               b(3)*spp(ii)%vars%k3(:,2)+ &
               b(4)*spp(ii)%vars%k4(:,2)+ &
               b(5)*spp(ii)%vars%k5(:,2)+ &
               b(6)*spp(ii)%vars%k6(:,2)
          spp(ii)%vars%Y(:,3)=spp(ii)%vars%Y0(:,3)+ &
               b(1)*spp(ii)%vars%k1(:,3)+ &
               b(2)*spp(ii)%vars%k2(:,3)+ &
               b(3)*spp(ii)%vars%k3(:,3)+ &
               b(4)*spp(ii)%vars%k4(:,3)+ &
               b(5)*spp(ii)%vars%k5(:,3)+ &
               b(6)*spp(ii)%vars%k6(:,3)
          spp(ii)%vars%V(:,1)=spp(ii)%vars%V0(:)+ &
               b(1)*spp(ii)%vars%k1(:,4)+ &
               b(2)*spp(ii)%vars%k2(:,4)+ &
               b(3)*spp(ii)%vars%k3(:,4)+ &
               b(4)*spp(ii)%vars%k4(:,4)+ &
               b(5)*spp(ii)%vars%k5(:,4)+ &
               b(6)*spp(ii)%vars%k6(:,4)

          !$OMP END WORKSHARE
          !$OMP END PARALLEL 

       end if ! if .not.params%FokPlan

       call get_profiles(params,spp(ii)%vars,P,F)
       !! Calls [[get_profiles]] in [[korc_profiles]].
       ! Interpolates profiles at local particles' position and keeps in
       ! spp%vars.

       if (params%collisions .AND. ss_collisions .and. .not.(init)) then

          call get_fields(params,spp(ii)%vars,F)

          ! Stochastic differential equations for including collisions
          !$OMP PARALLEL DO SHARED(ii,spp) PRIVATE(pp)
          do pp=1_idef,spp(ii)%ppp

             Bmag = SQRT( DOT_PRODUCT(spp(ii)%vars%B(pp,:), &
                  spp(ii)%vars%B(pp,:)))

             !! Calls [[include_CoulombCollisions_GC]] in [[korc_collisions]].
             call include_CoulombCollisions_GC(params,spp(ii)%vars%V(pp,:), &
                  Bmag, spp(ii)%m, spp(ii)%vars%flag(pp), &
                  spp(ii)%vars%ne(pp),spp(ii)%vars%Te(pp),spp(ii)%vars%Zeff(pp))
          end do
          !$OMP END PARALLEL DO
       end if

       if (output) then

          call get_fields(params,spp(ii)%vars,F)

          !$OMP PARALLEL DO SHARED(ii,spp) PRIVATE(pp,Bmag)
          ! Call OpenMP to calculate p_par and mu for each particle and
          ! put into spp%vars%V
          do pp=1_idef,spp(ii)%ppp
             if ( spp(ii)%vars%flag(pp) .EQ. 1_is ) then

                Bmag = SQRT( DOT_PRODUCT(spp(ii)%vars%B(pp,:), &
                     spp(ii)%vars%B(pp,:)))

                spp(ii)%vars%g(pp)=sqrt(1+(spp(ii)%vars%V(pp,1))**2+ &
                     2*spp(ii)%vars%V(pp,2)*Bmag)

                spp(ii)%vars%eta(pp) = atan2(sqrt(2*spp(ii)%m*Bmag* &
                     spp(ii)%vars%V(pp,2)),spp(ii)%vars%V(pp,1))*180.0_rp/C_PI

             end if ! if particle in domain, i.e. spp%vars%flag==1
          end do ! loop over particles on an mpi process
          !$OMP END PARALLEL DO                
       end if !if outputting data

    end do ! loop over particle species

  end subroutine advance_GC_vars_slow

  subroutine GCEoM_p(params,RHS_R,RHS_PHI,RHS_Z,RHS_PLL,B_R,B_PHI, &
       B_Z,E_R,E_PHI,E_Z,curlb_R,curlb_PHI,curlb_Z,gradB_R,gradB_PHI, &
       gradB_Z,V_PLL,V_MU,Y_R,q_cache,m_cache)
    TYPE(KORC_PARAMS), INTENT(INOUT)                           :: params
    !! Core KORC simulation parameters.
    REAL(rp),DIMENSION(8)  :: Bmag,bhat_R,bhat_PHI,bhat_Z,Bst_R,Bst_PHI
    REAL(rp),DIMENSION(8)  :: BstdotE,BstdotgradB,EcrossB_R,EcrossB_PHI,bdotBst
    REAL(rp),DIMENSION(8)  :: bcrossgradB_R,bcrossgradB_PHI,bcrossgradB_Z,gamgc
    REAL(rp),DIMENSION(8)  :: EcrossB_Z,Bst_Z
    REAL(rp),DIMENSION(8)  :: pm,xi
    REAL(rp),DIMENSION(8),INTENT(in) :: gradB_R,gradB_PHI,gradB_Z,curlb_R
    REAL(rp),DIMENSION(8),INTENT(in) :: curlb_Z,B_R,B_PHI,B_Z,E_R,E_PHI,E_Z
    REAL(rp),DIMENSION(8),INTENT(OUT) :: RHS_R,RHS_PHI,RHS_Z,RHS_PLL
    REAL(rp),DIMENSION(8),INTENT(IN) :: V_PLL,V_MU,Y_R,curlb_PHI
    REAL(rp),INTENT(in) :: q_cache,m_cache
    INTEGER(ip)  :: cc

    !$OMP SIMD 
    do cc=1_idef,8
       Bmag(cc) = SQRT(B_R(cc)*B_R(cc)+B_PHI(cc)*B_PHI(cc)+B_Z(cc)*B_Z(cc))

       bhat_R(cc) = B_R(cc)/Bmag(cc)
       bhat_PHI(cc) = B_PHI(cc)/Bmag(cc)
       bhat_Z(cc) = B_Z(cc)/Bmag(cc)

       Bst_R(cc)=q_cache*B_R(cc)+V_PLL(cc)*curlb_R(cc)
       Bst_PHI(cc)=q_cache*B_PHI(cc)+V_PLL(cc)*curlb_PHI(cc)
       Bst_Z(cc)=q_cache*B_Z(cc)+V_PLL(cc)*curlb_Z(cc)

       bdotBst(cc)=bhat_R(cc)*Bst_R(cc)+bhat_PHI(cc)*Bst_PHI(cc)+ &
            bhat_Z(cc)*Bst_Z(cc)
       BstdotE(cc)=Bst_R(cc)*E_R(cc)+Bst_PHI(cc)*E_PHI(cc)+Bst_Z(cc)*E_Z(cc)   
       BstdotgradB(cc)=Bst_R(cc)*gradB_R(cc)+Bst_PHI(cc)*gradB_PHI(cc)+ &
            Bst_Z(cc)*gradB_Z(cc)

       Ecrossb_R(cc)=E_PHI(cc)*bhat_Z(cc)-E_Z(cc)*bhat_PHI(cc)
       Ecrossb_PHI(cc)=E_Z(cc)*bhat_R(cc)-E_R(cc)*bhat_Z(cc)
       Ecrossb_Z(cc)=E_R(cc)*bhat_PHI(cc)-E_PHI(cc)*bhat_R(cc)


       bcrossgradB_R(cc)=bhat_PHI(cc)*gradB_Z(cc)-bhat_Z(cc)*gradB_PHI(cc)
       bcrossgradB_PHI(cc)=bhat_Z(cc)*gradB_R(cc)-bhat_R(cc)*gradB_Z(cc)
       bcrossgradB_Z(cc)=bhat_R(cc)*gradB_PHI(cc)-bhat_PHI(cc)*gradB_R(cc)

       gamgc(cc)=sqrt(1+V_PLL(cc)*V_PLL(cc)+2*V_MU(cc)*Bmag(cc))

       pm(cc)=sqrt(gamgc(cc)**2-1)
       xi(cc)=V_PLL(cc)/pm(cc)
       
       RHS_R(cc)=(q_cache*Ecrossb_R(cc)+(m_cache*V_MU(cc)* &
            bcrossgradB_R(cc)+V_PLL(cc)*Bst_R(cc))/(m_cache*gamgc(cc)))/ &
            bdotBst(cc)
       RHS_PHI(cc)=(q_cache*Ecrossb_PHI(cc)+(m_cache*V_MU(cc)* &
            bcrossgradB_PHI(cc)+V_PLL(cc)*Bst_PHI(cc))/(m_cache*gamgc(cc)))/ &
            (Y_R(cc)*bdotBst(cc))
       RHS_Z(cc)=(q_cache*Ecrossb_Z(cc)+(m_cache*V_MU(cc)* &
            bcrossgradB_Z(cc)+V_PLL(cc)*Bst_Z(cc))/(m_cache*gamgc(cc)))/ &
            bdotBst(cc)
       RHS_PLL(cc)=(q_cache*BstdotE(cc)-V_MU(cc)*BstdotgradB(cc)/gamgc(cc))/ &
            bdotBst(cc)
       
    end do
    !$OMP END SIMD

  end subroutine GCEoM_p

  subroutine GCEoM(params,spp)
    TYPE(SPECIES), INTENT(INOUT)    :: spp
    !! An instance of the derived type SPECIES containing all the parameters
    !! and simulation variables of the different species in the simulation.
    TYPE(KORC_PARAMS), INTENT(IN) :: params

    REAL(rp) :: Bmag
    REAL(rp),DIMENSION(3)  :: bhat
    REAL(rp),DIMENSION(3) :: Bst
    REAL(rp)  :: bdotBst
    REAL(rp)  :: BstdotE
    REAL(rp)  :: BstdotgradB
    REAL(rp),DIMENSION(3)  :: EcrossB
    REAL(rp),DIMENSION(3)  :: bcrossgradB
    REAL(rp) :: gamgc
    INTEGER  :: pp
    REAL(rp),DIMENSION(3) :: gradB
    REAL(rp),DIMENSION(3) :: curlb
    REAL(rp),DIMENSION(3) :: B_cache
    REAL(rp),DIMENSION(3) :: E_cache
    REAL(rp),DIMENSION(2) :: V_cache
    REAL(rp) :: R_cache


    !$OMP PARALLEL DO &
    !$OMP& PRIVATE(pp,Bmag,bhat,Bst,bdotBst,BstdotE,BstdotgradB, &
    !$OMP& Ecrossb,bcrossgradB,gamgc,gradB,curlb,B_cache,V_cache, &
    !$OMP& E_cache,R_cache)
    do pp=1_idef,spp%ppp
       !    if ( spp%vars%flag(pp) .EQ. 1_is ) then

       B_cache(1)=spp%vars%B(pp,1)
       B_cache(2)=spp%vars%B(pp,2)
       B_cache(3)=spp%vars%B(pp,3)

       E_cache(1)=spp%vars%E(pp,1)
       E_cache(2)=spp%vars%E(pp,2)
       E_cache(3)=spp%vars%E(pp,3)

       V_cache(1)=spp%vars%V(pp,1)
       V_cache(2)=spp%vars%V(pp,2)

       R_cache=spp%vars%Y(pp,1)

       Bmag = SQRT(B_cache(1)*B_cache(1)+B_cache(2)*B_cache(2)+ &
            B_cache(3)*B_cache(3))

       bhat(1) = B_cache(1)/Bmag
       bhat(2) = B_cache(2)/Bmag
       bhat(3) = B_cache(3)/Bmag

       !       if (params%orbit_model(3:5)=='pre') then
       curlb(1)=spp%vars%curlb(pp,1)
       curlb(2)=spp%vars%curlb(pp,2)
       curlb(3)=spp%vars%curlb(pp,3)

       gradB(1)=spp%vars%gradB(pp,1)
       gradB(2)=spp%vars%gradB(pp,2)
       gradB(3)=spp%vars%gradB(pp,3)           
       !       else if (params%orbit_model(3:6)=='grad') then
       !          call aux_fields(pp,spp,gradB,curlb,Bmag)
       !       end if

       Bst(1)=spp%q*B_cache(1)+V_cache(1)*curlb(1)
       Bst(2)=spp%q*B_cache(2)+V_cache(1)*curlb(2)
       Bst(3)=spp%q*B_cache(3)+V_cache(1)*curlb(3)

       bdotBst=bhat(1)*Bst(1)+bhat(2)*Bst(2)+bhat(3)*Bst(3)
       BstdotE=Bst(1)*E_cache(1)+ &
            Bst(2)*E_cache(2)+ &
            Bst(3)*E_cache(3)      
       BstdotgradB=Bst(1)*gradB(1)+Bst(2)*gradB(2)+Bst(3)*gradB(3)

       Ecrossb(1)=E_cache(2)*bhat(3)-E_cache(3)*bhat(2)
       Ecrossb(2)=E_cache(3)*bhat(1)-E_cache(1)*bhat(3)
       Ecrossb(3)=E_cache(1)*bhat(2)-E_cache(2)*bhat(1)


       bcrossgradB(1)=bhat(2)*gradB(3)-bhat(3)*gradB(2)
       bcrossgradB(2)=bhat(3)*gradB(1)-bhat(1)*gradB(3)
       bcrossgradB(3)=bhat(1)*gradB(2)-bhat(2)*gradB(1)

       gamgc=sqrt(1+V_cache(1)**2+2*V_cache(2)*Bmag)

       spp%vars%RHS(pp,1)=(spp%q*Ecrossb(1)+(spp%m*V_cache(2)* &
            bcrossgradB(1)+V_cache(1)*Bst(1))/(spp%m*gamgc))/bdotBst
       spp%vars%RHS(pp,2)=(spp%q*Ecrossb(2)+(spp%m*V_cache(2)* &
            bcrossgradB(2)+V_cache(1)*Bst(2))/(spp%m*gamgc))/ &
            (R_cache*bdotBst)
       spp%vars%RHS(pp,3)=(spp%q*Ecrossb(3)+(spp%m*V_cache(2)* &
            bcrossgradB(3)+V_cache(1)*Bst(3))/(spp%m*gamgc))/bdotBst
       spp%vars%RHS(pp,4)=(spp%q*BstdotE-V_cache(2)* &
            BstdotgradB/gamgc)/bdotBst

       !    end if ! if particle in domain, i.e. spp%vars%flag==1
    end do ! loop over particles on an mpi process
    !$OMP END PARALLEL DO


  end subroutine GCEoM

  subroutine aux_fields(pp,spp,gradB,curlb,Bmag)
    TYPE(SPECIES), INTENT(IN)    :: spp
    !! An instance of the derived type SPECIES containing all the parameters
    !! and simulation variables of the different species in the simulation.
    REAL(rp),DIMENSION(3),INTENT(INOUT) :: gradB
    REAL(rp),DIMENSION(3),INTENT(INOUT) :: curlb
    REAL(rp),INTENT(IN) :: Bmag
    REAL(rp) :: dRB
    REAL(rp) :: dPHIB
    REAL(rp) :: dZB
    INTEGER  :: pp

    dRB=(spp%vars%B(pp,1)*spp%vars%BR(pp,1)+ &
         spp%vars%B(pp,2)*spp%vars%BPHI(pp,1)+ &
         spp%vars%B(pp,3)*spp%vars%BZ(pp,1))/Bmag
    dPHIB=(spp%vars%B(pp,1)*spp%vars%BR(pp,2)+ &
         spp%vars%B(pp,2)*spp%vars%BPHI(pp,2)+ &
         spp%vars%B(pp,3)*spp%vars%BZ(pp,2))/Bmag
    dZB=(spp%vars%B(pp,1)*spp%vars%BR(pp,3)+ &
         spp%vars%B(pp,2)*spp%vars%BPHI(pp,3)+ &
         spp%vars%B(pp,3)*spp%vars%BZ(pp,3))/Bmag

    gradB(1)=dRB
    gradB(2)=dPHIB/spp%vars%Y(pp,1)
    gradB(3)=dZB

    curlb(1)=((Bmag*spp%vars%BZ(pp,2)-spp%vars%B(pp,3)*dPHIB)/spp%vars%Y(pp,1)- &
         (Bmag*spp%vars%BPHI(pp,3)-spp%vars%B(pp,2)*dZB))/Bmag**2
    curlb(2)=((Bmag*spp%vars%BR(pp,3)-spp%vars%B(pp,1)*dZB)- &
         (Bmag*spp%vars%BZ(pp,1)-spp%vars%B(pp,3)*dRB))/Bmag**2
    curlb(3)=((Bmag*spp%vars%BPHI(pp,1)-spp%vars%B(pp,2)*dRB) - &
         (Bmag*spp%vars%BPHI(pp,1)-spp%vars%B(pp,1)*dPHIB)/ &
         spp%vars%Y(pp,1))/Bmag**2+ &
         spp%vars%B(pp,2)/(Bmag*spp%vars%Y(pp,1))  

  end subroutine aux_fields


end module korc_ppusher
