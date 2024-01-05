#!/bin/bash
HOME_PATH=/data/rl/v1

IOTDB_SBIN_HOME=$HOME_PATH/iotdb-server-0.12.4/sbin
QUERY_JAR_PATH=$HOME_PATH/QueryData-0.12.4.jar

# only true in run-more-baselines.sh for saving query result csv for DSSIM exp
REP_ONCE_AND_SAVE_QUERY_RESULT=false
SAVE_QUERY_RESULT_PATH=NONE

echo 3 | sudo tee /proc/sys/vm/drop_caches
cd $IOTDB_SBIN_HOME

echo $REP_ONCE_AND_SAVE_QUERY_RESULT

#if [ $# -eq 8 ]
if $REP_ONCE_AND_SAVE_QUERY_RESULT
then
  a=1
else # default
  a=30
fi
echo "rep=$a"

for((i=0;i<a;i++)) do
    echo $i
    ./start-server.sh /dev/null 2>&1 &
    sleep 15s

    if ${REP_ONCE_AND_SAVE_QUERY_RESULT}
    then
      java -jar $QUERY_JAR_PATH $1 $2 $3 $4 $5 $6 $7 $8 true ${SAVE_QUERY_RESULT_PATH}
    else
      java -jar $QUERY_JAR_PATH $1 $2 $3 $4 $5 $6 $7 $8 false ${SAVE_QUERY_RESULT_PATH}
    fi

#    if ${SAVE_FIRST_QUERY_RESULT}
#    then
#      if [ $i -eq 0 ] # first query save
#      then
#        java -jar $QUERY_JAR_PATH $1 $2 $3 $4 $5 $6 $7 $8 true
#      else
#        java -jar $QUERY_JAR_PATH $1 $2 $3 $4 $5 $6 $7 $8 false
#      fi
#    else # always don't save
#      java -jar $QUERY_JAR_PATH $1 $2 $3 $4 $5 $6 $7 $8 false
#    fi

    ./stop-server.sh
    sleep 5s
    echo 3 | sudo tee /proc/sys/vm/drop_caches
    sleep 5s
done
