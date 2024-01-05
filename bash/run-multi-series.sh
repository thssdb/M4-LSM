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

echo 3 |sudo tee /proc/sys/vm/drop_cache
free -m
echo "Begin experiment!"

overlap_percentage=0
workspace="O_${overlap_percentage}_D_0_0"
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
# properties for cpv
$HOME_PATH/tool.sh enable_CPV true ../../iotdb-engine-example.properties
cp ../../iotdb-engine-example.properties iotdb-engine-enableCPVtrue.properties
# properties for moc
$HOME_PATH/tool.sh enable_CPV false ../../iotdb-engine-example.properties
cp ../../iotdb-engine-example.properties iotdb-engine-enableCPVfalse.properties

# [query data]
echo "Querying O_${overlap_percentage}_D_0_0 with varied number of time series"
cd $HOME_PATH/${DATASET}_testspace/O_${overlap_percentage}_D_0_0
mkdir vary_ts

echo "mac"
cd $HOME_PATH/${DATASET}_testspace/O_${overlap_percentage}_D_0_0/vary_ts
mkdir mac
cd mac
cp $HOME_PATH/ProcessResultMultiSeries.* .
cp ../../iotdb-engine-enableCPVfalse.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
echo "time(ns)" >> ../sumResultMAC.csv
i=1
# for nts in 1 10 50 100 200 300 400 500 600 700 800
for nts in 1 5 10 15 20 25 30 35 40 45
do
  echo "number of time series=$nts"
  # Usage: ./query_experiment_multiseries.sh device measurement timestamp_precision dataMinTime dataMaxTime range nts approach
  $HOME_PATH/query_experiment_multiseries.sh ${DEVICE} ${MEASUREMENT} ${TIMESTAMP_PRECISION} ${DATA_MIN_TIME} ${DATA_MAX_TIME} ${FIX_QUERY_RANGE} $nts mac >> result_${i}.txt
  java ProcessResultMultiSeries result_${i}.txt ../sumResultMAC.csv # average and append into sumResultMAC.csv
  let i+=1
done

echo "cpv"
cd $HOME_PATH/${DATASET}_testspace/O_${overlap_percentage}_D_0_0/vary_ts
mkdir cpv
cd cpv
cp $HOME_PATH/ProcessResultMultiSeries.* .
cp ../../iotdb-engine-enableCPVtrue.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
echo "time(ns)" >> ../sumResultCPV.csv
i=1
# for nts in 1 10 50 100 200 300 400 500 600 700 800
for nts in 1 5 10 15 20 25 30 35 40 45
do
  echo "number of time series=$nts"
  # Usage: ./query_experiment_multiseries.sh device measurement timestamp_precision dataMinTime dataMaxTime range w approach
  $HOME_PATH/query_experiment_multiseries.sh ${DEVICE} ${MEASUREMENT} ${TIMESTAMP_PRECISION} ${DATA_MIN_TIME} ${DATA_MAX_TIME} ${FIX_QUERY_RANGE} $nts cpv >> result_${i}.txt
  java ProcessResultMultiSeries result_${i}.txt ../sumResultCPV.csv # average and append into sumResultCPV.csv
  let i+=1
done

echo "raw"
cd $HOME_PATH/${DATASET}_testspace/O_${overlap_percentage}_D_0_0/vary_ts
mkdir raw
cd raw
cp $HOME_PATH/ProcessResultMultiSeries.* .
cp ../../iotdb-engine-enableCPVfalse.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
echo "time(ns)" >> ../sumResultRAW.csv
i=1
# for nts in 1 10 50 100 200 300 400 500 600 700 800
for nts in 1 5 10 15 20 25 30 35 40 45
do
  echo "number of time series=$nts"
  # Usage: ./query_experiment_multiseries.sh device measurement timestamp_precision dataMinTime dataMaxTime range nts approach
  $HOME_PATH/query_experiment_multiseries.sh ${DEVICE} ${MEASUREMENT} ${TIMESTAMP_PRECISION} ${DATA_MIN_TIME} ${DATA_MAX_TIME} ${FIX_QUERY_RANGE} $nts raw >> result_${i}.txt
  java ProcessResultMultiSeries result_${i}.txt ../sumResultRAW.csv # average and append into sumResultRAW.csv
  let i+=1
done

# unify results
cd $HOME_PATH/${DATASET}_testspace/O_${overlap_percentage}_D_0_0/vary_ts
cp $HOME_PATH/SumResultUnifyMultiSeries.* .
java SumResultUnifyMultiSeries sumResultRAW.csv sumResultMAC.csv sumResultCPV.csv result.csv
cp result.csv $HOME_PATH/res.csv

echo "ALL FINISHED!"
echo 3 |sudo tee /proc/sys/vm/drop_caches
free -m