!! @note KORC module containing subroutines to read and write data in HDF5
!! files. @endnote
!! This module contains interfaces to use the HDF5 library in a more friendly
!! way. This module is intended to help developers to create new I/O
!! subroutines without having to deal with the sometimes cumbersome details
!! of the HDF5 API.
module korc_HDF5
  use korc_hpc
  use korc_types
  use korc_constants
  use HDF5

  IMPLICIT NONE

  INTEGER(HID_T), PRIVATE 	:: KORC_HDF5_REAL
  !! HDF5 real precision data type to be used in the simulation.
  INTEGER(SIZE_T), PRIVATE 	:: rp_hdf5
  !! Size of the HDF5 real precision data type used in the simulation.

  INTERFACE load_from_hdf5
     !! @note Fortran interface to subroutines loading a real or integer
     !! value from HDF5 files. @endnote
     module procedure iload_from_hdf5, rload_from_hdf5
  END INTERFACE load_from_hdf5


  INTERFACE load_array_from_hdf5
     !! @note Fortran interface to subroutines loading 2-D and 3-D arrays
     !! of real values from HDF5 files.
     module procedure rload_1d_array_from_hdf5, rload_3d_array_from_hdf5, rload_2d_array_from_hdf5
  END INTERFACE load_array_from_hdf5


  INTERFACE save_to_hdf5
     !! @note Fortran interface to subroutines saving real or integer
     !! values to HDF5 files.
     module procedure i1save_to_hdf5,i2save_to_hdf5,i4save_to_hdf5,i8save_to_hdf5,rsave_to_hdf5
  END INTERFACE save_to_hdf5

  !! @note Fortran interface to subroutines saving real and integer
  !! values to HDF5 files.
  INTERFACE save_1d_array_to_hdf5
     module procedure isave_1d_array_to_hdf5,rsave_1d_array_to_hdf5
  END INTERFACE save_1d_array_to_hdf5

  !! @note Fortran interface to subroutines saving 2-D arrays of real values to HDF5 files.
  !! @todo To code the corresponding subroutines for saving integer 2-D arrays.
  INTERFACE save_2d_array_to_hdf5
     module procedure rsave_2d_array_to_hdf5
  END INTERFACE save_2d_array_to_hdf5

  !! @note Fortran interface to subroutines saving 3-D arrays of real values to HDF5 files.
  !! @todo To include the corresponding subroutines for saving arrays of integers.
  INTERFACE save_3d_array_to_hdf5
     module procedure rsave_3d_array_to_hdf5
  END INTERFACE save_3d_array_to_hdf5

  !! @note Fortran interface to subroutines saving 1-D, 2-D or 3-D arrays of real values to HDF5 files.
  !! @todo To include the corresponding subroutines for saving arrays of integers.
  INTERFACE save_array_to_hdf5
     module procedure isave_1d_array_to_hdf5,rsave_1d_array_to_hdf5,rsave_2d_array_to_hdf5,rsave_3d_array_to_hdf5
  END INTERFACE save_array_to_hdf5

  PRIVATE :: rsave_to_hdf5,&
       isave_1d_array_to_hdf5,&
       rsave_1d_array_to_hdf5,&
       rsave_2d_array_to_hdf5,&
       iload_from_hdf5,&
       rload_from_hdf5,&
       rload_1d_array_from_hdf5,&
       rload_3d_array_from_hdf5,&
       rload_2d_array_from_hdf5,&
       i1save_to_hdf5,&
       i2save_to_hdf5,&
       i4save_to_hdf5,&
       i8save_to_hdf5

  PUBLIC :: initialize_HDF5,&
       finalize_HDF5,&
       save_simulation_parameters,&
       save_to_hdf5,&
       save_1d_array_to_hdf5,&
       save_2d_array_to_hdf5,&
       load_from_hdf5,&
       load_array_from_hdf5,&
       save_string_parameter,&
       load_time_stepping_params,&
       load_prev_time,&
       save_restart_variables,&
       load_particles_ic

CONTAINS

  !! @note Initialization of HDF5 library.
  !!
  !! @param h5error HDF5 error status.
  subroutine initialize_HDF5()
    INTEGER :: h5error  ! Error flag
    call h5open_f(h5error)

#ifdef HDF5_DOUBLE_PRESICION
    call h5tcopy_f(H5T_NATIVE_DOUBLE, KORC_HDF5_REAL, h5error)
#elif HDF5_SINGLE_PRESICION
    call h5tcopy_f(H5T_NATIVE_REAL, KORC_HDF5_REAL, h5error)
#endif

    call h5tget_size_f(KORC_HDF5_REAL, rp_hdf5, h5error)
  end subroutine initialize_HDF5

  !! @note Finalization of HDF5 library.
  !!
  !! @param h5error HDF5 error status.
  subroutine finalize_HDF5()
    INTEGER :: h5error  ! Error flag
    call h5close_f(h5error)
  end subroutine finalize_HDF5

  !! @note Subroutine to load an integer datum from an HDF5 file.
  !!
  !! @todo Implement the reading of the attribute of idatum.
  !! @param[in] h5file_id HDF5 file identifier.
  !! @param[in] dset String containing the name of the datum.
  !! @param[out] idatum Integer datum read from HDF5 file.
  !! @param[out] attr Attribute of datum read from HDF5 file.
  !! @param aname Name of idatum attribute.
  !! @param dset_id HDF5 data set identifier.
  !! @param dspace_id HDF5 datum space identifier.
  !! @param aspace_id HDF5 datum's attribute space identifier.
  !! @param attr_id HDF5 datum's attribute identifier.
  !! @param atype_id Native HDF5 attribute type.
  !! @param dims Dimensions of data read from HDF5 file.
  !! @param adims Dimensions of data's attributes read from HDF5 file.
  !! @param h5error HDF5 error status.
  subroutine iload_from_hdf5(h5file_id,dset,idatum,attr)
    INTEGER(HID_T), INTENT(IN) 				:: h5file_id
    CHARACTER(MAX_STRING_LENGTH), INTENT(IN) 		:: dset
    INTEGER, INTENT(OUT) 				:: idatum
    CHARACTER(MAX_STRING_LENGTH), OPTIONAL, INTENT(OUT) :: attr
    CHARACTER(4) 					:: aname = "Info"
    INTEGER(HID_T) 					:: dset_id
    INTEGER(HID_T) 					:: dspace_id
    INTEGER(HID_T) 					:: aspace_id
    INTEGER(HID_T) 					:: attr_id
    INTEGER(HID_T) 					:: atype_id
    INTEGER(HSIZE_T), DIMENSION(1) 			:: dims = (/1/)
    INTEGER(HSIZE_T), DIMENSION(1) 			:: adims = (/1/)
    INTEGER 						:: h5error

    ! * * * Read datum from file * * *

    call h5dopen_f(h5file_id, TRIM(dset), dset_id, h5error)
    if (h5error .EQ. -1) then
       write(6,'("KORC ERROR: Something went wrong in: iload_from_hdf5 &
            --> h5dopen_f")')
    end if

    call h5dread_f(dset_id, H5T_NATIVE_INTEGER, idatum, dims, h5error)

    if (h5error .EQ. -1) then
       write(6,'("KORC ERROR: Something went wrong in: iload_from_hdf5 &
            --> h5dread_f")')
    end if

    call h5dclose_f(dset_id, h5error)
    if (h5error .EQ. -1) then
       write(6,'("KORC ERROR: Something went wrong in: iload_from_hdf5 &
            --> h5dclose_f")')
    end if

    if (PRESENT(attr)) then
       ! * * * Read attribute from file * * *

       ! * * * Read attribute from file * * *
    end if

    ! * * * Read datum from file * * *
  end subroutine iload_from_hdf5

  !! @note Subroutine to load a real datum from an HDF5 file.
  !!
  !! @param[in] h5file_id HDF5 file identifier.
  !! @param[in] dset String containing the name of the datum.
  !! @param[out] rdatum Real datum read from HDF5 file and casted to
  !! KORC's real precision type.
  !! @param[out] attr Attribute of datum read from HDF5 file.
  !! @param raw_datum Datum read from HDF5 file.
  !! @param aname Name of rdatum attribute.
  !! @param dset_id HDF5 data set identifier.
  !! @param dspace_id HDF5 datum space identifier.
  !! @param aspace_id HDF5 datum's attribute space identifier.
  !! @param attr_id HDF5 datum's attribute identifier.
  !! @param atype_id Native HDF5 attribute type.
  !! @param dims Dimensions of data read from HDF5 file.
  !! @param adims Dimensions of data's attributes read from HDF5 file.
  !! @param h5error HDF5 error status.
  !! @todo Implement the reading of the attribute of rdatum.
  subroutine rload_from_hdf5(h5file_id,dset,rdatum,attr)
    INTEGER(HID_T), INTENT(IN) 				:: h5file_id
    CHARACTER(MAX_STRING_LENGTH), INTENT(IN) 		:: dset
    REAL(rp), INTENT(OUT) 				:: rdatum
    REAL 						:: raw_datum
    CHARACTER(MAX_STRING_LENGTH), OPTIONAL, INTENT(OUT) :: attr
    CHARACTER(4) 					:: aname = "Info"
    INTEGER(HID_T) 					:: dset_id
    INTEGER(HID_T) 					:: dspace_id
    INTEGER(HID_T) 					:: aspace_id
    INTEGER(HID_T) 					:: attr_id
    INTEGER(HID_T) 					:: atype_id
    INTEGER(HSIZE_T), DIMENSION(1) 			:: dims = (/1/)
    INTEGER(HSIZE_T), DIMENSION(1) 			:: adims = (/1/)
    INTEGER 						:: h5error

    ! * * * Read datum from file * * *

    call h5dopen_f(h5file_id, TRIM(dset), dset_id, h5error)
    if (h5error .EQ. -1) then
       write(6,'("KORC ERROR: Something went wrong in: rload_from_hdf5 &
            --> h5dopen_f")')
    end if

    call h5dread_f(dset_id, H5T_NATIVE_REAL, raw_datum, dims, h5error)
    if (h5error .EQ. -1) then
       write(6,'("KORC ERROR: Something went wrong in: rload_from_hdf5 &
            --> h5dread_f")')
    end if
    rdatum = REAL(raw_datum,rp)

    call h5dclose_f(dset_id, h5error)
    if (h5error .EQ. -1) then
       write(6,'("KORC ERROR: Something went wrong in: rload_from_hdf5 &
            --> h5dclose_f")')
    end if

    if (PRESENT(attr)) then
       ! * * * Read attribute from file * * *

       ! * * * Read attribute from file * * *
    end if

    ! * * * Read datum from file * * *
  end subroutine rload_from_hdf5

  !! @note Subroutine to load a 1-D array of reals from an HDF5 file.
  !! @details The dimension of the 1-D array rdata is determined by the
  !! input-output array rdata.
  !!
  !! @param[in] h5file_id HDF5 file identifier.
  !! @param[in] dset String containing the name of the data.
  !! @param[out] rdata 1-D array of real values read from HDF5 file and
  !! casted to KORC's real precision type.
  !! @param[out] attr 1-D array of attributes of rdata.
  !! @param raw_data 1-D array read from HDF5 file.
  !! @param aname Name of rdata attribute.
  !! @param dset_id HDF5 data set identifier.
  !! @param dspace_id HDF5 datum space identifier.
  !! @param aspace_id HDF5 datum's attribute space identifier.
  !! @param attr_id HDF5 datum's attribute identifier.
  !! @param atype_id Native HDF5 attribute type.
  !! @param dims Dimensions of data read from HDF5 file.
  !! @param adims Dimensions of data's attributes read from HDF5 file.
  !! @param h5error HDF5 error status.
  !! @todo Implement the reading of the attributes of rdata.
  subroutine rload_1d_array_from_hdf5(h5file_id,dset,rdata,attr)
    INTEGER(HID_T), INTENT(IN) 				:: h5file_id
    CHARACTER(MAX_STRING_LENGTH), INTENT(IN)		:: dset
    REAL(rp), DIMENSION(:), ALLOCATABLE, INTENT(INOUT) 	:: rdata
    REAL, DIMENSION(:), ALLOCATABLE 			:: raw_data
    CHARACTER(MAX_STRING_LENGTH), OPTIONAL, DIMENSION(:), ALLOCATABLE, INTENT(OUT) 	:: attr
    CHARACTER(MAX_STRING_LENGTH) 			:: aname
    INTEGER(HID_T) 					:: dset_id
    INTEGER(HID_T) 					:: dspace_id
    INTEGER(HID_T) 					:: aspace_id
    INTEGER(HID_T) 					:: attr_id
    INTEGER(HID_T) 					:: atype_id
    INTEGER(HSIZE_T), DIMENSION(1) 			:: dims
    INTEGER(HSIZE_T), DIMENSION(1) 			:: adims
    INTEGER 						:: h5error

    dims = (/ shape(rdata) /)

    ALLOCATE( raw_data(dims(1)) )

    ! * * * Read data from file * * *

    call h5dopen_f(h5file_id, TRIM(dset), dset_id, h5error)
    if (h5error .EQ. -1) then
       write(6,'("KORC ERROR: Something went wrong in: rload_from_hdf5 --> h5dopen_f")')
    end if

    call h5dread_f(dset_id, H5T_NATIVE_REAL, raw_data, dims, h5error)
    if (h5error .EQ. -1) then
       write(6,'("KORC ERROR: Something went wrong in: rload_from_hdf5 --> h5dread_f")')
    end if
    rdata = REAL(raw_data,rp)

    call h5dclose_f(dset_id, h5error)
    if (h5error .EQ. -1) then
       write(6,'("KORC ERROR: Something went wrong in: rload_from_hdf5 --> h5dclose_f")')
    end if

    DEALLOCATE( raw_data )

    if (PRESENT(attr)) then
       ! * * * Read data attribute(s) from file * * *
    end if

    ! * * * Read data from file * * *
  end subroutine rload_1d_array_from_hdf5

  !! @note Subroutine to load a 2-D array of reals from an HDF5 file.
  !! @details The dimensions of the 2-D array rdata is determined by the input-output array rdata.
  !!
  !! @param[in] h5file_id HDF5 file identifier.
  !! @param[in] dset String containing the name of the data.
  !! @param[out] rdata 2-D array of real values read from HDF5 file and casted to KORC's real precision type.
  !! @param[out] attr 2-D array of attributes of rdata.
  !! @param raw_data 2-D array read from HDF5 file.
  !! @param aname Name of rdata attribute.
  !! @param dset_id HDF5 data set identifier.
  !! @param dspace_id HDF5 datum space identifier.
  !! @param aspace_id HDF5 datum's attribute space identifier.
  !! @param attr_id HDF5 datum's attribute identifier.
  !! @param atype_id Native HDF5 attribute type.
  !! @param dims Dimensions of data read from HDF5 file.
  !! @param adims Dimensions of data's attributes read from HDF5 file.
  !! @param h5error HDF5 error status.
  !! @todo Implement the reading of the attributes of rdata.
  subroutine rload_2d_array_from_hdf5(h5file_id,dset,rdata,attr)
    INTEGER(HID_T), INTENT(IN) 														:: h5file_id
    CHARACTER(MAX_STRING_LENGTH), INTENT(IN) 										:: dset
    REAL(rp), DIMENSION(:,:), ALLOCATABLE, INTENT(INOUT) 							:: rdata
    REAL, DIMENSION(:,:), ALLOCATABLE 												:: raw_data
    CHARACTER(MAX_STRING_LENGTH), OPTIONAL, DIMENSION(:), ALLOCATABLE, INTENT(IN) 	:: attr
    CHARACTER(MAX_STRING_LENGTH) 													:: aname
    INTEGER(HID_T) 																	:: dset_id
    INTEGER(HID_T) 																	:: dspace_id
    INTEGER(HID_T) 																	:: aspace_id
    INTEGER(HID_T) 																	:: attr_id
    INTEGER(HID_T) 																	:: atype_id
    INTEGER(HSIZE_T), DIMENSION(2) 													:: dims
    INTEGER(HSIZE_T), DIMENSION(2) 													:: adims
    INTEGER 																		:: h5error

    dims = shape(rdata)

    ALLOCATE( raw_data(dims(1),dims(2)) )

    ! * * * Read data from file * * *

    call h5dopen_f(h5file_id, TRIM(dset), dset_id, h5error)
    if (h5error .EQ. -1) then
       write(6,'("KORC ERROR: Something went wrong in: rload_from_hdf5 --> h5dopen_f")')
    end if

    call h5dread_f(dset_id, H5T_NATIVE_REAL, raw_data, dims, h5error)
    if (h5error .EQ. -1) then
       write(6,'("KORC ERROR: Something went wrong in: rload_from_hdf5 --> h5dread_f")')
    end if
    rdata = REAL(raw_data,rp)

    call h5dclose_f(dset_id, h5error)
    if (h5error .EQ. -1) then
       write(6,'("KORC ERROR: Something went wrong in: rload_from_hdf5 --> h5dclose_f")')
    end if

    DEALLOCATE( raw_data )

    if (PRESENT(attr)) then
       ! * * * Read data attribute(s) from file * * *
    end if

    ! * * * Read data from file * * *
  end subroutine rload_2d_array_from_hdf5

  !! @note Subroutine to load a 3-D array of reals from an HDF5 file.
  !! @details The dimensions of the 3-D array rdata is determined by the input-output array rdata.
  !!
  !! @param[in] h5file_id HDF5 file identifier.
  !! @param[in] dset String containing the name of the data.
  !! @param[out] rdata 3-D array of real values read from HDF5 file and casted to KORC's real precision type.
  !! @param[out] attr 3-D array of attributes of rdata.
  !! @param raw_data 3-D array read from HDF5 file.
  !! @param aname Name of rdata attribute.
  !! @param dset_id HDF5 data set identifier.
  !! @param dspace_id HDF5 datum space identifier.
  !! @param aspace_id HDF5 datum's attribute space identifier.
  !! @param attr_id HDF5 datum's attribute identifier.
  !! @param atype_id Native HDF5 attribute type.
  !! @param dims Dimensions of data read from HDF5 file.
  !! @param adims Dimensions of data's attributes read from HDF5 file.
  !! @param h5error HDF5 error status.
  !! @todo Implement the reading of the attributes of rdata.
  subroutine rload_3d_array_from_hdf5(h5file_id,dset,rdata,attr)
    INTEGER(HID_T), INTENT(IN) 														:: h5file_id
    CHARACTER(MAX_STRING_LENGTH), INTENT(IN) 										:: dset
    REAL(rp), DIMENSION(:,:,:), ALLOCATABLE, INTENT(INOUT) 							:: rdata
    REAL, DIMENSION(:,:,:), ALLOCATABLE 											:: raw_data
    CHARACTER(MAX_STRING_LENGTH), OPTIONAL, DIMENSION(:), ALLOCATABLE, INTENT(IN) 	:: attr
    CHARACTER(MAX_STRING_LENGTH) 													:: aname
    INTEGER(HID_T) 																	:: dset_id
    INTEGER(HID_T) 																	:: dspace_id
    INTEGER(HID_T) 																	:: aspace_id
    INTEGER(HID_T) 																	:: attr_id
    INTEGER(HID_T) 																	:: atype_id
    INTEGER(HSIZE_T), DIMENSION(3) 													:: dims
    INTEGER(HSIZE_T), DIMENSION(3) 													:: adims
    INTEGER 																		:: h5error

    dims = shape(rdata)

    ALLOCATE( raw_data(dims(1),dims(2),dims(3)) )

    ! * * * Read data from file * * *

    call h5dopen_f(h5file_id, TRIM(dset), dset_id, h5error)
    if (h5error .EQ. -1) then
       write(6,'("KORC ERROR: Something went wrong in: rload_from_hdf5 --> h5dopen_f")')
    end if

    call h5dread_f(dset_id, H5T_NATIVE_REAL, raw_data, dims, h5error)
    if (h5error .EQ. -1) then
       write(6,'("KORC ERROR: Something went wrong in: rload_from_hdf5 --> h5dread_f")')
    end if
    rdata = REAL(raw_data,rp)

    call h5dclose_f(dset_id, h5error)
    if (h5error .EQ. -1) then
       write(6,'("KORC ERROR: Something went wrong in: rload_from_hdf5 --> h5dclose_f")')
    end if

    DEALLOCATE( raw_data )

    if (PRESENT(attr)) then
       ! * * * Read data attribute(s) from file * * *
    end if

    ! * * * Read data from file * * *
  end subroutine rload_3d_array_from_hdf5

  !! @note Subroutine to write a 1 byte (8 bits) integer to an HDF5 file.
  !!
  !! @param[in] h5file_id HDF5 file identifier.
  !! @param[in] dset String containing the name of the datum.
  !! @param[in] idatum Integer datum read from HDF5 file.
  !! @param[in] attr Attribute of datum read from HDF5 file.
  !! @param aname Name of idatum attribute.
  !! @param dset_id HDF5 data set identifier.
  !! @param dspace_id HDF5 datum space identifier.
  !! @param aspace_id HDF5 datum's attribute space identifier.
  !! @param attr_id HDF5 datum's attribute identifier.
  !! @param atype_id Native HDF5 attribute type.
  !! @param dims Dimensions of data read from HDF5 file.
  !! @param adims Dimensions of data's attributes read from HDF5 file.
  !! @param rank Number of dimensions of idatum's dataspace.
  !! @param arank Number of dimensions of attr's dataspace.
  !! @param attrlen Lenght of idatum attribute's name.
  !! @param h5error HDF5 error status.
  subroutine i1save_to_hdf5(h5file_id,dset,idatum,attr)
    INTEGER(HID_T), INTENT(IN) 							:: h5file_id
    CHARACTER(MAX_STRING_LENGTH), INTENT(IN) 			:: dset
    INTEGER(KIND=1), INTENT(IN) 						:: idatum
    CHARACTER(MAX_STRING_LENGTH), OPTIONAL, INTENT(IN) 	:: attr
    CHARACTER(4) 										:: aname = "Info"
    INTEGER(HID_T) 										:: dset_id
    INTEGER(HID_T) 										:: dspace_id
    INTEGER(HID_T) 										:: aspace_id
    INTEGER(HID_T) 										:: attr_id
    INTEGER(HID_T) 										:: atype_id
    INTEGER(HSIZE_T), DIMENSION(1) 						:: dims = (/1/)
    INTEGER(HSIZE_T), DIMENSION(1) 						:: adims = (/1/)
    INTEGER 											:: rank = 1
    INTEGER 											:: arank = 1
    INTEGER(SIZE_T) 									:: attrlen
    INTEGER 											:: h5error

    ! * * * Write data to file * * *
    call h5screate_simple_f(rank,dims,dspace_id,h5error)
    call h5dcreate_f(h5file_id, TRIM(dset), H5T_NATIVE_INTEGER, dspace_id, dset_id, h5error)
    call h5dwrite_f(dset_id, H5T_NATIVE_INTEGER, INT(idatum,idef), dims, h5error)

    if (PRESENT(attr)) then
       ! * * * Write attribute of data to file * * *
       attrlen = LEN_TRIM(attr)
       call h5screate_simple_f(arank,adims,aspace_id,h5error)
       call h5tcopy_f(H5T_NATIVE_CHARACTER, atype_id, h5error)
       call h5tset_size_f(atype_id, attrlen, h5error)
       call h5acreate_f(dset_id, aname, atype_id, aspace_id, attr_id, h5error)
       call h5awrite_f(attr_id, atype_id, attr, adims, h5error)

       call h5aclose_f(attr_id, h5error)
       call h5sclose_f(aspace_id, h5error)
       ! * * * Write attribute of data to file * * *
    end if

    call h5sclose_f(dspace_id, h5error)
    call h5dclose_f(dset_id, h5error)
    ! * * * Write data to file * * *
  end subroutine i1save_to_hdf5

  !! @note Subroutine to write a 2 byte (16 bits) integer to an HDF5 file.
  !!
  !! @param[in] h5file_id HDF5 file identifier.
  !! @param[in] dset String containing the name of the datum.
  !! @param[in] idatum Integer datum read from HDF5 file.
  !! @param[in] attr Attribute of datum read from HDF5 file.
  !! @param aname Name of idatum attribute.
  !! @param dset_id HDF5 data set identifier.
  !! @param dspace_id HDF5 datum space identifier.
  !! @param aspace_id HDF5 datum's attribute space identifier.
  !! @param attr_id HDF5 datum's attribute identifier.
  !! @param atype_id Native HDF5 attribute type.
  !! @param dims Dimensions of data read from HDF5 file.
  !! @param adims Dimensions of data's attributes read from HDF5 file.
  !! @param rank Number of dimensions of idatum's dataspace.
  !! @param arank Number of dimensions of attr's dataspace.
  !! @param attrlen Lenght of idatum attribute's name.
  !! @param h5error HDF5 error status.
  subroutine i2save_to_hdf5(h5file_id,dset,idatum,attr)
    INTEGER(HID_T), INTENT(IN) 							:: h5file_id
    CHARACTER(MAX_STRING_LENGTH), INTENT(IN) 			:: dset
    INTEGER(KIND=2), INTENT(IN) 						:: idatum
    CHARACTER(MAX_STRING_LENGTH), OPTIONAL, INTENT(IN) 	:: attr
    CHARACTER(4) 										:: aname = "Info"
    INTEGER(HID_T) 										:: dset_id
    INTEGER(HID_T) 										:: dspace_id
    INTEGER(HID_T) 										:: aspace_id
    INTEGER(HID_T) 										:: attr_id
    INTEGER(HID_T) 										:: atype_id
    INTEGER(HSIZE_T), DIMENSION(1) 						:: dims = (/1/)
    INTEGER(HSIZE_T), DIMENSION(1) 						:: adims = (/1/)
    INTEGER 											:: rank = 1
    INTEGER 											:: arank = 1
    INTEGER(SIZE_T) 									:: attrlen
    INTEGER 											:: h5error

    ! * * * Write data to file * * *
    call h5screate_simple_f(rank,dims,dspace_id,h5error)
    call h5dcreate_f(h5file_id, TRIM(dset), H5T_NATIVE_INTEGER, dspace_id, dset_id, h5error)
    call h5dwrite_f(dset_id, H5T_NATIVE_INTEGER, INT(idatum,idef), dims, h5error)

    if (PRESENT(attr)) then
       ! * * * Write attribute of data to file * * *
       attrlen = LEN_TRIM(attr)
       call h5screate_simple_f(arank,adims,aspace_id,h5error)
       call h5tcopy_f(H5T_NATIVE_CHARACTER, atype_id, h5error)
       call h5tset_size_f(atype_id, attrlen, h5error)
       call h5acreate_f(dset_id, aname, atype_id, aspace_id, attr_id, h5error)
       call h5awrite_f(attr_id, atype_id, attr, adims, h5error)

       call h5aclose_f(attr_id, h5error)
       call h5sclose_f(aspace_id, h5error)
       ! * * * Write attribute of data to file * * *
    end if

    call h5sclose_f(dspace_id, h5error)
    call h5dclose_f(dset_id, h5error)
    ! * * * Write data to file * * *
  end subroutine i2save_to_hdf5

  !! @note Subroutine to write a 4 byte (32 bits) integer to an HDF5 file.
  !!
  !! @param[in] h5file_id HDF5 file identifier.
  !! @param[in] dset String containing the name of the datum.
  !! @param[in] idatum Integer datum read from HDF5 file.
  !! @param[in] attr Attribute of datum read from HDF5 file.
  !! @param aname Name of idatum attribute.
  !! @param dset_id HDF5 data set identifier.
  !! @param dspace_id HDF5 datum space identifier.
  !! @param aspace_id HDF5 datum's attribute space identifier.
  !! @param attr_id HDF5 datum's attribute identifier.
  !! @param atype_id Native HDF5 attribute type.
  !! @param dims Dimensions of data read from HDF5 file.
  !! @param adims Dimensions of data's attributes read from HDF5 file.
  !! @param rank Number of dimensions of idatum's dataspace.
  !! @param arank Number of dimensions of attr's dataspace.
  !! @param attrlen Lenght of idatum attribute's name.
  !! @param h5error HDF5 error status.
  subroutine i4save_to_hdf5(h5file_id,dset,idatum,attr)
    INTEGER(HID_T), INTENT(IN) 							:: h5file_id
    CHARACTER(MAX_STRING_LENGTH), INTENT(IN) 			:: dset
    INTEGER(KIND=4), INTENT(IN) 						:: idatum
    CHARACTER(MAX_STRING_LENGTH), OPTIONAL, INTENT(IN) 	:: attr
    CHARACTER(4) 										:: aname = "Info"
    INTEGER(HID_T) 										:: dset_id
    INTEGER(HID_T) 										:: dspace_id
    INTEGER(HID_T) 										:: aspace_id
    INTEGER(HID_T) 										:: attr_id
    INTEGER(HID_T) 										:: atype_id
    INTEGER(HSIZE_T), DIMENSION(1) 						:: dims = (/1/)
    INTEGER(HSIZE_T), DIMENSION(1) 						:: adims = (/1/)
    INTEGER 											:: rank = 1
    INTEGER 											:: arank = 1
    INTEGER(SIZE_T) 									:: attrlen
    INTEGER 											:: h5error

    ! * * * Write data to file * * *
    call h5screate_simple_f(rank,dims,dspace_id,h5error)
    call h5dcreate_f(h5file_id, TRIM(dset), H5T_NATIVE_INTEGER, dspace_id, dset_id, h5error)
    call h5dwrite_f(dset_id, H5T_NATIVE_INTEGER, INT(idatum,idef), dims, h5error)

    if (PRESENT(attr)) then
       ! * * * Write attribute of data to file * * *
       attrlen = LEN_TRIM(attr)
       call h5screate_simple_f(arank,adims,aspace_id,h5error)
       call h5tcopy_f(H5T_NATIVE_CHARACTER, atype_id, h5error)
       call h5tset_size_f(atype_id, attrlen, h5error)
       call h5acreate_f(dset_id, aname, atype_id, aspace_id, attr_id, h5error)
       call h5awrite_f(attr_id, atype_id, attr, adims, h5error)

       call h5aclose_f(attr_id, h5error)
       call h5sclose_f(aspace_id, h5error)
       ! * * * Write attribute of data to file * * *
    end if

    call h5sclose_f(dspace_id, h5error)
    call h5dclose_f(dset_id, h5error)
    ! * * * Write data to file * * *
  end subroutine i4save_to_hdf5

  !! @note Subroutine to write a 8 byte (64 bits) integer to an HDF5 file.
  !!
  !! @param[in] h5file_id HDF5 file identifier.
  !! @param[in] dset String containing the name of the datum.
  !! @param[in] idatum Integer datum read from HDF5 file.
  !! @param[in] attr Attribute of datum read from HDF5 file.
  !! @param aname Name of idatum attribute.
  !! @param dset_id HDF5 data set identifier.
  !! @param dspace_id HDF5 datum space identifier.
  !! @param aspace_id HDF5 datum's attribute space identifier.
  !! @param attr_id HDF5 datum's attribute identifier.
  !! @param atype_id Native HDF5 attribute type.
  !! @param dims Dimensions of data read from HDF5 file.
  !! @param adims Dimensions of data's attributes read from HDF5 file.
  !! @param rank Number of dimensions of idatum's dataspace.
  !! @param arank Number of dimensions of attr's dataspace.
  !! @param attrlen Lenght of idatum attribute's name.
  !! @param h5error HDF5 error status.
  subroutine i8save_to_hdf5(h5file_id,dset,idatum,attr)
    INTEGER(HID_T), INTENT(IN) 							:: h5file_id
    CHARACTER(MAX_STRING_LENGTH), INTENT(IN) 			:: dset
    INTEGER(KIND=8), INTENT(IN) 						:: idatum
    CHARACTER(MAX_STRING_LENGTH), OPTIONAL, INTENT(IN) 	:: attr
    CHARACTER(4) 										:: aname = "Info"
    INTEGER(HID_T) 										:: dset_id
    INTEGER(HID_T) 										:: dspace_id
    INTEGER(HID_T) 										:: aspace_id
    INTEGER(HID_T) 										:: attr_id
    INTEGER(HID_T) 										:: atype_id
    INTEGER(HSIZE_T), DIMENSION(1) 						:: dims = (/1/)
    INTEGER(HSIZE_T), DIMENSION(1) 						:: adims = (/1/)
    INTEGER 											:: rank = 1
    INTEGER 											:: arank = 1
    INTEGER(SIZE_T) 									:: attrlen
    INTEGER 											:: h5error

    ! * * * Write data to file * * *
    call h5screate_simple_f(rank,dims,dspace_id,h5error)
    call h5dcreate_f(h5file_id, TRIM(dset), H5T_NATIVE_DOUBLE, dspace_id, dset_id, h5error)
    call h5dwrite_f(dset_id, H5T_NATIVE_DOUBLE, REAL(idatum,8), dims, h5error)


    if (PRESENT(attr)) then
       ! * * * Write attribute of data to file * * *
       attrlen = LEN_TRIM(attr)
       call h5screate_simple_f(arank,adims,aspace_id,h5error)
       call h5tcopy_f(H5T_NATIVE_CHARACTER, atype_id, h5error)
       call h5tset_size_f(atype_id, attrlen, h5error)
       call h5acreate_f(dset_id, aname, atype_id, aspace_id, attr_id, h5error)
       call h5awrite_f(attr_id, atype_id, attr, adims, h5error)

       call h5aclose_f(attr_id, h5error)
       call h5sclose_f(aspace_id, h5error)
       ! * * * Write attribute of data to file * * *
    end if

    call h5sclose_f(dspace_id, h5error)
    call h5dclose_f(dset_id, h5error)
    ! * * * Write data to file * * *
  end subroutine i8save_to_hdf5

  !! @note Subroutine to write a 1-D array of integer values to an HDF5 file.
  !!
  !! @param[in] h5file_id HDF5 file identifier.
  !! @param[in] dset String containing the name of the data.
  !! @param[in] idata Data written to HDF5 file.
  !! @param[in] attr Attributes of data written to HDF5 file.
  !! @param aname Name of idata attributes.
  !! @param dset_id HDF5 data set identifier.
  !! @param dspace_id HDF5 data space identifier.
  !! @param aspace_id HDF5 data's attribute space identifier.
  !! @param attr_id HDF5 data's attribute identifier.
  !! @param atype_id Native HDF5 attribute type.
  !! @param dims Dimensions of data writen to HDF5 file.
  !! @param adims Dimensions of data's attributes written to HDF5 file.
  !! @param rank Number of dimensions of idata's dataspace.
  !! @param arank Number of dimensions of attr's dataspace.
  !! @param attrlen Lenght of idata attribute's name.
  !! @param h5error HDF5 error status.
  !! @param rr Rank iterator.
  !! @param dd Dimension iterator.
  !! @bug When using a 1-D array of attributes, only the first attribute is saved.
  subroutine isave_1d_array_to_hdf5(h5file_id,dset,idata,attr)
    INTEGER(HID_T), INTENT(IN) 														:: h5file_id
    CHARACTER(MAX_STRING_LENGTH), INTENT(IN) 										:: dset
    INTEGER, DIMENSION(:), INTENT(IN) 												:: idata
    CHARACTER(MAX_STRING_LENGTH), OPTIONAL, DIMENSION(:), ALLOCATABLE, INTENT(IN) 	:: attr
    CHARACTER(4) 																	:: aname = "Info"
    INTEGER(HID_T) 																	:: dset_id
    INTEGER(HID_T) 																	:: dspace_id
    INTEGER(HID_T) 																	:: aspace_id
    INTEGER(HID_T) 																	:: attr_id
    INTEGER(HID_T) 																	:: atype_id
    INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE 									:: dims
    INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE 									:: adims
    INTEGER 																		:: rank
    INTEGER 																		:: arank
    INTEGER(SIZE_T) 																:: attrlen
    INTEGER(SIZE_T) 																:: tmplen
    INTEGER 																		:: h5error
    INTEGER 																		:: rr,dd

    rank = size(shape(idata))
    ALLOCATE(dims(rank))
    dims = shape(idata)

    ! * * * Write data to file * * *
    call h5screate_simple_f(rank,dims,dspace_id,h5error)
    call h5dcreate_f(h5file_id, TRIM(dset), H5T_NATIVE_INTEGER, dspace_id, dset_id, h5error)
    call h5dwrite_f(dset_id, H5T_NATIVE_INTEGER, idata, dims, h5error)

    if (PRESENT(attr)) then
       arank = size(shape(attr))
       ALLOCATE(adims(arank))
       adims = shape(attr)

       ! * * * Write attribute of data to file * * *
       tmplen = 0
       attrlen = 0
       do rr=1_idef,arank
          do dd=1_idef,adims(rr)
             tmplen = LEN_TRIM(attr(dd))
             if ( tmplen .GT. attrlen) then
                attrlen = tmplen
             end if
          end do
       end do

       call h5screate_simple_f(arank,adims,aspace_id,h5error)
       call h5tcopy_f(H5T_NATIVE_CHARACTER, atype_id, h5error)
       call h5tset_size_f(atype_id, attrlen, h5error)
       call h5acreate_f(dset_id, aname, atype_id, aspace_id, attr_id, h5error)
       call h5awrite_f(attr_id, atype_id, attr, adims, h5error)

       call h5aclose_f(attr_id, h5error)
       call h5sclose_f(aspace_id, h5error)
       ! * * * Write attribute of data to file * * *

       DEALLOCATE(adims)
    end if

    call h5sclose_f(dspace_id, h5error)
    call h5dclose_f(dset_id, h5error)
    ! * * * Write data to file * * *

    DEALLOCATE(dims)
  end subroutine isave_1d_array_to_hdf5

  !! @note Subroutine to write a real to an HDF5 file.
  !!
  !! @param[in] h5file_id HDF5 file identifier.
  !! @param[in] dset String containing the name of the datum.
  !! @param[in] rdatum Real datum written to HDF5 file.
  !! @param[in] attr Attribute of datum written to HDF5 file.
  !! @param aname Name of rdatum attribute.
  !! @param dset_id HDF5 data set identifier.
  !! @param dspace_id HDF5 datum space identifier.
  !! @param aspace_id HDF5 datum's attribute space identifier.
  !! @param attr_id HDF5 datum's attribute identifier.
  !! @param atype_id Native HDF5 attribute type.
  !! @param dims Dimensions of data written to HDF5 file.
  !! @param adims Dimensions of data's attributes read from HDF5 file.
  !! @param rank Number of dimensions of rdatum's dataspace.
  !! @param arank Number of dimensions of attr's dataspace.
  !! @param attrlen Lenght of rdatum attribute's name.
  !! @param h5error HDF5 error status.
  subroutine rsave_to_hdf5(h5file_id,dset,rdatum,attr)
    INTEGER(HID_T), INTENT(IN) 							:: h5file_id
    CHARACTER(MAX_STRING_LENGTH), INTENT(IN) 			:: dset
    REAL(rp), INTENT(IN) 								:: rdatum
    CHARACTER(MAX_STRING_LENGTH), OPTIONAL, INTENT(IN) 	:: attr
    CHARACTER(4) 										:: aname = "Info"
    INTEGER(HID_T) 										:: dset_id
    INTEGER(HID_T) 										:: dspace_id
    INTEGER(HID_T) 										:: aspace_id
    INTEGER(HID_T) 										:: attr_id
    INTEGER(HID_T) 										:: atype_id
    INTEGER(HSIZE_T), DIMENSION(1) 						:: dims = (/1/)
    INTEGER(HSIZE_T), DIMENSION(1) 						:: adims = (/1/)
    INTEGER 											:: rank = 1
    INTEGER 											:: arank = 1
    INTEGER(SIZE_T) 									:: attrlen
    INTEGER 											:: h5error

    ! * * * Write data to file * * *

    call h5screate_simple_f(rank,dims,dspace_id,h5error)
    call h5dcreate_f(h5file_id, TRIM(dset), KORC_HDF5_REAL, dspace_id, dset_id, h5error)

    if (rp .EQ. INT(rp_hdf5)) then
       call h5dwrite_f(dset_id, KORC_HDF5_REAL, rdatum, dims, h5error)
    else
       call h5dwrite_f(dset_id, KORC_HDF5_REAL, REAL(rdatum,4), dims, h5error)
    end if

    if (PRESENT(attr)) then
       ! * * * Write attribute of data to file * * *
       attrlen = LEN_TRIM(attr)
       call h5screate_simple_f(arank,adims,aspace_id,h5error)
       call h5tcopy_f(H5T_NATIVE_CHARACTER, atype_id, h5error)
       call h5tset_size_f(atype_id, attrlen, h5error)
       call h5acreate_f(dset_id, aname, atype_id, aspace_id, attr_id, h5error)
       call h5awrite_f(attr_id, atype_id, attr, adims, h5error)

       call h5aclose_f(attr_id, h5error)
       call h5sclose_f(aspace_id, h5error)
       ! * * * Write attribute of data to file * * *
    end if

    call h5sclose_f(dspace_id, h5error)
    call h5dclose_f(dset_id, h5error)
    ! * * * Write data to file * * *
  end subroutine rsave_to_hdf5

  !! @note Subroutine to write a 1-D array of real values to an HDF5 file.
  !!
  !! @bug When using a 1-D array of attributes, only the first attribute is saved.
  !! @param[in] h5file_id HDF5 file identifier.
  !! @param[in] dset String containing the name of the data.
  !! @param[in] rdata Data written to HDF5 file.
  !! @param[in] attr Attributes of data written to HDF5 file.
  !! @param aname Name of rdata attributes.
  !! @param dset_id HDF5 data set identifier.
  !! @param dspace_id HDF5 data space identifier.
  !! @param aspace_id HDF5 data's attribute space identifier.
  !! @param attr_id HDF5 data's attribute identifier.
  !! @param atype_id Native HDF5 attribute type.
  !! @param dims Dimensions of data writen to HDF5 file.
  !! @param adims Dimensions of data's attributes written to HDF5 file.
  !! @param rank Number of dimensions of rdata's dataspace.
  !! @param arank Number of dimensions of attr's dataspace.
  !! @param tmplen Temporary length of rdata attribute's name.
  !! @param attrlen Lenght of rdata attribute's name.
  !! @param h5error HDF5 error status.
  !! @param rr Rank iterator.
  !! @param dd Dimension iterator.
  subroutine rsave_1d_array_to_hdf5(h5file_id,dset,rdata,attr)
    INTEGER(HID_T), INTENT(IN) 														:: h5file_id
    CHARACTER(MAX_STRING_LENGTH), INTENT(IN) 										:: dset
    REAL(rp), DIMENSION(:), INTENT(IN) 												:: rdata
    CHARACTER(MAX_STRING_LENGTH), OPTIONAL, DIMENSION(:), ALLOCATABLE, INTENT(IN) 	:: attr
    CHARACTER(4) 																	:: aname = "Info"
    INTEGER(HID_T) 																	:: dset_id
    INTEGER(HID_T) 																	:: dspace_id
    INTEGER(HID_T) 																	:: aspace_id
    INTEGER(HID_T) 																	:: attr_id
    INTEGER(HID_T) 																	:: atype_id
    INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE 									:: dims
    INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE 									:: adims
    INTEGER 																		:: rank
    INTEGER 																		:: arank
    INTEGER(SIZE_T) 																:: tmplen
    INTEGER(SIZE_T) 																:: attrlen
    INTEGER 																		:: h5error
    INTEGER 																		:: rr,dd

    rank = size(shape(rdata))
    ALLOCATE(dims(rank))
    dims = shape(rdata)

    ! * * * Write data to file * * *

    call h5screate_simple_f(rank,dims,dspace_id,h5error)
    call h5dcreate_f(h5file_id, TRIM(dset), KORC_HDF5_REAL, dspace_id, dset_id, h5error)

    if (rp .EQ. INT(rp_hdf5)) then
       call h5dwrite_f(dset_id, KORC_HDF5_REAL, rdata, dims, h5error)
    else
       call h5dwrite_f(dset_id, KORC_HDF5_REAL, REAL(rdata,4), dims, h5error)
    end if

    if (PRESENT(attr)) then
       arank = size(shape(attr))
       ALLOCATE(adims(arank))
       adims = shape(attr)

       ! * * * Write attribute of data to file * * *
       tmplen = 0
       attrlen = 0
       do rr=1_idef,arank
          do dd=1_idef,adims(rr)
             tmplen = LEN_TRIM(attr(dd))
             if ( tmplen .GT. attrlen) then
                attrlen = tmplen
             end if
          end do
       end do

       call h5screate_simple_f(arank,adims,aspace_id,h5error)
       call h5tcopy_f(H5T_NATIVE_CHARACTER, atype_id, h5error)
       call h5tset_size_f(atype_id, attrlen, h5error)
       call h5acreate_f(dset_id, aname, atype_id, aspace_id, attr_id, h5error)
       call h5awrite_f(attr_id, atype_id, attr, adims, h5error)

       call h5aclose_f(attr_id, h5error)
       call h5sclose_f(aspace_id, h5error)
       ! * * * Write attribute of data to file * * *

       DEALLOCATE(adims)
    end if

    call h5sclose_f(dspace_id, h5error)
    call h5dclose_f(dset_id, h5error)
    ! * * * Write data to file * * *

    DEALLOCATE(dims)
  end subroutine rsave_1d_array_to_hdf5

  !! @note Subroutine to write a 2-D array of real values to an HDF5 file.
  !!
  !! @param[in] h5file_id HDF5 file identifier.
  !! @param[in] dset String containing the name of the data.
  !! @param[in] rdata Data written to HDF5 file.
  !! @param[in] attr Attributes of data written to HDF5 file.
  !! @param aname Name of rdata attributes.
  !! @param dset_id HDF5 data set identifier.
  !! @param dspace_id HDF5 data space identifier.
  !! @param aspace_id HDF5 data's attribute space identifier.
  !! @param attr_id HDF5 data's attribute identifier.
  !! @param atype_id Native HDF5 attribute type.
  !! @param dims Dimensions of data writen to HDF5 file.
  !! @param adims Dimensions of data's attributes written to HDF5 file.
  !! @param rank Number of dimensions of rdata's dataspace.
  !! @param arank Number of dimensions of attr's dataspace.
  !! @param attrlen Lenght of rdata attribute's name.
  !! @param h5error HDF5 error status.
  !! @param rr Rank iterator.
  !! @param dd Dimension iterator.
  !! @todo Implement the writting of attributes to HDF5 file.
  subroutine rsave_2d_array_to_hdf5(h5file_id,dset,rdata,attr)
    INTEGER(HID_T), INTENT(IN) 														:: h5file_id
    CHARACTER(MAX_STRING_LENGTH), INTENT(IN) 										:: dset
    REAL(rp), DIMENSION(:,:), INTENT(IN) 											:: rdata
    CHARACTER(MAX_STRING_LENGTH), OPTIONAL, DIMENSION(:), ALLOCATABLE, INTENT(IN) 	:: attr
    CHARACTER(4) 																	:: aname = "Info"
    INTEGER(HID_T) 																	:: dset_id
    INTEGER(HID_T) 																	:: dspace_id
    INTEGER(HID_T) 																	:: aspace_id
    INTEGER(HID_T) 																	:: attr_id
    INTEGER(HID_T) 																	:: atype_id
    INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE 									:: dims
    INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE 									:: adims
    INTEGER 																		:: rank
    INTEGER 																		:: arank
    INTEGER(SIZE_T) 																:: attrlen
    INTEGER 																		:: h5error
    INTEGER 																		:: rr,dd

    rank = size(shape(rdata))
    ALLOCATE(dims(rank))
    dims = shape(rdata)

    ! * * * Write data to file * * *

    call h5screate_simple_f(rank,dims,dspace_id,h5error)
    call h5dcreate_f(h5file_id, TRIM(dset), KORC_HDF5_REAL, dspace_id, dset_id, h5error)

    if (rp .EQ. INT(rp_hdf5)) then
       call h5dwrite_f(dset_id, KORC_HDF5_REAL, rdata, dims, h5error)
    else
       call h5dwrite_f(dset_id, KORC_HDF5_REAL, REAL(rdata,4), dims, h5error)
    end if

    if (PRESENT(attr)) then
       ! * * * Write attribute of data to file * * *
    end if

    call h5sclose_f(dspace_id, h5error)
    call h5dclose_f(dset_id, h5error)
    ! * * * Write data to file * * *

    DEALLOCATE(dims)
  end subroutine rsave_2d_array_to_hdf5

  !! @note Subroutine to write a 3-D array of real values to an HDF5 file.
  !!
  !! @param[in] h5file_id HDF5 file identifier.
  !! @param[in] dset String containing the name of the data.
  !! @param[in] rdata Data written to HDF5 file.
  !! @param[in] attr Attributes of data written to HDF5 file.
  !! @param aname Name of rdata attributes.
  !! @param dset_id HDF5 data set identifier.
  !! @param dspace_id HDF5 data space identifier.
  !! @param aspace_id HDF5 data's attribute space identifier.
  !! @param attr_id HDF5 data's attribute identifier.
  !! @param atype_id Native HDF5 attribute type.
  !! @param dims Dimensions of data writen to HDF5 file.
  !! @param adims Dimensions of data's attributes written to HDF5 file.
  !! @param rank Number of dimensions of rdata's dataspace.
  !! @param arank Number of dimensions of attr's dataspace.
  !! @param attrlen Lenght of rdata attribute's name.
  !! @param h5error HDF5 error status.
  !! @param rr Rank iterator.
  !! @param dd Dimension iterator.
  !! @todo Implement the writting of attributes to HDF5 file.
  subroutine rsave_3d_array_to_hdf5(h5file_id,dset,rdata,attr)
    INTEGER(HID_T), INTENT(IN) 														:: h5file_id
    CHARACTER(MAX_STRING_LENGTH), INTENT(IN) 										:: dset
    REAL(rp), DIMENSION(:,:,:), INTENT(IN) 											:: rdata
    CHARACTER(MAX_STRING_LENGTH), OPTIONAL, DIMENSION(:), ALLOCATABLE, INTENT(IN) 	:: attr
    CHARACTER(4) 																	:: aname = "Info"
    INTEGER(HID_T) 																	:: dset_id
    INTEGER(HID_T) 																	:: dspace_id
    INTEGER(HID_T) 																	:: aspace_id
    INTEGER(HID_T) 																	:: attr_id
    INTEGER(HID_T) 																	:: atype_id
    INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE 									:: dims
    INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE 									:: adims
    INTEGER 																		:: rank
    INTEGER 																		:: arank
    INTEGER(SIZE_T) 																:: attrlen
    INTEGER 																		:: h5error
    INTEGER 																		:: rr,dd

    rank = size(shape(rdata))
    ALLOCATE(dims(rank))
    dims = shape(rdata)

    ! * * * Write data to file * * *

    call h5screate_simple_f(rank,dims,dspace_id,h5error)
    call h5dcreate_f(h5file_id, TRIM(dset), KORC_HDF5_REAL, dspace_id, dset_id, h5error)

    if (rp .EQ. INT(rp_hdf5)) then
       call h5dwrite_f(dset_id, KORC_HDF5_REAL, rdata, dims, h5error)
    else
       call h5dwrite_f(dset_id, KORC_HDF5_REAL, REAL(rdata,4), dims, h5error)
    end if

    if (PRESENT(attr)) then
       ! * * * Write attribute of data to file * * *
    end if

    call h5sclose_f(dspace_id, h5error)
    call h5dclose_f(dset_id, h5error)
    ! * * * Write data to file * * *

    DEALLOCATE(dims)
  end subroutine rsave_3d_array_to_hdf5

  !! @note Subroutine to write an array of strings to an HDF5 file.
  !!
  !! @param[in] h5file_id HDF5 file identifier.
  !! @param[in] dset String containing the name of the array of strings.
  !! @param[in] string_array Array of characters containing the strings to be written to HDF5 file.
  !! @param dset_id HDF5 data set identifier.
  !! @param dspace_id HDF5 data space identifier.
  !! @param dims Number of strings to be written to file.
  !! @param data_dims Dimensions of data written to HDF5 file. This is equal to (Maximum length of KORC string)x(Number of strings).
  !! @param str_len Size of strings to be written to file without blank spaces.
  !! @param string_type Native HDF5 string type.
  !! @param h5error HDF5 error status.
  subroutine save_string_parameter(h5file_id,dset,string_array)
    INTEGER(HID_T), INTENT(IN) 								:: h5file_id
    CHARACTER(MAX_STRING_LENGTH), INTENT(IN) 				:: dset
    CHARACTER(MAX_STRING_LENGTH), DIMENSION(:), INTENT(IN) 	:: string_array
    INTEGER(HID_T) 											:: dset_id
    INTEGER(HID_T) 											:: dspace_id
    INTEGER(HSIZE_T), DIMENSION(1) 							:: dims
    INTEGER(HSIZE_T), DIMENSION(2) 							:: data_dims
    INTEGER(SIZE_T), DIMENSION(:), ALLOCATABLE 				:: str_len
    INTEGER(HID_T) 											:: string_type
    INTEGER 												:: h5error

    ALLOCATE(str_len(SIZE(string_array)))

    dims = (/SIZE(string_array)/)
    data_dims = (/MAX_STRING_LENGTH,SIZE(string_array)/)
    str_len = (/LEN_TRIM(string_array)/)

    call h5tcopy_f(H5T_STRING,string_type,h5error)
    call h5tset_strpad_f(string_type,H5T_STR_SPACEPAD_F,h5error)

    call h5screate_simple_f(1,dims,dspace_id,h5error)

    call h5dcreate_f(h5file_id,TRIM(dset),string_type,dspace_id,dset_id,h5error)

    call h5dwrite_vl_f(dset_id,string_type,string_array,data_dims,str_len,h5error,dspace_id)

    call h5sclose_f(dspace_id, h5error)
    call h5dclose_f(dset_id, h5error)

    DEALLOCATE(str_len)
  end subroutine save_string_parameter


  subroutine save_simulation_parameters(params,spp,F,P)
    !! @note Subroutine to save to a HDF5 file all the relevant simulation
    !! parameters. @endnote
    !! This subroutine saves to the HDF5 file "<a>simulation_parameters.h5</a>"
    !! all the relevant simulation parameters of KORC, most of them being part
    !! of the input file, but also including some derived quantities from the
    !! input parameters. This file is intended to facilitate the
    !! post-processing of KORC data using any software that supports
    !! the HDF5 software.
    TYPE(KORC_PARAMS), INTENT(IN) 				:: params
    !!Core KORC simulation parameters.
    TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(IN) 	:: spp
    !! An instance of KORC's derived type SPECIES containing all
    !! the information of different electron species. See [[korc_types]].
    TYPE(FIELDS), INTENT(IN) 					:: F
    !! An instance of KORC's derived type FIELDS containing all the information
    !! about the fields used in the simulation. See [[korc_types]]
    !! and [[korc_fields]].
    TYPE(PROFILES), INTENT(IN) 					:: P
    !! An instance of KORC's derived type PROFILES containing all the
    !! information about the plasma profiles used in the simulation.
    !! See [[korc_types]] and [[korc_profiles]].
    CHARACTER(MAX_STRING_LENGTH) 				:: filename
    !! String containing the name of the HDF5 file.
    CHARACTER(MAX_STRING_LENGTH) 				:: gname
    !! String containing the group name of a set of KORC parameters.
    CHARACTER(MAX_STRING_LENGTH) 				:: dset
    !! Name of data set to be saved to file.
    INTEGER(HID_T) 						:: h5file_id
    !!  HDF5 file identifier.
    INTEGER(HID_T) 						:: group_id
    !! HDF5 group identifier.
    INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE 		:: dims
    !! Dimensions of data saved to HDF5 file.
    REAL(rp), DIMENSION(:), ALLOCATABLE 			:: rdata
    !! 1-D array of real data to be saved to HDF5 file.
    INTEGER, DIMENSION(:), ALLOCATABLE 				:: idata
    !! 1-D array of integer data to be saved to HDF5 file.
    CHARACTER(MAX_STRING_LENGTH), DIMENSION(:), ALLOCATABLE :: attr_array
    !! An 1-D array with attributes of 1-D real or integer arrays that are
    !! passed to KORC interfaces of HDF5 I/O subroutines.
    CHARACTER(MAX_STRING_LENGTH) 				:: attr
    !!  A single attributes of real or integer data that is passed to KORC
    !! interfaces of HDF5 I/O subroutines.
    INTEGER 							:: h5error
    !! HDF5 error status.
    CHARACTER(19) 						:: tmp_str
    !! Temporary string used to manipulate various strings.
    REAL(rp) 							:: units
    !! Temporary variable used to add physical units to KORC parameters.

    ! * * * Error handling * * * !
    call h5eset_auto_f(params%HDF5_error_handling, h5error)
    ! Turn off: 0_idef. Turn on: 1_idef

    if (.NOT.(params%restart)) then

    if (params%mpi_params%rank .EQ. 0) then
       write(6,'("Saving simulations parameters")')
    end if

       
       if (SIZE(params%outputs_list).GT.1_idef) then
          write(tmp_str,'(I18)') params%mpi_params%rank
          filename = TRIM(params%path_to_outputs) // "file_"  &
               // TRIM(ADJUSTL(tmp_str)) // ".h5"
          call h5fcreate_f(TRIM(filename), H5F_ACC_TRUNC_F, h5file_id, h5error)
          call h5fclose_f(h5file_id, h5error)
       end if

       if (params%mpi_params%rank .EQ. 0) then
          filename = TRIM(params%path_to_outputs) // "simulation_parameters.h5"

          call h5fcreate_f(TRIM(filename), H5F_ACC_TRUNC_F, h5file_id, h5error)

          ! Simulation parameters group
          gname = "simulation"
          call h5gcreate_f(h5file_id, TRIM(gname), group_id, h5error)

          ALLOCATE(attr_array(1))
          ALLOCATE(idata(1))

          dset = TRIM(gname) // "/plasma_model"
          call save_string_parameter(h5file_id,dset,(/params%plasma_model/))

          dset = TRIM(gname) // "/simulation_time"
          attr = "Total aimed simulation time in seconds"
          call save_to_hdf5(h5file_id,dset,params%simulation_time* &
               params%cpp%time,attr)

          dset = TRIM(gname) // "/snapshot_frequency"
          attr = "Time between snapshots in seconds"
          call save_to_hdf5(h5file_id,dset,params%snapshot_frequency* &
               params%cpp%time,attr)

          dset = TRIM(gname) // "/dt"
          attr = "Time step in secs"
          call save_to_hdf5(h5file_id,dset,params%dt*params%cpp%time,attr)

          dset = TRIM(gname) // "/t_steps"
          attr_array(1) = "Number of time steps"
          idata = params%t_steps
          call save_1d_array_to_hdf5(h5file_id,dset,idata,attr_array)

          dset = TRIM(gname) // "/num_omp_threads"
          attr = "Number of omp threads"
          call save_to_hdf5(h5file_id,dset, params%num_omp_threads,attr)

          dset = TRIM(gname) // "/output_cadence"
          attr_array(1) = "Cadence of output files"
          idata = params%output_cadence
          call save_1d_array_to_hdf5(h5file_id,dset,idata,attr_array)

          dset = TRIM(gname) // "/HDF5_error_handling"
          attr_array(1) = "Error handling option: 0=OFF, 1=ON"
          idata = params%HDF5_error_handling
          call save_1d_array_to_hdf5(h5file_id,dset,idata,attr_array)

          dset = TRIM(gname) // "/restart_output_cadence"
          attr_array(1) = "Cadence of output files"
          idata = params%restart_output_cadence
          call save_1d_array_to_hdf5(h5file_id,dset,idata,attr_array)

          dset = TRIM(gname) // "/num_snapshots"
          attr_array(1) = "Number of outputs for each variable"
          idata = params%num_snapshots
          call save_1d_array_to_hdf5(h5file_id,dset,idata,attr_array)

          dset = TRIM(gname) // "/num_species"
          attr = "Number of particle species"
          call save_to_hdf5(h5file_id,dset,params%num_species,attr)

          dset = TRIM(gname) // "/nmpi"
          attr = "Number of mpi processes"
          call save_to_hdf5(h5file_id,dset,params%mpi_params%nmpi,attr)

          dset = TRIM(gname) // "/minimum_particle_energy"
          attr = "Minimum energy of simulated particles in eV"
          call save_to_hdf5(h5file_id,dset,params%minimum_particle_energy* &
               params%cpp%energy/C_E,attr)

          dset = TRIM(gname) // "/minimum_particle_g"
          attr = "Minimum relativistic factor gamma of simulated particles"
          call save_to_hdf5(h5file_id,dset,params%minimum_particle_g,attr)

          dset = TRIM(gname) // "/radiation"
          attr = "Radiation losses included in simulation"
          if(params%radiation) then
             call save_to_hdf5(h5file_id,dset,1_idef,attr)
          else
             call save_to_hdf5(h5file_id,dset,0_idef,attr)
          end if

          dset = TRIM(gname) // "/collisions"
          attr = "Collisions included in simulation"
          if(params%collisions) then
             call save_to_hdf5(h5file_id,dset,1_idef,attr)
          else
             call save_to_hdf5(h5file_id,dset,0_idef,attr)
          end if

          dset = TRIM(gname) // "/outputs_list"
          call save_string_parameter(h5file_id,dset,params%outputs_list)

          dset = TRIM(gname) // "/orbit_model"
          call save_string_parameter(h5file_id,dset,(/params%orbit_model/))

          dset = TRIM(gname) // "/field_eval"
          call save_string_parameter(h5file_id,dset,(/params%field_eval/))

          DEALLOCATE(idata)
          DEALLOCATE(attr_array)

          call h5gclose_f(group_id, h5error)


          ! Plasma species group
          gname = "species"
          call h5gcreate_f(h5file_id, TRIM(gname), group_id, h5error)

          ALLOCATE(attr_array(params%num_species))

          dset = TRIM(gname) // "/spatial_distribution"
          call save_string_parameter(h5file_id,dset,spp%spatial_distribution)

          dset = TRIM(gname) // "/energy_distribution"
          call save_string_parameter(h5file_id,dset,spp%energy_distribution)

          dset = TRIM(gname) // "/pitch_distribution"
          call save_string_parameter(h5file_id,dset,spp%pitch_distribution)

          dset = TRIM(gname) // "/ppp"
          attr_array(1) = "Particles per (mpi) process"
          call save_1d_array_to_hdf5(h5file_id,dset,spp%ppp,attr_array)

          dset = TRIM(gname) // "/q"
          attr_array(1) = "Electric charge"
          call save_1d_array_to_hdf5(h5file_id,dset,spp%q* &
               params%cpp%charge,attr_array)

          dset = TRIM(gname) // "/m"
          attr_array(1) = "Species mass in kg"
          call save_1d_array_to_hdf5(h5file_id,dset,spp%m* &
               params%cpp%mass,attr_array)

          dset = TRIM(gname) // "/Eo"
          attr_array(1) = "Initial (average) energy in eV"
          call save_1d_array_to_hdf5(h5file_id,dset,spp%Eo* &
               params%cpp%energy/C_E,attr_array)

          dset = TRIM(gname) // "/go"
          attr_array(1) = "Initial relativistic g factor."
          call save_1d_array_to_hdf5(h5file_id,dset,spp%go,attr_array)

          dset = TRIM(gname) // "/etao"
          attr_array(1) = "Initial pitch angle in degrees"
          call save_1d_array_to_hdf5(h5file_id,dset,spp%etao,attr_array)

          dset = TRIM(gname) // "/wc"
          attr_array(1) = "Average relativistic cyclotron frequency in Hz"
          call save_1d_array_to_hdf5(h5file_id,dset,spp%wc_r/ &
               params%cpp%time,attr_array)

          dset = TRIM(gname) // "/Ro"
          attr_array(1) = "Initial radial position of population"
          call save_1d_array_to_hdf5(h5file_id,dset,spp%Ro* &
               params%cpp%length,attr_array)

          dset = TRIM(gname) // "/PHIo"
          attr_array(1) = "Azimuthal angle in degrees."
          call save_1d_array_to_hdf5(h5file_id,dset,spp%PHIo* &
               180.0_rp/C_PI,attr_array)

          dset = TRIM(gname) // "/Zo"
          attr_array(1) = "Initial Z position of population"
          call save_1d_array_to_hdf5(h5file_id,dset,spp%Zo* &
               params%cpp%length,attr_array)

          dset = TRIM(gname) // "/ri"
          attr_array(1) = "Inner radius of initial spatial distribution"
          call save_1d_array_to_hdf5(h5file_id,dset,spp%r_inner* &
               params%cpp%length,attr_array)

          dset = TRIM(gname) // "/ro"
          attr_array(1) = "Outter radius of initial spatial distribution"
          call save_1d_array_to_hdf5(h5file_id,dset,spp%r_outter* &
               params%cpp%length,attr_array)

          dset = TRIM(gname) // "/falloff_rate"
          attr_array(1) = "Falloff of gaussian or exponential radial &
               profile in m"
          call save_1d_array_to_hdf5(h5file_id,dset,spp%falloff_rate/ &
               params%cpp%length,attr_array)

          dset = TRIM(gname) // "/shear_factor"
          attr_array(1) = "Shear factor (in case ELLIPTIC-TORUS  &
               spatial distribution is used."
          call save_1d_array_to_hdf5(h5file_id,dset,spp%shear_factor, &
               attr_array)

          dset = TRIM(gname) // "/sigmaR"
          attr_array(1) = "Variance of first dimension of 2D spatial & 
               distribution."
          call save_1d_array_to_hdf5(h5file_id,dset,spp%sigmaR,attr_array)

          dset = TRIM(gname) // "/sigmaZ"
          attr_array(1) = "Variance of second dimension of 2D spatial &
               distribution."
          call save_1d_array_to_hdf5(h5file_id,dset,spp%sigmaZ,attr_array)

          dset = TRIM(gname) // "/theta_gauss"
          attr_array(1) = "Angle of rotation of 2D spatial distribution."
          call save_1d_array_to_hdf5(h5file_id,dset,spp%theta_gauss,attr_array)

          dset = TRIM(gname) // "/psi_max"
          attr_array(1) = "Indicator function level of the argument of &
               the 2D gaussian exponential."
          call save_1d_array_to_hdf5(h5file_id,dset,spp%psi_max,attr_array)



          call h5gclose_f(group_id, h5error)

          DEALLOCATE(attr_array)


          ! Plasma profiles group
!          if (params%collisions) then
             gname = "profiles"
             call h5gcreate_f(h5file_id, TRIM(gname), group_id, h5error)

             dset = TRIM(gname) // "/density_profile"
             call save_string_parameter(h5file_id,dset,(/P%ne_profile/))

             dset = TRIM(gname) // "/temperature_profile"
             call save_string_parameter(h5file_id,dset,(/P%Te_profile/))

             dset = TRIM(gname) // "/Zeff_profile"
             call save_string_parameter(h5file_id,dset,(/P%Zeff_profile/))

             dset = TRIM(gname) // "/neo"
             attr = "Density at the magnetic axis (m^-3)"
             call save_to_hdf5(h5file_id,dset,P%neo*params%cpp%density,attr)

             dset = TRIM(gname) // "/Teo"
             attr = "Temperature at the magnetic axis (eV)"
             call save_to_hdf5(h5file_id,dset,P%Teo* &
                  params%cpp%temperature/C_E,attr)

             dset = TRIM(gname) // "/Zeffo"
             attr = "Zeff at the magnetic axis"
             call save_to_hdf5(h5file_id,dset,P%Zeffo,attr)

             if (TRIM(params%plasma_model) .EQ. 'ANALYTICAL') then
                dset = TRIM(gname) // "/n_ne"
                attr = "Exponent of tanh(x)^n for density profile"
                call save_to_hdf5(h5file_id,dset,P%n_ne,attr)

                dset = TRIM(gname) // "/a_ne"
                attr = "Coefficients f=ao+a1*r+a2*r^2+a3*r^3.  &
                     a_ne=[a0,a1,a2,a3]"
                call save_1d_array_to_hdf5(h5file_id,dset,P%a_ne)

                dset = TRIM(gname) // "/n_Te"
                attr = "Exponent of tanh(x)^n for density profile"
                call save_to_hdf5(h5file_id,dset,P%n_Te,attr)

                dset = TRIM(gname) // "/a_Te"
                attr = "Coefficients f=ao+a1*r+a2*r^2+a3*r^3.  &
                     a_Te=[a0,a1,a2,a3]"
                call save_1d_array_to_hdf5(h5file_id,dset,P%a_Te)

                dset = TRIM(gname) // "/n_Zeff"
                attr = "Exponent of tanh(x)^n for Zeff profile"
                call save_to_hdf5(h5file_id,dset,P%n_Zeff,attr)

                dset = TRIM(gname) // "/a_Zeff"
                attr = "Coefficients f=ao+a1*r+a2*r^2+a3*r^3.  &
                     a_Zeff=[a0,a1,a2,a3]"
                call save_1d_array_to_hdf5(h5file_id,dset,P%a_Zeff)

                if  (params%field_eval.EQ.'interp') then

                   ALLOCATE(attr_array(1))
                   dset = TRIM(gname) // "/dims"
                   attr_array(1) = "Mesh dimension of the profile (NR,NPHI,NZ)"
                   call save_1d_array_to_hdf5(h5file_id,dset,F%dims,attr_array)

                   dset = TRIM(gname) // "/R"
                   attr_array(1) = "Radial position of the magnetic field grid nodes"
                   call save_1d_array_to_hdf5(h5file_id,dset, &
                        F%X%R*params%cpp%length,attr_array)

                   if (ALLOCATED(F%X%PHI)) then
                      dset = TRIM(gname) // "/PHI"
                      attr_array(1) = "Azimuthal angle of the magnetic &
                           field grid nodes"
                      call save_1d_array_to_hdf5(h5file_id,dset,F%X%PHI,attr_array)
                   end if

                   dset = TRIM(gname) // "/Z"
                   attr_array(1) = "Z position of the magnetic field grid nodes"
                   call save_1d_array_to_hdf5(h5file_id,dset,F%X%Z* &
                        params%cpp%length,attr_array)

                   dset = TRIM(gname) // "/ne"
                   units = params%cpp%density
                   call rsave_2d_array_to_hdf5(h5file_id, dset, &
                        units*P%ne_2D)

                   dset = TRIM(gname) // "/Te"
                   units = params%cpp%temperature
                   call rsave_2d_array_to_hdf5(h5file_id, dset, &
                        units*P%Te_2D)

                   dset = TRIM(gname) // "/Zeff"
                   call rsave_2d_array_to_hdf5(h5file_id, dset, &
                        P%Zeff_2D)

                   DEALLOCATE(attr_array)
                end if
                
             else if (params%plasma_model .EQ. 'EXTERNAL') then
                ALLOCATE(attr_array(1))
                dset = TRIM(gname) // "/dims"
                attr_array(1) = "Mesh dimension of the profiles (NR,NPHI,NZ)"
                call save_1d_array_to_hdf5(h5file_id,dset,P%dims,attr_array)

                dset = TRIM(gname) // "/R"
                attr_array(1) = "Grid nodes of profiles along the &
                     radial position"
                call save_1d_array_to_hdf5(h5file_id,dset,P%X%R* &
                     params%cpp%length,attr_array)

                if (ALLOCATED(F%X%PHI)) then
                   dset = TRIM(gname) // "/PHI"
                   attr_array(1) = "Grid nodes of profiles along the &
                        azimuthal position"
                   call save_1d_array_to_hdf5(h5file_id,dset, &
                        P%X%PHI,attr_array)
                end if

                dset = TRIM(gname) // "/Z"
                attr_array(1) = "Grid nodes of profiles along the Z position"
                call save_1d_array_to_hdf5(h5file_id,dset, &
                     P%X%Z*params%cpp%length,attr_array)

                dset = TRIM(gname) // "/ne"
                units = params%cpp%density
                call rsave_2d_array_to_hdf5(h5file_id, dset, &
                     units*P%ne_2D)

                dset = TRIM(gname) // "/Te"
                units = params%cpp%temperature
                call rsave_2d_array_to_hdf5(h5file_id, dset, &
                     units*P%Te_2D)

                dset = TRIM(gname) // "/Zeff"
                call rsave_2d_array_to_hdf5(h5file_id, dset, &
                     P%Zeff_2D)

                DEALLOCATE(attr_array)
             else if (params%plasma_model .EQ. 'UNIFORM') then
                ! Something
             end if

             call h5gclose_f(group_id, h5error)
          !end if


          ! Electromagnetic fields group

          gname = "fields"
          call h5gcreate_f(h5file_id, TRIM(gname), group_id, h5error)

          if (TRIM(params%plasma_model) .EQ. 'ANALYTICAL') then
             dset = TRIM(gname) // "/Bo"
             attr = "Toroidal field at the magnetic axis in T"
             call save_to_hdf5(h5file_id,dset,F%Bo*params%cpp%Bo,attr)

             dset = TRIM(gname) // "/current_direction"
             call save_string_parameter(h5file_id,dset, &
                  (/F%AB%current_direction/))

             dset = TRIM(gname) // "/a"
             attr = "Minor radius in m"
             call save_to_hdf5(h5file_id,dset,F%AB%a*params%cpp%length,attr)

             dset = TRIM(gname) // "/Ro"
             attr = "Major radius in m"
             call save_to_hdf5(h5file_id,dset,F%Ro*params%cpp%length,attr)

             dset = TRIM(gname) // "/qa"
             attr = "Safety factor at minor radius"
             call save_to_hdf5(h5file_id,dset,F%AB%qa,attr)

             dset = TRIM(gname) // "/qo"
             attr = "Safety factor at the magnetic axis"
             call save_to_hdf5(h5file_id,dset,F%AB%qo,attr)

             dset = TRIM(gname) // "/lambda"
             attr = "Parameter lamda in m"
             call save_to_hdf5(h5file_id,dset,F%AB%lambda* &
                  params%cpp%length,attr)

             dset = TRIM(gname) // "/Bpo"
             attr = "Poloidal magnetic field in T"
             call save_to_hdf5(h5file_id,dset,F%AB%Bpo*params%cpp%Bo,attr)

             dset = TRIM(gname) // "/Eo"
             attr = "Electric field at the magnetic axis in V/m"
             call save_to_hdf5(h5file_id,dset,F%Eo*params%cpp%Eo,attr)

             if  (params%field_eval.EQ.'interp') then

                ALLOCATE(attr_array(1))
                dset = TRIM(gname) // "/dims"
                attr_array(1) = "Mesh dimension of the magnetic  &
                     field (NR,NPHI,NZ)"
                call save_1d_array_to_hdf5(h5file_id,dset,F%dims,attr_array)

                dset = TRIM(gname) // "/R"
                attr_array(1) = "Radial position of the magnetic field grid nodes"
                call save_1d_array_to_hdf5(h5file_id,dset, &
                     F%X%R*params%cpp%length,attr_array)

                if (ALLOCATED(F%X%PHI)) then
                   dset = TRIM(gname) // "/PHI"
                   attr_array(1) = "Azimuthal angle of the magnetic &
                        field grid nodes"
                   call save_1d_array_to_hdf5(h5file_id,dset,F%X%PHI,attr_array)
                end if

                dset = TRIM(gname) // "/Z"
                attr_array(1) = "Z position of the magnetic field grid nodes"
                call save_1d_array_to_hdf5(h5file_id,dset,F%X%Z* &
                     params%cpp%length,attr_array)

                dset = TRIM(gname) // "/BR"
                units = params%cpp%Bo
                call rsave_2d_array_to_hdf5(h5file_id, dset, &
                     units*F%B_2D%R)

                dset = TRIM(gname) // "/BPHI"
                units = params%cpp%Bo
                call rsave_2d_array_to_hdf5(h5file_id, dset, &
                     units*F%B_2D%PHI)

                dset = TRIM(gname) // "/BZ"
                units = params%cpp%Bo
                call rsave_2d_array_to_hdf5(h5file_id, dset, &
                     units*F%B_2D%Z)

                if  (params%orbit_model(3:5).EQ.'pre') then

                   dset = TRIM(gname) // "/gradBR"
                   units = params%cpp%Bo/params%cpp%length
                   call rsave_2d_array_to_hdf5(h5file_id, dset, &
                        units*F%gradB_2D%R)

                   dset = TRIM(gname) // "/gradBPHI"
                   units = params%cpp%Bo/params%cpp%length
                   call rsave_2d_array_to_hdf5(h5file_id, dset, &
                        units*F%gradB_2D%PHI)

                   dset = TRIM(gname) // "/gradBZ"
                   units = params%cpp%Bo/params%cpp%length
                   call rsave_2d_array_to_hdf5(h5file_id, dset, &
                        units*F%gradB_2D%Z)

                   dset = TRIM(gname) // "/curlbR"
                   units = 1./params%cpp%length
                   call rsave_2d_array_to_hdf5(h5file_id, dset, &
                        units*F%curlb_2D%R)

                   dset = TRIM(gname) // "/curlbPHI"
                   units = 1./params%cpp%length
                   call rsave_2d_array_to_hdf5(h5file_id, dset, &
                        units*F%curlb_2D%PHI)

                   dset = TRIM(gname) // "/curlbZ"
                   units =1./params%cpp%length
                   call rsave_2d_array_to_hdf5(h5file_id, dset, &
                        units*F%curlb_2D%Z)

                end if

                DEALLOCATE(attr_array)
             end if

          else if (params%plasma_model .EQ. 'EXTERNAL') then
             ALLOCATE(attr_array(1))
             dset = TRIM(gname) // "/dims"
             attr_array(1) = "Mesh dimension of the magnetic  &
                  field (NR,NPHI,NZ)"
             call save_1d_array_to_hdf5(h5file_id,dset,F%dims,attr_array)

             dset = TRIM(gname) // "/R"
             attr_array(1) = "Radial position of the magnetic field grid nodes"
             call save_1d_array_to_hdf5(h5file_id,dset, &
                  F%X%R*params%cpp%length,attr_array)

             if (ALLOCATED(F%X%PHI)) then
                dset = TRIM(gname) // "/PHI"
                attr_array(1) = "Azimuthal angle of the magnetic &
                     field grid nodes"
                call save_1d_array_to_hdf5(h5file_id,dset,F%X%PHI,attr_array)
             end if

             dset = TRIM(gname) // "/Z"
             attr_array(1) = "Z position of the magnetic field grid nodes"
             call save_1d_array_to_hdf5(h5file_id,dset,F%X%Z* &
                  params%cpp%length,attr_array)

             dset = TRIM(gname) // "/Bo"
             attr = "Toroidal field at the magnetic axis in T"
             call save_to_hdf5(h5file_id,dset,F%Bo*params%cpp%Bo,attr)

             dset = TRIM(gname) // "/Eo"
             attr = "Electric field at the magnetic axis in V/m"
             call save_to_hdf5(h5file_id,dset,F%Eo*params%cpp%Eo,attr)

             dset = TRIM(gname) // "/Ro"
             attr = "Radial position of magnetic axis"
             call save_to_hdf5(h5file_id,dset,F%Ro*params%cpp%length,attr)

             dset = TRIM(gname) // "/Zo"
             attr = "Radial position of magnetic axis"
             call save_to_hdf5(h5file_id,dset,F%Zo*params%cpp%length,attr)

             if (ALLOCATED(F%PSIp)) then
                dset = TRIM(gname) // "/psi_p"
                units = params%cpp%Bo*params%cpp%length**2
                call rsave_2d_array_to_hdf5(h5file_id, dset, &
                     units*F%PSIp)
             end if

             if (ALLOCATED(F%FLAG2D)) then
                dset = TRIM(gname) // "/Flag"
                call rsave_2d_array_to_hdf5(h5file_id, dset, &
                     F%FLAG2D)
             end if
             
             if  (F%axisymmetric_fields) then

                dset = TRIM(gname) // "/BR"
                units = params%cpp%Bo
                call rsave_2d_array_to_hdf5(h5file_id, dset, &
                     units*F%B_2D%R)

                dset = TRIM(gname) // "/BPHI"
                units = params%cpp%Bo
                call rsave_2d_array_to_hdf5(h5file_id, dset, &
                     units*F%B_2D%PHI)

                dset = TRIM(gname) // "/BZ"
                units = params%cpp%Bo
                call rsave_2d_array_to_hdf5(h5file_id, dset, &
                     units*F%B_2D%Z)

                if  (params%orbit_model(3:5).EQ.'pre') then

                   dset = TRIM(gname) // "/gradBR"
                   units = params%cpp%Bo/params%cpp%length
                   call rsave_2d_array_to_hdf5(h5file_id, dset, &
                        units*F%gradB_2D%R)

                   dset = TRIM(gname) // "/gradBPHI"
                   units = params%cpp%Bo/params%cpp%length
                   call rsave_2d_array_to_hdf5(h5file_id, dset, &
                        units*F%gradB_2D%PHI)

                   dset = TRIM(gname) // "/gradBZ"
                   units = params%cpp%Bo/params%cpp%length
                   call rsave_2d_array_to_hdf5(h5file_id, dset, &
                        units*F%gradB_2D%Z)

                   dset = TRIM(gname) // "/curlbR"
                   units = 1./params%cpp%length
                   call rsave_2d_array_to_hdf5(h5file_id, dset, &
                        units*F%curlb_2D%R)

                   dset = TRIM(gname) // "/curlbPHI"
                   units = 1./params%cpp%length
                   call rsave_2d_array_to_hdf5(h5file_id, dset, &
                        units*F%curlb_2D%PHI)

                   dset = TRIM(gname) // "/curlbZ"
                   units = 1./params%cpp%length
                   call rsave_2d_array_to_hdf5(h5file_id, dset, &
                        units*F%curlb_2D%Z)

                end if
             end if

             DEALLOCATE(attr_array)
          else if (params%plasma_model .EQ. 'UNIFORM') then
             dset = TRIM(gname) // "/Bo"
             attr = "Magnetic field in T"
             call save_to_hdf5(h5file_id,dset,F%Bo*params%cpp%Bo,attr)

             dset = TRIM(gname) // "/Eo"
             attr = "Electric field in V/m"
             call save_to_hdf5(h5file_id,dset,F%Eo*params%cpp%Eo,attr)
          end if

          call h5gclose_f(group_id, h5error)


          ! Characteristic scales
          gname = "scales"
          call h5gcreate_f(h5file_id, TRIM(gname), group_id, h5error)

          dset = TRIM(gname) // "/t"
          attr = "Characteristic time in secs"
          call save_to_hdf5(h5file_id,dset,params%cpp%time,attr)

          dset = TRIM(gname) // "/m"
          attr = "Characteristic mass in kg"
          call save_to_hdf5(h5file_id,dset,params%cpp%mass,attr)

          dset = TRIM(gname) // "/q"
          attr = "Characteristic charge in Coulombs"
          call save_to_hdf5(h5file_id,dset,params%cpp%charge,attr)

          dset = TRIM(gname) // "/l"
          attr = "Characteristic length in m"
          call save_to_hdf5(h5file_id,dset,params%cpp%length,attr)

          dset = TRIM(gname) // "/v"
          attr = "Characteristic velocity in m"
          call save_to_hdf5(h5file_id,dset,params%cpp%velocity,attr)

          dset = TRIM(gname) // "/K"
          attr = "Characteristic kinetic energy in J"
          call save_to_hdf5(h5file_id,dset,params%cpp%energy,attr)

          dset = TRIM(gname) // "/n"
          attr = "Characteristic plasma density in m^-3"
          call save_to_hdf5(h5file_id,dset,params%cpp%density,attr)

          dset = TRIM(gname) // "/E"
          attr = "Characteristic electric field in V/m"
          call save_to_hdf5(h5file_id,dset,params%cpp%Eo,attr)

          dset = TRIM(gname) // "/B"
          attr = "Characteristic magnetic field in T"
          call save_to_hdf5(h5file_id,dset,params%cpp%Bo,attr)

          dset = TRIM(gname) // "/P"
          attr = "Characteristic pressure in Pa"
          call save_to_hdf5(h5file_id,dset,params%cpp%pressure,attr)

          dset = TRIM(gname) // "/T"
          attr = "Characteristic plasma temperature in J"
          call save_to_hdf5(h5file_id,dset,params%cpp%temperature,attr)

          call h5gclose_f(group_id, h5error)

          call h5fclose_f(h5file_id, h5error)
       end if

    end if
  end subroutine save_simulation_parameters


  subroutine save_simulation_outputs(params,spp)
    !! @note Subroutine that saves the electrons' variables specified in
    !! params::outputs_list to HDF5 files. @endnote
    TYPE(KORC_PARAMS), INTENT(IN) 				:: params
    !! Core KORC simulation parameters.
    TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(IN) 	:: spp
    !! An instance of KORC's derived type SPECIES containing all
    !! the information
    !! of different electron species. See [[korc_types]].
    CHARACTER(MAX_STRING_LENGTH) 				:: filename
    !! String containing the name of the HDF5 file.
    CHARACTER(MAX_STRING_LENGTH) 				:: gname
    !! String containing the group name of a set of KORC parameters.
    CHARACTER(MAX_STRING_LENGTH) 				:: subgname
    !! String containing the subgroup name of a set of KORC parameters.
    CHARACTER(MAX_STRING_LENGTH) 				:: dset
    !! Name of data set to be saved to file.
    INTEGER(HID_T) 						:: h5file_id
    !! HDF5 file identifier.
    INTEGER(HID_T) 						:: group_id
    !! HDF5 group identifier.
    INTEGER(HID_T) 						:: subgroup_id
    !! HDF5 subgroup identifier.
    INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE 		:: dims
    !! Dimensions of data saved to HDF5 file.
    REAL(rp), DIMENSION(:), ALLOCATABLE 			:: rdata
    !! 1-D array of real data to be saved to HDF5 file.
    INTEGER, DIMENSION(:), ALLOCATABLE 				:: idata
    !!1-D array of integer data to be saved to HDF5 file.
    CHARACTER(MAX_STRING_LENGTH), DIMENSION(:), ALLOCATABLE       :: attr_array
    !! An 1-D array with attributes of 1-D real or integer arrays that are
    !! passed to KORC interfaces of HDF5 I/O subroutines.
    CHARACTER(MAX_STRING_LENGTH) 				:: attr
    !! A single attributes of real or integer data that is passed to KORC
    !! interfaces of HDF5 I/O subroutines.
    INTEGER 							:: h5error
    !!HDF5 error status.
    CHARACTER(19) 						:: tmp_str
    !!Temporary string used to manipulate various strings.
    REAL(rp) 						:: units
    !! Temporary variable used to add physical units to electrons' variables.
    INTEGER 						:: ss
    !! Electron species iterator.
    INTEGER 						:: jj
    !! Iterator for reading all the entried of params::outputs_list.
    LOGICAL 						:: object_exists
    !! Flag determining if a certain dataset is already present in
    !! the HDF5 output files.
    REAL(rp), DIMENSION(:,:), ALLOCATABLE  ::YY
    !! Temporary variable get proper units on vars%Y(1,:) and vars%Y(3,:), which
    !! are lengths, while keeping vars%Y(2,:), which is an angle

    if (params%mpi_params%rank .EQ. 0) then
       write(6,'("Saving snapshot: ",I15)') params%it/params%t_skip
    end if

    if (SIZE(params%outputs_list).GT.1_idef) then
       write(tmp_str,'(I18)') params%mpi_params%rank
       filename = TRIM(params%path_to_outputs) // "file_" &
            // TRIM(ADJUSTL(tmp_str)) // ".h5"
       call h5fopen_f(TRIM(filename), H5F_ACC_RDWR_F, h5file_id, h5error)

       ! Create group 'it'
       write(tmp_str,'(I18)') params%it
       gname = TRIM(ADJUSTL(tmp_str))
       call h5lexists_f(h5file_id,TRIM(gname),object_exists,h5error)

       if (.NOT.object_exists) then ! Check if group does exist.
          call h5gcreate_f(h5file_id, TRIM(gname), group_id, h5error)

          dset = TRIM(gname) // "/time"
          attr = "Simulation time in secs"
          call save_to_hdf5(h5file_id,dset,params%init_time*params%cpp%time &
               + REAL(params%it,rp)*params%dt*params%cpp%time,attr)

          do ss=1_idef,params%num_species

             write(tmp_str,'(I18)') ss
             subgname = "spp_" // TRIM(ADJUSTL(tmp_str))
             call h5gcreate_f(group_id, TRIM(subgname), subgroup_id, h5error)

             do jj=1_idef,SIZE(params%outputs_list)
                SELECT CASE (TRIM(params%outputs_list(jj)))
                CASE ('X')
                   dset = "X"
                   units = params%cpp%length
                   call rsave_2d_array_to_hdf5(subgroup_id, dset, &
                        units*spp(ss)%vars%X)
                CASE ('Y')
                   dset = "Y"
                   units = params%cpp%length

                   YY=spp(ss)%vars%Y
                   YY(:,1)=units*YY(:,1)
                   YY(:,3)=units*YY(:,3)

                   call rsave_2d_array_to_hdf5(subgroup_id, dset, &
                        YY)

                   DEALLOCATE(YY)

                CASE('V')
                   dset = "V"
                   if (params%orbit_model.eq.'FO') then
                      units = params%cpp%velocity
                      call rsave_2d_array_to_hdf5(subgroup_id, dset, &
                           units*spp(ss)%vars%V)
                   else if (params%orbit_model(1:2).eq.'GC') then
                      YY=spp(ss)%vars%V

                      YY(:,1)=YY(:,1)*params%cpp%mass*params%cpp%velocity
                      YY(:,2)=YY(:,2)*params%cpp%mass* &
                           (params%cpp%velocity)**2/params%cpp%Bo

                      call rsave_2d_array_to_hdf5(subgroup_id, dset, &
                           YY)
                      DEALLOCATE(YY)

                   end if
                CASE('Rgc')
                   dset = "Rgc"
                   units = params%cpp%length
                   call rsave_2d_array_to_hdf5(subgroup_id, dset, &
                        units*spp(ss)%vars%Rgc)
                CASE('g')
                   dset = "g"
                   call save_1d_array_to_hdf5(subgroup_id, dset, &
                        spp(ss)%vars%g)
                CASE('eta')
                   dset = "eta"
                   call save_1d_array_to_hdf5(subgroup_id, dset, &
                        spp(ss)%vars%eta)
                CASE('mu')
                   dset = "mu"
                   units = params%cpp%mass*params%cpp%velocity**2/params%cpp%Bo
                   call save_1d_array_to_hdf5(subgroup_id, dset, &
                        units*spp(ss)%vars%mu)
                CASE('Prad')
                   dset = "Prad"
                   units = params%cpp%mass*(params%cpp%velocity**3)/ &
                        params%cpp%length
                   call save_1d_array_to_hdf5(subgroup_id, dset, &
                        units*spp(ss)%vars%Prad)
                CASE('Pin')
                   dset = "Pin"
                   units = params%cpp%mass*(params%cpp%velocity**3)/ &
                        params%cpp%length
                   call save_1d_array_to_hdf5(subgroup_id, dset, &
                        units*spp(ss)%vars%Pin)
                CASE('flag')
                   dset = "flag"
                   call save_1d_array_to_hdf5(subgroup_id,dset, &
                        INT(spp(ss)%vars%flag,idef))
                CASE('B')
                   dset = "B"
                   units = params%cpp%Bo
                   call rsave_2d_array_to_hdf5(subgroup_id, dset, &
                        units*spp(ss)%vars%B)
                CASE('gradB')
                   if (params%orbit_model(3:5).eq.'pre') then
                      dset = "gradB"
                      units = params%cpp%Bo/params%cpp%length
                      call rsave_2d_array_to_hdf5(subgroup_id, dset, &
                           units*spp(ss)%vars%gradB)
                   end if
                CASE('curlb')
                   if (params%orbit_model(3:5).eq.'pre') then
                      dset = "curlb"
                      units = 1./params%cpp%length
                      call rsave_2d_array_to_hdf5(subgroup_id, dset, &
                           units*spp(ss)%vars%curlb)
                   end if
                CASE('E')
                   dset = "E"
                   units = params%cpp%Eo
                   call rsave_2d_array_to_hdf5(subgroup_id, dset, &
                        units*spp(ss)%vars%E)
                CASE('AUX')
                   dset = "AUX"
                   call save_1d_array_to_hdf5(subgroup_id, dset, &
                        spp(ss)%vars%AUX)
                CASE ('ne')
                   dset = "ne"
                   units = params%cpp%density
                   call save_1d_array_to_hdf5(subgroup_id, dset, &
                        units*spp(ss)%vars%ne)
                CASE ('Te')
                   dset = "Te"
                   units = params%cpp%temperature
                   call save_1d_array_to_hdf5(subgroup_id, dset, &
                        units*spp(ss)%vars%Te/C_E)
                CASE ('Zeff')
                   dset = "Zeff"
                   call save_1d_array_to_hdf5(subgroup_id, dset, &
                        spp(ss)%vars%Zeff)
                CASE DEFAULT

                END SELECT
             end do

             call h5gclose_f(subgroup_id, h5error)
          end do

          call h5gclose_f(group_id, h5error)
       end if ! Check if group does exist.

       call h5fclose_f(h5file_id, h5error)
    end if
  end subroutine save_simulation_outputs



  subroutine save_restart_variables(params,spp)
    !! @note Subroutine that saves all the variables that KORC needs for
    !! restarting a simulation. These variables are saved to "restart_file.h5".
    TYPE(KORC_PARAMS), INTENT(IN) 				:: params
    !! params Core KORC simulation parameters.
    TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(IN) 	:: spp
    !! An instance of KORC's derived type SPECIES containing
    !! all the information of different electron species. See [[korc_types]].
    REAL(rp), DIMENSION(:), ALLOCATABLE :: send_buffer_rp, receive_buffer_rp
    !! Temporary buffer to be used by MPI to gather different electrons'
    !! variables.
    !! Temporary buffer to be used by MPI to gather different electrons'
    !! variables.
    INTEGER(is), DIMENSION(:), ALLOCATABLE :: send_buffer_is, receive_buffer_is
    !! Temporary buffer to be used by MPI to gather different electrons'
    !! variables.
    !! Temporary buffer to be used by MPI to gather different electrons'
    !! variables.
    REAL(rp), DIMENSION(:,:), ALLOCATABLE 			:: X
    REAL(rp), DIMENSION(:,:), ALLOCATABLE 			:: V
    REAL(rp), DIMENSION(:), ALLOCATABLE 			:: g
    INTEGER(is), DIMENSION(:), ALLOCATABLE 			:: flag
    CHARACTER(MAX_STRING_LENGTH) 				:: filename
    !! String containing the name of the HDF5 file.
    CHARACTER(MAX_STRING_LENGTH) 				:: gname
    !! String containing the group name of a set of KORC parameters.
    CHARACTER(MAX_STRING_LENGTH) 				:: subgname
    CHARACTER(MAX_STRING_LENGTH) 				:: dset
    !! Name of data set to be saved to file.
    INTEGER(HID_T) 						:: h5file_id
    !! HDF5 file identifier.
    INTEGER(HID_T) 						:: group_id
    !! HDF5 group identifier.
    INTEGER(HID_T) 						:: subgroup_id
    !! HDF5 subgroup identifier.
    INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE 		:: dims
    !!  Dimensions of data saved to HDF5 file.
    REAL(rp), DIMENSION(:), ALLOCATABLE 			:: rdata
    !! 1-D array of real data to be saved to HDF5 file.
    INTEGER, DIMENSION(:), ALLOCATABLE 				:: idata
    !! 1-D array of integer data to be saved to HDF5 file.
    CHARACTER(MAX_STRING_LENGTH), DIMENSION(:), ALLOCATABLE :: attr_array
    !! An 1-D array with attributes of 1-D real or integer arrays that
    !! are passed to KORC interfaces of HDF5 I/O subroutines.
    CHARACTER(MAX_STRING_LENGTH) 				:: attr
    !! A single attributes of real or integer data that is passed to KORC
    !! interfaces of HDF5 I/O subroutines.
    INTEGER 							:: h5error
    !! HDF5 error status.
    CHARACTER(19) 						:: tmp_str
    !! Temporary string used to manipulate various strings.
    REAL(rp) 							:: units
    !! Temporary variable used to add physical units to restart variables.
    INTEGER 							:: ss,jj
    !! Electron species iterator.
    !! Iterator for reading all the entried of params::outputs_list.
    INTEGER 							:: mpierr
    !! MPI error status.
    INTEGER 					:: numel_send, numel_receive
    !! Variable used by MPI to count the amount of data sent by each MPI
    !! procces.
    !! Variable used by MPI to count the amount of data received by the main
    !! MPI procces.


!    if ( MODULO(params%it,params%restart_output_cadence) .EQ. 0_ip ) then 
    if (params%mpi_params%rank.EQ.0_idef) then

       write(6,'("Saving restart: ",I15)') params%it/params%t_skip

       filename = TRIM(params%path_to_outputs) // "restart_file.h5"
       call h5fcreate_f(TRIM(filename), H5F_ACC_TRUNC_F, h5file_id, h5error)

       dset = "it"
       attr = "Iteration"
       call save_to_hdf5(h5file_id,dset,params%it,attr)

       dset = "time"
       attr = "Current simulation time in secs"
       call save_to_hdf5(h5file_id,dset,params%init_time*params%cpp%time &
            + REAL(params%it,rp)*params%dt*params%cpp%time,attr)

       dset = "simulation_time"
       attr = "Total simulation time in secs"
       call save_to_hdf5(h5file_id,dset,params%simulation_time* &
            params%cpp%time,attr)

       dset = "snapshot_frequency"
       attr = "Snapshot frequency in secs"
       call save_to_hdf5(h5file_id,dset,params%snapshot_frequency* &
            params%cpp%time,attr)

       dset = "dt"
       attr = "Time step in secs"
       call save_to_hdf5(h5file_id,dset,params%dt*params%cpp%time,attr)

       dset = "t_steps"
       attr = "Time steps in simulation"
       call save_to_hdf5(h5file_id,dset,params%t_steps,attr)

       dset = "output_cadence"
       attr = "Output cadence"
       call save_to_hdf5(h5file_id,dset,params%output_cadence,attr)

       dset = "restart_output_cadence"
       attr = "Restart output cadence"
       call save_to_hdf5(h5file_id,dset,params%restart_output_cadence,attr)

       dset = "num_snapshots"
       attr = "Number of snapshots in time for saving simulation variables"
       call save_to_hdf5(h5file_id,dset,params%num_snapshots,attr)
    end if

    do ss=1_idef,params%num_species
       numel_send = 3_idef*spp(ss)%ppp
       numel_receive = 3_idef*spp(ss)%ppp*params%mpi_params%nmpi

       if (params%mpi_params%rank.EQ.0_idef) then
          ALLOCATE(X(spp(ss)%ppp*params%mpi_params%nmpi,3))
          ALLOCATE(V(spp(ss)%ppp*params%mpi_params%nmpi,3))
          ALLOCATE(g(spp(ss)%ppp*params%mpi_params%nmpi))
          ALLOCATE(flag(spp(ss)%ppp*params%mpi_params%nmpi))
       end if

       ALLOCATE(send_buffer_rp(numel_send))
       ALLOCATE(receive_buffer_rp(numel_receive))

       if (params%orbit_model.EQ.'FO') then             
          send_buffer_rp = RESHAPE(spp(ss)%vars%X,(/numel_send/))
       else if (params%orbit_model(1:2).EQ.'GC') then
          send_buffer_rp = RESHAPE(spp(ss)%vars%Y,(/numel_send/))
       end if
       receive_buffer_rp = 0.0_rp
       CALL MPI_GATHER(send_buffer_rp,numel_send,MPI_REAL8, &
            receive_buffer_rp,numel_send,MPI_REAL8,0,MPI_COMM_WORLD, &
            mpierr)
       if (params%mpi_params%rank.EQ.0_idef) then
          X = RESHAPE(receive_buffer_rp,(/spp(ss)%ppp* &
               params%mpi_params%nmpi,3/))
       end if

       send_buffer_rp = RESHAPE(spp(ss)%vars%V,(/numel_send/))
       receive_buffer_rp = 0.0_rp
       CALL MPI_GATHER(send_buffer_rp,numel_send,MPI_REAL8, &
            receive_buffer_rp,numel_send,MPI_REAL8,0,MPI_COMM_WORLD,mpierr)
       if (params%mpi_params%rank.EQ.0_idef) then
          V = RESHAPE(receive_buffer_rp,(/spp(ss)%ppp* &
               params%mpi_params%nmpi,3/))
       end if

       DEALLOCATE(send_buffer_rp)
       DEALLOCATE(receive_buffer_rp)

       numel_send = spp(ss)%ppp
       numel_receive = spp(ss)%ppp*params%mpi_params%nmpi

       ALLOCATE(send_buffer_is(numel_send))
       ALLOCATE(receive_buffer_is(numel_receive))

       send_buffer_is = spp(ss)%vars%flag
       receive_buffer_is = 0_is
       CALL MPI_GATHER(send_buffer_is,numel_send,MPI_INTEGER1, &
            receive_buffer_is,numel_send,&
            MPI_INTEGER1,0,MPI_COMM_WORLD,mpierr)
       if (params%mpi_params%rank.EQ.0_idef) then
          flag = receive_buffer_is
       end if

       DEALLOCATE(send_buffer_is)
       DEALLOCATE(receive_buffer_is)

       ALLOCATE(send_buffer_rp(numel_send))
       ALLOCATE(receive_buffer_rp(numel_receive))

       send_buffer_rp = spp(ss)%vars%g
       receive_buffer_rp = 0_rp
       CALL MPI_GATHER(send_buffer_rp,numel_send,MPI_REAL8, &
            receive_buffer_rp,numel_send,&
            MPI_REAL8,0,MPI_COMM_WORLD,mpierr)
       if (params%mpi_params%rank.EQ.0_idef) then
          g = receive_buffer_rp
       end if

       DEALLOCATE(send_buffer_rp)
       DEALLOCATE(receive_buffer_rp)

       if (params%mpi_params%rank.EQ.0_idef) then
          write(tmp_str,'(I18)') ss
          subgname = "spp_" // TRIM(ADJUSTL(tmp_str))
          call h5gcreate_f(h5file_id, TRIM(subgname), group_id, h5error)

          dset = "X"
          call rsave_2d_array_to_hdf5(group_id, dset, X)

          dset = "V"
          call rsave_2d_array_to_hdf5(group_id, dset, V)

          dset = "flag"
          call save_1d_array_to_hdf5(group_id,dset, INT(flag,idef))

          dset = "g"
          call save_1d_array_to_hdf5(group_id,dset, g)

          call h5gclose_f(group_id, h5error)
       end if

       if (params%mpi_params%rank.EQ.0_idef) then
          DEALLOCATE(X)
          DEALLOCATE(V)
          DEALLOCATE(g)
          DEALLOCATE(flag)
       end if
    end do

    if (params%mpi_params%rank.EQ.0_idef) then
       call h5fclose_f(h5file_id, h5error)
    end if

!    end if
  end subroutine save_restart_variables

  ! * * * * * * * * * * * * * * * * * * * * * * * * * !
  ! * * * SUBROUTINES FOR RESTARTING SIMULATION * * * !
  ! * * * * * * * * * * * * * * * * * * * * * * * * * !

  subroutine load_time_stepping_params(params)
    !! @note Subroutine that loads KORC parameters that control the time
    !! stepping in [[main]].    
    TYPE(KORC_PARAMS), INTENT(INOUT) 	:: params
    !! Core KORC simulation parameters.
    CHARACTER(MAX_STRING_LENGTH) 		:: filename
    !! String containing the name of the HDF5 file.
    CHARACTER(MAX_STRING_LENGTH) 		:: dset
    !! Name of data set to be read from file.
    INTEGER(HID_T) 						:: h5file_id
    !! HDF5 file identifier.
    REAL(KIND=8) 						:: real_number
    !! A temporary real number.
    CHARACTER(19) 						:: tmp_str
    !! Temporary string used to manipulate various strings.
    INTEGER 							:: h5error
    !! HDF5 error status.
    INTEGER 							:: mpierr
    !!  MPI error status.
    INTEGER 							:: ss
    !! Electron species iterator.

    if (params%mpi_params%rank.EQ.0_idef) then
       filename = TRIM(params%path_to_outputs) // "restart_file.h5"
       call h5fopen_f(filename, H5F_ACC_RDONLY_F, h5file_id, h5error)
       if (h5error .EQ. -1) then
          write(6,'("KORC ERROR: Something went wrong in: &
               &load_particles_ic --> h5fopen_f")')
       end if

       dset = "/it"
       call load_from_hdf5(h5file_id,dset,real_number)
       params%ito = INT(real_number,ip) + 1_ip

       dset = "/dt"
       call load_from_hdf5(h5file_id,dset,params%dt)

       dset = "/t_steps"
       call load_from_hdf5(h5file_id,dset,real_number)
       params%t_steps = INT(real_number,ip)

       dset = "/simulation_time"
       call load_from_hdf5(h5file_id,dset,params%simulation_time)

       dset = "/snapshot_frequency"
       call load_from_hdf5(h5file_id,dset,params%snapshot_frequency)

       dset = "/output_cadence"
       call load_from_hdf5(h5file_id,dset,real_number)
       params%output_cadence = INT(real_number,ip)

       dset = "/restart_output_cadence"
       call load_from_hdf5(h5file_id,dset,real_number)
       params%restart_output_cadence = INT(real_number,ip)

       dset = "/num_snapshots"
       call load_from_hdf5(h5file_id,dset,real_number)
       params%num_snapshots = INT(real_number,ip)       

       call h5fclose_f(h5file_id, h5error)
    end if

    CALL MPI_BCAST(params%ito,1,MPI_INTEGER8,0,MPI_COMM_WORLD,mpierr)

    CALL MPI_BCAST(params%dt,1,MPI_REAL8,0,MPI_COMM_WORLD,mpierr)

    CALL MPI_BCAST(params%t_steps,1,MPI_INTEGER8,0,MPI_COMM_WORLD,mpierr)

    CALL MPI_BCAST(params%simulation_time,1,MPI_REAL8,0,MPI_COMM_WORLD,mpierr)

    CALL MPI_BCAST(params%snapshot_frequency,1,MPI_REAL8,0,MPI_COMM_WORLD, &
         mpierr)

    CALL MPI_BCAST(params%output_cadence,1,MPI_INTEGER8,0,MPI_COMM_WORLD,mpierr)

    CALL MPI_BCAST(params%restart_output_cadence,1,MPI_INTEGER8,0, &
         MPI_COMM_WORLD,mpierr)

    CALL MPI_BCAST(params%num_snapshots,1,MPI_INTEGER8,0,MPI_COMM_WORLD,mpierr)
  end subroutine load_time_stepping_params

  subroutine load_prev_time(params)
    !! @note Subroutine that loads KORC parameters that control the time
    !! stepping in [[main]].    
    TYPE(KORC_PARAMS), INTENT(INOUT) 	:: params
    !! Core KORC simulation parameters.
    CHARACTER(MAX_STRING_LENGTH) 		:: filename
    !! String containing the name of the HDF5 file.
    CHARACTER(MAX_STRING_LENGTH) 		:: dset
    !! Name of data set to be read from file.
    INTEGER(HID_T) 						:: h5file_id
    !! HDF5 file identifier.
    REAL(KIND=8) 						:: real_number
    !! A temporary real number.
    CHARACTER(19) 						:: tmp_str
    !! Temporary string used to manipulate various strings.
    INTEGER 							:: h5error
    !! HDF5 error status.
    INTEGER 							:: mpierr
    !!  MPI error status.
    INTEGER 							:: ss
    !! Electron species iterator.

    if (params%mpi_params%rank.EQ.0_idef) then
       filename = TRIM(params%path_to_outputs) // "restart_file.h5"
       call h5fopen_f(filename, H5F_ACC_RDONLY_F, h5file_id, h5error)
       if (h5error .EQ. -1) then
          write(6,'("KORC ERROR: Something went wrong in: &
               &load_particles_ic --> h5fopen_f")')
       end if

       dset = "/time"
       call load_from_hdf5(h5file_id,dset,params%init_time)      

       call h5fclose_f(h5file_id, h5error)
    end if

    CALL MPI_BCAST(params%init_time,1,MPI_REAL8,0,MPI_COMM_WORLD,mpierr)

  end subroutine load_prev_time


  subroutine load_particles_ic(params,spp)
    !! @note Subroutine that loads all the electrons' data from
    !! "restart_file.h5" to restart a simulation.
    TYPE(KORC_PARAMS), INTENT(INOUT) 			:: params
    !! Core KORC simulation parameters.
    TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(INOUT) :: spp
    !! An instance of KORC's derived type SPECIES containing all the
    !! information of different electron species. See korc_types.f90.
    REAL(rp), DIMENSION(:), ALLOCATABLE 		:: X_send_buffer
    !! Temporary buffer used by MPI for scattering the electrons' position
    !! to different MPI processes.
    REAL(rp), DIMENSION(:), ALLOCATABLE 		:: X_receive_buffer
    !! Temporary buffer used by MPI for scattering the electrons' position
    !! among MPI processes.
    REAL(rp), DIMENSION(:), ALLOCATABLE 		:: V_send_buffer
    !! Temporary buffer used by MPI for scattering the electrons' velocity
    !! among MPI processes.
    REAL(rp), DIMENSION(:), ALLOCATABLE 		:: V_receive_buffer
    !! Temporary buffer used by MPI for scattering the electrons' velocity
    !! among MPI processes.
    REAL(rp), DIMENSION(:), ALLOCATABLE 		:: AUX_send_buffer
    !!  Temporary buffer used by MPI to scatter various electrons' variables
    !! among MPI processes.
    REAL(rp), DIMENSION(:), ALLOCATABLE 		:: AUX_receive_buffer
    !! Temporary buffer used by MPI to scatter various electrons' variables
    !! among MPI processes.
    CHARACTER(MAX_STRING_LENGTH) 			:: filename
    !! String containing the name of the HDF5 file.
    CHARACTER(MAX_STRING_LENGTH) 			:: dset
    !! Name of data set to be saved to file.
    INTEGER(HID_T) 					:: h5file_id
    !! HDF5 file identifier.
    CHARACTER(19) 					:: tmp_str
    !! Temporary string used to manipulate various strings.
    INTEGER 						:: h5error
    !! HDF5 error status.
    INTEGER 						:: mpierr
    !! Electron species iterator.
    INTEGER 						:: ss
    !! MPI error status.

    do ss=1_idef,params%num_species
       ALLOCATE(X_send_buffer(3*spp(ss)%ppp*params%mpi_params%nmpi))
       ALLOCATE(X_receive_buffer(3*spp(ss)%ppp))

       ALLOCATE(V_send_buffer(3*spp(ss)%ppp*params%mpi_params%nmpi))
       ALLOCATE(V_receive_buffer(3*spp(ss)%ppp))

       ALLOCATE(AUX_send_buffer(spp(ss)%ppp*params%mpi_params%nmpi))
       ALLOCATE(AUX_receive_buffer(spp(ss)%ppp))

       if (params%mpi_params%rank.EQ.0_idef) then
          filename = TRIM(params%path_to_outputs) // "restart_file.h5"
          call h5fopen_f(filename, H5F_ACC_RDONLY_F, h5file_id, h5error)
          if (h5error .EQ. -1) then
             write(6,'("KORC ERROR: Something went wrong in: &
                  &load_particles_ic --> h5fopen_f")')
             call KORC_ABORT()
          end if

          write(tmp_str,'(I18)') ss

          dset = "/spp_" // TRIM(ADJUSTL(tmp_str)) // "/X"
          call load_array_from_hdf5(h5file_id,dset,X_send_buffer)

          call h5fclose_f(h5file_id, h5error)
       end if

       X_receive_buffer = 0.0_rp
       CALL MPI_SCATTER(X_send_buffer,3*spp(ss)%ppp,MPI_REAL8, &
            X_receive_buffer,3*spp(ss)%ppp,MPI_REAL8,0,MPI_COMM_WORLD,mpierr)
       if (params%orbit_model.EQ.'FO') then  
          spp(ss)%vars%X = RESHAPE(X_receive_buffer,(/spp(ss)%ppp,3/))
       else if (params%orbit_model(1:2).EQ.'GC') then
          spp(ss)%vars%Y = RESHAPE(X_receive_buffer,(/spp(ss)%ppp,3/))
       end if

       if (params%mpi_params%rank.EQ.0_idef) then
          filename = TRIM(params%path_to_outputs) // "restart_file.h5"
          call h5fopen_f(filename, H5F_ACC_RDONLY_F, h5file_id, h5error)
          if (h5error .EQ. -1) then
             write(6,'("KORC ERROR: Something went wrong in: &
                  &load_particles_ic --> h5fopen_f")')
             call KORC_ABORT()
          end if

          write(tmp_str,'(I18)') ss

          dset = "/spp_" // TRIM(ADJUSTL(tmp_str)) // "/V"
          call load_array_from_hdf5(h5file_id,dset,V_send_buffer)

          call h5fclose_f(h5file_id, h5error)
       end if

       V_receive_buffer = 0.0_rp
       CALL MPI_SCATTER(V_send_buffer,3*spp(ss)%ppp,MPI_REAL8, &
            V_receive_buffer,3*spp(ss)%ppp,MPI_REAL8,0,MPI_COMM_WORLD,mpierr)
       spp(ss)%vars%V = RESHAPE(V_receive_buffer,(/spp(ss)%ppp,3/))

       if (params%mpi_params%rank.EQ.0_idef) then
          filename = TRIM(params%path_to_outputs) // "restart_file.h5"
          call h5fopen_f(filename, H5F_ACC_RDONLY_F, h5file_id, h5error)
          if (h5error .EQ. -1) then
             write(6,'("KORC ERROR: Something went wrong in: &
                  &load_particles_ic --> h5fopen_f")')
             call KORC_ABORT()
          end if

          write(tmp_str,'(I18)') ss

          dset = "/spp_" // TRIM(ADJUSTL(tmp_str)) // "/flag"
          call load_array_from_hdf5(h5file_id,dset,AUX_send_buffer)

          call h5fclose_f(h5file_id, h5error)
       end if

       AUX_receive_buffer = 0.0_rp
       CALL MPI_SCATTER(AUX_send_buffer,spp(ss)%ppp,MPI_REAL8, &
            AUX_receive_buffer,spp(ss)%ppp,MPI_REAL8,0,MPI_COMM_WORLD,mpierr)
       spp(ss)%vars%flag = INT(AUX_receive_buffer,is)

       if (params%mpi_params%rank.EQ.0_idef) then
          filename = TRIM(params%path_to_outputs) // "restart_file.h5"
          call h5fopen_f(filename, H5F_ACC_RDONLY_F, h5file_id, h5error)
          if (h5error .EQ. -1) then
             write(6,'("KORC ERROR: Something went wrong in: &
                  &load_particles_ic --> h5fopen_f")')
             call KORC_ABORT()
          end if

          write(tmp_str,'(I18)') ss

          dset = "/spp_" // TRIM(ADJUSTL(tmp_str)) // "/g"
          call load_array_from_hdf5(h5file_id,dset,AUX_send_buffer)

          call h5fclose_f(h5file_id, h5error)
       end if

       AUX_receive_buffer = 0.0_rp
       CALL MPI_SCATTER(AUX_send_buffer,spp(ss)%ppp,MPI_REAL8, &
            AUX_receive_buffer,spp(ss)%ppp,MPI_REAL8,0,MPI_COMM_WORLD,mpierr)
       spp(ss)%vars%g = AUX_receive_buffer

       DEALLOCATE(X_send_buffer)
       DEALLOCATE(X_receive_buffer)

       DEALLOCATE(V_send_buffer)
       DEALLOCATE(V_receive_buffer)

       DEALLOCATE(AUX_send_buffer)
       DEALLOCATE(AUX_receive_buffer)
    end do

    if (params%orbit_model(1:2).EQ.'GC') then
       params%GC_coords=.TRUE.
    end if

  end subroutine load_particles_ic

end module korc_HDF5