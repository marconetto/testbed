#!/usr/bin/env bash

# based on: https://github.com/kaneuffe/azure-batch-workshop

echo "Creating run_mpi.sh file"



MPI_EXE=mpi_matrix_mult
MPI_CODE=mpi_matrix_mult.c
MPI_EXE_PATH="${AZ_BATCH_NODE_MOUNTS_DIR}/data/"

cat << EOF > run_mpi.sh
#!/bin/bash

MPI_EXE=${MPI_EXE}
MPI_CODE=${MPI_CODE}
MPI_EXE_PATH=${MPI_EXE_PATH}

[[ -f /etc/bashrc ]] && . /etc/bashrc

source /etc/profile.d/modules.sh

module load gcc-9.2.0
module load mpi/hpcx

# Create host file
batch_hosts=hosts.batch
rm -rf \$batch_hosts

IFS=';' read -ra ADDR <<< "\$AZ_BATCH_NODE_LIST"

[[ -z \$PPN ]] && echo "PPN not defined"
PPN=\$PPN

hostprocmap=""

for host in "\${ADDR[@]}"; do
    echo $host >> \$batch_hosts
    hostprocmap="\$hostprocmap,\$host:\${PPN}"
done

hostprocmap="\${hostprocmap:1}"

NODES=\$(cat \$batch_hosts | wc -l)

NP=\$((\$NODES*\$PPN))

echo "NODES=\$NODES PPN=\$PPN"
echo "hostprocmap=\$hostprocmap"
set -x

mpirun -np \$NP --oversubscribe --host \$hostprocmap --map-by ppr:\${PPN}:node //mnt/resource/batch/tasks/fsmounts/data//mpi_matrix_mult 6000 10

EOF

chmod +x run_mpi.sh

[[ -f /etc/bashrc ]] && . /etc/bashrc

source /etc/profile.d/modules.sh
module load gcc-9.2.0
module load mpi/hpcx

set -x
echo "Compiling mpi code"
mpicc -o ${MPI_EXE} ${MPI_CODE}
ls -l ${MPI_EXE}
