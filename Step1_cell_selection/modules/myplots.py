"""
Created on Tue Jun 15 14:49:16 2021

@author: ga78tas
"""

import matplotlib.pyplot as plt
from matplotlib import rc

class Myplots:
    
    def __init__(self):
        self.width_wide = 12.39 #full ppt slide
        self.width = 5.33 #half ppt slide
        self.height = 5.33
        self.font = {'weight': 'normal', 'size': 14}      
        rc('font', **self.font)
        self.savepath = "results/"    
        self.savepath_data = "results/data/"
        
    def cell_assessment_simple(self, method, res_raw, topcell):
        
        #Define marker shapes, colors and names for all plots
        markershapes = {"Cylindrical": "o", #Round
                        "Pouch": "d", #Thin diamond
                        "Prismatic": "s" #Square
                        }
        markercolors = {"NMC/NCA": "blue",
                  "LFP": "gray", 
                  "LTO": "red"
                  }
        shape = {
                "Cylindrical": "Cylindrical",
                "Pouch": "Pouch",
                "Prismatic": "Prismatic"
                }
        chems = {
            "NMC/NCA": "NMC/NCA", 
            "LFP": "LFP", 
            "LTO": "LTO",
            "not specified": ""}
            
        #Group cells by Chemistry and Format
        res = res_raw.dropna()
        res_sorted = res.sort_values("Chemistry", ascending=False)
        groups = res_sorted.groupby(["Chemistry", "Format"], sort = False)
        
        #Plot cell data
        fig, axs = plt.subplots(1, 2, figsize=(12.4,5.33), sharey = "all")       
        for name, group in groups:                    

            axs[0].scatter(group.maxpayload, 
                        group.cpar, 
                        marker = markershapes[name[1]],
                        color = markercolors[name[0]],
                        alpha = 0.7,
                        s = 150,
                        label=f"{chems[name[0]]} {shape[name[1]]}")
            
            axs[1].scatter(group.Vbat, 
                        group.cpar, 
                        marker = markershapes[name[1]],
                        color = markercolors[name[0]],
                        alpha = 0.7,
                        s = 150,
                        label=f"{chems[name[0]]} {shape[name[1]]}")
        
        axs[0].scatter(topcell.maxpayload, topcell.cpar, 
                          marker = markershapes[topcell.Format], 
                          color = "orange", s=80, label="reference cell")
        axs[1].scatter(topcell.Vbat, topcell.cpar, 
                          marker = markershapes[topcell.Format], 
                          color = "orange", s=80, label="reference cell")
        
        #Add annotations
        axs[0].axvline(method.sizing.ref_load, color = "red", linestyle = "dashed")
        axs[0].axvline(method.sizing.dt_payload_max, color = "red", linestyle = "dashed")
        axs[0].text(0.95*method.sizing.ref_load, 50, "Reference load",
                        color = "red", rotation=90,
                        ha = "center", va = "center")
        axs[0].text(1.075*method.sizing.dt_payload_max, 50, "Max. payload\n diesel truck",
                        color = "red", rotation=90,
                        ha = "center", va = "center")            
        
        axs[1].axvline(method.sizing.dt_vol_pt, color = "red", linestyle = "dashed")
        axs[1].text(0.8*method.sizing.dt_vol_pt,  50, "Powertrain volume\n Diesel truck",
                        color = "red", rotation=90,
                        ha = "center", va = "center")
    
        #Plot formatting
        axs[0].set_xlim(0, 28e3)
        # axs[0].set_ylim(0, 100)
        axs[1].set_xlim(0, 8750)
        # axs[1].set_ylim(0, 150)
        handles, labels = plt.gca().get_legend_handles_labels()        
        fig.legend(handles, labels, loc='upper center', ncol = len(handles))
        for ax in axs.flat: ax.grid()
        axs[0].set_xlabel("Maximum payload in kg" )
        axs[1].set_xlabel("Battery volume in liter")
        axs[0].set_ylabel("Cost parity price in €/kWh")
        
        fig.tight_layout()
        fig.subplots_adjust(top=0.85)
        