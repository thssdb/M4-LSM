from iotdb.Session import Session
from iotdb.utils.IoTDBConstants import TSDataType, TSEncoding, Compressor
from iotdb.utils.Tablet import Tablet

from matplotlib import pyplot as plt
import numpy as np
import csv
import datetime
import pandas as pd
import time
import argparse
import sys
import os
import math
import re
import subprocess

def myDeduplicate(seq): # deduplicate list seq by comparing the first element, e.g. l=[(1,1),(1,2)] => l=[(1,1)]
    seen = set()
    seen_add = seen.add
    return [x for x in seq if not (x[0] in seen or seen_add(x[0]))]

# remote node has not exported the environment variables, so passing them using args
parser=argparse.ArgumentParser(description="remote query to csv",
	formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument("-r","--read",help="READ_METHOD")
parser.add_argument("-f","--file",help="remote_M4_FILE_PATH")
parser.add_argument("-s","--tqs",help="query start time")
parser.add_argument("-e","--tqe",help="query end time")
parser.add_argument("-w","--w",help="number of time spans")
parser.add_argument("-t","--tool",help="export csv tool directory path")
args = parser.parse_args()
config = vars(args)

read_method=str(config.get('read'))
outputCsvPath=config.get('file')
print(read_method)
print(outputCsvPath)

tqs=int(config.get('tqs'))
tqe=int(config.get('tqe'))
w=int(config.get('w'))
# post-process, make divisible
interval=math.ceil((tqe-tqs)/w)
tqe=tqs+interval*w
if read_method == 'mac': # row-by-row point window
	sql="SELECT M4(mf03,'tqs'='{}','tqe'='{}','w'='{}') FROM root.debs2012 where time>={} and time<{}".\
		format(tqs,tqe,w,tqs,tqe)
elif read_method == 'cpv': #cpv
	sql="select min_time(mf03), max_time(mf03), first_value(mf03), last_value(mf03), min_value(mf03), max_value(mf03) \
		from root.debs2012 group by ([{}, {}), {}ns)".format(tqs,tqe,interval)
else: #rawQuery
	sql="select mf03 from root.debs2012 where time>={} and time<{}".format(tqs,tqe)
print(sql)


if read_method == 'rawQuery':
	exportCsvPath=str(config.get('tool'))+"/export-csv.sh"
	start = time.time_ns()
	os.system("bash {} -h 127.0.0.1 -p 6667 -u root -pw root -q '{}' -td {} -tf timestamp".format(exportCsvPath,sql,str(config.get('tool'))))
	end = time.time_ns()
	print(f"[2-ns]Server_Query_Execute,{end - start}") # print metric

if read_method == 'mac' or read_method == 'cpv':
	ip = "127.0.0.1"
	port_ = "6667"
	username_ = "root"
	password_ = "root"
	fetchsize = 100000 # make it big enough to ensure no second fetch, for result.todf_noFetch
	session = Session(ip, port_, username_, password_, fetchsize)
	session.open(False)

	result = session.execute_query_statement(sql) # server execute metrics have been collected by session.execute_finish()

	start = time.time_ns() # for parse_data metric
	df = result.todf_noFetch() # Transform to Pandas Dataset
	if read_method == 'mac':
		# for each row, extract four points, sort and deduplicate, deal with empty
		ts=[]
		for ir in df.itertuples():
			string = ir[2] # ir[0] is idx
			# deal with "empty" string
			if str(string)=="empty":
				# print("empty")
				continue
			# deal with "FirstPoint=(t,v), LastPoint=(t,v), BottomPoint=(t,v), TopPoint=(t,v)"
			numberStrList = re.findall(r'\d+(?:\.\d+)?',string) # find int or float str

			FP_t=int(numberStrList[0])
			FP_v=float(numberStrList[1])
			LP_t=int(numberStrList[2])
			LP_v=float(numberStrList[3])
			BP_t=int(numberStrList[4])
			BP_v=float(numberStrList[5])
			TP_t=int(numberStrList[6])
			TP_v=float(numberStrList[7])

			ts.append((FP_t,FP_v))
			ts.append((LP_t,LP_v))
			ts.append((BP_t,BP_v))
			ts.append((TP_t,TP_v))

		# sort
		ts.sort(key=lambda x: x[0])

		# deduplicate
		ts=myDeduplicate(ts)

		df = pd.DataFrame(ts,columns=['time','value'])
		df.to_csv(outputCsvPath, sep=',',index=False)
	elif read_method == 'cpv':
		# for each row, extract four points, sort and deduplicate, deal with None
		ts=[]
		for ir in df.itertuples():
			# deal with "None" string
			string=ir[2] # ir[0] is idx
			if str(string)=="None" or pd.isnull(ir[2]):
				# print("None/NaN")
				continue

			# deal with minTime,maxTime,firstValue,lastValue,minValue[bottomTime],maxValue[TopTime]
			FP_t=int(ir[2])
			FP_v=float(ir[4])
			LP_t=int(ir[3])
			LP_v=float(ir[5])
			BP_str=ir[6]
			numberStrList = re.findall(r'\d+(?:\.\d+)?',BP_str) # find int or float str
			BP_t=int(numberStrList[1])
			BP_v=float(numberStrList[0])
			TP_str=ir[7]
			numberStrList = re.findall(r'\d+(?:\.\d+)?',TP_str) # find int or float str
			TP_t=int(numberStrList[1])
			TP_v=float(numberStrList[0])

			ts.append((FP_t,FP_v))
			ts.append((LP_t,LP_v))
			ts.append((BP_t,BP_v))
			ts.append((TP_t,TP_v))	
			
		# sort
		ts.sort(key=lambda x: x[0])

		# deduplicate
		ts=myDeduplicate(ts)	

		df = pd.DataFrame(ts,columns=['time','value'])
		df.to_csv(outputCsvPath, sep=',',index=False)
	else:
		print("unsupported read_method!")
	end = time.time_ns()
	print(f"[1-ns]parse_data,{end - start}") # print metric

	result = session.execute_finish() 
	print(result) # print metrics from IoTDB server
	session.close()