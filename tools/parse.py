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

# read csv, parse, plot

def myDeduplicate(seq): # deduplicate list seq by comparing the first element, e.g. l=[(1,1),(1,2)] => l=[(1,1)]
  seen = set()
  seen_add = seen.add
  return [x for x in seq if not (x[0] in seen or seen_add(x[0]))]

# remote node has not exported the environment variables, so passing them using args
parser=argparse.ArgumentParser(description="remote query to csv",
                               formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument("-i","--input",help="input directory")
parser.add_argument("-o","--output",help="output directory")
parser.add_argument("-a","--approach",help="approach")
parser.add_argument("-w","--width",help="width")
parser.add_argument("-H","--height",help="height")
parser.add_argument("-tqs","--tqs",help="query start time")
parser.add_argument("-tqe","--tqe",help="query end time")

args = parser.parse_args()
config = vars(args)

inputDir=str(config.get('input'))
outputDir=str(config.get('output'))
approach=str(config.get('approach'))
w=int(config.get('width'))
h=int(config.get('height'))
tqs=int(config.get('tqs'))
tqe=int(config.get('tqe'))

t_min=tqs
t_max_temp=tqe # not use max(t) because downsampling result may not cover the target end point
# t_min=511996 # BallSpeed dataset, corresponds to tqs in run-python-query-save-exp.sh
# t_max_temp=4259092178974 # BallSpeed dataset, corresponds to tqe in run-python-query-save-exp.sh
t_max=math.ceil((t_max_temp-t_min)/(2*w))*2*w+t_min # corresponds to tqe in query-save.py
print(t_max)

# --------------------input path--------------------------
inputCsvPath="{}/data-{}-{}.csv".format(inputDir,approach,w)

# --------------------output path--------------------------
outputCsvPath="{}/ts-{}-{}.csv".format(outputDir,approach,w)

# --------------------parse--------------------------
if approach == 'rawQuery': # hasHeader
  inputCsvPath="{}/data-{}-{}.csv".format(inputDir,approach,1) # rawQuery source only w=1
  # os.system("cp {} {}".format(inputCsvPath,outputCsvPath)
  df = pd.read_csv(inputCsvPath)
  t=df.iloc[:,0]
  v=df.iloc[:,1]
  # scale t -> x
  x=(t-t_min)/(t_max-t_min)*w
  # scale v -> y
  y=(v-v.min())/(v.max()-v.min())*h
  # print(x)
  # print(y)
  df = pd.DataFrame({'time':x,'value':y}) # output csv has header
  df['time'] = df['time'].apply(np.floor)
  df.to_csv(outputCsvPath, sep=',',index=False)

else: # no header
  df = pd.read_csv(inputCsvPath, sep='\t', header=None)

  if approach == 'mac':
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

    df = pd.DataFrame(ts,columns=['time','value']) # output csv has header

    t=df.iloc[:,0]
    v=df.iloc[:,1]
    # scale t -> x
    x=(t-t_min)/(t_max-t_min)*w
    x=x.apply(np.floor)
    # scale v -> y
    y=(v-v.min())/(v.max()-v.min())*h
    # print(x)
    # print(y)
    df = pd.DataFrame({'time':x,'value':y}) # output csv has header

    df.to_csv(outputCsvPath, sep=',',index=False)
  elif approach == 'cpv':
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
    # ts=myDeduplicate(ts)

    df = pd.DataFrame(ts,columns=['time','value'])

    t=df.iloc[:,0]
    v=df.iloc[:,1]
    # scale t -> x
    x=(t-t_min)/(t_max-t_min)*w
    x=x.apply(np.floor)

    # scale v -> y
    y=(v-v.min())/(v.max()-v.min())*h
    # print(x)
    # print(y)
    df = pd.DataFrame({'time':x,'value':y}) # output csv has header

    df.to_csv(outputCsvPath, sep=',',index=False)

  elif approach == 'minmax':
    # for each row, extract two points, sort and deduplicate, deal with empty
    ts=[]
    for ir in df.itertuples():
      string = ir[2] # ir[0] is idx
      # deal with "empty" string
      if str(string)=="empty":
        # print("empty")
        continue
      # deal with "FirstPoint=(t,v), LastPoint=(t,v), BottomPoint=(t,v), TopPoint=(t,v)"
      numberStrList = re.findall(r'\d+(?:\.\d+)?',string) # find int or float str

      BP_t=int(numberStrList[0])
      BP_v=float(numberStrList[1])
      TP_t=int(numberStrList[2])
      TP_v=float(numberStrList[3])

      ts.append((BP_t,BP_v))
      ts.append((TP_t,TP_v))

    # sort
    ts.sort(key=lambda x: x[0])

    # deduplicate
    ts=myDeduplicate(ts)

    df = pd.DataFrame(ts,columns=['time','value'])

    t=df.iloc[:,0]
    v=df.iloc[:,1]
    # scale t -> x
    x=(t-t_min)/(t_max-t_min)*w
    x=x.apply(np.floor)
    # scale v -> y
    y=(v-v.min())/(v.max()-v.min())*h
    # print(x)
    # print(y)
    df = pd.DataFrame({'time':x,'value':y}) # output csv has header

    df.to_csv(outputCsvPath, sep=',',index=False)

  elif approach == 'minmax_lsm':
    # for each row, extract two points, sort and deduplicate, deal with None
    ts=[]
    for ir in df.itertuples():
      # deal with "None" string
      string=ir[2] # ir[0] is idx
      if str(string)=="None" or pd.isnull(ir[2]):
        # print("None/NaN")
        continue

      # deal with minValue[bottomTime],maxValue[TopTime]
      BP_str=ir[2]
      numberStrList = re.findall(r'\d+(?:\.\d+)?',BP_str) # find int or float str
      BP_t=int(numberStrList[1])
      BP_v=float(numberStrList[0])
      TP_str=ir[3]
      numberStrList = re.findall(r'\d+(?:\.\d+)?',TP_str) # find int or float str
      TP_t=int(numberStrList[1])
      TP_v=float(numberStrList[0])

      ts.append((BP_t,BP_v))
      ts.append((TP_t,TP_v))

    # sort
    ts.sort(key=lambda x: x[0])

    # deduplicate
    ts=myDeduplicate(ts)

    df = pd.DataFrame(ts,columns=['time','value'])

    t=df.iloc[:,0]
    v=df.iloc[:,1]
    # scale t -> x
    x=(t-t_min)/(t_max-t_min)*w
    x=x.apply(np.floor)
    # scale v -> y
    y=(v-v.min())/(v.max()-v.min())*h
    # print(x)
    # print(y)
    df = pd.DataFrame({'time':x,'value':y}) # output csv has header

    df.to_csv(outputCsvPath, sep=',',index=False)

  elif approach == 'lttb':
    # print(df)
    t=df.iloc[:,0]
    v=df.iloc[:,1]
    # scale t -> x
    x=(t-t_min)/(t_max-t_min)*w
    x=x.apply(np.floor)
    # scale v -> y
    y=(v-v.min())/(v.max()-v.min())*h
    # print(x)
    # print(y)
    df = pd.DataFrame({'time':x,'value':y}) # output csv has header

    df.to_csv(outputCsvPath, sep=',',index=False,header=['time','value'])
  else:
    print("unsupported approach!")




