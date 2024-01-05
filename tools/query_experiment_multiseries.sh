#!/bin/bash
HOME_PATH=/data/rl/v1

IOTDB_SBIN_HOME=$HOME_PATH/iotdb-server-0.12.4/sbin
QUERY_JAR_PATH=$HOME_PATH/QueryDataMultiSeries-jar-with-dependencies.jar
IOTDB_EXPORT_CSV_HOME=$HOME_PATH/iotdb-cli-0.12.4/tools

echo 3 | sudo tee /proc/sys/vm/drop_caches >>/dev/null
cd $IOTDB_SBIN_HOME

a=30
#echo "rep=$a"

w=100 # 10 00 0000

#echo "n_ts=$7"

for((i=0;i<a;i++)) do
    if [ $8 == "mac" ] || [ $8 == "cpv" ]
    then
        ./start-server.sh >>/dev/null 2>&1 &
        sleep 15s

        ts=$(date +%s%N) ;
        for ((deviceID=1; deviceID<=$7; deviceID++)); # query $7 number of time series simultaneously
        do
          java -jar $QUERY_JAR_PATH "$1${deviceID}" $2 $3 $4 $5 $6 $w $8 false NONE >>/dev/null 2>&1 &
          pids[${deviceID}]=$!
        done;
        for pid in ${pids[*]}; do
            wait $pid
        done
        # tt=$((($(date +%s%N) - $ts)/1000000)) ; echo "Time taken: $tt milliseconds"
        tt=$((($(date +%s%N) - $ts))) ; echo "$tt" # ns

        ./stop-server.sh >>/dev/null 2>&1
        sleep 5s
        echo 3 | sudo tee /proc/sys/vm/drop_caches >>/dev/null
        sleep 5s

    else # rawQuery
        ./start-server.sh >>/dev/null 2>&1 &
        sleep 15s

        ts=$(date +%s%N) ;
        for ((deviceID=1; deviceID<=$7; deviceID++)); # query $7 number of time series simultaneously
        do
          bash ${IOTDB_EXPORT_CSV_HOME}/export-csv.sh -h 127.0.0.1 -p 6667 -u root -pw root -q "select $2 from $1${deviceID} where time<1683616109697000000" -td ${IOTDB_EXPORT_CSV_HOME} -tf timestamp -f ${deviceID} >>/dev/null 2>&1 &
          pids[${deviceID}]=$!
        done;
        for pid in ${pids[*]}; do
            wait $pid
        done
        tt=$((($(date +%s%N) - $ts))) ; echo "$tt" # ns

        ./stop-server.sh >>/dev/null 2>&1
        sleep 5s
        echo 3 | sudo tee /proc/sys/vm/drop_caches >>/dev/null
        sleep 5s
    fi
done
