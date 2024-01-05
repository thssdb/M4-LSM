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

# remote node has not exported the environment variables, so passing them using args
parser=argparse.ArgumentParser(description="remote query to csv",
                               formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument("-i","--input",help="input log file")
args = parser.parse_args()
config = vars(args)

input=str(config.get('input'))
output="{}.csv".format(input)

f = open(input, "r")
TPList=[]
for line in f:
  if "M4_CHUNK_METADATA" in line:
    numberStrList = re.findall(r'\d+(?:\.\d+)?',line)
    TP_v=numberStrList[19]
    # print(TP_v)
    TPList.append(TP_v)

df = pd.DataFrame(TPList,columns=['TP_value']) # output csv has header
df.to_csv(output, sep=',',index=False)