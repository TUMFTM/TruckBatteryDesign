"""
Created on Fri Apr 30 10:42:58 2021

@author: olaf_
"""

from pandas import read_excel
from modules.cellPostprocessing import postprocess
from modules.method import Method
from modules.myplots import Myplots

#%% Load & postprocess cell data
cells_raw = read_excel("inputs/CellDatabase_v6.xlsx") #Load cell database
cells = postprocess(cells_raw) #Post process cell data

#%% Evaluate 1MW charging scenario
method = Method(1000) #Initialize method
results = method.eval_cells(cells) #Execute for cells in database
refcell = results.loc["TUM-05"] #Reference cell: highlighted in plot and used for parameter sensitivity analysis

#%% Find cost for corrected lifetime
t_bat_corrected = 9.457057014205988 #From electric-thermal-aging simulation
c_par_corrected = method.costmodel.costparityanalysis(method.s_annual, refcell.Ebat, refcell.Econs, t_bat_corrected)

#%% Generate plots
myplots = Myplots()
myplots.cell_assessment_simple(method, results, refcell) #Cost parity price over payload & battery volume