program main

use korc_types
use korc_units
use korc_hpc
use korc_HDF5
use emf
use pic
use initialize
use finalize

implicit none

	TYPE(KORC_PARAMS) :: params
	TYPE(SPECIES), DIMENSION(:), ALLOCATABLE :: spp
	TYPE(CHARCS_PARAMS) :: cpp
	TYPE(FIELDS) :: EB
	INTEGER(ip) :: it ! Iterator(s)
	REAL(rp) :: t1, t2 ! variables for timing the simulation

	call initialize_communications(params)

	! * * * INITIALIZATION STAGE * * *
	call initialize_korc_parameters(params) ! Initialize korc parameters

	call initialize_particles(params,spp) ! Initialize particles

	call initialize_fields(params,EB)

	call compute_charcs_plasma_params(spp,EB,cpp)

	call define_time_step(cpp,params)

	call initialize_HDF5()
	! * * * INITIALIZATION STAGE * * *

	call normalize_variables(params,spp,EB,cpp)

	call save_simulation_parameters(params,spp,EB,cpp)

	! *** *** *** *** *** ***   *** *** *** *** *** *** ***
	! *** BEYOND THIS POINT VARIABLES ARE DIMENSIONLESS ***
	! *** *** *** *** *** ***   *** *** *** *** *** *** ***

	! First particle push
	call advance_particles_velocity(params,EB,spp,0.5_rp*params%dt)

	t1 = MPI_WTIME()

	do it=1,params%t_steps
		call advance_particles_position(params,EB,spp,params%dt)
		call advance_particles_velocity(params,EB,spp,params%dt)
		if ( modulo(it,params%output_cadence) .EQ. 0 ) then
			if (params%mpi_params%rank_topo .EQ. 0) then
!				write(default_unit_write,'(F15.12)') spp(1)%vars%gamma(1)
			end if
        end if
	end do
	
	t2 = MPI_WTIME()
	write(6,'("MPI: ",I2," Total time: ",F15.10)') params%mpi_params%rank, t2 - t1

	! * * * FINALIZING SIMULATION * * * 
	call finalize_HDF5()

	! DEALLOCATION OF VARIABLES
	call deallocate_variables(params,spp)

	call finalize_communications(params)
	! * * * FINALIZING SIMULATION * * * 
end program main
