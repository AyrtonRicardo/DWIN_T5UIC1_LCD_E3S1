#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load env vars when run manually (systemd loads them via EnvironmentFile)
[ -f /etc/simpleLCD.env ] && set -a && source /etc/simpleLCD.env && set +a

i=0
start_time=$(date +%s)
while [ $i -lt 5 ]
do
  echo "LCD attempt $i"
  sleep 4
  /usr/bin/env python3 "$SCRIPT_DIR/run.py" &
  script_pid=$!
  script_start_time=$(date +%s)
  wait $script_pid
  if [ $? -eq 0 ]
  then
    i=$((i+1))
  else
    i=$((i+1))
  fi
  script_elapsed_time=$(( $(date +%s) - $script_start_time ))
  elapsed_time=$(( $(date +%s) - $start_time ))
  if [ $script_elapsed_time -ge 30 ] || [ $elapsed_time -ge 30 ]
  then
    start_time=$(date +%s)
    i=0
  fi
done
