BASE_HOME=/root/ubuntu

M4_VISUALIZATION_EXP=${BASE_HOME}/M4-visualization-exp
HOME_PATH=${BASE_HOME}/updateExp

VALUE_ENCODING=PLAIN # RLE for int/long, GORILLA for float/double
TIME_ENCODING=PLAIN # TS_2DIFF
COMPRESSOR=UNCOMPRESSED #SNAPPY

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

#====prepare run bash for each dataset====
cd $HOME_PATH
cp $M4_VISUALIZATION_EXP/bash/run-update.sh .
$HOME_PATH/tool.sh HOME_PATH $HOME_PATH run-update.sh
$HOME_PATH/tool.sh DATASET CQD1 run-update.sh
$HOME_PATH/tool.sh DEVICE "root.ooo" run-update.sh
$HOME_PATH/tool.sh MEASUREMENT "cq" run-update.sh
$HOME_PATH/tool.sh DATA_TYPE double run-update.sh
$HOME_PATH/tool.sh TIMESTAMP_PRECISION ms run-update.sh

## 5s 10s
#$HOME_PATH/tool.sh DATA_MIN_TIME 1415624015125 run-update.sh
#$HOME_PATH/tool.sh DATA_MAX_TIME 1421774010125 run-update.sh
#$HOME_PATH/tool.sh TOTAL_POINT_NUMBER 2440000 run-update.sh
#$HOME_PATH/tool.sh FIX_W 100 run-update.sh
#$HOME_PATH/tool.sh IOTDB_CHUNK_POINT_SIZE 1000 run-update.sh

# 500ms 5s
$HOME_PATH/tool.sh DATA_MIN_TIME 1415624020125 run-update.sh
$HOME_PATH/tool.sh DATA_MAX_TIME 1421759019625 run-update.sh
$HOME_PATH/tool.sh TOTAL_POINT_NUMBER 121800000 run-update.sh
$HOME_PATH/tool.sh FIX_W 100 run-update.sh
$HOME_PATH/tool.sh IOTDB_CHUNK_POINT_SIZE 10000 run-update.sh

$HOME_PATH/tool.sh VALUE_ENCODING ${VALUE_ENCODING} run-update.sh # four dataset value types are the same, so can assign the same encodingType
$HOME_PATH/tool.sh TIME_ENCODING ${TIME_ENCODING} run-update.sh
$HOME_PATH/tool.sh COMPRESSOR ${COMPRESSOR} run-update.sh
$HOME_PATH/tool.sh hasHeader false run-update.sh

#====prepare directory for each dataset====
datasetArray=("CQD1");
for value in ${datasetArray[@]};
do
echo "prepare data directory";
cd $HOME_PATH
mkdir $value
cd $value
cp $M4_VISUALIZATION_EXP/datasets/$value.csv .
cp $M4_VISUALIZATION_EXP/tools/AppendTool.java .
# remove the line starting with "package" in the java file
sed '/^package/d' AppendTool.java > AppendTool2.java
rm AppendTool.java
mv AppendTool2.java AppendTool.java
# then javac it
javac AppendTool.java
java AppendTool $value.csv $value-cp.csv 10000
rm $value.csv
mv $value-cp.csv $value.csv

#cp $M4_VISUALIZATION_EXP/tools/OverlapGenerator.java .
## remove the line starting with "package" in the java file
#sed '/^package/d' OverlapGenerator.java > OverlapGenerator2.java
#rm OverlapGenerator.java
#mv OverlapGenerator2.java OverlapGenerator.java
## then javac it
#javac OverlapGenerator.java

echo "prepare testspace directory";
cd $HOME_PATH
mkdir ${value}_testspace

done;

find $HOME_PATH -type f -iname "*.sh" -exec chmod +x {} \;

echo "finish"
