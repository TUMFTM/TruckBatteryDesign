# -*- coding: utf-8 -*-
"""
Created on Fri Aug 19 17:15:06 2022

@author: ga78tas
"""

import pickle
import numpy as np
import matplotlib.pyplot as plt
from copy import deepcopy
from numpy.random import choice

class Charging():
    
    def __init__(self, Ebat):
                
        #Availability of charging infrastructure
        self.p_chargers = {
            "Home": {100: 1}, # 50kW available at home depot
            "Driving": {0: 1}, #0kW available during driving (unless Elon road scenario)
            "Away": {
                0: 0.5, # no charger available at away stop
                350: 0.3, # 350kW Chademo charger at away stop
                1000: 0.2} # 1MW MCS charger at away stop
            }
        
        #Vehicle
        self.t_plug_unplug = 0#5/60 #time needed to plug & unplug charger
        self.eol = 0.8 #End of Life condition at which continuous operation is still required
        self.eta_charge = 0.95 #Charging efficiency 
        self.battery_capacity = Ebat
        
        #Rules
        self.soc_min = 0.041 #minimum SOC limit
        self.soc_max = 0.97 #maximum SOC limit
        self.soc_charge = 1 #0.8 #vehicle will only be charged if SOC is below this threshold

    def assign_chargers(self, c_profile):
        
        p_profile = deepcopy(c_profile)
        
        #Split up in individual tours
        ihome = p_profile[p_profile["state"] == "Home"].index #Index of profile rows where the vehicle is at the home depot
        p_cha = []
        soc = [self.soc_max]
        
        for i1, i2 in zip(ihome[:-1], ihome[1:]):
            #Get states, durations, distances and energy consumption between two stops at the home depot
            states = p_profile.iloc[i1:i2]["state"]
            durations = p_profile.iloc[i1:i2]["duration"]
            distances = p_profile.iloc[i1:i2]["distance"]
            cons = p_profile.iloc[i1:i2]["cons"]
            
            i=0
            feasible = False
            while not feasible:
                
                p_cha_try = []
                soc_try = [soc[-1]]
                for state, duration, distance, con in zip(states, durations, distances, cons):
                    
                    if soc_try[-1] < self.soc_charge or state=="Home": #Only charge at home or when soc is below a predefined limit
                        p_cha_try += [choice(list(self.p_chargers[state].keys()), 
                                           p=list(self.p_chargers[state].values()))] #Sample available charger power
                    else:
                        p_cha_try += [0] #Vehicle won't be charged
                    
                    soc_try += [min(self.soc_max, 
                                    soc_try[-1] 
                                    + (p_cha_try[-1] * self.eta_charge * (duration-self.t_plug_unplug)
                                       - con * distance)
                                    / self.battery_capacity)] #Calculate SOC
                
                if all([s > (self.soc_min+1-self.eol) for s in soc_try]): #if all SOCs are above the lower SOC limit
                    feasible=True
                    p_cha += p_cha_try #append list of available charging powers
                    soc += soc_try[1:] #append list of SOCs
        
                #Infinite loop backstop
                i += 1
                if i > 100:
                    import pdb; pdb.set_trace()
                    print("No charger distribution found that doesn't violate the lower SOC limit after 100 iterations. Try changing the SOC threshold of the charging strategy (line 37)")
        
        #Include final stop at home
        p_cha += [choice(list(self.p_chargers["Home"].keys()), p=list(self.p_chargers["Home"].values()))]
        soc += [min(self.soc_max, soc[-1] + p_cha[-1]*p_profile.iloc[-1]["duration"]/self.battery_capacity)]
        
        if soc[-1] != soc[0]: 
            print("Warning: profile doesn't start and end at the same SOC")
                    
        #Add to profile and save to pickle file
        p_profile["p_cha"] = p_cha
        p_profile["soc_start"] = soc[:-1]
        p_profile["soc_end"] = soc[1:]
        
        with open("results/charging.pickle",'wb') as f: pickle.dump(p_profile, f)
        
        return p_profile

    def gen_loadprofile(self, p_profile, writetocsv = True):
    
        #Generate load profile and save as csv
        p_bat = []
        i = 0
        for state, ptrip, p_cha, duration in zip(p_profile["state"], p_profile["pbat"], p_profile["p_cha"], p_profile["duration"]):
            i+=1
            if state == "Driving":
                p_bat.extend(-1*ptrip) #Reverse sign such that positive battery power corresponds to charging
            else:
                p_bat.extend([p_cha*1000]*round(duration*3600))
            
        #Crop to correct length (small error is due to scaling speed profile)
        print(f"Profile shortened by {len(p_bat)-3600*24*365}s, due to small errors in scaling speed profiles")
        p_bat = p_bat[:3600*24*365]
        
        if writetocsv: 
            with open("results/Loadprofile_Truck.csv",'w') as f:
                f.writelines(f"{p}, " for p in p_bat[0:-1])
                f.writelines(f"{p_bat[-1]}") #Write last line without comma

        return p_bat

    def plot_chargeravailability(self):
                
        fig, axs = plt.subplots(1, 3, figsize=(12.41, 5.33))
        colordict = {0: "blue",
                    100: "red", 
                    350: "green", 
                    1000: "purple"}
        for ax, state in zip(axs, self.p_chargers): 
            powers = [f"{x}kW" for x in self.p_chargers[state].keys()]    
            mycolors = [colordict[p] for p in self.p_chargers[state].keys()]
            ax.pie(self.p_chargers[state].values(), labels=powers, colors = mycolors, startangle=90)
            ax.set_title(state)
        fig.tight_layout()
        fig.savefig("results/figures/charger_availability.svg")

    def plot_chargerusage(self, p_profile):
        
        p_profile[p_profile["state"] == "Away"].groupby("p_cha").size().plot.pie()
        
        pass

    def plot_soc(self, p_profile):
        
        #Add additional points where charging was stopped at the upper SOC limit
        t_soc = [0]
        soc = [p_profile.soc_start[0]]
        for soc_start, soc_end, duration, p_cha in zip(p_profile.soc_start, p_profile.soc_end, p_profile.duration, p_profile.p_cha):
            if soc_end == self.soc_max:
                t_cha = (self.soc_max-soc_start)*self.battery_capacity/p_cha/self.eta_charge
                if p_cha > 0 and t_cha < duration:
                    t_soc.append(t_soc[-1]+t_cha/24/365*12)
                    soc.append(self.soc_max*100)
                    duration -= t_cha
            
            t_soc.append(t_soc[-1]+duration/24/365*12)
            soc.append(soc_end*100)
        
        #Generate plot
        fig3, ax3 = plt.subplots(1,1,figsize=(12.33, 5.33))
        ax3.plot(t_soc, soc)
        ax3.set_xlim(0,12)
        ax3.set_ylim(0,100)
        ax3.grid()
        ax3.set_xlabel("Months")
        ax3.set_ylabel("EOL-Battery SOC in %")
        fig3.savefig("results/figures/soc.svg")
    
    def plot_states(self, p_profile): 
        
        t = np.append(0,np.cumsum(p_profile.duration))
        colors = {"Home": "gray", 
                  "Driving": "blue", 
                  "Away": "orange"}
        
        fig, ax = plt.subplots(1,1, figsize=(12.33, 5.33))
        for t0, duration, state in zip(t, p_profile.duration, p_profile.state):
            ax.barh(0, duration/24, left=t0/24, color=colors[state])
        
    def plot_pbat(self, p_bat):
        t = np.arange(3600*24*365)/3600/24
        fig2, ax2 = plt.subplots(1,1, figsize=(12.33, 5.33))
        ax2.plot(t, [p/1000 for p in p_bat])
        ax2.set_xlabel("Time in days")
        ax2.set_ylabel("Battery power in kW")
        fig2.savefig("results/figures/powerprofile.svg")

    def print_metrics(self, profile):
        
        Pmax = max(profile.p_cha)
        n_fc = sum((profile.state=="Away") & (profile.p_cha>=350))
        print(f"maximum charging power: {Pmax}kW")
        print(f"number of fast charging events: {n_fc}")

if __name__ == "__main__":
    import os
    if os.getcwd().split("\\")[-1] == "modules":
        os.chdir(("..")) #Change to parent directory for correct paths
    charging = Charging(616)    
    with open("results/consumption.pickle",'rb') as f: c_profile = pickle.load(f)
    p_profile = charging.assign_chargers(c_profile)
    p_bat = charging.gen_loadprofile(p_profile)