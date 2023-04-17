# -*- coding: utf-8 -*-
"""
Created on Mon Nov  7 19:34:49 2022

@author: ga78tas
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from matplotlib import rc
rc('font', **{'weight': 'normal', 'size': 14})

#%% Load data

fits = ["1RC_oldfit", "1RC", "2RC"]
params = ["Urban_15deg", "Urban_30deg", "Interurban_15deg", "Interurban_30deg", 
          "Highway_15deg", "Highway_30deg", "Wallbox_charging_0-100_VW_11kw", 
          "Fast_charging_0-100_VW_warm"]

df = pd.DataFrame(columns=["Fit", "Cycle", "Uerror", "Terror"])
for fit in fits:
    for param in params:    
        Uerror = pd.read_csv(f"{fit}\Results\{param}_Uerror.txt", header=None).values.squeeze()
        Terror = pd.read_csv(f"{fit}\Results\{param}_Terror.txt", header=None).values.squeeze()
        df = df.append(pd.DataFrame(zip([fit]*len(Uerror), [param]*len(Uerror), Uerror, Terror), columns=["Fit", "Cycle", "Uerror", "Terror"]))
    
#%% Generate violinplots
fig, [ax1, ax2] = plt.subplots(2,1,figsize=(12.41,5.33), tight_layout = True)
sns.violinplot(ax=ax1, x="Cycle", y="Uerror", hue="Fit", data=df)
sns.violinplot(ax=ax2, x="Cycle", y="Terror", hue="Fit", data=df)
ax1.grid()
ax1.get_legend().remove()
ax1.set_xlabel(None)
ax1.set(xticklabels=[])
ax1.set_ylabel("Voltage error in mV")
ax2.grid()
ax2.set_xlabel(None)
ax2.set_xticklabels(["Urban 15°C", "Urban 30°C", "Interurban 15°C", "Interurban 30°C", "Highway 15°C", "Highway 30°C", "AC charging", "DC charging"], rotation=15)
ax2.set_ylabel("Temperature error in °C")