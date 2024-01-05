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
TOTAL_POINT_NUMBER=1200000
let TOTAL_TIME_RANGE=${DATA_MAX_TIME}-${DATA_MIN_TIME} # check what if not +1 what the difference
VALUE_ENCODING=PLAIN
TIME_ENCODING=PLAIN
COMPRESSOR=UNCOMPRESSED

# iotdb config info
IOTDB_CHUNK_POINT_SIZE=100

# exp controlled parameter design
FIX_W=1000
FIX_QUERY_RANGE=$TOTAL_TIME_RANGE
FIX_OVERLAP_PERCENTAGE=10
FIX_DELETE_PERCENTAGE=49
FIX_DELETE_RANGE=10

hasHeader=false # default

############################
# Experimental parameter design:
#
# [EXP2] Varying query time range
# (1) w: 1000
# (2) query range: 1%,5%,10%,20%,40%,60%,80%,100% of totalRange
# - corresponding estimated chunks per interval = 1%,5%,10%,20%,40%,60%,80%,100% of kmax
# - kMax=(pointNum/chunkSize)/w, when range = 100% of totalRange.
# (3) overlap percentage: 10%
# (4) delete percentage: 0%
# (5) delete time range: 0
#
############################
# O_10_D_0_0

# O_0_D_0_0
# O_20_D_0_0
# O_30_D_0_0
# O_40_D_0_0
# O_50_D_0_0
# O_60_D_0_0
# O_70_D_0_0
# O_80_D_0_0
# O_90_D_0_0

# O_10_D_9_10
# O_10_D_19_10
# O_10_D_29_10
# O_10_D_39_10
# O_10_D_49_10
# O_10_D_59_10
# O_10_D_69_10
# O_10_D_79_10
# O_10_D_89_10

# O_10_D_49_20
# O_10_D_49_30
# O_10_D_49_40
# O_10_D_49_50
# O_10_D_49_60
# O_10_D_49_70
# O_10_D_49_80
# O_10_D_49_90
############################

echo 3 |sudo tee /proc/sys/vm/drop_cache
free -m
echo "Begin experiment!"

############################
# prepare out-of-order source data.
# Vary overlap percentage: 0%, 10%, 20%, 30%, 40%, 50%, 60%, 70%, 80%, 90%
############################
echo "prepare out-of-order source data"
cd $HOME_PATH/${DATASET}
cp ${DATASET}.csv ${DATASET}-O_0
# java OverlapGenerator iotdb_chunk_point_size dataType inPath outPath timeIdx valueIdx overlapPercentage overlapDepth
java OverlapGenerator ${IOTDB_CHUNK_POINT_SIZE} ${DATA_TYPE} ${DATASET}.csv ${DATASET}-O_10 0 1 10 10 ${hasHeader}

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

# properties for cpv
$HOME_PATH/tool.sh enable_CPV true ../../iotdb-engine-example.properties
cp ../../iotdb-engine-example.properties iotdb-engine-enableCPVtrue.properties
# properties for moc
$HOME_PATH/tool.sh enable_CPV false ../../iotdb-engine-example.properties
cp ../../iotdb-engine-example.properties iotdb-engine-enableCPVfalse.properties

# [write data]
echo "Writing O_10_D_0_0"
cp iotdb-engine-enableCPVfalse.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
cd $HOME_PATH/iotdb-server-0.12.4/sbin
./start-server.sh /dev/null 2>&1 &
sleep 8s
# Usage: java -jar WriteData-0.12.4.jar device measurement dataType timestamp_precision total_time_length total_point_number iotdb_chunk_point_size filePath deleteFreq deleteLen timeIdx valueIdx VALUE_ENCODING
java -jar $HOME_PATH/WriteData*.jar ${DEVICE} ${MEASUREMENT} ${DATA_TYPE} ${TIMESTAMP_PRECISION} ${TOTAL_TIME_RANGE} ${TOTAL_POINT_NUMBER} ${IOTDB_CHUNK_POINT_SIZE} $HOME_PATH/${DATASET}/${DATASET}-O_10 0 0 0 1 ${VALUE_ENCODING} ${hasHeader}
sleep 5s
./stop-server.sh
sleep 5s
echo 3 | sudo tee /proc/sys/vm/drop_caches

############################
# [EXP2] Varying query time range
# (1) w: 100
# (2) query range: 1%,5%,10%,20%,40%,60%,80%,100% of totalRange
# - corresponding estimated chunks per interval = 1%,5%,10%,20%,40%,60%,80%,100% of kmax
# - kMax=(pointNum/chunkSize)/w, when range = 100% of totalRange.
# (3) overlap percentage: 10%
# (4) delete percentage: 0%
# (5) delete time range: 0
############################
echo "Querying O_10_D_0_0 with varied tqe"

cd $HOME_PATH/${DATASET}_testspace/O_10_D_0_0
mkdir vary_tqe

# echo "moc"
# cd $HOME_PATH/${DATASET}_testspace/O_10_D_0_0/vary_tqe
# mkdir moc
# cd moc
# cp $HOME_PATH/ProcessResult.* .
# cp ../../iotdb-engine-enableCPVfalse.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
# i=1
# for per in 1 5 10 20 40 60 80 # 100% is already done in exp1
# do
#   range=$((echo scale=0 ; echo ${per}*${TOTAL_TIME_RANGE}/100) | bc )
#   echo "per=${per}% of ${TOTAL_TIME_RANGE}, range=${range}"
#   #  range=$((echo scale=0 ; echo ${k}*${FIX_W}*${TOTAL_TIME_RANGE}*${IOTDB_CHUNK_POINT_SIZE}/${TOTAL_POINT_NUMBER}) | bc )
#   # Usage: ./query_experiment.sh device measurement timestamp_precision dataMinTime dataMaxTime range w approach
#   $HOME_PATH/query_experiment.sh ${DEVICE} ${MEASUREMENT} ${TIMESTAMP_PRECISION} ${DATA_MIN_TIME} ${DATA_MAX_TIME} ${range} ${FIX_W} moc >> result_${i}.txt
#   java ProcessResult result_${i}.txt result_${i}.out ../sumResultMOC.csv
#   let i+=1
# done

echo "mac"
cd $HOME_PATH/${DATASET}_testspace/O_10_D_0_0/vary_tqe
mkdir mac
cd mac
cp $HOME_PATH/ProcessResult.* .
cp ../../iotdb-engine-enableCPVfalse.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
i=1
for per in 1 5 10 20 40 60 80 100 # 100% is already done in exp1
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
cp ../../iotdb-engine-enableCPVtrue.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
i=1
for per in 1 5 10 20 40 60 80 100 # 100% is already done in exp1
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
# [EXP2]
# w: 100
# query range: k*w*totalRange/(pointNum/chunkSize).
# - target estimated chunks per interval = k
# - range = k*w*totalRange/(pointNum/chunkSize)
# - kMax=(pointNum/chunkSize)/w, that is, range=totalRange.
# - E.g. k=0.2,0.5,1,2.5,5,12
# overlap percentage: 10%
# delete percentage: 0%
# delete time range: 0

cd $HOME_PATH/${DATASET}_testspace/O_10_D_0_0
cd vary_tqe
cat result.csv >$HOME_PATH/${DATASET}_testspace/exp2.csv

## 把exp1里FIX_W的那一行结果追加到exp2.csv最后一行，且不要前两列
## append the line starting with FIX_W and without the first two columns in exp1.csv to exp2.csv
#sed -n -e "/^${FIX_W},/p" $HOME_PATH/${DATASET}_testspace/exp1.csv > tmp # the line starting with FIX_W
#cut -d "," -f 3- tmp >> $HOME_PATH/${DATASET}_testspace/exp2.csv # without the first two columns
#rm tmp

# add varied parameter value and the corresponding estimated chunks per interval for each line
# estimated chunks per interval = range/w/(totalRange/(pointNum/chunkSize))
# for exp2, estimated chunks per interval=k
sed -i -e 1's/^/range,estimated chunks per interval,/' $HOME_PATH/${DATASET}_testspace/exp2.csv
line=2
for per in 1 5 10 20 40 60 80 100 # 100% is already done in exp1
do
  range=$((echo scale=0 ; echo ${per}*${TOTAL_TIME_RANGE}/100) | bc )
  c=$((echo scale=0 ; echo ${TOTAL_POINT_NUMBER}/${IOTDB_CHUNK_POINT_SIZE}/${FIX_W}*${per}/100) | bc )
  sed -i -e ${line}"s/^/${range},${c},/" $HOME_PATH/${DATASET}_testspace/exp2.csv
  let line+=1
done

(cut -f 1 -d "," $HOME_PATH/${DATASET}_testspace/exp2.csv) > tmp1.csv
(cut -f 4 -d "," $HOME_PATH/${DATASET}_testspace/exp2.csv| paste -d, tmp1.csv -) > tmp2.csv
(cut -f 71 -d "," $HOME_PATH/${DATASET}_testspace/exp2.csv| paste -d, tmp2.csv -) > tmp3.csv
echo "param,M4(ns),M4-LSM(ns)" > $HOME_PATH/${DATASET}_testspace/exp2_res.csv
sed '1d' tmp3.csv >> $HOME_PATH/${DATASET}_testspace/exp2_res.csv
rm tmp1.csv
rm tmp2.csv
rm tmp3.csv

echo "ALL FINISHED!"
echo 3 |sudo tee /proc/sys/vm/drop_caches
free -m