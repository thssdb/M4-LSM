#!/bin/bash

echo 3 | sudo tee /proc/sys/vm/drop_caches >>/dev/null

remote_passwd='xxx' # do not use double quotes

# #prepare data files to be transferred
#for i in {1..50}
#do
#  cp MF03.csv MF03-${i}.csv
#done;

ts=$(date +%s%N) ;
for ((i=1; i<=$1; i++)); # transfer $1 number of time series in parallel
do
  sshpass -p "${remote_passwd}" scp MF03-${i}.csv root@182.92.84.230:~/data/. &
  pids[${i}]=$!
done;
for pid in ${pids[*]}; do
    wait $pid
done
tt=$((($(date +%s%N) - $ts)/1000000000)) ; echo "Number of time series transferred in parallel: $1, Time taken: $tt s"
#tt=$((($(date +%s%N) - $ts))) ; echo "$tt ns" # ns

# be careful with the following command if you have important data on that machine
sshpass -p "${remote_passwd}" ssh root@182.92.84.230 "rm ~/data/*"