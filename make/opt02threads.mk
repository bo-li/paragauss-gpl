#-*- makefile -*-
#
# ParaGauss,  a program package  for high-performance  computations of
# molecular systems
#
# Copyright (C) 2014     T. Belling,     T. Grauschopf,     S. Krüger,
# F. Nörtemann, M. Staufer,  M. Mayer, V. A. Nasluzov, U. Birkenheuer,
# A. Hu, A. V. Matveev, A. V. Shor, M. S. K. Fuchs-Rohr, K. M. Neyman,
# D. I. Ganyushin,   T. Kerdcharoen,   A. Woiterski,  A. B. Gordienko,
# S. Majumder,     M. H. i Rotllant,     R. Ramakrishnan,    G. Dixit,
# A. Nikodem, T. Soini, M. Roderus, N. Rösch
#
# This program is free software; you can redistribute it and/or modify
# it under  the terms of the  GNU General Public License  version 2 as
# published by the Free Software Foundation [1].
#
# This program is distributed in the  hope that it will be useful, but
# WITHOUT  ANY   WARRANTY;  without  even  the   implied  warranty  of
# MERCHANTABILITY  or FITNESS FOR  A PARTICULAR  PURPOSE. See  the GNU
# General Public License for more details.
#
# [1] http://www.gnu.org/licenses/gpl-2.0.html
#
# Please see the accompanying LICENSE file for further information.
#
# Make sure to set the MPI libary path and the MPIRUN global environment variable before
# running a code with a executable compiled with this machine.inc
# LD_LIBRARY_PATH : /home/System/mpi/openmpi-1.4.2_wt/lib/
# MPIRUN         : /home/System/mpi/openmpi-1.4.2_wt/bin/mpirun
# on a bash shell this would be done by
# export LD_LIBRARY_PATH=/home/System/mpi/openmpi-1.4.2_wt/lib/
# export MPIRUN=/home/System/mpi/openmpi-1.4.2_wt/bin/mpirun
# on a tcsh shell it will be:
# setenv LD_LIBRARY_PATH /home/System/mpi/openmpi-1.4.2_wt/lib/
# setenv MPIRUN /home/System/mpi/openmpi-1.4.2_wt/bin/mpirun

### Machine Keyword for FPP
MACH =	LINUX

#### Directory where Sources are stored ####
ifndef BASEDIR
  BASEDIR = $(PWD)
endif

#### Directory where Scripts are stored #####
BINDIR =	$(BASEDIR)/bin


#### NAME OF EXECUTABLE ####
exe = mainscf_$(VERS)

#### COMPILER ####
## Fortran 90/77

MPIDIR = /nowhere/
GCCDIR = /usr/lib/gcc-snapshot/bin
GCCDIR = /usr/bin
ifeq ($(serial),1)
  FC = $(GCCDIR)/gfortran
else
  FC = mpif90
endif
F77 = $(FC)

ifeq ($(WITH_OLD_INPUT),0)
$(error NEW INPUT doesnt yet work with Gfortran 4.3, set WITH_OLD_INPUT=1 in Makefile)
endif

#### Extensions compiler understands:
src_ext = F90

#### Does compiler UPPERCASE module files:
UPPERCASE.mod = 0

# Command to compare MOD-files,
# GNU FORTRAN puts a date in the first line (approx 70 chars)
CMPMOD = cmp -s -i 100

#### COMPILER FLAGS ####
## F90BASEFLAGS free  form Fortran 90 flags (always used)
## FBASEFLAGS   fixed form Fortran 90 flags (always used)
## F90FLAGS    additonal Fortran 90 flags
## F90ALTFLAGS additonal Fortran 90 alternate flags (see makro ALTFLAGS below to see for which files)
## CCFLAGS  C compiler flags

#
# type "make NOOPT=1 modules/anything.compile"
# or add it to $(noopt_targets) in "misc.inc"
#
# -x f95 tells to not apply preprocessor to *.F90 files
F90BASEFLAGS = -x f95 -Wall #-fbounds-check #-pedantic-errors -Werror
FBASEFLAGS   = -x f95 -Wall #-fbounds-check #-pedantic-errors -Werror
optflags     = -O1 -g -std=gnu
optaltflags  = -O1 -g -std=gnu
dbgflags     = -O0 -g -std=gnu
F90FLAGS     = $(if $(NOOPT), $(dbgflags), $(optflags))
F90ALTFLAGS  = $(if $(NOOPT), $(dbgflags), $(optaltflags))
F77FLAGS     = $(optflags) $(FBASEFLAGS)
extraflags   =
staticflags  = -static
LINKFLAGS    = $(if $(STATIC), $(staticflags), )
# these are used in Make.rules:
FFLAGS       = $(F90BASEFLAGS)
FFLAGS      += $(if $(altflags), $(F90ALTFLAGS), $(F90FLAGS)) $(extraflags)

#modules/filename_module.o: extraflags=-std=gnu

## CPP/FPP preprocessor:
CPP = /lib/cpp
CPPUNDEF = -undef
CPPOPTIONS = $(CPPUNDEF) -traditional-cpp -P -C -I$(BASEDIR)/include

FPP = $(CPP)
FPPOPTIONS += $(CPPOPTIONS) -D_$(MACH)
#
# type "make DEBUG=1" to compile in debug features
# or add it to $(debug_targets) in "misc.inc"
#
FPPOPTIONS += $(if $(DEBUG), -DFPP_DEBUG=$(DEBUG), )
FPPOPTIONS += -DFPP_PARAGAUSS_VERS="\"$(paragauss_vers)\""
FPPOPTIONS += -DFPP_GFORTRAN_BUGS
# OpenMPI provides f90 interface, one can directly "use mpi":
FPPOPTIONS += -DUSE_MPI_MODULE
FPPOPTIONS += -DINTRINSIC_ISNAN
FPPOPTIONS += -DMAX_PATH=256
FPPOPTIONS += -DINTRINSIC_SECNDS -DINTRINSIC_ETIME
FPPOPTIONS += -DFPP_HAVE_FLUSH
FPPOPTIONS += -DFPP_HAVE_F2003_FLUSH


SETMTIME = touch -r


## C compiler:
ifeq ($(serial),1)
  CC = $(GCCDIR)/gcc
else
  CC = mpicc
endif
CCFLAGS = -Wall


#### LDFLAGS, LIBRARY-PATH ####

AR = ar
RANLIB = ranlib

MPIINCLUDE =    -I/home/System/mpi/openmpi-1.4.2_wt/include/
MPILIBS =    -L/home/System/mpi/openmpi-1.4.2_wt/lib -lmpi  #-lmpich
#LAPACKLIBS =	-L/home/matveev/cvs/lib/LAPACK -llapack_g95 -lblas_g95
LAPACKLIBS =	-llapack -lblas
#LAPACKLIBS =	-llapack -lg2c
#BLASLIBS =	-L$(HOME)/lib/ATLAS -lf77blas -latlas
#BLASLIBS =	-L$(ABSOFT)/lib -L$(ABSOFT)/extras/ATLAS/Linux_INTEL32SSE2 -lf77blas -latlas
BLASLIBS =	#-lblas
# NAG, Absoft provide them for system()/etime() calls:
#YSTEMLIBS =	$(MPILIBS) -L$(ABSOFT)/lib -lU77 -lV77 -lm
SYSTEMLIBS =
PVMINCLUDE =	/usr/lib/pvm3/include
PVMLIBS =	-lfpvm3 -lpvm3

# dynamic load balancing (DLB) module comes with several variants adapted to
# different needs, see dlb module README
# The variant 2 needs mulit-threaded MPI, thus different MPI backend than the
# standard one
DLB_VARIANT = 0

ifeq ($(WITH_SCALAPACK),1)
  BLACS_LIB = -lblacs
  SCALAPACK_LIB = -lscalapack
endif

ifeq ($(serial),1)
COMMINCLUDE =
COMMLIBS =
COMMDIR =	comm/serial_dir
else
COMMINCLUDE =	$(MPIINCLUDE)
COMMLIBS =	$(MPILIBS)
COMMDIR =	comm/mpi_dir
endif

#
# These are, eventually, absolute paths:
#
DIRS = $(patsubst %,$(BASEDIR)/%,$(dirs))

# (note -p/-I syntax on different platforms/compilers)
# -I$(COMMINCLUDE) only needed for mpif.h/fpvm3.h,
# not needed with mpif90 script (as on linux):
INCLUDE = $(patsubst %,-I%,$(DIRS)) $(COMMINCLUDE)

# include path for C files:
CINCLUDE =	-I$(BASEDIR)/$(COMMDIR) $(COMMINCLUDE)

# The one with underscores:
COMMCDIR =	comm/mpi_dir

# libraries, possibly classified by type:
LIBS       = \
	$(SCALAPACK_LIB) $(BLACS_LIB) \
	$(LAPACKLIBS) $(BLASLIBS) \
	$(COMMLIBS) $(SYSTEMLIBS)

ifeq ($(WITH_GUILE),1)
    INCLUDE += -I$(BASEDIR)/guile
    LIBS += -lguile
endif

# FIXME: objects that require F90ALTFLAGS:
f90objs_altflags = $(libttfs_opt.a)
