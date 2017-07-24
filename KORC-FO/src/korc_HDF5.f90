module korc_HDF5

	use korc_types
	use korc_constants
	use HDF5

	implicit none

	INTEGER(HID_T), PRIVATE :: KORC_HDF5_REAL ! Real precision used in HDF5
	INTEGER(SIZE_T), PRIVATE :: rp_hdf5 ! Size of real precision used in HDF5


	INTERFACE load_from_hdf5
	  module procedure iload_from_hdf5, rload_from_hdf5
	END INTERFACE

	INTERFACE load_array_from_hdf5
	  module procedure rload_1d_array_from_hdf5, rload_3d_array_from_hdf5, rload_2d_array_from_hdf5
	END INTERFACE

	INTERFACE save_to_hdf5
	  module procedure isave_to_hdf5,ip_save_to_hdf5,rsave_to_hdf5
	END INTERFACE

	INTERFACE save_1d_array_to_hdf5
	  module procedure isave_1d_array_to_hdf5,rsave_1d_array_to_hdf5
	END INTERFACE

	INTERFACE save_2d_array_to_hdf5
	  module procedure rsave_2d_array_to_hdf5
	END INTERFACE

	INTERFACE save_3d_array_to_hdf5
	  module procedure rsave_3d_array_to_hdf5
	END INTERFACE

	INTERFACE save_array_to_hdf5
	  module procedure isave_1d_array_to_hdf5,rsave_1d_array_to_hdf5,rsave_2d_array_to_hdf5,rsave_3d_array_to_hdf5
	END INTERFACE

	PRIVATE :: isave_to_hdf5,rsave_to_hdf5,isave_1d_array_to_hdf5,&
				rsave_1d_array_to_hdf5,rsave_2d_array_to_hdf5,&
				iload_from_hdf5,rload_from_hdf5,rload_1d_array_from_hdf5,&
				rload_3d_array_from_hdf5,rload_2d_array_from_hdf5
				
	PUBLIC :: initialize_HDF5,finalize_HDF5,save_simulation_parameters,&
                save_to_hdf5,save_1d_array_to_hdf5,save_2d_array_to_hdf5,&
				load_from_hdf5,load_array_from_hdf5

contains


subroutine initialize_HDF5()
	implicit none
	INTEGER :: h5error  ! Error flag
	call h5open_f(h5error)
	
#ifdef HDF5_DOUBLE_PRESICION
	call h5tcopy_f(H5T_NATIVE_DOUBLE, KORC_HDF5_REAL, h5error)
#elif HDF5_SINGLE_PRESICION
	call h5tcopy_f(H5T_NATIVE_REAL, KORC_HDF5_REAL, h5error)
#endif
	call h5tget_size_f(KORC_HDF5_REAL, rp_hdf5, h5error)
end subroutine initialize_HDF5


subroutine finalize_HDF5()
	implicit none
	INTEGER :: h5error  ! Error flag
	call h5close_f(h5error)
end subroutine finalize_HDF5


subroutine iload_from_hdf5(h5file_id,dset,rdatum,attr)
	implicit none
	INTEGER(HID_T), INTENT(IN) :: h5file_id
	CHARACTER(MAX_STRING_LENGTH), INTENT(IN) :: dset
	INTEGER, INTENT(OUT) :: rdatum
	CHARACTER(MAX_STRING_LENGTH), OPTIONAL, INTENT(IN) :: attr
	CHARACTER(4) :: aname = "Info"
	INTEGER(HID_T) :: dset_id
	INTEGER(HID_T) :: dspace_id
	INTEGER(HID_T) :: aspace_id
	INTEGER(HID_T) :: attr_id
	INTEGER(HID_T) :: atype_id
	INTEGER(HSIZE_T), DIMENSION(1) :: dims = (/1/)
	INTEGER(HSIZE_T), DIMENSION(1) :: adims = (/1/)
	INTEGER :: rank = 1
	INTEGER :: arank = 1
	INTEGER(SIZE_T) :: tmplen
	INTEGER(SIZE_T) :: attrlen
	INTEGER :: h5error

	! * * * Read datum from file * * *

	call h5dopen_f(h5file_id, TRIM(dset), dset_id, h5error)
	if (h5error .EQ. -1) then
		write(6,'("KORC ERROR: Something went wrong in: iload_from_hdf5 --> h5dopen_f")')
	end if

	call h5dread_f(dset_id, H5T_NATIVE_INTEGER, rdatum, dims, h5error)

	if (h5error .EQ. -1) then
		write(6,'("KORC ERROR: Something went wrong in: iload_from_hdf5 --> h5dread_f")')
	end if

	call h5dclose_f(dset_id, h5error)
	if (h5error .EQ. -1) then
		write(6,'("KORC ERROR: Something went wrong in: iload_from_hdf5 --> h5dclose_f")')
	end if

	if (PRESENT(attr)) then
		! * * * Read attribute from file * * *

		! * * * Read attribute from file * * *
	end if

	! * * * Read datum from file * * *
end subroutine iload_from_hdf5


subroutine rload_from_hdf5(h5file_id,dset,rdatum,attr)
	implicit none
	INTEGER(HID_T), INTENT(IN) :: h5file_id
	CHARACTER(MAX_STRING_LENGTH), INTENT(IN) :: dset
	REAL(rp), INTENT(OUT) :: rdatum
	REAL :: raw_datum
	CHARACTER(MAX_STRING_LENGTH), OPTIONAL, INTENT(IN) :: attr
	CHARACTER(4) :: aname = "Info"
	INTEGER(HID_T) :: dset_id
	INTEGER(HID_T) :: dspace_id
	INTEGER(HID_T) :: aspace_id
	INTEGER(HID_T) :: attr_id
	INTEGER(HID_T) :: atype_id
	INTEGER(HSIZE_T), DIMENSION(1) :: dims = (/1/)
	INTEGER(HSIZE_T), DIMENSION(1) :: adims = (/1/)
	INTEGER :: rank = 1
	INTEGER :: arank = 1
	INTEGER(SIZE_T) :: tmplen
	INTEGER(SIZE_T) :: attrlen
	INTEGER :: h5error

	! * * * Read datum from file * * *

	call h5dopen_f(h5file_id, TRIM(dset), dset_id, h5error)
	if (h5error .EQ. -1) then
		write(6,'("KORC ERROR: Something went wrong in: rload_from_hdf5 --> h5dopen_f")')
	end if

	call h5dread_f(dset_id, H5T_NATIVE_REAL, raw_datum, dims, h5error)
	if (h5error .EQ. -1) then
		write(6,'("KORC ERROR: Something went wrong in: rload_from_hdf5 --> h5dread_f")')
	end if
	rdatum = REAL(raw_datum,rp)

	call h5dclose_f(dset_id, h5error)
	if (h5error .EQ. -1) then
		write(6,'("KORC ERROR: Something went wrong in: rload_from_hdf5 --> h5dclose_f")')
	end if

	if (PRESENT(attr)) then
		! * * * Read attribute from file * * *

		! * * * Read attribute from file * * *
	end if

	! * * * Read datum from file * * *
end subroutine rload_from_hdf5


subroutine rload_1d_array_from_hdf5(h5file_id,dset,rdata,attr)
	implicit none
	INTEGER(HID_T), INTENT(IN) :: h5file_id
	CHARACTER(MAX_STRING_LENGTH), INTENT(IN) :: dset
	REAL(rp), DIMENSION(:), ALLOCATABLE, INTENT(INOUT) :: rdata
	REAL, DIMENSION(:), ALLOCATABLE :: raw_data
	CHARACTER(MAX_STRING_LENGTH), OPTIONAL, DIMENSION(:), ALLOCATABLE, INTENT(IN) :: attr
	CHARACTER(MAX_STRING_LENGTH) :: aname
	INTEGER(HID_T) :: dset_id
	INTEGER(HID_T) :: dspace_id
	INTEGER(HID_T) :: aspace_id
	INTEGER(HID_T) :: attr_id
	INTEGER(HID_T) :: atype_id
	INTEGER(HSIZE_T), DIMENSION(1) :: dims
	INTEGER(HSIZE_T), DIMENSION(1) :: adims
	INTEGER(SIZE_T) :: tmplen
	INTEGER(SIZE_T) :: attrlen
	INTEGER :: h5error

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


subroutine rload_2d_array_from_hdf5(h5file_id,dset,rdata,attr)
	implicit none
	INTEGER(HID_T), INTENT(IN) :: h5file_id
	CHARACTER(MAX_STRING_LENGTH), INTENT(IN) :: dset
	REAL(rp), DIMENSION(:,:), ALLOCATABLE, INTENT(INOUT) :: rdata
	REAL, DIMENSION(:,:), ALLOCATABLE :: raw_data
	CHARACTER(MAX_STRING_LENGTH), OPTIONAL, DIMENSION(:), ALLOCATABLE, INTENT(IN) :: attr
	CHARACTER(MAX_STRING_LENGTH) :: aname
	INTEGER(HID_T) :: dset_id
	INTEGER(HID_T) :: dspace_id
	INTEGER(HID_T) :: aspace_id
	INTEGER(HID_T) :: attr_id
	INTEGER(HID_T) :: atype_id
	INTEGER(HSIZE_T), DIMENSION(2) :: dims
	INTEGER(HSIZE_T), DIMENSION(2) :: adims
	INTEGER(SIZE_T) :: tmplen
	INTEGER(SIZE_T) :: attrlen
	INTEGER :: h5error

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


subroutine rload_3d_array_from_hdf5(h5file_id,dset,rdata,attr)
	implicit none
	INTEGER(HID_T), INTENT(IN) :: h5file_id
	CHARACTER(MAX_STRING_LENGTH), INTENT(IN) :: dset
	REAL(rp), DIMENSION(:,:,:), ALLOCATABLE, INTENT(INOUT) :: rdata
	REAL, DIMENSION(:,:,:), ALLOCATABLE :: raw_data
	CHARACTER(MAX_STRING_LENGTH), OPTIONAL, DIMENSION(:), ALLOCATABLE, INTENT(IN) :: attr
	CHARACTER(MAX_STRING_LENGTH) :: aname
	INTEGER(HID_T) :: dset_id
	INTEGER(HID_T) :: dspace_id
	INTEGER(HID_T) :: aspace_id
	INTEGER(HID_T) :: attr_id
	INTEGER(HID_T) :: atype_id
	INTEGER(HSIZE_T), DIMENSION(3) :: dims
	INTEGER(HSIZE_T), DIMENSION(3) :: adims
	INTEGER(SIZE_T) :: tmplen
	INTEGER(SIZE_T) :: attrlen
	INTEGER :: h5error

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


subroutine ip_save_to_hdf5(h5file_id,dset,ip_data,attr)
	implicit none
	INTEGER(HID_T), INTENT(IN) :: h5file_id
	CHARACTER(MAX_STRING_LENGTH), INTENT(IN) :: dset
	INTEGER(ip), INTENT(IN) :: ip_data
	INTEGER :: idata
	CHARACTER(MAX_STRING_LENGTH), OPTIONAL, INTENT(IN) :: attr
	CHARACTER(4) :: aname = "Info"
	INTEGER(HID_T) :: dset_id
	INTEGER(HID_T) :: dspace_id
	INTEGER(HID_T) :: aspace_id
	INTEGER(HID_T) :: attr_id
	INTEGER(HID_T) :: atype_id
	INTEGER(HSIZE_T), DIMENSION(1) :: dims = (/1/)
	INTEGER(HSIZE_T), DIMENSION(1) :: adims = (/1/)
	INTEGER :: rank = 1
	INTEGER :: arank = 1
	INTEGER(SIZE_T) :: tmplen
	INTEGER(SIZE_T) :: attrlen
	INTEGER :: h5error

	idata = INT(ip_data,idef)

	! * * * Write data to file * * *
	call h5screate_simple_f(rank,dims,dspace_id,h5error)
	call h5dcreate_f(h5file_id, TRIM(dset), H5T_NATIVE_INTEGER, dspace_id, dset_id, h5error)
	call h5dwrite_f(dset_id, H5T_NATIVE_INTEGER, idata, dims, h5error)

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
end subroutine ip_save_to_hdf5


subroutine isave_to_hdf5(h5file_id,dset,idata,attr)
	implicit none
	INTEGER(HID_T), INTENT(IN) :: h5file_id
	CHARACTER(MAX_STRING_LENGTH), INTENT(IN) :: dset
	INTEGER, INTENT(IN) :: idata
	CHARACTER(MAX_STRING_LENGTH), OPTIONAL, INTENT(IN) :: attr
	CHARACTER(4) :: aname = "Info"
	INTEGER(HID_T) :: dset_id
	INTEGER(HID_T) :: dspace_id
	INTEGER(HID_T) :: aspace_id
	INTEGER(HID_T) :: attr_id
	INTEGER(HID_T) :: atype_id
	INTEGER(HSIZE_T), DIMENSION(1) :: dims = (/1/)
	INTEGER(HSIZE_T), DIMENSION(1) :: adims = (/1/)
	INTEGER :: rank = 1
	INTEGER :: arank = 1
	INTEGER(SIZE_T) :: tmplen
	INTEGER(SIZE_T) :: attrlen
	INTEGER :: h5error

	! * * * Write data to file * * *
	call h5screate_simple_f(rank,dims,dspace_id,h5error)
	call h5dcreate_f(h5file_id, TRIM(dset), H5T_NATIVE_INTEGER, dspace_id, dset_id, h5error)
	call h5dwrite_f(dset_id, H5T_NATIVE_INTEGER, idata, dims, h5error)

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
end subroutine isave_to_hdf5


subroutine isave_1d_array_to_hdf5(h5file_id,dset,idata,attr)
	implicit none
	INTEGER(HID_T), INTENT(IN) :: h5file_id
	CHARACTER(MAX_STRING_LENGTH), INTENT(IN) :: dset
	INTEGER, DIMENSION(:), INTENT(IN) :: idata
	CHARACTER(MAX_STRING_LENGTH), OPTIONAL, DIMENSION(:), ALLOCATABLE, INTENT(IN) :: attr
	CHARACTER(4) :: aname = "Info"
	INTEGER(HID_T) :: dset_id
	INTEGER(HID_T) :: dspace_id
	INTEGER(HID_T) :: aspace_id
	INTEGER(HID_T) :: attr_id
	INTEGER(HID_T) :: atype_id
	INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE :: dims
	INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE :: adims
	INTEGER :: rank
	INTEGER :: arank
	INTEGER(SIZE_T) :: tmplen
	INTEGER(SIZE_T) :: attrlen
	INTEGER :: h5error
	INTEGER :: rr,dd ! Iterators

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


subroutine rsave_to_hdf5(h5file_id,dset,rdata,attr)
	implicit none
	INTEGER(HID_T), INTENT(IN) :: h5file_id
	CHARACTER(MAX_STRING_LENGTH), INTENT(IN) :: dset
	REAL(rp), INTENT(IN) :: rdata
	CHARACTER(MAX_STRING_LENGTH), OPTIONAL, INTENT(IN) :: attr
	CHARACTER(4) :: aname = "Info"
	INTEGER(HID_T) :: dset_id
	INTEGER(HID_T) :: dspace_id
	INTEGER(HID_T) :: aspace_id
	INTEGER(HID_T) :: attr_id
	INTEGER(HID_T) :: atype_id
	INTEGER(HSIZE_T), DIMENSION(1) :: dims = (/1/)
	INTEGER(HSIZE_T), DIMENSION(1) :: adims = (/1/)
	INTEGER :: rank = 1
	INTEGER :: arank = 1
	INTEGER(SIZE_T) :: tmplen
	INTEGER(SIZE_T) :: attrlen
	INTEGER :: h5error

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


subroutine rsave_1d_array_to_hdf5(h5file_id,dset,rdata,attr)
	implicit none
	INTEGER(HID_T), INTENT(IN) :: h5file_id
	CHARACTER(MAX_STRING_LENGTH), INTENT(IN) :: dset
	REAL(rp), DIMENSION(:), INTENT(IN) :: rdata
	CHARACTER(MAX_STRING_LENGTH), OPTIONAL, DIMENSION(:), ALLOCATABLE, INTENT(IN) :: attr
	CHARACTER(4) :: aname = "Info"
	INTEGER(HID_T) :: dset_id
	INTEGER(HID_T) :: dspace_id
	INTEGER(HID_T) :: aspace_id
	INTEGER(HID_T) :: attr_id
	INTEGER(HID_T) :: atype_id
	INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE :: dims
	INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE :: adims
	INTEGER :: rank
	INTEGER :: arank
	INTEGER(SIZE_T) :: tmplen
	INTEGER(SIZE_T) :: attrlen
	INTEGER :: h5error
	INTEGER :: rr,dd ! Iterators

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


subroutine rsave_2d_array_to_hdf5(h5file_id,dset,rdata,attr)
	implicit none
	INTEGER(HID_T), INTENT(IN) :: h5file_id
	CHARACTER(MAX_STRING_LENGTH), INTENT(IN) :: dset
	REAL(rp), DIMENSION(:,:), INTENT(IN) :: rdata
	CHARACTER(MAX_STRING_LENGTH), OPTIONAL, DIMENSION(:), ALLOCATABLE, INTENT(IN) :: attr
	CHARACTER(4) :: aname = "Info"
	INTEGER(HID_T) :: dset_id
	INTEGER(HID_T) :: dspace_id
	INTEGER(HID_T) :: aspace_id
	INTEGER(HID_T) :: attr_id
	INTEGER(HID_T) :: atype_id
	INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE :: dims
	INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE :: adims
	INTEGER :: rank
	INTEGER :: arank
	INTEGER(SIZE_T) :: tmplen
	INTEGER(SIZE_T) :: attrlen
	INTEGER :: h5error
	INTEGER :: rr,dd ! Iterators

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


subroutine rsave_3d_array_to_hdf5(h5file_id,dset,rdata,attr)
	implicit none
	INTEGER(HID_T), INTENT(IN) :: h5file_id
	CHARACTER(MAX_STRING_LENGTH), INTENT(IN) :: dset
	REAL(rp), DIMENSION(:,:,:), INTENT(IN) :: rdata
	CHARACTER(MAX_STRING_LENGTH), OPTIONAL, DIMENSION(:), ALLOCATABLE, INTENT(IN) :: attr
	CHARACTER(4) :: aname = "Info"
	INTEGER(HID_T) :: dset_id
	INTEGER(HID_T) :: dspace_id
	INTEGER(HID_T) :: aspace_id
	INTEGER(HID_T) :: attr_id
	INTEGER(HID_T) :: atype_id
	INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE :: dims
	INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE :: adims
	INTEGER :: rank
	INTEGER :: arank
	INTEGER(SIZE_T) :: tmplen
	INTEGER(SIZE_T) :: attrlen
	INTEGER :: h5error
	INTEGER :: rr,dd ! Iterators

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


subroutine save_simulation_parameters(params,spp,F)
	implicit none
	TYPE(KORC_PARAMS), INTENT(IN) :: params
	TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(IN) :: spp
	TYPE(FIELDS), INTENT(IN) :: F
	CHARACTER(MAX_STRING_LENGTH) :: filename
	CHARACTER(MAX_STRING_LENGTH) :: gname
	CHARACTER(MAX_STRING_LENGTH) :: dset
	INTEGER(HID_T) :: h5file_id
	INTEGER(HID_T) :: group_id
	INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE :: dims
	REAL(rp), DIMENSION(:), ALLOCATABLE :: rdata
	INTEGER, DIMENSION(:), ALLOCATABLE :: idata
	CHARACTER(MAX_STRING_LENGTH), DIMENSION(:), ALLOCATABLE :: attr_array
	CHARACTER(MAX_STRING_LENGTH) :: attr
	INTEGER :: h5error
	CHARACTER(19) :: tmp_str
	REAL(rp) :: units

	if (SIZE(params%outputs_list).GT.1_idef) then
		write(tmp_str,'(I18)') params%mpi_params%rank
		filename = TRIM(params%path_to_outputs) // "file_" // TRIM(ADJUSTL(tmp_str)) // ".h5"
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

		dset = TRIM(gname) // "/simulation_time"
        attr = "Total aimed simulation time in seconds"
		call save_to_hdf5(h5file_id,dset,params%simulation_time*params%cpp%time,attr)

		dset = TRIM(gname) // "/snapshot_frequency"
        attr = "Time between snapshots in seconds"
		call save_to_hdf5(h5file_id,dset,params%snapshot_frequency*params%cpp%time,attr)

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
		call save_to_hdf5(h5file_id,dset,params%minimum_particle_energy*params%cpp%energy/C_E,attr)

		dset = TRIM(gname) // "/radiation"
		attr = "Radiation losses included in simulation"
		if(params%radiation) then
			call save_to_hdf5(h5file_id,dset,1_idef,attr)
		else
			call save_to_hdf5(h5file_id,dset,0_idef,attr)
		end if

		dset = TRIM(gname) // "/collisions"
		attr = "Radiation losses included in simulation"
		if(params%collisions) then
			call save_to_hdf5(h5file_id,dset,1_idef,attr)
		else
			call save_to_hdf5(h5file_id,dset,0_idef,attr)
		end if

		DEALLOCATE(idata)
		DEALLOCATE(attr_array)

		call h5gclose_f(group_id, h5error)


		! Plasma species group
		gname = "species"
		call h5gcreate_f(h5file_id, TRIM(gname), group_id, h5error)

		ALLOCATE(attr_array(params%num_species))

		dset = TRIM(gname) // "/ppp"
		attr_array(1) = "Particles per (mpi) process"
		call save_1d_array_to_hdf5(h5file_id,dset,spp%ppp,attr_array)

		dset = TRIM(gname) // "/q"
		attr_array(1) = "Electric charge"
		call save_1d_array_to_hdf5(h5file_id,dset,spp%q*params%cpp%charge,attr_array)

		dset = TRIM(gname) // "/m"
		attr_array(1) = "Species mass in kg"
		call save_1d_array_to_hdf5(h5file_id,dset,spp%m*params%cpp%mass,attr_array)

		dset = TRIM(gname) // "/Eo"
		attr_array(1) = "Initial (average) energy in eV"
		call save_1d_array_to_hdf5(h5file_id,dset,spp%Eo*params%cpp%energy/C_E,attr_array)

		dset = TRIM(gname) // "/go"
		attr_array(1) = "Initial relativistic g factor."
		call save_1d_array_to_hdf5(h5file_id,dset,spp%go,attr_array)

		dset = TRIM(gname) // "/etao"
		attr_array(1) = "Initial pitch angle in degrees"
		call save_1d_array_to_hdf5(h5file_id,dset,spp%etao,attr_array)

		dset = TRIM(gname) // "/wc"
		attr_array(1) = "Average relativistic cyclotron frequency in Hz"
		call save_1d_array_to_hdf5(h5file_id,dset,spp%wc_r/params%cpp%time,attr_array)

		dset = TRIM(gname) // "/Ro"
		attr_array(1) = "Initial radial position of population"
		call save_1d_array_to_hdf5(h5file_id,dset,spp%Ro*params%cpp%length,attr_array)

		dset = TRIM(gname) // "/Zo"
		attr_array(1) = "Initial Z position of population"
		call save_1d_array_to_hdf5(h5file_id,dset,spp%Zo*params%cpp%length,attr_array)

		dset = TRIM(gname) // "/r"
		attr_array(1) = "Radius of initial spatial distribution"
		call save_1d_array_to_hdf5(h5file_id,dset,spp%r*params%cpp%length,attr_array)

		call h5gclose_f(group_id, h5error)

		DEALLOCATE(attr_array)

		! Electromagnetic fields group
		gname = "fields"
		call h5gcreate_f(h5file_id, TRIM(gname), group_id, h5error)

		if (params%magnetic_field_model .EQ. 'ANALYTICAL') then
			dset = TRIM(gname) // "/Bo"
			attr = "Toroidal field at the magnetic axis in T"
			call save_to_hdf5(h5file_id,dset,F%Bo*params%cpp%Bo,attr)

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
        	call save_to_hdf5(h5file_id,dset,F%AB%lambda*params%cpp%length,attr)

			dset = TRIM(gname) // "/Bpo"
			attr = "Poloidal magnetic field in T"
        	call save_to_hdf5(h5file_id,dset,F%AB%Bpo*params%cpp%Bo,attr)

			dset = TRIM(gname) // "/Eo"
			attr = "Electric field at the magnetic axis in V/m"
			call save_to_hdf5(h5file_id,dset,F%Eo*params%cpp%Eo,attr)
		else if (params%magnetic_field_model .EQ. 'EXTERNAL') then
			ALLOCATE(attr_array(1))
			dset = TRIM(gname) // "/dims"
			attr_array(1) = "Mesh dimension of the magnetic field (NR,NPHI,NZ)"
			call save_1d_array_to_hdf5(h5file_id,dset,F%dims,attr_array)		

			dset = TRIM(gname) // "/R"
			attr_array(1) = "Radial position of the magnetic field grid nodes"
			call save_1d_array_to_hdf5(h5file_id,dset,F%X%R*params%cpp%length,attr_array)

			if (ALLOCATED(F%X%PHI)) then
				dset = TRIM(gname) // "/PHI"
				attr_array(1) = "Azimuthal angle of the magnetic field grid nodes"
				call save_1d_array_to_hdf5(h5file_id,dset,F%X%PHI,attr_array)
			end if

			dset = TRIM(gname) // "/Z"
			attr_array(1) = "Z position of the magnetic field grid nodes"
			call save_1d_array_to_hdf5(h5file_id,dset,F%X%Z*params%cpp%length,attr_array)

			if (params%poloidal_flux.OR.params%axisymmetric) then
				dset = TRIM(gname) // "/Bo"
				attr = "Toroidal field at the magnetic axis in T"
				call save_to_hdf5(h5file_id,dset,F%Bo*params%cpp%Bo,attr)

				dset = TRIM(gname) // "/Ro"
				attr = "Radial position of magnetic axis"
				call save_to_hdf5(h5file_id,dset,F%Ro*params%cpp%length,attr)

				dset = TRIM(gname) // "/Zo"
				attr = "Radial position of magnetic axis"
				call save_to_hdf5(h5file_id,dset,F%Zo*params%cpp%length,attr)
			end if

			DEALLOCATE(attr_array)
		else if (params%magnetic_field_model .EQ. 'UNIFORM') then
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

end subroutine save_simulation_parameters


subroutine save_simulation_outputs(params,spp,F)
	implicit none
	TYPE(KORC_PARAMS), INTENT(IN) :: params
	TYPE(SPECIES), DIMENSION(:), ALLOCATABLE, INTENT(IN) :: spp
	TYPE(FIELDS), INTENT(IN) :: F
	CHARACTER(MAX_STRING_LENGTH) :: filename
	CHARACTER(MAX_STRING_LENGTH) :: gname
	CHARACTER(MAX_STRING_LENGTH) :: subgname
	CHARACTER(MAX_STRING_LENGTH) :: dset
	INTEGER(HID_T) :: h5file_id
	INTEGER(HID_T) :: group_id
	INTEGER(HID_T) :: subgroup_id
	INTEGER(HSIZE_T), DIMENSION(:), ALLOCATABLE :: dims
	REAL(rp), DIMENSION(:), ALLOCATABLE :: rdata
	INTEGER, DIMENSION(:), ALLOCATABLE :: idata
	CHARACTER(MAX_STRING_LENGTH), DIMENSION(:), ALLOCATABLE :: attr_array
	CHARACTER(MAX_STRING_LENGTH) :: attr
	INTEGER :: h5error
	CHARACTER(19) :: tmp_str
	REAL(rp) :: units
    INTEGER :: ii,jj

	if (SIZE(params%outputs_list).GT.1_idef) then
		write(tmp_str,'(I18)') params%mpi_params%rank
		filename = TRIM(params%path_to_outputs) // "file_" // TRIM(ADJUSTL(tmp_str)) // ".h5"
		call h5fopen_f(TRIM(filename), H5F_ACC_RDWR_F, h5file_id, h5error)

		! Create group 'it'
		write(tmp_str,'(I18)') params%it
		gname = TRIM(ADJUSTL(tmp_str))
		call h5gcreate_f(h5file_id, TRIM(gname), group_id, h5error)
		
		dset = TRIM(gname) // "/time"
		attr = "Simulation time in secs"
		call save_to_hdf5(h5file_id,dset,REAL(params%it,rp)*params%dt*params%cpp%time,attr)

		do ii=1_idef,params%num_species
		    write(tmp_str,'(I18)') ii
			subgname = "spp_" // TRIM(ADJUSTL(tmp_str))
			call h5gcreate_f(group_id, TRIM(subgname), subgroup_id, h5error)

			do jj=1_idef,SIZE(params%outputs_list)
				SELECT CASE (TRIM(params%outputs_list(jj)))
					CASE ('X')
						dset = "X"
						units = params%cpp%length
						call rsave_2d_array_to_hdf5(subgroup_id, dset, units*spp(ii)%vars%X)
					CASE('V')
						dset = "V"
						units = params%cpp%velocity
						call rsave_2d_array_to_hdf5(subgroup_id, dset, units*spp(ii)%vars%V)
					CASE('Rgc')
						dset = "Rgc"
						units = params%cpp%length
						call rsave_2d_array_to_hdf5(subgroup_id, dset, units*spp(ii)%vars%Rgc)
					CASE('g')
						dset = "g"
						call save_1d_array_to_hdf5(subgroup_id, dset, spp(ii)%vars%g)
					CASE('eta')
						dset = "eta"
						call save_1d_array_to_hdf5(subgroup_id, dset, spp(ii)%vars%eta)
					CASE('mu')
						dset = "mu"
						units = params%cpp%mass*params%cpp%velocity**2/params%cpp%Bo
						call save_1d_array_to_hdf5(subgroup_id, dset, units*spp(ii)%vars%mu)
					CASE('Prad')
						dset = "Prad"
						units = params%cpp%mass*(params%cpp%velocity**3)/params%cpp%length
						call save_1d_array_to_hdf5(subgroup_id, dset, units*spp(ii)%vars%Prad)
					CASE('Pin')
						dset = "Pin"
						units = params%cpp%mass*(params%cpp%velocity**3)/params%cpp%length
						call save_1d_array_to_hdf5(subgroup_id, dset, units*spp(ii)%vars%Pin)
					CASE('flag')
						dset = "flag"
						call save_1d_array_to_hdf5(subgroup_id,dset, spp(ii)%vars%flag)
					CASE('B')
						dset = "B"
						units = params%cpp%Bo
						call rsave_2d_array_to_hdf5(subgroup_id, dset, units*spp(ii)%vars%B)
					CASE('E')
						dset = "E"
						units = params%cpp%Eo
						call rsave_2d_array_to_hdf5(subgroup_id, dset, units*spp(ii)%vars%E)
					CASE('AUX')
						dset = "AUX"
						call save_1d_array_to_hdf5(subgroup_id, dset, spp(ii)%vars%AUX)

					CASE DEFAULT
				
				END SELECT
			end do 

		    call h5gclose_f(subgroup_id, h5error)
		end do

		call h5gclose_f(group_id, h5error)

		call h5fclose_f(h5file_id, h5error)
	end if
end subroutine save_simulation_outputs

end module korc_HDF5
