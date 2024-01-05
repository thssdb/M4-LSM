#!/bin/bash

echo 3 | sudo tee /proc/sys/vm/drop_caches

sshpass -p "${remote_passwd}" ssh ${remote_user_name}@${remote_ip} "sed -i -e 's/\r$//' $remote_tool_bash"
if [ $READ_METHOD == "cpv" ]
then 
    sshpass -p "${remote_passwd}" ssh ${remote_user_name}@${remote_ip} "bash $remote_tool_bash enable_CPV true $remote_IOTDB_CONF_PATH"
fi


cd $IOTDB_SBIN_HOME
for((i=0;i<$repetition;i++)) do
    echo "repetition No.$i"

    # client get data from data server 
    # start remote iotdb server
    sshpass -p "${remote_passwd}" ssh ${remote_user_name}@${remote_ip} "bash ${remote_IOTDB_START} >/dev/null 2>&1 &" >/dev/null 2>&1 &
    sleep 10s

    # query at remote server and transfom query result to csv
    sshpass -p "${remote_passwd}" ssh ${remote_user_name}@${remote_ip} "python3 ${remote_M4_VISUALIZATION_EXP}/python-exp/remote-query-to-csv.py -r ${READ_METHOD} -f ${remote_M4_FILE_PATH} -s ${tqs} -e ${tqe} -w ${w} -t ${remote_IOTDB_EXPORT_CSV_TOOL}"
    
    # stop remote iotdb server
    sshpass -p "${remote_passwd}" ssh ${remote_user_name}@${remote_ip} "bash ${remote_IOTDB_STOP}"
    sleep 3s
    
    # transfer csv from server to client
    if [ $READ_METHOD == "mac" ] || [ $READ_METHOD == "cpv" ]
    then
        path=${remote_M4_FILE_PATH}
    else # rawQuery
        path=${remote_IOTDB_EXPORT_CSV_TOOL}/dump0.csv
    fi
    ts=$(date +%s%N)
    sshpass -p "${remote_passwd}" scp ${remote_user_name}@${remote_ip}:$path ${local_FILE_PATH}
    transfer_time=$((($(date +%s%N) - $ts)))
    echo "[1-ns]transfer_data,$transfer_time" # print metric

    # client local read and plot
    python3 $PYTHON_READ_PLOT_PATH

    echo 3 | sudo tee /proc/sys/vm/drop_caches
    sleep 3s
done
