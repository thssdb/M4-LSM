BASE_HOME=/root/ubuntu

M4_VISUALIZATION_EXP=${BASE_HOME}/M4-visualization-exp
HOME_PATH=${BASE_HOME}/v4

VALUE_ENCODING=PLAIN # RLE for int/long, GORILLA for float/double
TIME_ENCODING=PLAIN # TS_2DIFF
COMPRESSOR=UNCOMPRESSED

mkdir -p $HOME_PATH

find $M4_VISUALIZATION_EXP -type f -iname "*.sh" -exec chmod +x {} \;
find $M4_VISUALIZATION_EXP -type f -iname "*.sh" -exec sed -i -e 's/\r$//' {} \;

# check bc installed
REQUIRED_PKG="bc"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
  echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
  sudo apt-get --yes install $REQUIRED_PKG
fi

#====prepare general environment====
cd $HOME_PATH
cp $M4_VISUALIZATION_EXP/tools/tool.sh .
cp $M4_VISUALIZATION_EXP/jars/WriteData-*.jar .
cp $M4_VISUALIZATION_EXP/jars/WriteUpdateData-*.jar .
cp $M4_VISUALIZATION_EXP/jars/QueryData-*.jar .
cp $M4_VISUALIZATION_EXP/tools/query_experiment.sh .
$HOME_PATH/tool.sh HOME_PATH $HOME_PATH $HOME_PATH/query_experiment.sh
scp -r $M4_VISUALIZATION_EXP/iotdb-server-0.12.4 .
scp -r $M4_VISUALIZATION_EXP/iotdb-cli-0.12.4 .
cp $M4_VISUALIZATION_EXP/tools/iotdb-engine-example.properties .
cp $M4_VISUALIZATION_EXP/tools/ProcessResult.java .
cp $M4_VISUALIZATION_EXP/tools/SumResultUnify.java .
# remove the line starting with "package" in the java file
sed '/^package/d' ProcessResult.java > ProcessResult2.java
rm ProcessResult.java
mv ProcessResult2.java ProcessResult.java
# then javac it
javac ProcessResult.java
# remove the line starting with "package" in the java file
sed '/^package/d' SumResultUnify.java > SumResultUnify2.java
rm SumResultUnify.java
mv SumResultUnify2.java SumResultUnify.java
# then javac it
javac SumResultUnify.java

#====prepare run bash for ballspeed====
idArray=("1" "2" "3" "4" "5");
for value in ${idArray[@]};
do
cd $HOME_PATH
cp $M4_VISUALIZATION_EXP/bash/run-single-${value}.sh .
$HOME_PATH/tool.sh HOME_PATH $HOME_PATH run-single-${value}.sh
$HOME_PATH/tool.sh DATASET BallSpeed run-single-${value}.sh
$HOME_PATH/tool.sh DEVICE "root.game" run-single-${value}.sh
$HOME_PATH/tool.sh MEASUREMENT "s6" run-single-${value}.sh
$HOME_PATH/tool.sh DATA_TYPE long run-single-${value}.sh
$HOME_PATH/tool.sh TIMESTAMP_PRECISION ns run-single-${value}.sh
$HOME_PATH/tool.sh DATA_MIN_TIME 0 run-single-${value}.sh
$HOME_PATH/tool.sh DATA_MAX_TIME 4259092178974 run-single-${value}.sh
$HOME_PATH/tool.sh TOTAL_POINT_NUMBER 7193200 run-single-${value}.sh
$HOME_PATH/tool.sh IOTDB_CHUNK_POINT_SIZE 1000 run-single-${value}.sh
$HOME_PATH/tool.sh VALUE_ENCODING ${VALUE_ENCODING} run-single-${value}.sh # four dataset value types are the same, so can assign the same encodingType
$HOME_PATH/tool.sh TIME_ENCODING ${TIME_ENCODING} run-single-${value}.sh
$HOME_PATH/tool.sh COMPRESSOR ${COMPRESSOR} run-single-${value}.sh
$HOME_PATH/tool.sh hasHeader false run-single-${value}.sh
cp run-single-${value}.sh run-BallSpeed-${value}.sh

done;

#====prepare run bash for mf03====
idArray=("1" "2" "3" "4" "5");
for value in ${idArray[@]};
do
cd $HOME_PATH
cp $M4_VISUALIZATION_EXP/bash/run-single-${value}.sh .
$HOME_PATH/tool.sh HOME_PATH $HOME_PATH run-single-${value}.sh
$HOME_PATH/tool.sh DATASET MF03 run-single-${value}.sh
$HOME_PATH/tool.sh DEVICE "root.debs2012" run-single-${value}.sh
$HOME_PATH/tool.sh MEASUREMENT "mf03" run-single-${value}.sh
$HOME_PATH/tool.sh DATA_TYPE long run-single-${value}.sh
$HOME_PATH/tool.sh TIMESTAMP_PRECISION ns run-single-${value}.sh
$HOME_PATH/tool.sh DATA_MIN_TIME 1329929188967032000 run-single-${value}.sh
$HOME_PATH/tool.sh DATA_MAX_TIME 1330029647713284600 run-single-${value}.sh
$HOME_PATH/tool.sh TOTAL_POINT_NUMBER 10000000 run-single-${value}.sh
$HOME_PATH/tool.sh IOTDB_CHUNK_POINT_SIZE 1000 run-single-${value}.sh
$HOME_PATH/tool.sh VALUE_ENCODING ${VALUE_ENCODING} run-single-${value}.sh # four dataset value types are the same, so can assign the same encodingType
$HOME_PATH/tool.sh TIME_ENCODING ${TIME_ENCODING} run-single-${value}.sh
$HOME_PATH/tool.sh COMPRESSOR ${COMPRESSOR} run-single-${value}.sh
$HOME_PATH/tool.sh hasHeader false run-single-${value}.sh
cp run-single-${value}.sh run-MF03-${value}.sh

done;

#====prepare run bash for train====
idArray=("1" "2" "3" "4" "5");
for value in ${idArray[@]};
do
cd $HOME_PATH
cp $M4_VISUALIZATION_EXP/bash/run-single-${value}.sh .
$HOME_PATH/tool.sh HOME_PATH $HOME_PATH run-single-${value}.sh
$HOME_PATH/tool.sh DATASET Train run-single-${value}.sh #
$HOME_PATH/tool.sh DEVICE "root.group6.d17" run-single-${value}.sh #
$HOME_PATH/tool.sh MEASUREMENT "Z765" run-single-${value}.sh #
$HOME_PATH/tool.sh DATA_TYPE long run-single-${value}.sh #
$HOME_PATH/tool.sh TIMESTAMP_PRECISION ms run-single-${value}.sh #
$HOME_PATH/tool.sh DATA_MIN_TIME 1591717867194 run-single-${value}.sh #
$HOME_PATH/tool.sh DATA_MAX_TIME 1605706903793 run-single-${value}.sh #
$HOME_PATH/tool.sh TOTAL_POINT_NUMBER 127802876 run-single-${value}.sh #
$HOME_PATH/tool.sh IOTDB_CHUNK_POINT_SIZE 10000 run-single-${value}.sh #
$HOME_PATH/tool.sh VALUE_ENCODING ${VALUE_ENCODING} run-single-${value}.sh # four dataset value types are the same, so can assign the same encodingType
$HOME_PATH/tool.sh TIME_ENCODING ${TIME_ENCODING} run-single-${value}.sh
$HOME_PATH/tool.sh COMPRESSOR ${COMPRESSOR} run-single-${value}.sh #
$HOME_PATH/tool.sh hasHeader true run-single-${value}.sh #
cp run-single-${value}.sh run-Train-${value}.sh

done;

#====prepare run bash for steel====
idArray=("1" "2" "3" "4" "5");
for value in ${idArray[@]};
do
cd $HOME_PATH
cp $M4_VISUALIZATION_EXP/bash/run-single-${value}.sh .
$HOME_PATH/tool.sh HOME_PATH $HOME_PATH run-single-${value}.sh
$HOME_PATH/tool.sh DATASET Steel run-single-${value}.sh
$HOME_PATH/tool.sh DEVICE "root.group2.d7" run-single-${value}.sh
$HOME_PATH/tool.sh MEASUREMENT "c60" run-single-${value}.sh
$HOME_PATH/tool.sh DATA_TYPE double run-single-${value}.sh
$HOME_PATH/tool.sh TIMESTAMP_PRECISION ms run-single-${value}.sh
$HOME_PATH/tool.sh DATA_MIN_TIME 1664062557838 run-single-${value}.sh
$HOME_PATH/tool.sh DATA_MAX_TIME 1683566109697 run-single-${value}.sh
$HOME_PATH/tool.sh TOTAL_POINT_NUMBER 314572100 run-single-${value}.sh
$HOME_PATH/tool.sh IOTDB_CHUNK_POINT_SIZE 10000 run-single-${value}.sh
$HOME_PATH/tool.sh VALUE_ENCODING ${VALUE_ENCODING} run-single-${value}.sh # four dataset value types are the same, so can assign the same encodingType
$HOME_PATH/tool.sh TIME_ENCODING ${TIME_ENCODING} run-single-${value}.sh
$HOME_PATH/tool.sh COMPRESSOR ${COMPRESSOR} run-single-${value}.sh
$HOME_PATH/tool.sh hasHeader true run-single-${value}.sh
cp run-single-${value}.sh run-Steel-${value}.sh

done;

#====prepare run bash for CQD1====
cd $HOME_PATH
cp $M4_VISUALIZATION_EXP/bash/run-update.sh .
$HOME_PATH/tool.sh HOME_PATH $HOME_PATH run-update.sh
$HOME_PATH/tool.sh DATASET CQD1 run-update.sh
$HOME_PATH/tool.sh DEVICE "root.ooo" run-update.sh
$HOME_PATH/tool.sh MEASUREMENT "cq" run-update.sh
$HOME_PATH/tool.sh DATA_TYPE double run-update.sh
$HOME_PATH/tool.sh TIMESTAMP_PRECISION ms run-update.sh
# 500ms 5s
$HOME_PATH/tool.sh DATA_MIN_TIME 1415624020125 run-update.sh
$HOME_PATH/tool.sh DATA_MAX_TIME 1421759019625 run-update.sh
$HOME_PATH/tool.sh TOTAL_POINT_NUMBER 121800000 run-update.sh
$HOME_PATH/tool.sh FIX_W 100 run-update.sh
$HOME_PATH/tool.sh IOTDB_CHUNK_POINT_SIZE 10000 run-update.sh
# 500ms 5s
$HOME_PATH/tool.sh VALUE_ENCODING ${VALUE_ENCODING} run-update.sh # four dataset value types are the same, so can assign the same encodingType
$HOME_PATH/tool.sh TIME_ENCODING ${TIME_ENCODING} run-update.sh
$HOME_PATH/tool.sh COMPRESSOR ${COMPRESSOR} run-update.sh
$HOME_PATH/tool.sh hasHeader false run-update.sh
mv run-update.sh run-CQD1-2.sh

#====prepare directory for each dataset====
datasetArray=("BallSpeed" "MF03" "Train" "Steel" "CQD1");
for value in ${datasetArray[@]};
do
echo "prepare $value directory, this is for data";
cd $HOME_PATH
mkdir $value
cd $value
cp $M4_VISUALIZATION_EXP/datasets/$value.csv .
cp $M4_VISUALIZATION_EXP/tools/OverlapGenerator.java .
# remove the line starting with "package" in the java file
sed '/^package/d' OverlapGenerator.java > OverlapGenerator2.java
rm OverlapGenerator.java
mv OverlapGenerator2.java OverlapGenerator.java
# then javac it
javac OverlapGenerator.java
cp $M4_VISUALIZATION_EXP/tools/AppendTool.java .
# remove the line starting with "package" in the java file
sed '/^package/d' AppendTool.java > AppendTool2.java
rm AppendTool.java
mv AppendTool2.java AppendTool.java
# then javac it
javac AppendTool.java

if [ $value == "CQD1" ]
then
java AppendTool $value.csv $value-cp.csv 10000
rm $value.csv
mv $value-cp.csv $value.csv
fi

echo "prepare ${value}_testspace directory, this is for write and query";
cd $HOME_PATH
mkdir ${value}_testspace

done;

find $HOME_PATH -type f -iname "*.sh" -exec chmod +x {} \;

echo "finish"
