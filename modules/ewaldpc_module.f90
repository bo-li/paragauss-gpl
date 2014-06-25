!
! ParaGauss,  a program package  for high-performance  computations of
! molecular systems
!
! Copyright (C) 2014     T. Belling,     T. Grauschopf,     S. Krüger,
! F. Nörtemann, M. Staufer,  M. Mayer, V. A. Nasluzov, U. Birkenheuer,
! A. Hu, A. V. Matveev, A. V. Shor, M. S. K. Fuchs-Rohr, K. M. Neyman,
! D. I. Ganyushin,   T. Kerdcharoen,   A. Woiterski,  A. B. Gordienko,
! S. Majumder,     M. H. i Rotllant,     R. Ramakrishnan,    G. Dixit,
! A. Nikodem, T. Soini, M. Roderus, N. Rösch
!
! This program is free software; you can redistribute it and/or modify
! it under  the terms of the  GNU General Public License  version 2 as
! published by the Free Software Foundation [1].
!
! This program is distributed in the  hope that it will be useful, but
! WITHOUT  ANY   WARRANTY;  without  even  the   implied  warranty  of
! MERCHANTABILITY  or FITNESS FOR  A PARTICULAR  PURPOSE. See  the GNU
! General Public License for more details.
!
! [1] http://www.gnu.org/licenses/gpl-2.0.html
!
! Please see the accompanying LICENSE file for further information.
!
module ewaldpc_module
!!! description of the option in ewald_in  !!!
#include <def.h>
 use type_module
 use datatype
 use comm_module, only: commpack, communpack
 use operations_module, only: operations_qm_epe

  implicit none
  save            ! keep contents of module
  private         ! by default, all names are private
!------------ Declaration of types ------------------------------

 integer(kind=i4_kind):: ewa_allocstat(27)=0
 logical, allocatable,public:: ewpc_arrel_used(:)
 integer(kind=i4_kind),public:: EWPC_N=0  &!  no of the PC in the Ewald MP generated file
                        ,ewpc_unit & ! iunit of file ewald.pcr
                        ,pcr_n=0   & ! no of regular EPE positions
                        ,pcs_n=0   & ! No of EPE shells
                        ,pcc_n=0   & ! No of EPE cores
                        ,n_unique_pcr=0 & !
                        ,start_regI_epevar
 integer(kind=i4_kind), public   :: n_gxat_pcr=0_i4_kind
 real(kind=r8_kind),public:: cluster_nuc_epe_en
 logical,public:: ex_pcew  ! true if ewald.pcr file exist
 logical,public:: ex_gxepe  !true if lcgto.r file generated by simol with iw=0 exist
 logical,public:: ex_pcr=.false.  ! true if file with regular EPE  positions  exist
 logical,public:: ex_pcs=.false.  ! true if file with the shell EPE  positions  exist
 logical,public:: ex_pcc=.false.  ! true if file with the core EPE  positions  exist
 type(pointcharge_type), pointer, public  :: ewpc_array(:) => NULL()
 type(pointcharge_type), dimension(:) ,pointer, public  :: gxepe_array
 integer(kind=i4_kind), public,allocatable, dimension(:) :: gxepe_impu
 integer(kind=i4_kind), public :: n_epe_r
!       regular positions of gx-file epe centers
 type(pointcharge_type), pointer, public  :: pcr_array(:)
 type(pointcharge_type), pointer, public  :: pcs_array(:)
 type(pointcharge_type), pointer, public  :: pcc_array(:)
 real(kind=r8_kind), public,allocatable, dimension(:,:) ::pcr_temp
!       regular positions of EPE envinroment
 logical,public:: epe_rel_done=.false.

#ifdef NEW_EPE
 logical, public :: get_epe_references
 logical, public :: get_qm_references
 logical, public :: no_pg
 logical, public :: use_epe_qm_references
 logical, public :: no_relax

 logical, public :: qm_ref_run=.false.
 logical, public :: opt_and_relax
#endif

 logical,public:: ewaldpc,epe_embedding, epe_relaxation

 real(kind=r8_kind), public,allocatable :: zepe(:)
 real(kind=r8_kind), allocatable :: zcharge(:)
 integer(kind=i4_kind), allocatable :: ncharge(:)
 integer(kind=i4_kind),public::nzepe
 logical:: df_ewaldpc=.false., &
      df_epe_embedding=.false., &
      df_epe_relaxation=.false.
 integer(kind=i4_kind):: df_nzepe=0

 public :: ewpc_bcast
 public :: epe_read
 public :: epe_write
 public :: ewa_allocstat
 public :: ewpc_close

#ifndef NEW_EPE
 namelist/epe_data/ ewaldpc,epe_embedding,epe_relaxation,nzepe
#endif

#ifdef NEW_EPE
 logical :: df_get_epe_references=.false.
 logical :: df_get_qm_references=.false.
 logical :: df_no_pg=.false.
 logical :: df_use_epe_qm_references=.false.
 logical :: df_no_relax=.false.
 logical :: df_opt_and_relax=.false.
 character(len=80) :: epe_task
 character(len=7) :: df_epe_task="nothing"
 character(len=11)  :: task1="GET_EPE_REF"
 character(len=10)  :: task2="GET_QM_REF"
 character(len=10)  :: subtask21="WITHOUT_PG" !affects in combination with task2
 character(len=9)   :: subtask22="NO_QM_OPT"  !affects in combination with task2
 character(len=14)  :: task3="QM_CLUSTER_OPT"
 character(len=8)   :: subtask31="NO_EWALD"   !affects in combination with task3
 character(len=10)  :: subtask32="NO_EPE_ENV" !affects in combination with task3
 character(len=9)   :: task4="EPE_RELAX"
 character(len=9)   :: subtask41="NO_RELAX"   !affects in combination with task4
 namelist/epe_data/ epe_task
#endif
 

 contains

   subroutine epe_read(N_unique_at)
     !------------ Modules used -----------------------------------
     use input_module
#ifdef NEW_EPE
     use operations_module
     use inp_out_module, only: upcase, check_string !from MM
#else
     use operations_module, only: operations_task,namelist_tasks_used
#endif
     !------------ Declaration of formal parameters ---------------
     integer, intent(in) :: N_unique_at
     !------------ Declaration of local variables -----------------
     integer (i4_kind):: unit, status
#ifndef NEW_EPE
     integer (i4_kind):: i, j
#endif
     !------------ Executable code --------------------------------

     ewaldpc=df_ewaldpc
     epe_embedding=df_epe_embedding
     epe_relaxation=df_epe_relaxation
     nzepe=df_nzepe

#ifdef NEW_EPE
     get_epe_references=df_get_epe_references
     get_qm_references=df_get_qm_references
     no_pg=df_no_pg
     use_epe_qm_references=df_use_epe_qm_references
     no_relax=df_no_relax
     opt_and_relax=df_opt_and_relax
     epe_task=df_epe_task

!     if(.not. operations_qm_epe) return
#endif

     if(input_line_is_namelist("epe_data")) then
        unit = input_intermediate_unit()
        call input_read_to_intermediate
        read(unit, nml=epe_data, iostat=status)
        if(namelist_tasks_used) call task_epedata(operations_task)
        if (status .gt. 0) call input_error("epe_read: namelist epe_data")
#ifdef NEW_EPE
        if(.not. operations_qm_epe) return
        if (trim(epe_task)=="nothing" .and. operations_qm_epe) call input_error( &
             "epe_read: namelist epe_data: Nothing to do")
        call upcase(epe_task)
        if(check_string(epe_task,task1)) then 
           get_epe_references=.true.
           operations_epe_lattice=.true.
        elseif(check_string(epe_task,task2)) then
           get_qm_references=.true.
           operations_epe_lattice=.false.
           if(check_string(epe_task,subtask21)) no_pg=.true.
           ewaldpc=.true.
           epe_embedding=.true.
           if(check_string(epe_task,subtask22)) qm_ref_run=.true.
           if(qm_ref_run) epe_relaxation=.true.
        elseif(check_string(epe_task,task3) .and. check_string(epe_task,task4)) then
           operations_epe_lattice=.false.
           ewaldpc=.true.
           epe_embedding=.true.
           epe_relaxation=.true.
           use_epe_qm_references=.true.
           opt_and_relax=.true.
        elseif(check_string(epe_task,task3)) then
           operations_epe_lattice=.false.
           ewaldpc=.true.
           epe_embedding=.true.
           if(check_string(epe_task,subtask31)) ewaldpc=.false.
           if(check_string(epe_task,subtask32)) epe_embedding=.false.
           if(.not.ewaldpc .and. .not.epe_embedding) then
              call input_error("epe_read: namelist epe_data: either NO_EWALD or NO_EPE_ENV options can be done")
           end if
        elseif(check_string(epe_task,task4)) then
           operations_epe_lattice=.false.
           ewaldpc=.true.
           epe_embedding=.true.
           epe_relaxation=.true.
           use_epe_qm_references=.true.
           if(check_string(epe_task,subtask41)) no_relax=.true.
        else
           call input_error("epe_read: namelist epe_data: Wrong EPE_TASK")
        endif
        if(no_pg) operations_epe_lattice=.true.

        if(operations_epe_lattice) then
           operations_symm              = .false.
           operations_scf               = .false.
           operations_integral          = .false.
           operations_post_scf          = .false.
           operations_dipole            = .false.
           operations_gradients         = .false.
           operations_geo_opt           = .false.
#ifdef WITH_MOLMECH
           operations_qm_mm_new         = .false.
#endif
           operations_qm_mm             = .false.
           operations_symadapt_gx       = .false.
           operations_make_gx           = .false.
           operations_properties        = .false.
           operations_response          = .false.
           operations_core_density      = .false.
           operations_fitbasis_opt      = .false.
           operations_solvation_effect  = .false.
           operations_gtensor           = .false.
           operations_potential         = .false.
           operations_gx_test           = .false.
#ifdef WITH_MOLMECH
           operations_mol_mech          = .false.
#endif
        end if
#else
        if (nzepe < 0) call input_error( &
        "epe_read: namelist epe_data: nzepe < 0")
        if (nzepe > N_unique_at) call input_error( &
        "epe_read: namelist epe_data: nzepe > N_unique_atoms")
        if(nzepe > 0)  then 
           allocate(zepe(N_unique_at),stat=ewa_allocstat(1))
           if (ewa_allocstat(1) .gt. 0) call error_handler("epe_read: zepe allocate failed.")
           ewa_allocstat(1)=1
           zepe=0.0_r8_kind
        
           allocate(zcharge(nzepe),ncharge(nzepe),stat=ewa_allocstat(2))
           if (ewa_allocstat(2) .gt. 0) call error_handler("epe_read: zcharge allocate failed")
           ewa_allocstat(2)=1

           do i=1,nzepe
              call input_read_to_intermediate
              read(unit, fmt=*, iostat=status) ncharge(i),zcharge(i)
              if (status .gt. 0) call input_error("epe_read: ncharge, zcharge")
              if(ncharge(i) > N_unique_at) call input_error("epe_read: ncharge > N_unique_atoms")
           enddo
        
           do i=1,N_unique_at
              do j=1,nzepe
                 if(ncharge(j) == i) zepe(i)=zcharge(j)
              enddo
           enddo
        endif
#endif
     endif
   end subroutine epe_read

   subroutine epe_write(iounit)
     use echo_input_module, only: start, real, flag, intg, word, stop, &
          echo_level_full, word_format
     use operations_module, only: operations_qm_epe,operations_echo_input_level
     implicit none
     integer(kind=i4_kind), intent(in) :: iounit
     ! *** end of interface ***

#ifndef NEW_EPE
     integer (i4_kind) :: i, status
#endif

     if(operations_qm_epe) then
        word_format = '("    ",a," = ",a70:" # ",a)'
        call start("EPE_DATA","EPE_WRITE",iounit,operations_echo_input_level)
#ifdef NEW_EPE
        call   word("EPE_TASK      ",epe_task      ,df_epe_task      )
        call stop()
#else
        call   flag("EWALDPC       ",ewaldpc       ,df_ewaldpc       )
        call   flag("EPE_EMBEDDING ",epe_embedding ,df_epe_embedding )
        call   flag("EPE_RELAXATION",epe_relaxation,df_epe_relaxation)
        call   intg("NZEPE         ",nzepe         ,df_nzepe         )
!!$        call   intg("N_FIT_ATOMS   ",n_fit_atoms   ,df_n_fit_atoms   )
!!$        call   real("FIT_CHARGE    ",fit_charge    ,df_fit_charge    )
!!$        call   real("FIT_DISTANCE  ",fit_distance  ,df_fit_distance  )
!!$        call intg_d("ATOM_NUMBER   ",atom_number   ,df_atom_number   ,n_fit_atoms)
        call stop(empty_line=.false.)
        do i=1,nzepe
           write(iounit, fmt='(3x,i5,4x,f15.8)', iostat=status) ncharge(i),zcharge(i)
           if (status .gt. 0) call error_handler("epe_write: ncharge, zcharge.")
        enddo
        write(iounit, fmt='()', iostat=status)
        if (status .gt. 0) call error_handler("epe_write: error after ncharge, zcharge.")
        if(nzepe > 0) then
           deallocate(zcharge,ncharge,stat=ewa_allocstat(2))
           if (ewa_allocstat(2) .gt. 0) call error_handler("epe_write: zcharge deallocate failed.")
        endif
#endif
     endif
   end subroutine epe_write

 subroutine ewpc_bcast()
   !  Purpose:  broadcasts all information contained in ewpc_array(:)
   ! called by send_recv_init_options
   !** End of interface ********************************************************
   !------------ Modules used ------------------- ------------------------------
   use comm,                   only: comm_bcast                                &
                                   , comm_rank
   implicit none
   !------------ Declaration of local variables --------------------------------
   type(pointcharge_type), pointer :: pc
   integer(kind=i4_kind)           :: i_pc
   !------------ Executable code -----------------------------------------------
   !
   call comm_bcast( epe_relaxation    )
   call comm_bcast( start_regI_epevar )
   call comm_bcast( EWPC_N            )
   call comm_bcast( ex_gxepe          )
   !
   if ( comm_rank() /= 0 .and. EWPC_N .ne. 0 ) then
     allocate( ewpc_array(EWPC_N), stat=ewa_allocstat(3) )
     if (ewa_allocstat(3) .gt. 0) then
       call error_handler("ewpc_array allocate failed.")
     endif
     ewa_allocstat(3) = 1
   endif
   !
   ! loop over unique atoms
   do i_pc=1,EWPC_N
     !
     pc => ewpc_array(i_pc)
     call comm_bcast( pc%Z               )
     call comm_bcast( pc%C               )
     call comm_bcast( pc%N_equal_charges )
     call comm_bcast( pc%name            )
     !
     if ( comm_rank() /= 0 ) then
       allocate( pc%position(3,pc%N_equal_charges), stat=ewa_allocstat(4) )
       if( ewa_allocstat(4) .gt. 0 ) then
         call error_handler("4 ewpc_array allocate failed.")
       endif
       ewa_allocstat(4)=1
     endif
     !
     ! bcast atom coordinates of all equal atoms
     call comm_bcast( pc%position )
     pc%position_first_ec = pc%position(:, 1)
     !
   enddo ! i_pc=1,EWPC_N
   !
   !----------------------------------------------------------------------------
 end subroutine ewpc_bcast

 subroutine print_ewa_allocstat
  integer(kind=i4_kind) i
  do i=1,size(ewa_allocstat)
   if(ewa_allocstat(i).ne.0) print *,'error ewa_allocstat ne. 0', i
  enddo
 end subroutine print_ewa_allocstat

 subroutine ewpc_close
  use unique_atom_module,only: N_unique_atoms
 ! executed on  master and slaves
 integer(kind=i4_kind) i_pc,i_ua

    if(ewpc_n.ne.0.and.associated(ewpc_array)) then
     do i_pc=1,size(ewpc_array)
       if(associated(ewpc_array(i_pc)%position)) then
        deallocate(ewpc_array(i_pc)%position,stat=ewa_allocstat(4))
        if(ewa_allocstat(4)/=0) call error_handler("ewpc: deallocating pc position failed")
           ewa_allocstat(25)=0 ! pcs
           ewa_allocstat(26)=0 ! pcc
       endif
     end do
     deallocate(ewpc_array,stat=ewa_allocstat(3))
     if(ewa_allocstat(3)/=0) call error_handler("ewpc_close: deallocating ewpc_array &
          & failed")
    endif

        if(associated(gxepe_array)) then
         do i_ua=1,N_unique_atoms
           deallocate(gxepe_array(i_ua)%position,stat=ewa_allocstat(23))
           ASSERT(ewa_allocstat(23).eq.0)
         end do
           deallocate(gxepe_array,gxepe_impu,stat=ewa_allocstat(22))
           ASSERT(ewa_allocstat(23).eq.0)
         endif ! ex_gxepe


    call print_ewa_allocstat()

   end subroutine ewpc_close



  recursive subroutine task_epedata(task)
    use input_module, only: input_error
    use strings, only: tolower
    implicit none
    character(len=11), intent(in)  :: task
    ! *** end of interface ***

    character(len=11) :: newtask
    character(len=11) :: subtask
    integer(i4_kind)  :: I


    newtask = tolower(task)
    I = INDEX( newtask,',')
    if( I /= 0 )then
       subtask = newtask(1:I-1)
       call task_epedata(subtask)
       subtask = newtask(I+1:11)
       call task_epedata(subtask)
       RETURN
    endif

    select case (newtask)
    case ('use_eperef','relax_epe','make_eperef')
    epe_relaxation=.true.
    ewaldpc=.true.
    epe_embedding=.true.
    case ('fixed_epe')
    epe_relaxation=.false.
    ewaldpc=.true.
    epe_embedding=.true.
    end select

  end subroutine task_epedata

end module ewaldpc_module
