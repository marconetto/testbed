#!/usr/bin/env bash

export MPI_EXE=mpi_matrix_mult

[[ -f /etc/bashrc ]] && . /etc/bashrc

source /etc/profile.d/modules.sh
module load gcc-9.2.0
module load mpi/openmpi

main_setup() {
  echo "main setup: $(pwd)"

  set -x

  CODEURL=https://raw.githubusercontent.com/marconetto/testbed/main/mpi_matrix_mult.c
  MPI_CODE=$(basename $CODEURL)
  curl -sL $CODEURL -o "$MPI_CODE"

  mpicc -o ${MPI_EXE} "${MPI_CODE}"
  if [[ $? -ne 0 ]]; then
    echo "Compilation failed"
    return 1
  fi
  return 1

}

main_run() {
  echo "main run: $(pwd)"
  cp "../${MPI_EXE}" .

  [[ -z $APPINTERACTIONS ]] && APPINTERACTIONS=5
  [[ -z $APPMATRIXSIZE ]] && APPMATRIXSIZE=1000

  NP=$(($NODES * $PPN))
  APPEXECUTABLE=$(realpath ${MPI_EXE})
  mpirun -np $NP --host "$AZ_HOST_LIST_PPN" --map-by ppr:"${PPN}":node "$APPEXECUTABLE" "${APPMATRIXSIZE}" "${APPINTERACTIONS}"
}
