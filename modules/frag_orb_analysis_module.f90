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
!=====================================================================
! Public interface of module
!=====================================================================
module  frag_orb_analysis_module
  !-------------------------------------------------------------------
  !
  !  Purpose: module performs a fragment_orbital_analysis
  !           every molecular system can be divided into
  !           arbitrary number of fragments. Every atom
  !           of the system must appear in exactly one fragment.
  !           the fragments have to be calculated with the same
  !           input parameters and the same geometry as the complete
  !           system. For every fragment a file saved_fragment.dat<i>,
  !           with i the number of the fragment must exist in the input
  !           directory. This file is generated by setting the switch
  !           save_as_fragment in namelist recover_options to true.
  !           For the complete system the file saved_eigenvec.dat must
  !           exist and contain all eigenvectors ( save_eigenvec_all=t).
  !           As a result one gets Populations in terms of the fragment
  !           orbitals and the corresponding MO coefficients.
  !
  !           input switches:
  !
  !           n_fragments: number of fragments
  !           pop_limit  : only contributions greater then
  !                        pop_limit will be shown in the output
  !           eig_min
  !           eig_max:     only orbitals with energies lieing between
  !                        will be listed in the output
  !           n_atoms:     number of atoms in the fragment
  !  Module called by: main_master
  !
  !  References:
  !
  !
  !  Author: MS
  !  Date: 12/97
  !
  !-------------------------------------------------------------------
  !== Interrupt of public interface of module ========================
  !-------------------------------------------------------------------
  ! Modifications
  !-------------------------------------------------------------------
  !
  ! Modification (Please copy before editing)
  ! Author: ...
  ! Date:   ...
  ! Description: ...
  !
  !-------------------------------------------------------------------
  use type_module ! type specification parameters
  use datatype
  use occupation_module
  use density_data_module
  use symmetry_data_module
  use unique_atom_module
  use overlap_module
  use iounitadmin_module
  use operations_module, only: operations_echo_input_level, operations_scf
  use eigen_data_module
  implicit none
  save            ! save all variables defined in this module
  private         ! by default, all names are private
  !== Interrupt end of public interface of module ====================

  type fragment_type ! used to describe fragments
     !in fragment orbital analysis
     integer(kind=i4_kind)              :: n_atoms  ! number of atoms in this fragment
     integer(kind=i4_kind), allocatable :: atoms(:) ! indices of fragment atoms
     logical                            :: active   ! perform FMO on fragment
  end type fragment_type

  !------------ public functions and subroutines ---------------------
  public frag_orb_analysis_read, frag_orb_analysis_write, frag_orb_analysis_main
  !external dgeco, dgedi !!!!!!!!!!!!!!!!!!!!!

  !===================================================================
  ! End of public interface of module
  !===================================================================

  !------------ Declaration of constants and variables ---------------

  type(pop_store_type), allocatable :: pop_store(:,:,:)
  ! pop_store(n_irrep,n_spin,n_fragments)

  type(fragment_type), allocatable :: fragments(:) ! store information
                                                   ! about fragments

  integer(kind=i4_kind) :: df_n_fragments=0, &
                           df_n_atoms=0

  real(kind=r8_kind)    :: df_pop_limit=0.01_r8_kind,   &
                           df_eig_min=-100.0_r8_kind,   &
                           df_eig_max=10.0_r8_kind

  integer(kind=i4_kind) :: n_fragments, & ! number of fragments
                           n_atoms         ! number of atoms per fragment

  real(kind=r8_kind)    :: pop_limit, &   ! minimum contripution,
                                           ! which will be displayed
                           eig_min,     &  ! minimal value of eigenvalue,
                                           ! for wich frag_orb_anal will be
                                           ! performed ( in ev)
                           eig_max

  namelist /frag_orb_analysis/ n_fragments, pop_limit, eig_min, eig_max

  namelist /fragment/ n_atoms

  !-------------------------------------------------------------------
  !------------ Subroutines ------------------------------------------
contains


  !*************************************************************

  subroutine frag_orb_analysis_read()
    ! purpose: read in input
    !
    !** End of interface *****************************************
    !------------ Modules used ----------------------------------
    use input_module
    integer :: unit, status, alloc_stat, i_frag, i_atom
    logical :: atom_check(n_unique_atoms), true=.true.
    !------------ Executable code ------------------------------------
    ! population_level = df_population_level
    n_fragments=df_n_fragments
    pop_limit=df_pop_limit
    eig_min=df_eig_min
    eig_max=df_eig_max
    atom_check=.false.
    if ( input_line_is_namelist("frag_orb_analysis") ) then
       call input_read_to_intermediate
       unit = input_intermediate_unit()
       read(unit, nml=frag_orb_analysis, iostat=status)
       if (status .gt. 0) call input_error( &
            "frag_orb_analysis_read: namelist frag_orb_analysis")
    endif
    if(n_fragments<0.or.n_fragments>n_unique_atoms) &
         call input_error(&
         'frag_orb_analysis_read: sensless value for n_fragments')
    if(pop_limit<0.0_r8_kind.or.pop_limit>1.0_r8_kind) &
         call input_error(&
         'frag_orb_analysis_read: sensless value for pop_limit')
    if(eig_min>=eig_max) call input_error(&
         'frag_orb_analysis_read: sensless value for eig_min or eig_max')
    eig_min=eig_min/27.211652_r8_kind
    eig_max=eig_max/27.211652_r8_kind
    if(n_fragments>0) then
       allocate(fragments(n_fragments), stat=alloc_stat)
       if(alloc_stat/=0) call error_handler(&
            'frag_orb_analysis_read: allocating fragments failed')
       do i_frag=1,n_fragments
          if ( input_line_is_namelist("fragment") ) then
             call input_read_to_intermediate
             unit = input_intermediate_unit()
             read(unit, nml=fragment, iostat=status)
             if (status .gt. 0) call input_error( &
                  "frag_orb_analysis_read: namelist frag_orb_analysis")
             if(n_atoms < 0.or.n_atoms > n_unique_atoms) &
                  call input_error(&
                  'frag_orb_analysis_read: n_atoms is senseless')
             fragments(i_frag)%n_atoms=n_atoms
             allocate(fragments(i_frag)%atoms(n_atoms), stat=alloc_stat)
             if(alloc_stat/=0) call error_handler(&
                  'frag_orb_analysis_read: allocating fragments%atoms failed')
              call input_read_to_intermediate
             unit = input_intermediate_unit()
             read(unit,*,iostat=status)  fragments(i_frag)%atoms
             if (status .gt. 0) call input_error( &
                  "frag_orb_analysis_read: reading atoms")
             do i_atom=1,n_atoms
                if(fragments(i_frag)%atoms(i_atom)<1.or.&
                     fragments(i_frag)%atoms(i_atom)>n_unique_atoms) then
                   call input_error(&
                        'frag_orb_analysis_read: atom is senseless')
                else
                   atom_check(fragments(i_frag)%atoms(i_atom))=atom_check(fragments(i_frag)%atoms(i_atom))&
                        .neqv.true
                end if
             end do
          else
             call input_error(&
                  'frag_orb_analysis_read: namelist fragment required')
          endif
       end do
       if(.not.all(atom_check)) &
            call input_error(&
            'frag_orb_analysis_read: error in definition of fragments')
    end if
  end subroutine frag_orb_analysis_read

  !*************************************************************

  subroutine frag_orb_analysis_write(iounit)
    !
    ! Write input to iounit in input format.
    !
    use echo_input_module
    implicit none
    integer, intent(in) :: iounit
    !** End of interface *****************************************

    integer(kind=i4_kind) :: i_frag

    call start("FRAG_ORB_ANALYSIS","FRAG_ORB_ANALYSIS_WRITE", &
         iounit,operations_echo_input_level)
    call intg("N_FRAGMENTS",n_fragments,df_n_fragments)
    call real("POP_LIMIT  ",pop_limit, df_pop_limit)
    call real("EIG_MIN    ",eig_min*27.211652_r8_kind,df_eig_min)
    call real("EIG_MAX    ",eig_max*27.211652_r8_kind,df_eig_max)
    call stop()
    if(n_fragments>0) then
       do i_frag=1,n_fragments
          call start("FRAGMENT","FRAG_ORB_ANALYSIS_WRITE", &
               iounit,operations_echo_input_level)
          call intg("N_ATOMS",fragments(i_frag)%n_atoms,df_n_atoms)
          call stop()
          write(iounit,'(20I4)') fragments(i_frag)%atoms
       end do
    end if
  end subroutine frag_orb_analysis_write

  !*************************************************************


  subroutine frag_orb_analysis_main()
    !  Purpose: main subroutine for doing a population analysis
    !** End of interface *****************************************
    !------------ Modules used ------------------- ---------------
    use filename_module
    use orbitalprojection_module
    use symmetry_data_module
    use readwriteblocked_module
    use unique_atom_module
    use occupation_module
    use datatype
    use math_module
    !------------ Declaration of local variables ---------------------
    type(readwriteblocked_tapehandle)   :: th
    integer(kind=i4_kind) :: n_spin, i_frag, i_ir, dimi, i_atom, atom_index, &
         n_ir, skip_length, alloc_stat, index, &
         index_start, index_end, i_start, i_end, i_l, i_spin, i_orb, orb_index,&
         i_eig, i, orb_index_keep, counter, i_i
    integer(kind=i4_kind),allocatable :: dim_irrep(:,:), &
         ipvt(:)
    real(kind=r8_kind), allocatable :: buffer(:), overlap_frag(:,:), &
         eig_frag(:,:), help_mat(:,:), eigvec_tot(:,:,:), work(:), z(:)
    real(kind=r8_kind) :: popul
    type(arrmat3), allocatable :: eigvec_frag(:,:)
    character(len=7) :: chfrag

    external error_handler
    intrinsic transpose
    !------------ Executable code ------------------------------------
    write(output_unit,'(A30)') 'Fragment orbital analysis:'
    write(output_unit,'(A22,i4)') 'Number of fragments:',n_fragments
    do i_frag=1,n_fragments
       write(output_unit,*) 'Fragment',i_frag,'consists of',fragments(i_frag)%n_atoms,'atoms'
       write(output_unit,'(20I4)') fragments(i_frag)%atoms
    end do
    write(output_unit,'(A12,F8.4)') 'eig_min:',eig_min
    write(output_unit,'(A12,F8.4)') 'eig_max:',eig_max
    write(output_unit,'(A12,F8.4)') 'pop_limit:',pop_limit

    n_spin=ssym%n_spin
        allocate( &
         dim_irrep(ssym%n_irrep,n_fragments), &
         eigvec_frag(ssym%n_irrep,n_fragments), &
         pop_store(ssym%n_irrep,n_spin,n_fragments), stat=alloc_stat)
    if(alloc_stat/=0) call error_handler( &
         'fragment_orbital_analysis: allocating dim_irrep')
    n_spin=ssym%n_spin
    do i_frag=1,n_fragments
       ! first we calculate the dimension of the irreps
       do i_ir=1,ssym%n_irrep
          dimi=0
          do i_atom=1,fragments(i_frag)%n_atoms
             ! loop over angular momentum
             atom_index=fragments(i_frag)%atoms(i_atom)
             do i_l=0,unique_atoms(atom_index)%lmax_ob
                dimi=dimi+&
                     unique_atoms(atom_index)%symadapt_partner(i_ir,i_l)%&
                     N_independent_fcts*(unique_atoms(atom_index)%l_ob(i_l)%&
                     N_uncontracted_fcts + unique_atoms(atom_index)%l_ob(i_l)%&
                     N_contracted_fcts)
             enddo! i_l
          end do! loop over atoms
          dim_irrep(i_ir,i_frag)=dimi
       end do! loop over irreps
       ! now determine sum of non empty irreps and allocate
       n_ir=0
       do i_ir=1,ssym%n_irrep
          if(dim_irrep(i_ir,i_frag)>0) then
             n_ir=n_ir+1
             allocate(eigvec_frag(i_ir,i_frag)%m(&
                  dim_irrep(i_ir,i_frag),dim_irrep(i_ir,i_frag),n_spin),&
                  stat=alloc_stat)
             if(alloc_stat/=0) call error_handler(&
                  'fragment_orbital_analysis: allocating eigvec_frag')
          end if
       end do
       ! now read eigenvectors from file
       write(chfrag,'(i4)') i_frag
       chfrag=adjustl(chfrag)
       call readwriteblocked_startread(trim(inpfile('saved_fragment.dat'//trim(chfrag))),  &
            th,variable_length=.true.)
       ! first we have to skip the parts we don`t need
       skip_length=1+n_spin*n_ir*2
       allocate(buffer(skip_length), stat=alloc_stat)
       if(alloc_stat/=0) call error_handler(&
            'fragment_orbital_analysis: allocating buffer 1')
       call readwriteblocked_read(buffer,th)
       deallocate(buffer, stat=alloc_stat)
       if(alloc_stat/=0) call error_handler(&
            'fragment_orbital_analysis: deallocating buffer 1')
       do i_ir=1,ssym%n_irrep
          if(dim_irrep(i_ir,i_frag)>0) then
             skip_length=dim_irrep(i_ir,i_frag)*2
             allocate(buffer(skip_length), stat=alloc_stat)
             if(alloc_stat/=0) call error_handler(&
                  'fragment_orbital_analysis: allocating buffer 2')
             do i_spin=1,n_spin
                call readwriteblocked_read(buffer,th)
                do i_orb=1,dim_irrep(i_ir,i_frag)
                   call readwriteblocked_read(eigvec_frag(i_ir,i_frag)%m(:,i_orb,i_spin),th)
                end do
             end do
             deallocate(buffer, stat=alloc_stat)
             if(alloc_stat/=0) call error_handler(&
                  'fragment_orbital_analysis: deallocating buffer 2')
          end if
       end do
       call readwriteblocked_stopread(th)
    end do! loop over fragments
    ! now we have everything read in and we start building the eigenvectors
    ! from the fragment orbitals
    do i_ir=1,ssym%n_irrep
       ! now we have to make some allocations
       do i_spin=1,n_spin
          counter=0
          do i_eig=1,ssym%dim(i_ir)
             if(eigval(i_ir)%m(i_eig,i_spin)>eig_min.and.&
                  eigval(i_ir)%m(i_eig,i_spin)<eig_max) counter=counter+1
          end do
          do i_frag=1,n_fragments
             allocate(pop_store(i_ir,i_spin,i_frag)%eig_cont(counter), &
                  stat=alloc_stat)
             if(alloc_stat/=0) call error_handler(&
                  'fragment_orbital_analysis: allocating pop_store%m')
             pop_store(i_ir,i_spin,i_frag)%eig_cont(:)%sum=0.0_r8_kind
          end do
       end do
       allocate( help_mat(ssym%dim(i_ir),ssym%dim(i_ir)), &
            overlap_frag(ssym%dim(i_ir),ssym%dim(i_ir)), &
            eig_frag(ssym%dim(i_ir),ssym%dim(i_ir)), &
            eigvec_tot(ssym%dim(i_ir),ssym%dim(i_ir),n_spin), &
            work(ssym%dim(i_ir)), ipvt(ssym%dim(i_ir)), &
            z(ssym%dim(i_ir)), stat=alloc_stat)
       if(alloc_stat/=0) call error_handler(&
            'fragment_orbital_analysis: allocating help_mat')
       do i_spin=1,n_spin
          orb_index=1
          orb_index_keep=1
          overlap_frag=0.0_r8_kind
          eig_frag=0.0_r8_kind
          eigvec_tot=0.0_r8_kind
          do i_frag=1,n_fragments
             if(dim_irrep(i_ir,i_frag)> 0) then
                index_start=1
                do i_atom=1,fragments(i_frag)%n_atoms
                   atom_index=fragments(i_frag)%atoms(i_atom)
                   orb_index=orb_index_keep
                   i_start=orbitalprojection_ob(i_ir,0,atom_index)
                   if(atom_index==n_unique_atoms) then
                      i_end=ssym%dim(i_ir)
                   else
                      i_end=orbitalprojection_ob(i_ir,0,atom_index+1)-1
                   end if
                   index_end=index_start+i_end-i_start
                   do i_orb=1,dim_irrep(i_ir,i_frag)
                      eigvec_tot(i_start:i_end,orb_index,i_spin)=&
                           eigvec_frag(i_ir,i_frag)%m(index_start:index_end,i_orb,i_spin)
                      orb_index=orb_index+1
                   end do! loop over i_orb
                   index_start=index_end+1
                end do! loop over atoms
                orb_index_keep=orb_index
             end if
          end do! loop over fragments
          ! now eigvec_tot is completely assembled and we can start building
          ! eigenvectors and overlap matrix in fragment orbitals
          help_mat=matmul(overlap(i_ir)%m,eigvec_tot(:,:,i_spin))
          overlap_frag=matmul(transpose(eigvec_tot(:,:,i_spin)),help_mat)
          ! eig_frag=matmul(eigvec(i_ir)%m(:,:,i_spin)),eigvec_tot(:,:,i_spin))
          ! now we invert the matrix eigvec_tot
          !call dgeco(eigvec_tot(1,1,i_spin),ssym%dim(i_ir),ssym%dim(i_ir),ipvt,rcond,z)
          !call dgedi(eigvec_tot(1,1,i_spin),ssym%dim(i_ir),ssym%dim(i_ir), ipvt, det, work, 1_i4_kind)
          call invert_matrix(ssym%dim(i_ir),eigvec_tot(:,:,i_spin))
          eig_frag=matmul(eigvec_tot(:,:,i_spin),eigvec(i_ir)%m(:,:,i_spin))
          ! now we can allready make a population analysis with the new orbitals
          counter=0
          do i_eig=1,ssym%dim(i_ir)
             ! check if eigenvalue is in the allowed range
             if(eigval(i_ir)%m(i_eig,i_spin)>eig_min.and.&
                  eigval(i_ir)%m(i_eig,i_spin)<eig_max) then
                counter=counter+1
                index=1
                do i_frag=1,n_fragments
                   allocate(pop_store(i_ir,i_spin,i_frag)%eig_cont(counter)%index(dim_irrep(i_ir,i_frag)), &
                        pop_store(i_ir, i_spin, i_frag)%eig_cont(counter)%pop(dim_irrep(i_ir,i_frag)), &
                        pop_store(i_ir, i_spin, i_frag)%eig_cont(counter)%coeff(dim_irrep(i_ir,i_frag)), &
                        stat=alloc_stat)
                   if(alloc_stat/=0) call error_handler(&
                        'fragment_orbital_analysis: allocation pop_store(i_ir)%eig_cont(counter)%index')
                   pop_store(i_ir,i_spin,i_frag)%eig_cont(counter)%n_cont=0
                   do i_i=1,dim_irrep(i_ir,i_frag)
                      popul=0.0_r8_kind
                      do i=1,ssym%dim(i_ir)
                         popul=popul+eig_frag(i,i_eig)*overlap_frag(i,index)
                      end do
                      popul=popul*eig_frag(index, i_eig)
                      ! sum up
                      pop_store(i_ir,i_spin,i_frag)%eig_cont(counter)%sum=&
                           pop_store(i_ir,i_spin,i_frag)%eig_cont(counter)%sum+popul
                      if(abs(popul)>pop_limit) then
                         pop_store(i_ir,i_spin,i_frag)%eig_cont(counter)%&
                              n_cont=pop_store(i_ir,i_spin,i_frag)%eig_cont(counter)%n_cont+1
                         pop_store(i_ir,i_spin,i_frag)%eig_cont(counter)%&
                              pop(pop_store(i_ir,i_spin,i_frag)%eig_cont(counter)%n_cont)=popul
                         pop_store(i_ir,i_spin,i_frag)%eig_cont(counter)%&
                              index(pop_store(i_ir,i_spin,i_frag)%eig_cont(counter)%n_cont)=i_i
                         pop_store(i_ir,i_spin,i_frag)%eig_cont(counter)%&
                              coeff(pop_store(i_ir,i_spin,i_frag)%eig_cont(counter)%n_cont)=eig_frag(index, i_eig)
                      end if
                      index=index+1
                   end do! i_i
                end do! i_frag
             end if! eigval
          end do! i_eig
       end do! spin
       ! do deallocations
       deallocate(help_mat, overlap_frag, eig_frag, eigvec_tot, &
            z, work, ipvt, stat= alloc_stat)
       if(alloc_stat/=0) call error_handler( &
            'fragment_orbital_analysis: deallocation help_mat')
    end do! loop over irreps
    ! now we simply have to print the spectrum
    call occupation_print_popspectrum(pop_store=pop_store,eig_min=eig_min,eig_max=eig_max)
    ! do final deallocations
    do i_ir=1,ssym%n_irrep
       do i_spin=1,n_spin
          do i_frag=1,n_fragments
             do i_eig=1,size(pop_store(i_ir,i_spin,i_frag)%eig_cont)
                deallocate(pop_store(i_ir,i_spin,i_frag)%eig_cont(i_eig)%index,&
                  pop_store(i_ir,i_spin,i_frag)%eig_cont(i_eig)%pop,&
                  pop_store(i_ir,i_spin,i_frag)%eig_cont(i_eig)%coeff,&
                  stat=alloc_stat)
                if(alloc_stat/=0) call error_handler( &
                     'fragment_orbital_analysis: deallocate pop_store%eig_cont%index')
             end do
             deallocate(pop_store(i_ir,i_spin,i_frag)%eig_cont,&
                  stat=alloc_stat)
             if(alloc_stat/=0) call error_handler( &
                  'fragment_orbital_analysis: deallocate pop_store%eig_cont')
          enddo
       end do
       do i_frag=1,n_fragments
          if(dim_irrep(i_ir,i_frag)>0) then
          deallocate(eigvec_frag(i_ir,i_frag)%m,stat=alloc_stat)
          if(alloc_stat/=0) call error_handler( &
               'fragment_orbital_analysis: deallocate eigvec_frag%m')
          endif
       end do
    end do
    do i_frag=1,n_fragments
       deallocate(fragments(i_frag)%atoms,stat=alloc_stat)
       if(alloc_stat/=0) call error_handler( &
            'fragment_orbital_analysis: deallocate fragments%atoms')
    end do
    deallocate(pop_store,dim_irrep, &
         eigvec_frag, fragments, stat=alloc_stat)
    if(alloc_stat/=0) call error_handler( &
         'fragment_orbital_analysis: deallocate pop_store')
  end subroutine frag_orb_analysis_main

  !*************************************************************

  !--------------- End of module -------------------------------------
end module frag_orb_analysis_module
