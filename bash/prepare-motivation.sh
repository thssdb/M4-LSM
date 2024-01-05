M4_VISUALIZATION_EXP=/root/ubuntu/M4-visualization-exp
HOME_PATH=/root/ubuntu/motivationExp

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
cp $M4_VISUALIZATION_EXP/bash/run-motivation.sh .
$HOME_PATH/tool.sh HOME_PATH $HOME_PATH run-motivation.sh
$HOME_PATH/tool.sh DATASET MF03 run-motivation.sh
$HOME_PATH/tool.sh DEVICE "root.debs2012" run-motivation.sh
$HOME_PATH/tool.sh MEASUREMENT "mf03" run-motivation.sh
$HOME_PATH/tool.sh DATA_TYPE long run-motivation.sh
$HOME_PATH/tool.sh TIMESTAMP_PRECISION ns run-motivation.sh
$HOME_PATH/tool.sh DATA_MIN_TIME 1329929188967032000 run-motivation.sh
$HOME_PATH/tool.sh DATA_MAX_TIME 1331034235275774600 run-motivation.sh
$HOME_PATH/tool.sh TOTAL_POINT_NUMBER 100000000 run-motivation.sh
$HOME_PATH/tool.sh IOTDB_CHUNK_POINT_SIZE 1000 run-motivation.sh
$HOME_PATH/tool.sh VALUE_ENCODING ${VALUE_ENCODING} run-motivation.sh # four dataset value types are the same, so can assign the same encodingType
$HOME_PATH/tool.sh TIME_ENCODING ${TIME_ENCODING} run-motivation.sh
$HOME_PATH/tool.sh COMPRESSOR ${COMPRESSOR} run-motivation.sh

#====prepare directory for each dataset====
datasetArray=("MF03");
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
java AppendTool $value.csv $value-cp10.csv 10
rm $value.csv
mv $value-cp10.csv $value.csv
cp $M4_VISUALIZATION_EXP/tools/OverlapGenerator.java .
# remove the line starting with "package" in the java file
sed '/^package/d' OverlapGenerator.java > OverlapGenerator2.java
rm OverlapGenerator.java
mv OverlapGenerator2.java OverlapGenerator.java
# then javac it
javac OverlapGenerator.java

echo "prepare testspace directory";
cd $HOME_PATH
mkdir ${value}_testspace

done;

find $HOME_PATH -type f -iname "*.sh" -exec chmod +x {} \;

echo "finish"
