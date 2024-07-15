#!/usr/bin/env bash

set -x

APP_EXE_PATH="${AZ_BATCH_NODE_MOUNTS_DIR}/data/"
echo "APP_EXE_PATH=$APP_EXE_PATH"

function setup_data {
  echo "Downloading data for lammps"
  pwd
  wget https://www.lammps.org/inputs/in.lj.txt
  ls -l in.lj.txt

}

function generate_run_script {

  cat <<EOF >run_app.sh
#!/bin/bash

cd \$AZ_TASKRUN_DIR
echo "Execution directory: \$(pwd)"

source /cvmfs/software.eessi.io/versions/2023.06/init/bash
module load LAMMPS
which mpirun
which lmp

cp ../in.lj.txt .

NP=\$((\$NODES*\$PPN))
export UCX_NET_DEVICES=mlx5_ib0:1


time mpirun -np \$NP lmp -i in.lj.txt

EOF
  chmod +x run_app.sh
}

cd "$APP_EXE_PATH" || exit
setup_data
generate_run_script
