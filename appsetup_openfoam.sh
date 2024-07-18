#!/usr/bin/env bash

hpcadvisor_setup() {
  echo "main setup $(pwd)"
  echo "data comes from openfoam installation...skipping"
  return 0
}

hpcadvisor_run() {
  echo "main run $(pwd)"

  source /cvmfs/software.eessi.io/versions/2023.06/init/bash
  module load OpenFOAM
  source "$FOAM_BASH"

  which mpirun
  which simpleFoam

  cp -r "$FOAM_TUTORIALS"/incompressibleFluid/motorBike/motorBike/* .
  chmod -R u+w .

  NP=$(($NODES * $PPN))

  echo "Running OpenFOAM with $NP processes ..."
  export UCX_NET_DEVICES=mlx5_ib0:1
  export OMPI_MCA_pml=ucx

  # allow flags to be added to the mpirun command through FOAM_MPIRUN_FLAGS environment variable
  sed -i '/RunFunctions/a source <(declare -f runParallel | sed "s/mpirun/mpirun \\\\$FOAM_MPIRUN_FLAGS/g")' Allrun

  sed -i 's#/bin/sh#/bin/bash#g' Allrun
  sed -i '/bash/a set -x' Allrun

  export FOAM_MPIRUN_FLAGS="--hostfile $AZ_HOSTFILE_PATH $(env | grep 'WM_\|FOAM_' | cut -d'=' -f1 | sed 's/^/-x /g' | tr '\n' ' ') -x PATH -x LD_LIBRARY_PATH -x MPI_BUFFER_SIZE -x UCX_IB_MLX5_DEVX=n -x UCX_POSIX_USE_PROC_LINK=n --report-bindings --verbose --map-by core --bind-to core "
  echo "$FOAM_MPIRUN_FLAGS"

  ########################### APP EXECUTION #####################################
  # BLOCKMESH_DIMENSIONS="120 48 48"
  # BLOCKMESH_DIMENSIONS="60 24 24"
  # BLOCKMESH_DIMENSIONS="80 32 32"
  BLOCKMESH_DIMENSIONS="40 16 16"
  # BLOCKMESH_DIMENSIONS="20 8 8" # 0.35M cells

  X=$(($NP / 4))
  Y=2
  Z=2

  foamDictionary -entry numberOfSubdomains -set "$NP" system/decomposeParDict
  foamDictionary -entry "hierarchicalCoeffs/n" -set "( $X $Y $Z )" system/decomposeParDict
  foamDictionary -entry blocks -set "( hex ( 0 1 2 3 4 5 6 7 ) ( $BLOCKMESH_DIMENSIONS ) simpleGrading ( 1 1 1 ) )" system/blockMeshDict

  cat Allrun
  time ./Allrun

  ########################### TEST OUTPUT #####################################
  LOGFILE="log.foamRun"
  if [[ -f $LOGFILE && $(tail -n 1 "$LOGFILE") == 'Finalising parallel run' ]]; then
    echo "Simulation completed"
    #  reconstructPar -constant
    touch case.foam
    FOAMRUNCLOCKTIME=$(cat log.foamRun | grep ClockTime | tail -n 1 | awk {'print $7 '})
    echo "HPCADVISORVAR FOAMRUNCLOCKTIME=$FOAMRUNCLOCKTIME"
    echo "HPCADVISORVAR APPEXECTIME=$FOAMRUNCLOCKTIME"
    return 0
  else
    echo "Simulation failed"
    return 1
  fi
}
