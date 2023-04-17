# -*- coding: utf-8 -*-
"""
Created on Mon Nov  7 19:34:49 2022

@author: ga78tas
"""
import itertools
import pandas as pd
import matplotlib.pyplot as plt

params = ["Urban_15deg", "Urban_30deg", "Interurban_15deg", "Interurban_30deg", 
          "Highway_15deg", "Highway_30deg", "Wallbox_charging_0-100_VW_11kw", 
          "Fast_charging_0-100_VW_warm"]

#%% Load data
Vdata = []
for param in params:    
    df = pd.read_csv(f"Results/{param}_Verror.txt", header=None)
    Vdata.append(df[0].to_list())

Tdata = []
for param in params:    
    df = pd.read_csv(f"Results/{param}_Terror.txt", header=None)
    Tdata.append(df[0].to_list())

#%% Add totals
Vdata.append(list(itertools.chain.from_iterable(Vdata))) #Add total    
Tdata.append(list(itertools.chain.from_iterable(Tdata))) #Add total

#%% Voltage error violin plot

plt.figure()
plt.violinplot(Vdata)
plt.xticks(range(1,10), labels=params + ["total"], rotation=90)
plt.ylabel("Voltage error in mV")
plt.grid()

#%% Temperature error violin plot

plt.figure()
plt.violinplot(Tdata)
plt.xticks(range(1,10), labels=params + ["total"], rotation=90)
plt.ylabel("Temperature error in deg C")
plt.grid()