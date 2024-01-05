#!/bin/bash

HOME_PATH=moreBaselinesQueryExp
DATA_MIN_TIME=0  # in the corresponding timestamp precision
DATA_MAX_TIME=617426057626  # in the corresponding timestamp precision

rm ${HOME_PATH}/rustPlot.sh
rm ${HOME_PATH}/dssimCompare.sh

for w in 100 200 400 600 1200 2000 3000 4000
do
  approachArray=("mac" "cpv" "minmax" "minmax_lsm" "lttb" "rawQuery");
  for approach in ${approachArray[@]};
  do
      python3 ${HOME_PATH}/parse.py -i ${HOME_PATH} -a ${approach} -w ${w} -H 100 -tqs ${DATA_MIN_TIME} -tqe ${DATA_MAX_TIME} -o ${HOME_PATH}

      # arguments: width,height,csv_path,has_header
      echo "${HOME_PATH}/line-density ${w} 100 ${HOME_PATH}/ts-${approach}-${w}.csv true" >> ${HOME_PATH}/rustPlot.sh

      echo "echo \"w=${w}, DSSIM(${approach},rawQuery)=\"" >> ${HOME_PATH}/dssimCompare.sh
      echo "python3 ${HOME_PATH}/calcDSSIM.py -f1 ${HOME_PATH}/ts-${approach}-${w}.csv-${w}.png -f2 ${HOME_PATH}/ts-rawQuery-${w}.csv-${w}.png" >> ${HOME_PATH}/dssimCompare.sh
  done;
done;

echo "echo \"ALL FINISHED!\"" >> ${HOME_PATH}/rustPlot.sh
echo "echo \"ALL FINISHED!\"" >> ${HOME_PATH}/dssimCompare.sh

find $HOME_PATH -type f -iname "*.sh" -exec chmod +x {} \;

echo "ALL FINISHED!"
echo 3 |sudo tee /proc/sys/vm/drop_caches
free -m
