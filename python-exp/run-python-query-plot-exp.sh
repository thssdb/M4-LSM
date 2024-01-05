#!/bin/bash

export READ_METHOD=rawQuery # rawQuery/mac/cpv
export M4_VISUALIZATION_EXP=/root/ubuntu/M4-visualization-exp
export remote_M4_VISUALIZATION_EXP=/root/ubuntu/M4-visualization-exp
export remote_IOTDB_HOME_PATH=/root/ubuntu/motivationExp
export remote_ip=80.240.20.233
export remote_user_name=root
export remote_passwd='(q3N?],hskEes]-!' # do not use double quotes

# below are local client configurations
export PYTHON_READ_PLOT_PATH=$M4_VISUALIZATION_EXP/python-exp/python-read-plot.py
export EXPERIMENT_PATH=$M4_VISUALIZATION_EXP/python-exp/python_query_plot_experiment.sh
export repetition=20
export PROCESS_QUERY_PLOT_JAVA_PATH=$M4_VISUALIZATION_EXP/python-exp/ProcessQueryPlotResult.java
export tqs=1329929188967032000
export w=1000
export local_FILE_PATH=$M4_VISUALIZATION_EXP/python-exp/localData.csv

# below are remote data server configurations
export remote_IOTDB_SBIN_HOME=$remote_IOTDB_HOME_PATH/iotdb-server-0.12.4/sbin
export remote_IOTDB_CONF_PATH=$remote_IOTDB_HOME_PATH/iotdb-server-0.12.4/conf/iotdb-engine.properties
export remote_IOTDB_START=$remote_IOTDB_SBIN_HOME/start-server.sh
export remote_IOTDB_STOP=$remote_IOTDB_SBIN_HOME/stop-server.sh
export remote_IOTDB_EXPORT_CSV_TOOL=$remote_IOTDB_HOME_PATH/iotdb-cli-0.12.4/tools
export remote_iotdb_port=6667
export remote_iotdb_username=root
export remote_iotdb_passwd=root
export remote_RAW_FILE_PATH=$remote_IOTDB_HOME_PATH/MF03/MF03.csv
export remote_tool_bash=$remote_M4_VISUALIZATION_EXP/python-exp/tool.sh
export remote_M4_FILE_PATH=$remote_M4_VISUALIZATION_EXP/python-exp/m4.csv

echo "begin"

# prepare ProcessQueryPlotResult tool
sed '/^package/d' ProcessQueryPlotResult.java > ProcessQueryPlotResult2.java
rm ProcessQueryPlotResult.java
mv ProcessQueryPlotResult2.java ProcessQueryPlotResult.java
javac ProcessQueryPlotResult.java

for N in 10000000 20000000 30000000 40000000 50000000 60000000 70000000 80000000 90000000 100000000
do
	echo "N=$N"
	export N=$N

	# set tqe according to N
	# make this access remote file and output to local export
	sshpass -p "${remote_passwd}" ssh ${remote_user_name}@${remote_ip} "sed -n '$N p' $remote_RAW_FILE_PATH" > temporary.out
	export tqe=$(cut -d, -f1 temporary.out)
	echo "tqe=$tqe"

	$EXPERIMENT_PATH >result-${READ_METHOD}_${N}.txt #> is overwrite, >> is append

	java ProcessQueryPlotResult result-${READ_METHOD}_${N}.txt result-${READ_METHOD}_${N}.out sumResult-${READ_METHOD}.csv ${N}
done

echo "ALL FINISHED!"
echo 3 |sudo tee /proc/sys/vm/drop_caches
free -m