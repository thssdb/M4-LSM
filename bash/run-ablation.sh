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
let TOTAL_TIME_RANGE=${DATA_MAX_TIME}-${DATA_MIN_TIME}
VALUE_ENCODING=PLAIN
TIME_ENCODING=PLAIN
COMPRESSOR=UNCOMPRESSED
use_Mad=false

# iotdb config info
IOTDB_CHUNK_POINT_SIZE=1000

# exp controlled parameter design
FIX_W=1000
FIX_QUERY_RANGE=$TOTAL_TIME_RANGE
FIX_OVERLAP_PERCENTAGE=90

echo 3 |sudo tee /proc/sys/vm/drop_cache
free -m
echo "Begin experiment!"

############################
# prepare out-of-order source data.
# Vary overlap percentage: 0%, 10%, 20%, 30%, 40%, 50%, 60%, 70%, 80%, 90%
############################
echo "prepare out-of-order source data"
cd $HOME_PATH/${DATASET}
#cp ${DATASET}.csv ${DATASET}-O_0
# long D:\desktop\test.csv D:\desktop\test2.csv 0 1 10 4
java OverlapGenerator2 ${DATA_TYPE} ${DATASET}.csv ${DATASET}-O_90 0 1 ${TOTAL_POINT_NUMBER} 10000

for IOTDB_CHUNK_POINT_SIZE in 10000 50000 100000 500000 1000000 3000000 5000000
#for IOTDB_CHUNK_POINT_SIZE in 3000000
do
  workspace="O_90_D_0_0_${IOTDB_CHUNK_POINT_SIZE}"
  cd $HOME_PATH/${DATASET}_testspace
  mkdir ${workspace}
  cd ${workspace}

  # prepare IoTDB config properties
  $HOME_PATH/tool.sh system_dir $HOME_PATH/dataSpace/${DATASET}_${workspace}/system ../../iotdb-engine-example.properties
  $HOME_PATH/tool.sh data_dirs $HOME_PATH/dataSpace/${DATASET}_${workspace}/data ../../iotdb-engine-example.properties
  $HOME_PATH/tool.sh wal_dir $HOME_PATH/dataSpace/${DATASET}_${workspace}/wal ../../iotdb-engine-example.properties
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
  $HOME_PATH/tool.sh use_Mad ${use_Mad} ../../iotdb-engine-example.properties
  $HOME_PATH/tool.sh wal_buffer_size 1073741824 ../../iotdb-engine-example.properties
  $HOME_PATH/tool.sh max_number_of_points_in_page 10485760 ../../iotdb-engine-example.properties
  # properties for cpv true and disable chunk index
  $HOME_PATH/tool.sh enable_CPV true ../../iotdb-engine-example.properties
  $HOME_PATH/tool.sh use_TimeIndex false ../../iotdb-engine-example.properties
  $HOME_PATH/tool.sh use_ValueIndex false ../../iotdb-engine-example.properties
  cp ../../iotdb-engine-example.properties iotdb-engine-disableChunkIndex.properties
  # properties for cpv true and enable time index only
  $HOME_PATH/tool.sh enable_CPV true ../../iotdb-engine-example.properties
  $HOME_PATH/tool.sh use_TimeIndex true ../../iotdb-engine-example.properties
  $HOME_PATH/tool.sh use_ValueIndex false ../../iotdb-engine-example.properties
  cp ../../iotdb-engine-example.properties iotdb-engine-enableTimeIndexOnly.properties
  # properties for cpv true and enable both time and value index
  $HOME_PATH/tool.sh enable_CPV true ../../iotdb-engine-example.properties
  $HOME_PATH/tool.sh use_TimeIndex true ../../iotdb-engine-example.properties
  $HOME_PATH/tool.sh use_ValueIndex true ../../iotdb-engine-example.properties
  cp ../../iotdb-engine-example.properties iotdb-engine-enableChunkIndex.properties

  # [write data]
  echo "Writing ${workspace}"
  cp iotdb-engine-enableChunkIndex.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
  cd $HOME_PATH/iotdb-server-0.12.4/sbin
  ./start-server.sh >$HOME_PATH/${DATASET}_testspace/${workspace}/iotdb-server-log-${IOTDB_CHUNK_POINT_SIZE}.log 2>&1 &
  sleep 8s
  # Usage: java -jar WriteData-0.12.4.jar device measurement dataType timestamp_precision total_time_length total_point_number iotdb_chunk_point_size filePath deleteFreq deleteLen timeIdx valueIdx VALUE_ENCODING
  java -jar $HOME_PATH/WriteData*.jar ${DEVICE} ${MEASUREMENT} ${DATA_TYPE} ${TIMESTAMP_PRECISION} ${TOTAL_TIME_RANGE} ${TOTAL_POINT_NUMBER} ${IOTDB_CHUNK_POINT_SIZE} $HOME_PATH/${DATASET}/${DATASET}-O_90 0 0 0 1 ${VALUE_ENCODING}
  sleep 5s
  ./stop-server.sh
  sleep 5s
  echo 3 | sudo tee /proc/sys/vm/drop_caches

  # [query data]
  echo "Querying ${workspace}"
  cd $HOME_PATH/${DATASET}_testspace/${workspace}
  mkdir fix

  echo "disableAll"
  cd $HOME_PATH/${DATASET}_testspace/${workspace}/fix
  mkdir disableChunkIndex
  cd disableChunkIndex
  cp $HOME_PATH/ProcessResult.* .
  cp ../../iotdb-engine-disableChunkIndex.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
  # Usage: ./query_experiment.sh device measurement timestamp_precision dataMinTime dataMaxTime range w approach
  $HOME_PATH/query_experiment.sh ${DEVICE} ${MEASUREMENT} ${TIMESTAMP_PRECISION} ${DATA_MIN_TIME} ${DATA_MAX_TIME} ${FIX_QUERY_RANGE} ${FIX_W} cpv >> result_${FIX_W}.txt
  java ProcessResult result_${FIX_W}.txt result_${FIX_W}.out ../sumResult_disableChunkIndex.csv

  echo "enableTimeIndexOnly"
  cd $HOME_PATH/${DATASET}_testspace/${workspace}/fix
  mkdir enableTimeIndexOnly
  cd enableTimeIndexOnly
  cp $HOME_PATH/ProcessResult.* .
  cp ../../iotdb-engine-enableTimeIndexOnly.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
  # Usage: ./query_experiment.sh device measurement timestamp_precision dataMinTime dataMaxTime range w approach
  $HOME_PATH/query_experiment.sh ${DEVICE} ${MEASUREMENT} ${TIMESTAMP_PRECISION} ${DATA_MIN_TIME} ${DATA_MAX_TIME} ${FIX_QUERY_RANGE} ${FIX_W} cpv >> result_${FIX_W}.txt
  java ProcessResult result_${FIX_W}.txt result_${FIX_W}.out ../sumResult_enableTimeIndexOnly.csv

  echo "enableAll"
  cd $HOME_PATH/${DATASET}_testspace/${workspace}/fix
  mkdir enableChunkIndex
  cd enableChunkIndex
  cp $HOME_PATH/ProcessResult.* .
  cp ../../iotdb-engine-enableChunkIndex.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
  # Usage: ./query_experiment.sh device measurement timestamp_precision dataMinTime dataMaxTime range w approach
  $HOME_PATH/query_experiment.sh ${DEVICE} ${MEASUREMENT} ${TIMESTAMP_PRECISION} ${DATA_MIN_TIME} ${DATA_MAX_TIME} ${FIX_QUERY_RANGE} ${FIX_W} cpv >> result_${FIX_W}.txt
  java ProcessResult result_${FIX_W}.txt result_${FIX_W}.out ../sumResult_enableChunkIndex.csv

done


cd $HOME_PATH/${DATASET}_testspace/O_90_D_0_0_10000/fix
header=$(cat sumResult_disableChunkIndex.csv| sed -n 1p)
echo "numberOfPointsInChunk," "disableAll" $header "," "enableTimeIndexOnly" $header "," "enableAll" $header >> $HOME_PATH/${DATASET}_testspace/allMetrics.csv

echo "numberOfPointsInChunk,disableAll_QueryTime(ns),disableAll_CTGT_traversedPointNum,disableAll_MV_traversedPointNum,\
enableTimeIndexOnly_QueryTime(ns),enableTimeIndexOnly_CTGT_traversedPointNum,enableTimeIndexOnly_MV_traversedPointNum,\
enableAll_QueryTime(ns),enableAll_CTGT_traversedPointNum,enableAll_MV_traversedPointNum" >> $HOME_PATH/ablationExp_res.csv
for IOTDB_CHUNK_POINT_SIZE in 10000 50000 100000 500000 1000000 3000000 5000000
do
  workspace="O_90_D_0_0_${IOTDB_CHUNK_POINT_SIZE}"
  cd $HOME_PATH/${DATASET}_testspace/${workspace}/fix

  disableChunkIndex_QueryTime=$(cat sumResult_disableChunkIndex.csv| cut -f 2 -d "," | sed -n 2p)
  disableChunkIndex_timeIndex_traversedPointNum=$(cat sumResult_disableChunkIndex.csv| cut -f 36 -d "," | sed -n 2p)
  disableChunkIndex_valueIndex_traversedPointNum=$(cat sumResult_disableChunkIndex.csv| cut -f 37 -d "," | sed -n 2p)
  disableChunkIndex_line=$(cat sumResult_disableChunkIndex.csv| sed -n 2p)

  enableTimeIndexOnly_QueryTime=$(cat sumResult_enableTimeIndexOnly.csv| cut -f 2 -d "," | sed -n 2p)
  enableTimeIndexOnly_timeIndex_traversedPointNum=$(cat sumResult_enableTimeIndexOnly.csv| cut -f 36 -d "," | sed -n 2p)
  enableTimeIndexOnly_valueIndex_traversedPointNum=$(cat sumResult_enableTimeIndexOnly.csv| cut -f 37 -d "," | sed -n 2p)
  enableTimeIndexOnly_line=$(cat sumResult_enableTimeIndexOnly.csv| sed -n 2p)

  enableChunkIndex_QueryTime=$(cat sumResult_enableChunkIndex.csv| cut -f 2 -d "," | sed -n 2p)
  enableChunkIndex_timeIndex_traversedPointNum=$(cat sumResult_enableChunkIndex.csv| cut -f 36 -d "," | sed -n 2p)
  enableChunkIndex_valueIndex_traversedPointNum=$(cat sumResult_enableChunkIndex.csv| cut -f 37 -d "," | sed -n 2p)
  enableChunkIndex_line=$(cat sumResult_enableChunkIndex.csv| sed -n 2p)

  echo ${IOTDB_CHUNK_POINT_SIZE} "," \
  ${disableChunkIndex_QueryTime} "," \
  ${disableChunkIndex_timeIndex_traversedPointNum} "," \
  ${disableChunkIndex_valueIndex_traversedPointNum} "," \
  ${enableTimeIndexOnly_QueryTime} "," \
  ${enableTimeIndexOnly_timeIndex_traversedPointNum} "," \
  ${enableTimeIndexOnly_valueIndex_traversedPointNum} "," \
  ${enableChunkIndex_QueryTime} "," \
  ${enableChunkIndex_timeIndex_traversedPointNum} "," \
  ${enableChunkIndex_valueIndex_traversedPointNum} \
  >> $HOME_PATH/ablationExp_res.csv

  echo ${IOTDB_CHUNK_POINT_SIZE} "," \
  ${disableChunkIndex_line} "," \
  ${enableTimeIndexOnly_line} "," \
  ${enableChunkIndex_line} \
  >> $HOME_PATH/${DATASET}_testspace/allMetrics.csv
done

echo "ALL FINISHED!"
echo 3 |sudo tee /proc/sys/vm/drop_caches
free -m