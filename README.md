# M4-LSM-SIGMOD24

The code and data of experiments for our paper "Time Series Representation for Visualization in Apache IoTDB" are available here. The experiments are conducted on machines running Ubuntu. We provide detailed guidelines below to reproduce our experimental results.

**Table of Contents:**

1.   Download Java
2.   Download `M4-visualization-exp` Folder
3.   Guides to "1.1 Motivation"
4.   Guides to "8.1 Experiments with Varying Parameters"
5.   Guides to "8.2 Applications to Other Visualizations"



## 1. Download Java

Java >= 1.8 is needed. Please make sure the JAVA_HOME environment path has been set. You can follow the steps below to install and configure Java.

```shell
# install
sudo apt-get update
sudo apt-get upgrade
sudo apt install openjdk-8-jdk-headless

# configure
vim /etc/profile
# add the following two lines to the end of /etc/profile
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre
export PATH=$JAVA_HOME/bin:$PATH
# save and exit vim, and let the configuration take effect
source /etc/profile
```

## 2. Download `M4-visualization-exp` Folder

The first step is to download this `M4-visualization-exp` folder. For easy download, we provide a compressed zip on Kaggle, which can be downloaded using the following commands:

```shell
# First install kaggle.
pip install kaggle
pip show kaggle 

# Then set up kaggle API credentials.
mkdir ~/.kaggle # or /root/.kaggle
cd ~/.kaggle # or /root/.kaggle
vim kaggle.json # input your Kaggle API, in the format of {"username":"xx","key":"xx"}

# In the following, we assume that the downloaded path is /root/ubuntu/M4-visualization-exp.
cd /root/ubuntu
kaggle datasets download xxx123456789/m4-visualization-exp
unzip m4-visualization-exp.zip
```

### 2.1 Folder Structure

-   `README.md`: This file.
-   `bash`: Folder of scripts for running experiments.
-   `datasets`: Folder of datasets used in experiments. **Note that this folder is empty right after unzipping. Please follow the instructions in the "Download datasets from Kaggle" and "Download CQD1 Dataset" sections of this README to download datasets before doing experiments.**
-   `iotdb-cli-0.12.4`: Folder of the IoTDB client.
-   `iotdb-server-0.12.4`: Folder of the IoTDB server.
-   `jarCode`: Folder of JAVA source codes for jars used in experiments.
-   `jars`: Folder of jars used in experiments to write data to IoTDB and query data from IoTDB.
-   `tools`: Folder of tools to assist automated experiment scripts.
-   `python-exp`: Folder for the motivation experiment involving remote connections.

### 2.2 Download Datasets from Kaggle

The datasets are available in https://www.kaggle.com/datasets/xxx123456789/exp-datasets.

Here is the method of downloading data from kaggle on Ubuntu.

```shell
# First install kaggle.
pip install kaggle
pip show kaggle 

# Then set up kaggle API credentials.
mkdir ~/.kaggle # or /root/.kaggle
cd ~/.kaggle # or /root/.kaggle
vim kaggle.json # input your Kaggle API, in the format of {"username":"xx","key":"xx"}

# Finally you can download datasets.
cd /root/ubuntu/M4-visualization-exp
mkdir datasets
cd /root/ubuntu/M4-visualization-exp/datasets
kaggle datasets download xxx123456789/exp-datasets
unzip exp-datasets.zip 
# After unzipping, you will find BallSpeed.csv, MF03.csv, Train.csv, Steel.csv in /root/ubuntu/M4-visualization-exp/datasets.
```

-   BallSpeed dataset, with 7,193,200 points, coming from "[DEBS 2013 Grand Challenge](https://www.iis.fraunhofer.de/en/ff/lv/dataanalytics/ek/download.html)", extracted with `ExtractBallSpeedData.java` in the jarCode folder.
-   MF03 dataset, with 10,000,000 points, coming from "[DEBS 2012 Grand Challenge](https://debs.org/grand-challenges/2012/)", extracted with `ExtractMF03Data.java` in the jarCode folder.
-   Train dataset, with 127,802,876 points, is a 5-month train monitoring data collected by a vibration sensor at around 20Hz frequency, provided by real customers of Apache IoTDB.
-   Steel dataset,  with 314,572,100 points, is 7-month steel production monitoring data collected by a vibration sensor at around 20Hz frequency, provided by real customers of Apache IoTDB.

### 2.3 Download CQD1 Dataset

We also include a dataset CQD1 with updates from real usage. 

Use the following commands to download CQD1 dataset:

```shell
cd /root/ubuntu/M4-visualization-exp/datasets
wget https://anonymous.4open.science/r/dataset_with_updates-E014/CQD1.csv
```

For more details of CQD1, please see https://anonymous.4open.science/r/dataset_with_updates-E014.


## 3. Guides to "1.1 Motivation"

>   Corresponding to Figure 3 in the paper.

This experiments involves communication between two nodes and is a bit more complicated than the previous two sections in terms of installation preparation. Assume that the server and client nodes have the following IP addresses, usernames, and passwords.

|            | Database Server Node | Rendering Client Node |
| ---------- | -------------------- | --------------------- |
| IP address | A                    | B                     |
| Username   | server               | client                |
| Password   | x                    | y                     |

### 3.1 Environment Setup for Both Nodes

-   **Download Java** as instructed earlier.

-   **Download `M4-visualization-exp` folder** as instructed earlier.

-   Download sshpass:

    ```shell
    sudo apt-get install sshpass
    ```

    After downloading sshpass, run `sshpass -p 'x' ssh server@A "echo 'a'"` on the client node to verify if sshpass works. If sshpass works, you will see an "a" printed on the screen. Otherwise, try executing `ssh server@A "echo 'a'"` on the client node, and then reply "yes" to the prompt ("Are you sure you want to continue connecting (yes/no/[fingerprint])?") and enter the password 'x' manually. Then run again `sshpass -p 'x' ssh server@A "echo 'a'"` on the client node to verify if sshpass works.

-   Download the Python packages to be used:

    ```shell
    sudo apt install python3-pip
    pip install matplotlib
    pip install thrift
    pip install pandas
    pip install pyarrow
    
    pip show matplotlib # this is to check where python packages are installed. 
    
    cd /root/ubuntu/M4-visualization-exp/python-exp
    cd iotdb # If you download M4-visualization-exp from Kaggle as instructed in chapter 2, then this iotdb directory has been unzipped by Kaggle, otherwise use "unzip iotdb.zip" instead of "cd iotdb" here
    
    # In the following, we assume that python packages are installed in "/usr/local/lib/python3.8/dist-packages"
    cp -r iotdb /usr/local/lib/python3.8/dist-packages/. # this step installs iotdb-python-connector
    ```

### 3.2 Populate the Database Server Node

Before doing experiments, follow the steps below to populate the database server with test data.

1. Go to the database server node.

2. Enter the `bash` folder in the `M4-visualization-exp` folder, and then:

    1. Make all scripts executable by executing `chmod +x *.sh`. If you have done this step before, you can ignore it here.

    2. Update `prepare-motivation.sh` as follows:

        -   Update `M4_VISUALIZATION_EXP` as the downloaded path of the `M4-visualization-exp` folder.

        -   Update `HOME_PATH` as an **empty** folder where you want the experiments to be executed.

    3. Run `prepare-motivation.sh` and then the folder at `HOME_PATH` will be ready for experiments.

3. Enter the folder at `HOME_PATH`, and run experiments using `nohup ./run-motivation.sh 2>&1 &`.
    The running logs are saved in nohup.out, which can be checked by the command: `tail nohup.out`.

4. When the experiment script finishes running ("ALL FINISHED!" appears in nohup.out), preparations are complete.

### 3.3 Experiments on the Rendering Client Node

1.   Go to the rendering client node.
2.   Enter the `python-exp` folder in the `M4-visualization-exp` folder, and then:
     1.   Make all scripts executable by executing `chmod +x *.sh`.
     2.   Update `run-python-query-plot-exp.sh` as follows:
          -   Update `READ_METHOD` as `rawQuery`/`mac`/`cpv`.
              -   `rawQuery`: corresponding to "without-M4" in Figure 3 in the paper.
              -   `mac`: corresponding to "M4" in Figure 3 in the paper.
              -   `cpv`: corresponding to "M4-LSM" in Figure 3 in the paper.
          -   Update `M4_VISUALIZATION_EXP` as the downloaded path of the `M4-visualization-exp` folder on the client node.
          -   Update `remote_M4_VISUALIZATION_EXP` as the downloaded path of the `M4-visualization-exp` folder on the server node.
          -   Update `remote_IOTDB_HOME_PATH` to the same path as the "HOME_PATH" set in the "Prepare the Database Server Node" section of this README.
          -   Update `remote_ip` as the IP address of the database server node.
          -   Update `remote_user_name` as the login username of the database server node.
          -   Update `remote_passwd` as the login password of the database server node.
     3.   Run experiments using `nohup ./run-python-query-plot-exp.sh 2>&1 &`. The running logs are saved in nohup.out, which can be checked by the command: `tail nohup.out`. 
     4.   When the experiment script finishes running ("ALL FINISHED!" appears in nohup.out), the corresponding experimental results are in `sumResult-[READ_METHOD].csv`, where `[READ_METHOD]` is `rawQuery`/`mac`/`cpv`. 
     5.   In the result csv, the last four columns are server computation time, communication time, client rendering time, and total response time, and each row corresponds to a different number of raw data points.

## 4. Guides to "8.1 Experiments with Varying Parameters"

>   Corresponding to Figures 17~22 in the paper.

Steps:

1. Enter the `bash` folder in the `M4-visualization-exp` folder, and then:

    1. Make all scripts executable by executing `chmod +x *.sh`.

    2. Update `prepare-all.sh` as follows:

        -   Update `M4_VISUALIZATION_EXP` as the downloaded path of the `M4-visualization-exp` folder.

        -   Update `HOME_PATH` as an **empty** folder where you want the experiments to be executed.

    3. Run `prepare-all.sh` and then the folder at `HOME_PATH` will be ready for experiments.

2. Enter the folder at `HOME_PATH`, and run experiments using `nohup ./run-[datasetName]-[N].sh 2>&1 &`, where `[datasetName]` is `BallSpeed`/`MF03`/`Train`/`Steel`/`CQD1`, `N`=1/2/3/4/5 stands for the N-th experiment. The running logs are saved in nohup.out, which can be checked by the command: `tail nohup.out`.

    -   Summary for Figures 17~22 in the paper:

        -   Figure 17: (a) run-BallSpeed-1.sh, (b) run-MF03-1.sh, (c) run-Train-1.sh, (d) run-Steel-1.sh
        -   Figure 18: (a) run-BallSpeed-2.sh, (b) run-MF03-2.sh, (c) run-Train-2.sh, (d) run-Steel-2.sh
        -   Figure 19: (a) run-BallSpeed-3.sh, (b) run-MF03-3.sh, (c) run-Train-3.sh, (d) run-Steel-3.sh
        -   Figure 20: (a) run-BallSpeed-4.sh, (b) run-MF03-4.sh, (c) run-Train-4.sh, (d) run-Steel-4.sh
        -   Figure 21: (a) run-BallSpeed-5.sh, (b) run-MF03-5.sh, (c) run-Train-5.sh, (d) run-Steel-5.sh
        -   Figure 22: run-CQD1-2.sh. The update count results of figure (a) are in `nohup.out` (searching the lines containing "Rate of updated points"). The query time results of figure (b) are in `exp2_res.csv` as described below.

3. When the experiment script finishes running ("ALL FINISHED!" appears in nohup.out), the corresponding experimental results of query time for the N-th experiment are in `HOME_PATH/[datasetName]_testspace/exp[N]_res.csv` as follows:

    - `exp1_res.csv` for varying the number of time spans, 
    - `exp2_res.csv` for varying query time range, 
    - `exp3_res.csv` for varying chunk overlap percentage, 
    - `exp4_res.csv` for varying delete percentage, 
    - `exp5_res.csv` for varying update percentage.

    In the result csv, counting from 1, the second column is the query execution time of M4, and the third column is the query execution time of M4-LSM.

## 5. Guides to "8.2 Applications to Other Visualizations"

### 5.1 Apply to MinMax Representation

#### 5.1.1 Query Time Experiment

>   Corresponding to Figure 23(b) in the paper.

Steps:

1. Enter the `bash` folder in the `M4-visualization-exp` folder, and then:

    1. Make all scripts executable by executing `chmod +x *.sh`.

    2. Update `prepare-more-baselines.sh` as follows:

        -   Update `M4_VISUALIZATION_EXP` as the downloaded path of the `M4-visualization-exp` folder.

        -   Update `HOME_PATH` as an **empty** folder where you want the experiments to be executed.

    3. Run `prepare-more-baselines.sh` and then the folder at `HOME_PATH` will be ready for experiments.
2. Enter the folder at `HOME_PATH`, and run experiments using `nohup ./run-more-baselines.sh 2>&1 &`. The running logs are saved in nohup.out, which can be checked by the command: `tail nohup.out`.
3. When the experiment script finishes running ("ALL FINISHED!" appears in nohup.out), the corresponding experimental results of query time are in `HOME_PATH/res.csv`. 
4. In the result csv, counting from 1, the 3,4,5,6,7 columns are the query execution times of M4, M4-LSM, MinMax, MinMax-LSM, LTTB, respectively.

#### 5.1.2 DSSIM Experiment

>   Corresponding to Figure 23(a) in the paper.

When the query time experiment in the previous section is done, the data csv for the DSSIM experiment are ready in `HOME_PATH`. After that, enter the folder at `HOME_PATH`, and then:

1.   Download line chart plot tool by the command: `wget https://anonymous.4open.science/r/line-density-rust-2E29/line-density`. After downloading, make it executable by executing `chmod +x line-density`.
2.   Run `runDSSIMexp.sh` to prepare csv and scripts. When "ALL FINISHED!" appears in the console, this script has finished running.
3.   Run `rustPlot.sh` to render line charts. When "ALL FINISHED!" appears in the console, this script has finished running.
4.   Run `dssimCompare.sh` to calculate DSSIM. When "ALL FINISHED!" appears in the console, this script has finished running. The corresponding experimental results of DSSIM have been printed to the console.

### 5.2 Apply to DenseLines Visualization

#### 5.2.1 DenseLines Example

>   Corresponding to Figure 24(a) in the paper.

Figure 24(a) is an example of DenseLines using 45 public stock exchange time series. 

Steps:

1.   Download the public stock exchange dataset on Kaggle: https://www.kaggle.com/datasets/dgawlik/nyse
2.   Using `parsePrice.py` in the `M4-visualization-exp/tools` folder to extract the closing price time series of each stock from the `prices.csv`. Assume below that these extracted csv are placed under the empty folder `/root/csvDir`.
3.   Download DenseLines plot tool by the command: `wget https://anonymous.4open.science/r/line-density-rust-A320/line-density`. After downloading, make it executable by executing `chmod +x line-density`.
4.   Draw DensLines using the command: `./line-density 45 10 160 100 true /root/csvDir true`, which plots the DenseLines of 45 time series each containing 1600 points from /root/csvDir on a `160*100` canvas, using raw data points and M4 representation points to render `output-i45-k10-w160-h100-utrue-dfalse.png` and `output-i45-k10-w160-h100-utrue-dtrue.png`, respectively. The two pngs are identical thanks to the visual representativeness of M4.

#### 5.2.2 Cost of Visualizing DenseLines From a Database

>   Corresponding to Figure 24(b) in the paper.

Similar to `3. Guides to "1.1 Motivation"`, this experiment measures the end-to-end time of DenseLines visualization, which is decomposed into three components: server computation time, communication time, and client rendering time.

##### Server Computation Time

Steps:

1. Enter the `bash` folder in the `M4-visualization-exp` folder, and then:
    1. Make all scripts executable by executing `chmod +x *.sh`. If you have done this step before, you can ignore it here.
    2. Update `prepare-multi-series.sh` as follows:
        -   Update `M4_VISUALIZATION_EXP` as the downloaded path of the `M4-visualization-exp` folder.
        -   Update `HOME_PATH` as an **empty** folder where you want the experiments to be executed.
    3. Run `prepare-multi-series.sh` and then the folder at `HOME_PATH` will be ready for experiments.
2. Enter the folder at `HOME_PATH`, and then:
    1. Write 50 test time series into IoTDB using `nohup ./run-write.sh 2>&1 &`. The running logs are saved in nohup.out, which can be checked by the command: `tail nohup.out`. When the experiment script finishes running ("WRITE ALL FINISHED!" appears in nohup.out), data preparations are complete.
    2. Run the query experiments using `nohup ./run-query.sh 2>&1 &`.
        The running logs are saved in nohup.out, which can be checked by the command: `tail nohup.out`. When the experiment script finishes running ("ALL FINISHED!" appears in nohup.out), the corresponding experimental results are in `HOME_PATH/res.csv`. In the result csv, counting from 1, the 1,2,3 columns are the query execution times of raw data query, M4, M4-LSM, respectively. The ten rows correspond to the results of querying `N` time series, where N=1/5/10/15/20/25/30/35/40/45.

##### Communication Time

Communication time is calculated using the empirical bandwith measured in the `3. Guides to "1.1 Motivation"` section.

##### Client Rendering Time

Steps:

1.   Download DenseLines plot tool by the command: `wget https://anonymous.4open.science/r/line-density-rust-A320/line-density`. After downloading, make it executable by executing `chmod +x line-density`.
2.   Test the rendering speed of DenseLines under different number of time series using the command: `./line-density [N] 100000 100 100`, where `N` is the number of time series, N=1/5/10/15/20/25/30/35/40/45. The corresponding rendering time without and with M4 are printed to the console.
