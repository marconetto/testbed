#!/usr/bin/env bash

export MPI_EXE=mpi_matrix_mult
export MPI_CODE=mpi_matrix_mult.c
export MPI_EXE_PATH="${AZ_BATCH_NODE_MOUNTS_DIR}/data/"

[[ -f /etc/bashrc ]] && . /etc/bashrc

source /etc/profile.d/modules.sh
module load gcc-9.2.0
module load mpi/hpcx

main_setup() {
  echo "main setup"

  set -x

  CODEURL=https://raw.githubusercontent.com/marconetto/testbed/main/mpi_matrix_mult.c
  curl -sL $CODEURL -o "$MPI_EXE_PATH"/$MPI_CODE

  which mpicc

  mpicc -o ${MPI_EXE} ${MPI_CODE}
  ls -l ${MPI_EXE}
}

main_run() {
  echo "main run $(pwd)"
  cp "../${MPI_EXE}" .

  [[ -z $APPINTERACTIONS ]] && APPINTERACTIONS=5
  [[ -z $APPMATRIXSIZE ]] && APPMATRIXSIZE=1000

  NP=$(($NODES * $PPN))
  set
  set -x
  APPEXECUTABLE=$(realpath ${MPI_EXE})
  mpirun -np $NP --host "$AZ_HOST_LIST_PPN" --map-by ppr:"${PPN}":node "$APPEXECUTABLE" "${APPMATRIXSIZE}" "${APPINTERACTIONS}"
}
