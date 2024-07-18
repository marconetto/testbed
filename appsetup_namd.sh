#!/usr/bin/env bash

hpcadvisor_setup() {
  echo "main setup $(pwd)"
  echo "Setting up data ..."
  namdurl=https://www.ks.uiuc.edu/Research/namd/3.0b6/download/120834/NAMD_3.0b6_Linux-x86_64-verbs-smp.tar.gz
  namddir=NAMD_3.0b6_Linux-x86_64-verbs-smp

  if [ ! -d $namddir ]; then
    wget "$namdurl"
    namdtgz=$(basename $namdurl)
    tar zxvf "$namdtgz"
    caseurl=https://www.ks.uiuc.edu/Research/namd/utilities/stmv.tar.gz
    wget "$caseurl"
    casetgz=$(basename $caseurl)
    tar zxvf "$casetgz"
    sed -i 's| .*stmv-output| ./stmv-output|g' stmv/stmv.namd
    sed -i 's|numsteps.*|numsteps 5000|g' stmv/stmv.namd
  else
    echo "nothing to be done. App and data all ready"
  fi
}

hpcadvisor_run() {
  echo "main run $(pwd)"

  namddir=NAMD_3.0b6_Linux-x86_64-verbs-smp
  export PATH="$APP_EXE_PATH/$namddir:$PATH"

  NP=$(($NODES * $PPN))

  APP_EXE=$(which namd3)

  IFS=';' read -ra ADDR <<<"\$AZ_BATCH_NODE_LIST"
  batch_hosts=hosts.batch
  rm -rf $batch_hosts

  for host in "${ADDR[@]}"; do
    echo "host $host ++cpus $PPN" >>$batch_hosts
  done

  ########################### APP EXECUTION #####################################
  cp "$APP_EXE_PATH"/stmv/* .
  ls -l
  # time charmrun "$APP_EXE" ++p $NP ++nodelist "$AZ_HOST_LIST_PPN" +setcpuaffinity stmv.namd
  time charmrun "$APP_EXE" ++p $NP ++nodelist $batch_hosts +setcpuaffinity stmv.namd
  #############################################################################

  ########################### TEST OUTPUT #####################################
  OUTPUTFILE=stmv-output.coor

  if [ -f "$OUTPUTFILE" ]; then
    echo "Output file found: $OUTPUTFILE"
    return 0
  else
    echo "Output file not found: $OUTPUTFILE"
    return 1
  fi
  #############################################################################
}
