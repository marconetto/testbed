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
  module load OpenMPI/4.1.6-GCC-13.2.0
  # ls -l /cvmfs/software.eessi.io/versions/2023.06/software/linux/x86_64/amd/zen3/software/OpenMPI/4.1.5-GCC-12.3.0/bin/orted
  # module load OpenFOAM/10-foss-2023a
  source "$FOAM_BASH"

  # IFS=';' read -ra ADDR <<<"$AZ_BATCH_NODE_LIST"
  # for i in "${ADDR[@]}"; do
  #   echo "ssh $i which orted"
  #   ssh "$i" which orted
  # done

  # cp -r "$FOAM_TUTORIALS"/incompressible/simpleFoam/motorBike/* .
  cp -r "$FOAM_TUTORIALS"/incompressibleFluid/motorBike/motorBike/* .
  chmod -R u+w .

  NP=$(($NODES * $PPN))
  echo "Running OpenFOAM with $NP processes..."

  export UCX_NET_DEVICES=mlx5_ib0:1
  export OMPI_MCA_pml=ucx

  # allow flags to be added to the mpirun command through FOAM_MPIRUN_FLAGS environment variable
  sed -i '/RunFunctions/a source <(declare -f runParallel | sed "s/mpirun/mpirun \\\$FOAM_MPIRUN_FLAGS/g")' Allrun
  sed -i 's#/bin/sh#/bin/bash#g' Allrun

  export FOAM_MPIRUN_FLAGS="--hostfile $AZ_HOSTFILE_PATH $(env | grep 'WM_\|FOAM_' | cut -d'=' -f1 | sed 's/^/-x /g' | tr '\n' ' ') -x PATH -x LD_LIBRARY_PATH -x MPI_BUFFER_SIZE -x UCX_IB_MLX5_DEVX=n -x UCX_POSIX_USE_PROC_LINK=n --report-bindings --verbose --map-by core --bind-to core "
  echo "$FOAM_MPIRUN_FLAGS"

  ########################### APP EXECUTION #####################################
  [ -z "$BLOCKMESH_DIMENSIONS" ] && BLOCKMESH_DIMENSIONS="20 8 8"

  # X=$(($NP / 4))
  # Y=2
  # Z=2

  # Determine X,Y,Z based on total cores
  if [ "$(($PPN % 4))" == "0" ]; then
    X=$(($NP / 4))
    Y=2
    Z=2
  elif [ "$(($PPN % 6))" == "0" ]; then
    X=$(($NP / 6))
    Y=3
    Z=2
  elif [ "$(($PPN % 9))" == "0" ]; then
    X=$(($NP / 9))
    Y=3
    Z=3
  else
    echo "Incompataible value of PPN: $PPN. Try something that is divisable by 4,6, or 9"
    return 1
  fi
  echo "X: $X, Y: $Y, Z: $Z"

  foamDictionary -entry numberOfSubdomains -set "$NP" system/decomposeParDict
  foamDictionary -entry "hierarchicalCoeffs/n" -set "( $X $Y $Z )" system/decomposeParDict
  foamDictionary -entry blocks -set "( hex ( 0 1 2 3 4 5 6 7 ) ( $BLOCKMESH_DIMENSIONS ) simpleGrading ( 1 1 1 ) )" system/blockMeshDict

  foamDictionary \
    -entry "castellatedMeshControls/maxGlobalCells" \
    -set 300000000 \
    system/snappyHexMeshDict

  foamDictionary \
    -entry "castellatedMeshControls/maxLocalCells" \
    -set 2000000 \
    system/snappyHexMeshDict

  time ./Allrun

  ########################### TEST OUTPUT #####################################
  ########################### TEST OUTPUT #####################################
  LOGFILE="log.foamRun"
  LOGFILE2="log.snappyHexMesh"
  if [[ -f $LOGFILE && $(tail -n 1 "$LOGFILE") == 'Finalising parallel run' ]] &&
    [[ -f $LOGFILE2 && $(tail -n 1 "$LOGFILE2") == 'Finalising parallel run' ]]; then
    echo "Simulation completed"
    # reconstructPar -constant
    # touch case.foam
    FOAMRUNCLOCKTIME=$(cat log.foamRun | grep ClockTime | tail -n 1 | awk {'print $7 '})
    FOAMMESHCELLS=$(cat log.snappyHexMesh | grep "Snapped mesh : cells:" | grep -o 'cells:[0-9]*' | sed 's/cells://')
    echo "HPCADVISORVAR FOAMRUNCLOCKTIME=$FOAMRUNCLOCKTIME"
    echo "HPCADVISORVAR FOAMMESHCELLS=$FOAMMESHCELLS"
    echo "HPCADVISORVAR APPEXECTIME=$FOAMRUNCLOCKTIME"
    return 0
  else
    echo "Simulation failed"
    return 1
  fi

}
