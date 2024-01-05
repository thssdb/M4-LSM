BASE_PATH=/root/ubuntu

M4_VISUALIZATION_EXP=$BASE_PATH/M4-visualization-exp
HOME_PATH=$BASE_PATH/multiSeriesExp

VALUE_ENCODING=PLAIN # RLE for int/long, GORILLA for float/double
TIME_ENCODING=PLAIN # TS_2DIFF
COMPRESSOR=UNCOMPRESSED #SNAPPY
overlap_percentage=0

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
cp $M4_VISUALIZATION_EXP/jars/QueryDataMultiSeries*.jar .
cp $M4_VISUALIZATION_EXP/tools/query_experiment_multiseries.sh .
$HOME_PATH/tool.sh HOME_PATH $HOME_PATH $HOME_PATH/query_experiment_multiseries.sh
scp -r $M4_VISUALIZATION_EXP/iotdb-server-0.12.4 .
scp -r $M4_VISUALIZATION_EXP/iotdb-cli-0.12.4 .
cp $M4_VISUALIZATION_EXP/tools/iotdb-engine-example.properties .
cp $M4_VISUALIZATION_EXP/tools/ProcessResultMultiSeries.java .
cp $M4_VISUALIZATION_EXP/tools/SumResultUnifyMultiSeries.java .
# remove the line starting with "package" in the java file
sed '/^package/d' ProcessResultMultiSeries.java > ProcessResultMultiSeries2.java
rm ProcessResultMultiSeries.java
mv ProcessResultMultiSeries2.java ProcessResultMultiSeries.java
# then javac it
javac ProcessResultMultiSeries.java
# remove the line starting with "package" in the java file
sed '/^package/d' SumResultUnifyMultiSeries.java > SumResultUnifyMultiSeries2.java
rm SumResultUnifyMultiSeries.java
mv SumResultUnifyMultiSeries2.java SumResultUnifyMultiSeries.java
# then javac it
javac SumResultUnifyMultiSeries.java

#====prepare write bash====
cd $HOME_PATH
cp $M4_VISUALIZATION_EXP/bash/run-motivation.sh .
$HOME_PATH/tool.sh HOME_PATH $HOME_PATH run-motivation.sh
$HOME_PATH/tool.sh DATASET MF03 run-motivation.sh
#$HOME_PATH/tool.sh DEVICE "root.debs2012" run-motivation.sh
$HOME_PATH/tool.sh MEASUREMENT "mf03" run-motivation.sh
$HOME_PATH/tool.sh DATA_TYPE long run-motivation.sh
$HOME_PATH/tool.sh TIMESTAMP_PRECISION ns run-motivation.sh
$HOME_PATH/tool.sh DATA_MIN_TIME 1329929188967032000 run-motivation.sh
$HOME_PATH/tool.sh DATA_MAX_TIME 1330029647713284600 run-motivation.sh
$HOME_PATH/tool.sh TOTAL_POINT_NUMBER 10000000 run-motivation.sh
$HOME_PATH/tool.sh IOTDB_CHUNK_POINT_SIZE 10000 run-motivation.sh
$HOME_PATH/tool.sh VALUE_ENCODING ${VALUE_ENCODING} run-motivation.sh # four dataset value types are the same, so can assign the same encodingType
$HOME_PATH/tool.sh TIME_ENCODING ${TIME_ENCODING} run-motivation.sh
$HOME_PATH/tool.sh COMPRESSOR ${COMPRESSOR} run-motivation.sh
$HOME_PATH/tool.sh overlap_percentage ${overlap_percentage} run-motivation.sh

for i in {1..50}
do
$HOME_PATH/tool.sh DEVICE "root.debs${i}" run-motivation.sh
cp run-motivation.sh run-write-$i.sh
echo "./run-write-$i.sh" >> run-write.sh # Serial write data to avoid memory contention
done;
echo "WRITE ALL FINISHED!" >> run-write.sh
rm run-motivation.sh
find $HOME_PATH -type f -iname "*.sh" -exec chmod +x {} \;

#====prepare query bash====
cd $HOME_PATH
cp $M4_VISUALIZATION_EXP/bash/run-multi-series.sh .
$HOME_PATH/tool.sh HOME_PATH $HOME_PATH run-multi-series.sh
$HOME_PATH/tool.sh DATASET MF03 run-multi-series.sh
$HOME_PATH/tool.sh DEVICE "root.debs" run-multi-series.sh
$HOME_PATH/tool.sh MEASUREMENT "mf03" run-multi-series.sh
$HOME_PATH/tool.sh DATA_TYPE long run-multi-series.sh
$HOME_PATH/tool.sh TIMESTAMP_PRECISION ns run-multi-series.sh
$HOME_PATH/tool.sh DATA_MIN_TIME 1329929188967032000 run-multi-series.sh
$HOME_PATH/tool.sh DATA_MAX_TIME 1330029647713284600 run-multi-series.sh
$HOME_PATH/tool.sh TOTAL_POINT_NUMBER 10000000 run-multi-series.sh
$HOME_PATH/tool.sh IOTDB_CHUNK_POINT_SIZE 10000 run-multi-series.sh
$HOME_PATH/tool.sh VALUE_ENCODING ${VALUE_ENCODING} run-multi-series.sh # four dataset value types are the same, so can assign the same encodingType
$HOME_PATH/tool.sh TIME_ENCODING ${TIME_ENCODING} run-multi-series.sh
$HOME_PATH/tool.sh COMPRESSOR ${COMPRESSOR} run-multi-series.sh
$HOME_PATH/tool.sh overlap_percentage ${overlap_percentage} run-multi-series.sh
mv run-multi-series.sh run-query.sh

#====prepare directory for each dataset====
datasetArray=("MF03");
for value in ${datasetArray[@]};
do
echo "prepare data directory";
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

echo "prepare testspace directory";
cd $HOME_PATH
mkdir ${value}_testspace

done;

find $HOME_PATH -type f -iname "*.sh" -exec chmod +x {} \;

echo "finish"
