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


read_method=str(os.environ['READ_METHOD'])
print(read_method) # rawQuery/mac/cpv

# read data---------------------------------------------------------------------------
disk_file_path=str(os.environ['local_FILE_PATH'])
start = time.time_ns()
df = pd.read_csv(disk_file_path,engine="pyarrow") # the first line is header; use engine="pyarrow" to accelerate read_csv otherwise is slow
convert_dict = {
	df.columns[0]:np.int64,
	df.columns[1]:np.double,
}
df = df.astype(convert_dict)
parse_time = time.time_ns()-start
print(f"[1-ns]parse_data,{parse_time}") # print metric

# plot data---------------------------------------------------------------------------
x=df[df.columns[0]] # time
y=df[df.columns[1]] # value
r, c = df.shape
print(r) #number of points
print(c) #two columns: time and value

fig=plt.figure(1,dpi=120)
start = time.time_ns()
plt.plot(x,y,linewidth=0.5)
plt.savefig(os.environ['M4_VISUALIZATION_EXP']+"/python-exp/MF03-dataset-{}-{}.png".format(read_method,os.environ['N']),bbox_inches='tight') #specify absolute fig path
end = time.time_ns()
print(f"[1-ns]plot_data,{end - start}") # print metric

plt.close(fig)