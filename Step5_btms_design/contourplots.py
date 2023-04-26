# -*- coding: utf-8 -*-
"""
Created on Thu Dec  2 14:48:10 2021

@author: ga78tas
"""

import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
import pandas as pd
import numpy as np
import os

#Generate colormap
r1, g1, b1 = [x/256 for x in [0,101,189]] #TUM blue
r2, g2, b2 = [x/256 for x in [256,256,256]] #TUM white

cdict = {'red': ((0, r1, r1),
               (1, r2, r2)),
       'green': ((0, g1, g1),
                (1, g2, g2)),
       'blue': ((0, b1, b1),
               (1, b2, b2))}
cmp = LinearSegmentedColormap('custom_cmap', cdict)

Tcool = range(25,41)
Pcooler = [0.2*x*800*792/64.9/1000 for x in range(11)]

for filename in os.listdir("./Results"):
    if filename[-3:] == "csv":
        param = filename[:-4]
        data = pd.read_csv(f"./Results/{filename}", header=None)
        
        lmin = data.min().min()
        lmax = data.max().max()
        
        plt.figure()
        plt.contourf(Tcool, Pcooler, data,cmap = cmp, levels=np.linspace(lmin, lmax, 8))
        plt.title(param)
        h = plt.colorbar()