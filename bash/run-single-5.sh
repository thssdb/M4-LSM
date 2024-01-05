#!/bin/bash

# right now Not added in run-all.sh, but prepared in prepare-all.sh
# for update exp
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
#FIX_update_percentage=10
#FIX_DELETE_PERCENTAGE=49
#FIX_DELETE_RANGE=10

hasHeader=false # default

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
# [exp5] Varying chunk update percentage
# (1) w: 1000
# (2) query range: totalRange
# (3) overlap percentage: 0%
# (4) delete percentage: 0%
# (5) delete time range: 0
# (6) update percentage: 0%, 10%, 20%, 30%, 40%, 50%, 60%, 70%, 80%, 90%
############################
############################
# O_0_D_0_0_U_x
############################

for update_percentage in 0 10 20 30 40 50 60 70 80 90 100
#for update_percentage in 0 10 50 90
do
  workspace="O_0_D_0_0_U_${update_percentage}"
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
  $HOME_PATH/tool.sh error_Param 50 ../../iotdb-engine-example.properties
  # properties for cpv
  $HOME_PATH/tool.sh enable_CPV true ../../iotdb-engine-example.properties
  cp ../../iotdb-engine-example.properties iotdb-engine-enableCPVtrue.properties
  # properties for moc
  $HOME_PATH/tool.sh enable_CPV false ../../iotdb-engine-example.properties
  cp ../../iotdb-engine-example.properties iotdb-engine-enableCPVfalse.properties

  # [write data]
  echo "Writing ${workspace}"
  cp iotdb-engine-enableCPVfalse.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
  cd $HOME_PATH/iotdb-server-0.12.4/sbin
  ./start-server.sh /dev/null 2>&1 &
  sleep 8s
  # Usage: java -jar WriteUpdate*.jar device measurement dataType timestamp_precision iotdb_chunk_point_size filePath updatePercentage timeIdx valueIdx VALUE_ENCODING hasHeader
  # Example: "root.game" "s6" long ns 100 "D:\full-game\tmp.csv" 50 0 1 PLAIN true
  java -jar $HOME_PATH/WriteUpdate*.jar ${DEVICE} ${MEASUREMENT} ${DATA_TYPE} ${TIMESTAMP_PRECISION} ${IOTDB_CHUNK_POINT_SIZE} $HOME_PATH/${DATASET}/${DATASET}-O_0 ${update_percentage} 0 1 ${VALUE_ENCODING} ${hasHeader}
  sleep 5s
  ./stop-server.sh
  sleep 5s
  echo 3 | sudo tee /proc/sys/vm/drop_caches

  # [query data]
  echo "Querying ${workspace}"
  cd $HOME_PATH/${DATASET}_testspace/${workspace}
  mkdir fix

  # echo "moc"
  # cd $HOME_PATH/${DATASET}_testspace/${workspace}/fix
  # mkdir moc
  # cd moc
  # cp $HOME_PATH/ProcessResult.* .
  # cp ../../iotdb-engine-enableCPVfalse.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
  # # Usage: ./query_experiment.sh device measurement timestamp_precision dataMinTime dataMaxTime range w approach
  # $HOME_PATH/query_experiment.sh ${DEVICE} ${MEASUREMENT} ${TIMESTAMP_PRECISION} ${DATA_MIN_TIME} ${DATA_MAX_TIME} ${FIX_QUERY_RANGE} ${FIX_W} moc >> result_3.txt
  # java ProcessResult result_3.txt result_3.out ../sumResultMOC.csv

  echo "mac"
  cd $HOME_PATH/${DATASET}_testspace/${workspace}/fix
  mkdir mac
  cd mac
  cp $HOME_PATH/ProcessResult.* .
  cp ../../iotdb-engine-enableCPVfalse.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
  # Usage: ./query_experiment.sh device measurement timestamp_precision dataMinTime dataMaxTime range w approach
  $HOME_PATH/query_experiment.sh ${DEVICE} ${MEASUREMENT} ${TIMESTAMP_PRECISION} ${DATA_MIN_TIME} ${DATA_MAX_TIME} ${FIX_QUERY_RANGE} ${FIX_W} mac >> result_3.txt
  java ProcessResult result_3.txt result_3.out ../sumResultMAC.csv

  echo "cpv"
  cd $HOME_PATH/${DATASET}_testspace/${workspace}/fix
  mkdir cpv
  cd cpv
  cp $HOME_PATH/ProcessResult.* .
  cp ../../iotdb-engine-enableCPVtrue.properties $HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
  # Usage: ./query_experiment.sh device measurement timestamp_precision dataMinTime dataMaxTime range w approach
  $HOME_PATH/query_experiment.sh ${DEVICE} ${MEASUREMENT} ${TIMESTAMP_PRECISION} ${DATA_MIN_TIME} ${DATA_MAX_TIME} ${FIX_QUERY_RANGE} ${FIX_W} cpv >> result_3.txt
  java ProcessResult result_3.txt result_3.out ../sumResultCPV.csv

  # unify results
  cd $HOME_PATH/${DATASET}_testspace/${workspace}/fix
  cp $HOME_PATH/SumResultUnify.* .
  # java SumResultUnify sumResultMOC.csv sumResultMAC.csv sumResultCPV.csv result.csv
  java SumResultUnify sumResultMAC.csv sumResultCPV.csv result.csv
done

# export results
# [exp5]
# (1) w: 1000
# (2) query range: totalRange
# (3) overlap percentage: 0%
# (4) delete percentage: 0%
# (5) delete time range: 0
# (6) update percentage: 0%, 10%, 20%, 30%, 40%, 50%, 60%, 70%, 80%, 90%

cd $HOME_PATH/${DATASET}_testspace/O_0_D_0_0_U_0
cd fix
sed -n '1,1p' result.csv >>$HOME_PATH/${DATASET}_testspace/exp5.csv #only copy header

## overlap percentage 10% exp result
## 把exp1.csv里的w=FIX_W那一行复制到exp5.csv里作为overlap percentage 10%的结果
## append the line starting with FIX_W and without the first two columns in exp1.csv to exp5.csv
## sed -n '8,8p' $HOME_PATH/${DATASET}_testspace/exp1.csv >> $HOME_PATH/${DATASET}_testspace/exp4.csv
#sed -n -e "/^${FIX_W},/p" $HOME_PATH/${DATASET}_testspace/exp1.csv > tmp # the line starting with FIX_W
#cut -d "," -f 3- tmp >> $HOME_PATH/${DATASET}_testspace/exp5.csv # without the first two columns
#rm tmp

for update_percentage in 0 10 20 30 40 50 60 70 80 90 100
#for update_percentage in 0 10 50 90
do
  cd $HOME_PATH/${DATASET}_testspace/O_0_D_0_0_U_${update_percentage}
  cd fix
  sed -n '2,2p' result.csv >>$HOME_PATH/${DATASET}_testspace/exp5.csv
done

# add varied parameter value and the corresponding estimated chunks per interval for each line
# estimated chunks per interval = range/w/(totalRange/(pointNum/chunkSize))
# for exp5, range=totalRange, estimated chunks per interval=(pointNum/chunkSize)/w
sed -i -e 1's/^/update percentage,estimated chunks per interval,/' $HOME_PATH/${DATASET}_testspace/exp5.csv
line=2
for update_percentage in 0 10 20 30 40 50 60 70 80 90 100
#for update_percentage in 0 10 50 90
do
  c=$((echo scale=3 ; echo ${TOTAL_POINT_NUMBER}/${IOTDB_CHUNK_POINT_SIZE}/${FIX_W}) | bc )
  sed -i -e ${line}"s/^/${update_percentage},${c},/" $HOME_PATH/${DATASET}_testspace/exp5.csv
  let line+=1
done

(cut -f 1 -d "," $HOME_PATH/${DATASET}_testspace/exp5.csv) > tmp1.csv
(cut -f 4 -d "," $HOME_PATH/${DATASET}_testspace/exp5.csv| paste -d, tmp1.csv -) > tmp2.csv
(cut -f 71 -d "," $HOME_PATH/${DATASET}_testspace/exp5.csv| paste -d, tmp2.csv -) > tmp3.csv
echo "param,M4(ns),M4-LSM(ns)" > $HOME_PATH/${DATASET}_testspace/exp5_res.csv
sed '1d' tmp3.csv >> $HOME_PATH/${DATASET}_testspace/exp5_res.csv
rm tmp1.csv
rm tmp2.csv
rm tmp3.csv

echo "ALL FINISHED!"
echo 3 |sudo tee /proc/sys/vm/drop_caches
free -m