import matplotlib.pyplot as plt 
import numpy as np 
import os 
import pandas as pd 

import csv

with open('prices.csv') as fin:    
    csvin = csv.DictReader(fin)
    # Category -> open file lookup
    outputs = {}
    print(csvin.fieldnames)
    for row in csvin:
        cat = row['symbol']
        # Open a new file and write the header
        if cat not in outputs:
            fout = open('{}.csv'.format(cat), 'w',newline='')
            dw = csv.DictWriter(fout, fieldnames=['date', 'close'])
            dw.writeheader()
            outputs[cat] = fout, dw
        # Always write the row
        # print(row)
        outputs[cat][1].writerow({"date":row["date"],"close":row["close"]})
    # Close all the files
    for fout, _ in outputs.values():
        fout.close()
