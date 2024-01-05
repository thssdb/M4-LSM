#!/bin/bash

# generate HOME_PATH workspace by running prepare.sh first
HOME_PATH=/data/v4

# dataset basic info
DATASET=BallSpeed # BallSpeed KOB MF03 RcvTime
DEVICE="root.game"
MEASUREMENT="s6"
DATA_TYPE=long # long or double
TIMESTAMP_PRECISION=ns
DATA_MIN_TIME=0  # in the corresponding timestamp precision
DATA_MAX_TIME=617426057626  # in the corresponding timestamp precision
TOTAL_POINT_NUMBER=1200000 # not accurate as this is the number before resolving updates, but it's ok
let TOTAL_TIME_RANGE=${DATA_MAX_TIME}-${DATA_MIN_TIME} # check what if not +1 what the difference
VALUE_ENCODING=PLAIN
TIME_ENCODING=PLAIN
COMPRESSOR=UNCOMPRESSED

# iotdb config info
IOTDB_CHUNK_POINT_SIZE=100

# exp controlled parameter design
FIX_W=1000
#FIX_QUERY_RANGE=$TOTAL_TIME_RANGE

hasHeader=false # default

############################
# Experimental parameter design:
#
# Varying query time range
# (1) w: 1000
# (2) query range: 1%,5%,10%,20%,40%,60%,80%,100% of totalRange
# - corresponding estimated chunks per interval = 1%,5%,10%,20%,40%,60%,80%,100% of kmax
# - kMax=(pointNum/chunkSize)/w, when range = 100% of totalRange.
# (3) with real updates
############################

echo 3 |sudo tee /proc/sys/vm/drop_cache
free -m
echo "Begin experiment!"

############################
# prepare out-of-order source data.
############################
echo "prepare out-of-order source data"
cd $HOME_PATH/${DATASET}
cp ${DATASET}.csv ${DATASET}-O_0

############################
# O_10_D_0_0
############################

cd $HOME_PATH/${DATASET}_testspace
mkdir O_10_D_0_0
cd O_10_D_0_0

# prepare IoTDB config properties
$HOME_PATH/tool.sh system_dir $HOME_PATH/dataSpace/${DATASET}_O_10_D_0_0/system ../../iotdb-engine-example.properties
$HOME_PATH/tool.sh data_dirs $HOME_PATH/dataSpace/${DATASET}_O_10_D_0_0/data ../../iotdb-engine-example.properties
$HOME_PATH/tool.sh wal_dir $HOME_PATH/dataSpace/${DATASET}_O_10_D_0_0/wal ../../iotdb-engine-example.properties
$HOME_PATH/tool.sh timestamp_precision ${TIMESTAMP_PRECISION} ../../iotdb-engine-example.properties
$HOME_PATH/tool.sh unseq_tsfile_size 1073741824 ../../iotdb-engine-example.properties
$HOME_PATH/tool.sh seq_tsfile_size 1073741824 ../../iotdb-engine-example.properties
$HOME_PATH/tool.sh avg_series_point_number_threshold ${IOTDB_CHUNK_POINT_SIZE} ../../iotdb-engine-example.properties
$HOME_PATH/tool.sh compaction_strategy NO_COMPACTION ../../iotdb-engine-example.properties
$HOME_PATH/tool.sh enable_unseq_compaction false ../../iotdb-engine-example.properties
$HOME_PATH/tool.sh group_size_in_byte 1073741824 ../../iotdb-engine-example.properties
$HOME_PATH/tool.sh page_size_in_byte 1073741824 ../../iotdb-engine-example.properties
$HOME_PATH/tool.sh rpc_address 0.0.0.0 ../../iotdb-engine-example.properties
$HOME_PATH/tool.sh rpc_port 6667 ../../iotdb-engine-example.properties
$HOME_PATH/tool.sh time_encoder ${TIME_ENCODING} ../../iotdb-engine-example.properties
$HOME_PATH/tool.sh compressor ${COMPRESSOR} ../../iotdb-engine-example.properties
$HOME_PATH/tool.sh error_Param 50 ../../iotdb-engine-example.properties
$HOME_PATH/tool.sh enable_CPV true ../../iotdb-engine-example.properties

# properties for disabling tracing
$HOME_PATH/tool.sh enable_performance_tracing false ../../iotdb-engine-example.properties
cp ../../iotdb-engine-example.properties iotdb-engine-enableTraceFalse.properties
# properties for enabling tracing
$HOME_PATH/tool.sh enable_performance_tracing true ../../iotdb-engine-example.properties
cp ../../iotdb-engine-example.properties iotdb-engine-enableTraceTrue.properties

# [write data]
echo "Writing O_10_D_0_0"
cp iotdb-engine-enableTraceFalse.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
cd $HOME_PATH/iotdb-server-0.12.4/sbin
./start-server.sh /dev/null 2>&1 &
sleep 8s
# Usage: java -jar WriteUpdate*.jar device measurement dataType timestamp_precision iotdb_chunk_point_size filePath updatePercentage timeIdx valueIdx VALUE_ENCODING hasHeader
# Example: "root.game" "s6" long ns 100 "D:\full-game\tmp.csv" 0 0 1 PLAIN true
java -jar $HOME_PATH/WriteUpdate*.jar ${DEVICE} ${MEASUREMENT} ${DATA_TYPE} ${TIMESTAMP_PRECISION} ${IOTDB_CHUNK_POINT_SIZE} $HOME_PATH/${DATASET}/${DATASET}-O_0 0 0 1 ${VALUE_ENCODING} ${hasHeader}

sleep 5s
./stop-server.sh
sleep 5s
echo 3 | sudo tee /proc/sys/vm/drop_caches

# [query data]
echo "Querying O_10_D_0_0 with varied tqe"

cd $HOME_PATH/${DATASET}_testspace/O_10_D_0_0
mkdir vary_tqe

echo "mac"
cd $HOME_PATH/${DATASET}_testspace/O_10_D_0_0/vary_tqe
mkdir mac
cd mac
cp $HOME_PATH/ProcessResult.* .
cp ../../iotdb-engine-enableTraceFalse.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
i=1
for per in 1 5 10 20 40 60 80 100
#for per in 1 20 60 100
do
  range=$((echo scale=0 ; echo ${per}*${TOTAL_TIME_RANGE}/100) | bc )
  echo "per=${per}% of ${TOTAL_TIME_RANGE}, range=${range}"
  # Usage: ./query_experiment.sh device measurement timestamp_precision dataMinTime dataMaxTime range w approach
  $HOME_PATH/query_experiment.sh ${DEVICE} ${MEASUREMENT} ${TIMESTAMP_PRECISION} ${DATA_MIN_TIME} ${DATA_MAX_TIME} ${range} ${FIX_W} mac >> result_${i}.txt
  java ProcessResult result_${i}.txt result_${i}.out ../sumResultMAC.csv
  let i+=1
done

echo "cpv"
cd $HOME_PATH/${DATASET}_testspace/O_10_D_0_0/vary_tqe
mkdir cpv
cd cpv
cp $HOME_PATH/ProcessResult.* .
cp ../../iotdb-engine-enableTraceFalse.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
i=1
for per in 1 5 10 20 40 60 80 100
#for per in 1 20 60 100
do
  range=$((echo scale=0 ; echo ${per}*${TOTAL_TIME_RANGE}/100) | bc )
  echo "per=${per}% of ${TOTAL_TIME_RANGE}, range=${range}"
  # Usage: ./query_experiment.sh device measurement timestamp_precision dataMinTime dataMaxTime range w approach
  $HOME_PATH/query_experiment.sh ${DEVICE} ${MEASUREMENT} ${TIMESTAMP_PRECISION} ${DATA_MIN_TIME} ${DATA_MAX_TIME} ${range} ${FIX_W} cpv >> result_${i}.txt
  java ProcessResult result_${i}.txt result_${i}.out ../sumResultCPV.csv
  let i+=1
done

# unify results
cd $HOME_PATH/${DATASET}_testspace/O_10_D_0_0/vary_tqe
cp $HOME_PATH/SumResultUnify.* .
# java SumResultUnify sumResultMOC.csv sumResultMAC.csv sumResultCPV.csv result.csv
java SumResultUnify sumResultMAC.csv sumResultCPV.csv result.csv

# export results
# [exp]
# w: 100
# query range: k*w*totalRange/(pointNum/chunkSize).
# - target estimated chunks per interval = k
# - range = k*w*totalRange/(pointNum/chunkSize)
# - kMax=(pointNum/chunkSize)/w, that is, range=totalRange.
# - E.g. k=0.2,0.5,1,2.5,5,12

cd $HOME_PATH/${DATASET}_testspace/O_10_D_0_0
cd vary_tqe
cat result.csv >$HOME_PATH/${DATASET}_testspace/exp.csv

# add varied parameter value and the corresponding estimated chunks per interval for each line
# estimated chunks per interval = range/w/(totalRange/(pointNum/chunkSize))
# for exp, estimated chunks per interval=k
sed -i -e 1's/^/range,estimated chunks per interval,/' $HOME_PATH/${DATASET}_testspace/exp.csv
line=2
for per in 1 5 10 20 40 60 80 100
#for per in 1 20 60 100
do
  range=$((echo scale=0 ; echo ${per}*${TOTAL_TIME_RANGE}/100) | bc )
  c=$((echo scale=0 ; echo ${TOTAL_POINT_NUMBER}/${IOTDB_CHUNK_POINT_SIZE}/${FIX_W}*${per}/100) | bc )
  sed -i -e ${line}"s/^/${range},${c},/" $HOME_PATH/${DATASET}_testspace/exp.csv
  let line+=1
done

(cut -f 1 -d "," $HOME_PATH/${DATASET}_testspace/exp.csv) > tmp1.csv
(cut -f 4 -d "," $HOME_PATH/${DATASET}_testspace/exp.csv| paste -d, tmp1.csv -) > tmp2.csv
(cut -f 71 -d "," $HOME_PATH/${DATASET}_testspace/exp.csv| paste -d, tmp2.csv -) > tmp3.csv
echo "param,M4(ns),M4-LSM(ns)" > $HOME_PATH/${DATASET}_testspace/exp2_res.csv
sed '1d' tmp3.csv >> $HOME_PATH/${DATASET}_testspace/exp2_res.csv
rm tmp1.csv
rm tmp2.csv
rm tmp3.csv

# [update rate statistics]
echo "update rate with varied tqe"

echo "mac"
cd $HOME_PATH/${DATASET}_testspace/O_10_D_0_0
cp iotdb-engine-enableTraceTrue.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
$HOME_PATH/tool.sh REP_ONCE_AND_SAVE_QUERY_RESULT true $HOME_PATH/query_experiment.sh
find $HOME_PATH -type f -iname "*.sh" -exec chmod +x {} \;
i=1
for per in 1 5 10 20 40 60 80 100
do
  $HOME_PATH/tool.sh SAVE_QUERY_RESULT_PATH ${HOME_PATH}/data-mac-${per}.csv $HOME_PATH/query_experiment.sh
  find $HOME_PATH -type f -iname "*.sh" -exec chmod +x {} \;

  range=$((echo scale=0 ; echo ${per}*${TOTAL_TIME_RANGE}/100) | bc )
  echo "per=${per}% of ${TOTAL_TIME_RANGE}, range=${range}"

  # Usage: ./query_experiment.sh device measurement timestamp_precision dataMinTime dataMaxTime range w approach
  $HOME_PATH/query_experiment.sh ${DEVICE} ${MEASUREMENT} ${TIMESTAMP_PRECISION} ${DATA_MIN_TIME} ${DATA_MAX_TIME} ${range} ${FIX_W} mac
  let i+=1
done
$HOME_PATH/tool.sh REP_ONCE_AND_SAVE_QUERY_RESULT false $HOME_PATH/query_experiment.sh
find $HOME_PATH -type f -iname "*.sh" -exec chmod +x {} \;

cat $HOME_PATH/iotdb-server-0.12.4/data/tracing/tracing.txt # "Rate of updated points"


echo "ALL FINISHED!"
echo 3 |sudo tee /proc/sys/vm/drop_caches
free -m