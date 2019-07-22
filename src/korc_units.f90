module korc_units
  !! @note Module with subroutines that calculate the characteristic 
  !! scales in the simulation used in the normalization and 
  !! nondimensionalization of the simulation variables. @endnote
  use korc_types
  use korc_constants

  IMPLICIT NONE

  PUBLIC :: compute_charcs_plasma_params,&
       normalize_variables

CONTAINS


subroutine compute_charcs_plasma_params(params,spp,F)
  !! @note Subroutine that calculates characteristic scales of 
  !! the current KORC simulation. @endnote
  !! Normalization and non-dimensionalization of the variables and equations 
  !! of motion allows us to solve them more accurately by reducing truncation 
  !! erros when performing operations that combine small and large numbers.
  !!
  !! For normalizing and obtaining the non-dimensional form of the variables 
  !! and equations solved in KORC we use characteristic scales calculated with 
  !! the input data of each KORC simulation.
  !! <table cellspacing="10">
  !! <caption id="multi_row">Characteristic scales in KORC</caption>
  !! <tr><th>Characteristic scale</th>	<th>Symbol</th>	        <th>Value</th>			<th>Description</th></tr>
  !! <tr><td rowspan="1">Velocity 	<td>\(v_{ch}\)		<td>\(c\)			<td> Speed of light
  !! <tr><td rowspan="1">Time 		<td>\(t_{ch}\)		<td>\(\Omega^{-1} = m_{ch}/q_{ch}B_{ch}\) 	<td> Inverse of electron cyclotron frequency
  !! <tr><td rowspan="1">Relativistic time <td>\(t_{r,ch}\)	<td>\(\Omega_r^{-1} = \gamma m_{ch}/q_{ch}B_{ch}\) 	<td> Inverse of relativistic electron cyclotron frequency
  !! <tr><td rowspan="1">Length 	<td>\(l_{ch}\)		<td>\(v_{ch}t_{ch}\)		<td>--
  !! <tr><td rowspan="1">Mass 		<td>\(m_{ch}\)		<td>\(m_e\)			<td> Electron mass
  !! <tr><td rowspan="1">Charge 	<td>\(q_{ch}\)		<td>\(e\)			<td> Absolute value of electron charge
  !! <tr><td rowspan="1">Momentum       <td>\(p_{ch}\)	        <td>\(m_{ch}v_{ch}\) 	        <td> --
  !! <tr><td rowspan="1">Magnetic field <td>\(B_{ch}\)		<td>\(B_0\)		        <td> Magnetic field at the magnetic axis
  !! <tr><td rowspan="1">Electric field <td>\(E_{ch}\)		<td>\(v_{ch}B_{ch}\)		<td> --
  !! <tr><td rowspan="1">Energy 	<td>\(\mathcal{E}_{ch}\)<td>\(m_{ch}v_{ch}^2\)		<td>--
  !! <tr><td rowspan="1">Temperature 	<td>\(T_{ch}\)		<td>\(m_{ch}v_{ch}^2\)		<td> Temperature given in Joules.
  !! <tr><td rowspan="1">Density 	<td>\(n_{ch}\)		<td>\(l_{ch}^{-3}\)		<td>--
  !! <tr><td rowspan="1">Magnetic moment 	<td>\(\mu_{ch}\)<td>\(m_{ch}v_{ch}^2/B_{ch}\)	<td>--
  !! <tr><td rowspan="1">Pressure 	<td>\(P_{ch}\)		<td>--		                <td>--
  !! </table>
  !! With these characteristic scales we can write the dimensionless 
  !! form of all the equations. For example, the Lorentz force for a 
  !! charged particle \(q\), mass \(m\), and momentum 
  !! \(\mathbf{p}=\gamma m \mathbf{v}\) can be written as:
  !!
  !! $$\frac{d \mathbf{p}'}{dt'} = q'\left[ \mathbf{E}' + 
  !! \frac{\mathbf{p}'}{\gamma m'}\times \mathbf{B}' \right],$$
  !!
  !! where \(\mathbf{p}' = \mathbf{p}/p_{ch}\), \(t' = t/t_{ch}\), 
  !! \(q' = q/q_{ch}\), \(m' = m/m_{ch}\), \(\mathbf{E}' = \mathbf{E}/E_{ch}\), 
  !! and \(\mathbf{B}'=\mathbf{B}/B_{ch}\).
  !! @todo Characteristic pressure needs to be defined.
  TYPE(KORC_PARAMS), INTENT(INOUT) 				:: params
    !! Core KORC simulation parameters.
  TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT)       :: spp
    !! An instance of KORC's derived type SPECIES containing all the 
    !! information of different electron species. See [[korc_types]].
  TYPE(FIELDS), INTENT(IN) 					:: F
    !! An instance of KORC's derived type FIELDS containing all the 
    !! information about the fields used in the simulation. 
    !! See [[korc_types]] and [[korc_fields]].
  INTEGER 							:: ii
    !! Index of the spp array containing the mass, electric charge 
    !! and corresponding cyclotron frequency used to derived some characteristic scales.

  params%cpp%velocity = C_C
  params%cpp%Bo = ABS(F%Bo)
  params%cpp%Eo = ABS(params%cpp%velocity*params%cpp%Bo)

  ! Non-relativistic cyclotron frequency
  spp(:)%wc = ( ABS(spp(:)%q)/spp(:)%m )*params%cpp%Bo

  ! Relativistic cyclotron frequency
  spp(:)%wc_r =  ABS(spp(:)%q)*params%cpp%Bo/( spp(:)%go*spp(:)%m )


  ii = MAXLOC(spp(:)%wc,1) ! Index to maximum cyclotron frequency
  params%cpp%time = 1.0_rp/spp(ii)%wc

  ii = MAXLOC(spp(:)%wc_r,1) ! Index to maximum relativistic cyclotron frequency
  params%cpp%time_r = 1.0_rp/spp(ii)%wc_r

  params%cpp%mass = C_ME
  params%cpp%charge = C_E
  params%cpp%length = params%cpp%velocity*params%cpp%time
  params%cpp%energy = params%cpp%mass*params%cpp%velocity**2

  params%cpp%density = 1.0_rp/params%cpp%length**3
  params%cpp%pressure = 0.0_rp
  params%cpp%temperature = params%cpp%energy
end subroutine compute_charcs_plasma_params


subroutine normalize_variables(params,spp,F,P)
  !! @note Subroutine that normalizes the simulation variables with 
  !! the previously computed characteristic scales. @endnote
  TYPE(KORC_PARAMS), INTENT(INOUT) 				:: params
    !! Core KORC simulation parameters.
  TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT)       :: spp
    !! An instance of KORC's derived type SPECIES containing all 
    !! the information of different electron species. See [[korc_types]].
  TYPE(FIELDS), INTENT(INOUT) 					:: F
    !! @param[in,out] F An instance of KORC's derived type FIELDS 
    !! containing all the information about the fields used in the simulation.
    !! See [[korc_types]] and [[korc_fields]].
  TYPE(PROFILES), INTENT(INOUT) 				:: P
    !! @param[in,out] P An instance of KORC's derived type PROFILES containing all the information about the plasma profiles used in
!! the simulation. See korc_types.f90 and korc_profiles.f90.
  INTEGER 							:: ii
    !! @param ii Interator of spp array.

  !	Normalize params variables
  params%dt = params%dt/params%cpp%time
  params%simulation_time = params%simulation_time/params%cpp%time
  params%snapshot_frequency = params%snapshot_frequency/params%cpp%time
  params%minimum_particle_energy = params%minimum_particle_energy/params%cpp%energy
  params%init_time=params%init_time/params%cpp%time

  !	Normalize particle variables
  do ii=1_idef,size(spp)
     spp(ii)%q = spp(ii)%q/params%cpp%charge
     spp(ii)%m = spp(ii)%m/params%cpp%mass
     spp(ii)%Eo = spp(ii)%Eo/params%cpp%energy
     spp(ii)%Eo_lims = spp(ii)%Eo_lims/params%cpp%energy
     spp(ii)%wc = spp(ii)%wc*params%cpp%time
     spp(ii)%wc_r = spp(ii)%wc_r*params%cpp%time
     spp(ii)%vars%X = spp(ii)%vars%X/params%cpp%length
     spp(ii)%vars%V = spp(ii)%vars%V/params%cpp%velocity
     spp(ii)%vars%Rgc = spp(ii)%vars%Rgc/params%cpp%length

     spp(ii)%Ro = spp(ii)%Ro/params%cpp%length
     spp(ii)%Zo = spp(ii)%Zo/params%cpp%length
     spp(ii)%r_inner = spp(ii)%r_inner/params%cpp%length
     spp(ii)%r_outter = spp(ii)%r_outter/params%cpp%length
     spp(ii)%sigmaR = spp(ii)%sigmaR/params%cpp%length
     spp(ii)%sigmaZ = spp(ii)%sigmaZ/params%cpp%length
     spp(ii)%falloff_rate = spp(ii)%falloff_rate*params%cpp%length
     spp(ii)%Xtrace = spp(ii)%Xtrace/params%cpp%length
     spp(ii)%Spong_b = spp(ii)%Spong_b/params%cpp%length
     spp(ii)%Spong_w = spp(ii)%Spong_w/params%cpp%length
     spp(ii)%dR = spp(ii)%dR/params%cpp%length
     spp(ii)%dZ = spp(ii)%dZ/params%cpp%length
     
  end do

  !	Normalize electromagnetic fields and profiles
  F%Bo = F%Bo/params%cpp%Bo
  F%Eo = F%Eo/params%cpp%Eo
  F%Ro = F%Ro/params%cpp%length
  F%Zo = F%Zo/params%cpp%length

  P%a = P%a/params%cpp%length
  P%R0 = P%R0/params%cpp%length
  P%Z0 = P%Z0/params%cpp%length
  P%neo = P%neo/params%cpp%density
  P%n_ne = P%n_ne/params%cpp%density
  P%Teo = P%Teo/params%cpp%temperature
  P%n_REr0=P%n_REr0/params%cpp%length
  P%n_tauion=P%n_tauion/params%cpp%time
  P%n_lamfront=P%n_lamfront/params%cpp%length
  P%n_lamback=P%n_lamback/params%cpp%length

  if (params%plasma_model .EQ. 'ANALYTICAL') then
     F%AB%Bo = F%AB%Bo/params%cpp%Bo
     F%AB%a = F%AB%a/params%cpp%length
     F%AB%Ro = F%AB%Ro/params%cpp%length
     F%AB%lambda = F%AB%lambda/params%cpp%length
     F%AB%Bpo = F%AB%Bpo/params%cpp%Bo

     if (params%field_eval.eq.'interp') then
        if (ALLOCATED(F%B_2D%R)) F%B_2D%R = F%B_2D%R/params%cpp%Bo
        if (ALLOCATED(F%B_2D%PHI)) F%B_2D%PHI = F%B_2D%PHI/params%cpp%Bo
        if (ALLOCATED(F%B_2D%Z)) F%B_2D%Z = F%B_2D%Z/params%cpp%Bo

        if (ALLOCATED(F%E_2D%R)) F%E_2D%R = F%E_2D%R/params%cpp%Eo
        if (ALLOCATED(F%E_2D%PHI)) F%E_2D%PHI = F%E_2D%PHI/params%cpp%Eo
        if (ALLOCATED(F%E_2D%Z)) F%E_2D%Z = F%E_2D%Z/params%cpp%Eo

        F%X%R = F%X%R/params%cpp%length
        ! Nothing to do for the PHI component
        F%X%Z = F%X%Z/params%cpp%length
        
!        if (params%collisions) then
        if (ALLOCATED(P%X%R)) P%X%R = P%X%R/params%cpp%length
        if (ALLOCATED(P%X%Z)) P%X%Z = P%X%Z/params%cpp%length
           

!           write(6,'("P_R: ",E17.10)') P%X%R
!           write(6,'("P_Z: ",E17.10)') P%X%Z
           
        if (ALLOCATED(P%ne_2D)) P%ne_2D = P%ne_2D/params%cpp%density
        if (ALLOCATED(P%Te_2D)) P%Te_2D = P%Te_2D/params%cpp%temperature


        
!           write(6,'("P_ne: ",E17.10)') P%ne_2d(:,10)
!           write(6,'("P_Te: ",E17.10)') P%Te_2d(:,10)
           
           !       write(6,'("Te: ",E17.10)') P%Te_2D(1,1)

!        end if
        


        if (params%orbit_model(3:5).eq.'pre') then
           if (ALLOCATED(F%gradB_2D%R)) F%gradB_2D%R = F%gradB_2D%R/ &
                (params%cpp%Bo/params%cpp%length)
           if (ALLOCATED(F%gradB_2D%PHI)) F%gradB_2D%PHI = F%gradB_2D%PHI/ &
                (params%cpp%Bo/params%cpp%length)
           if (ALLOCATED(F%gradB_2D%Z)) F%gradB_2D%Z = F%gradB_2D%Z/ &
                (params%cpp%Bo/params%cpp%length)

           if (ALLOCATED(F%curlb_2D%R)) F%curlb_2D%R = F%curlb_2D%R/ &
                (1./params%cpp%length)
           if (ALLOCATED(F%curlb_2D%PHI)) F%curlb_2D%PHI = F%curlb_2D%PHI/ &
                (1./params%cpp%length)
           if (ALLOCATED(F%curlb_2D%Z)) F%curlb_2D%Z = F%curlb_2D%Z/ &
                (1./params%cpp%length)
        end if
        
     end if


      
     
  else if (params%plasma_model .EQ. 'EXTERNAL') then
     if (ALLOCATED(F%B_3D%R)) F%B_3D%R = F%B_3D%R/params%cpp%Bo
     if (ALLOCATED(F%B_3D%PHI)) F%B_3D%PHI = F%B_3D%PHI/params%cpp%Bo
     if (ALLOCATED(F%B_3D%Z)) F%B_3D%Z = F%B_3D%Z/params%cpp%Bo

     if (ALLOCATED(F%E_3D%R)) F%E_3D%R = F%E_3D%R/params%cpp%Eo
     if (ALLOCATED(F%E_3D%PHI)) F%E_3D%PHI = F%E_3D%PHI/params%cpp%Eo
     if (ALLOCATED(F%E_3D%Z)) F%E_3D%Z = F%E_3D%Z/params%cpp%Eo

     if (ALLOCATED(F%PSIp)) F%PSIp = F%PSIp/(params%cpp%Bo*params%cpp%length**2)

     if (ALLOCATED(F%B_2D%R)) F%B_2D%R = F%B_2D%R/params%cpp%Bo
     if (ALLOCATED(F%B_2D%PHI)) F%B_2D%PHI = F%B_2D%PHI/params%cpp%Bo
     if (ALLOCATED(F%B_2D%Z)) F%B_2D%Z = F%B_2D%Z/params%cpp%Bo

     if (ALLOCATED(F%E_2D%R)) F%E_2D%R = F%E_2D%R/params%cpp%Eo
     if (ALLOCATED(F%E_2D%PHI)) F%E_2D%PHI = F%E_2D%PHI/params%cpp%Eo
     if (ALLOCATED(F%E_2D%Z)) F%E_2D%Z = F%E_2D%Z/params%cpp%Eo

     if (params%orbit_model(3:5).eq.'pre') then
        if (ALLOCATED(F%gradB_2D%R)) F%gradB_2D%R = F%gradB_2D%R/ &
             (params%cpp%Bo/params%cpp%length)
        if (ALLOCATED(F%gradB_2D%PHI)) F%gradB_2D%PHI = F%gradB_2D%PHI/ &
             (params%cpp%Bo/params%cpp%length)
        if (ALLOCATED(F%gradB_2D%Z)) F%gradB_2D%Z = F%gradB_2D%Z/ &
             (params%cpp%Bo/params%cpp%length)

        if (ALLOCATED(F%curlb_2D%R)) F%curlb_2D%R = F%curlb_2D%R/ &
             (1./params%cpp%length)
        if (ALLOCATED(F%curlb_2D%PHI)) F%curlb_2D%PHI = F%curlb_2D%PHI/ &
             (1./params%cpp%length)
        if (ALLOCATED(F%curlb_2D%Z)) F%curlb_2D%Z = F%curlb_2D%Z/ &
             (1./params%cpp%length)
     end if
     
     F%X%R = F%X%R/params%cpp%length
     ! Nothing to do for the PHI component
     F%X%Z = F%X%Z/params%cpp%length

!     if (params%collisions) then
        if (ALLOCATED(P%X%R)) P%X%R = P%X%R/params%cpp%length
        if (ALLOCATED(P%X%Z)) P%X%Z = P%X%Z/params%cpp%length

        if (ALLOCATED(P%ne_2D)) P%ne_2D = P%ne_2D/params%cpp%density
        if (ALLOCATED(P%Te_2D)) P%Te_2D = P%Te_2D/params%cpp%temperature

        if (ALLOCATED(P%ne_3D)) P%ne_3D = P%ne_3D/params%cpp%density
        if (ALLOCATED(P%Te_3D)) P%Te_3D = P%Te_3D/params%cpp%temperature

 !       write(6,'("Te: ",E17.10)') P%Te_2D(1,1)
        
!     end if
  end if
end subroutine normalize_variables

end module korc_units