from skimage import data, img_as_float
from skimage.metrics import structural_similarity as ssim
from skimage.metrics import mean_squared_error
import csv
import cv2
from matplotlib import pyplot as plt
import numpy as np
import pandas as pd
import math
import argparse
import sys
import os

parser=argparse.ArgumentParser(description="plot and compute DSSIM",
                               formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument("-i","--input",help="input csv directory")
parser.add_argument("-tqs","--tqs",help="query start time")
parser.add_argument("-tqe","--tqe",help="query end time")
args = parser.parse_args()
config = vars(args)
input=str(config.get('input'))
tqs=int(config.get('tqs'))
tqe=int(config.get('tqe'))

DSSIM_res="{}/dssim.csv".format(input)

def full_frame(width=None, height=None, dpi=None):
  import matplotlib as mpl
  # First we remove any padding from the edges of the figure when saved by savefig.
  # This is important for both savefig() and show(). Without this argument there is 0.1 inches of padding on the edges by default.
  mpl.rcParams['savefig.pad_inches'] = 0
  figsize = None if width is None else (width/dpi, height/dpi) # so as to control pixel size exactly
  fig = plt.figure(figsize=figsize,dpi=dpi)
  # Then we set up our axes (the plot region, or the area in which we plot things).
  # Usually there is a thin border drawn around the axes, but we turn it off with `frameon=False`.
  ax = plt.axes([0,0,1,1], frameon=False)
  # Then we disable our xaxis and yaxis completely. If we just say plt.axis('off'),
  # they are still used in the computation of the image padding.
  ax.get_xaxis().set_visible(False)
  ax.get_yaxis().set_visible(False)
  # Even though our axes (plot region) are set to cover the whole image with [0,0,1,1],
  # by default they leave padding between the plotted data and the frame. We use tigher=True
  # to make sure the data gets scaled to the full extents of the axes.
  plt.autoscale(tight=True)

def myplot(csvPath,width,tqs,tqe):
  height=width
  full_frame(width,height,16)
  df=pd.read_csv(csvPath,engine="pyarrow") # the first line is header; use engine="pyarrow" to accelerate read_csv otherwise is slow
  t=df.iloc[:,0]
  v=df.iloc[:,1]

  # # restrict data to be plotted because raw data export use original tqe, not adapted tqe
  # idx=0
  # for index in reversed(range(len(t))):
  #   idx=index
  #   if t.loc[index]<tqe:
  #     break
  # t=t.loc[:idx]
  # v=v.loc[:idx]

  v_min=min(v)
  v_max=max(v)

  # use the same t_min and t_max as used in downsampling algorithm
  t_min=tqs
  t_max_temp=tqe # not use max(t) because downsampling result may not cover the target end point
  # t_min=511996 # BallSpeed dataset, corresponds to tqs in run-python-query-save-exp.sh
  # t_max_temp=4259092178974 # BallSpeed dataset, corresponds to tqe in run-python-query-save-exp.sh
  t_max=math.ceil((t_max_temp-t_min)/(2*width))*2*width+t_min # corresponds to tqe in query-save.py
  print(t_min)
  print(t_max)

  plt.plot(t,v,color='k',linewidth=0.1,antialiased=False)
  plt.xlim(t_min, t_max)
  plt.ylim(v_min, v_max)
  plt.savefig("{}-{}.png".format(csvPath,width),backend='agg')
  # plt.show()
  plt.close()
  return df.shape[0] # number of points

def mymse(imfil1,imfil2): # mse=mse_in_255/(255*255)
  img1 = cv2.imread(imfil1)
  img2 = cv2.imread(imfil2)
  img1 = img_as_float(cv2.cvtColor(img1, cv2.COLOR_BGR2GRAY))
  img2 = img_as_float(cv2.cvtColor(img2, cv2.COLOR_BGR2GRAY))
  squared_diff = (img1-img2) ** 2
  summed = np.sum(squared_diff)
  num_pix = img1.shape[0] * img1.shape[1] #img1 and 2 should have same shape
  err = summed / num_pix
  return err

def myssim(imfil1,imfil2):
  img1=cv2.imread(imfil1)
  (h,w)=img1.shape[:2]
  img2=cv2.imread(imfil2)
  resized=cv2.resize(img2,(w,h))
  (h1,w1)=resized.shape[:2]
  # print(img1.dtype)
  img1=img_as_float(cv2.cvtColor(img1, cv2.COLOR_BGR2GRAY)) # img_as_float: the dtype is uint8, means convert [0, 255] to [0, 1]
  img2=img_as_float(cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY))
  return ssim(img1,img2,data_range=img2.max() - img2.min())

def mydssim(imfil1,imfil2):
  return (1-myssim(imfil1,imfil2))/2

# TODO
approachArray=["mac","cpv","minmax","minmax_lsm","lttb"] # should be same as in run-more-baselines.sh
# wArray=[10,20,50,80,100,200,400,600,800,1200,1600,2000,3000,4000] # should be same as in run-more-baselines.sh
# wArray=[10,15]
wArray=[100,200,400,600,1200,2000,3000,4000]

with open(DSSIM_res, 'w', newline='') as f:
  writer = csv.writer(f)
  header = ['w', 'DSSIM(M4,raw)', 'DSSIM(M4-LSM,raw)', 'DSSIM(MinMax,raw)','DSSIM(MinMax-LSM,raw)','DSSIM(LTTB,raw)','n_raw','n_m4','n_m4_lsm','n_minmax','n_minmax_lsm','n_lttb']
  writer.writerow(header)
  # plot figure according to specified w
  for w in wArray:
    print("==============="+str(w)+"===============")
    n_arr=[]
    dssim_arr=[]

    # rawQuery
    os.system("python3 {}/parse.py -i {} -a {} -w {}".format(input,input,"rawQuery",1)) # "data-rawQuery-1.csv" corresponds to the file exported in run-more-baselines.sh
    n=myplot("{}/ts-rawQuery-1.csv".format(input),w,tqs,tqe) # no need to parse actually
    n_arr.append(n)

    for approach in approachArray:
      print("========="+approach+"=========")
      os.system("python3 {}/parse.py -i {} -a {} -w {}".format(input,input,approach,w))
      n=myplot("{}/ts-{}-{}.csv".format(input,approach,w),w,tqs,tqe)
      n_arr.append(n)
      dssim=mydssim("{}/ts-rawQuery-1.csv-{}.png".format(input,w),"{}/ts-{}-{}.csv-{}.png".format(input,approach,w,w))
      # the first w is used for downsampling parameter, the second w is used for chart pixel width
      # visualization driven, they should match
      dssim_arr.append(dssim)

    data=[w] + dssim_arr + n_arr
    writer.writerow(data)

