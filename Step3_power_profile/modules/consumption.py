# -*- coding: utf-8 -*-
"""
Created on Wed Aug 17 16:43:49 2022

@author: ga78tas
"""

import pickle
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from copy import deepcopy
from numpy.random import choice
from scipy.optimize import bisect
from modules.simulation import Simulation

class Consumption():
    
    def __init__(self, Ebat):
        
        #Load inputs
        self.p_vw = pd.read_csv("inputs/payload.csv") #payload distribution
        self.cycle_longhaul = pd.read_csv("inputs/drivingcycles/LongHaul.vdri") #VECTO longhaul driving cycle
        self.cycle_regional = pd.read_csv("inputs/drivingcycles/Regionaldelivery.vdri") #VECTO regional driving cycle
        self.cycle_urban = pd.read_csv("inputs/drivingcycles/UrbanDelivery.vdri") #VECTO urban driving cycle
        
        #Define vehicle parameters for simulation
        self.bet = {
            "motor_power": 352.3675316051114e3, #Max power in W [average of all DT registered between the 1st January 2019 and the 30 June 2020]
            "fr": 0.00385, # Rolling friction coefficient [Lowest of all DT registered between the 1st January 2019 and the 30 June 2020]
            "cd_a": 4.325, # Drag coefficient x Front surface area in m^2 [Lowest of all DT registered between the 1st January 2019 and the 30 June 2020]
            "p_aux": 2.3e3, # auxiliary power consumption in W [Zhao 2013]
            "eta": 0.85, # overall powertrain efficiency [Earl 2018]
            }
        
        #Define vehicle & component weights
        self.dt_m_max = 40e3 # maximum gross vehicle weight in kg [§ 34 StVZO] 
        self.dt_m_szm = 7753.136555182494 # Mass of semi-truck tractor in kg [average of all DT registered between the 1st January 2019 and the 30 June 2020]
        self.bet_m_max = 42e3 # maximum gross vehicle weight in kg [§ 34 StVZO]  
        self.bet_m_chassis = 0.75*self.dt_m_szm # chassis mass in kg [Phadke 2021]
        self.mspec = 173 #ID3 pack level specific energy in Wh/kg
        self.mbet = self.bet_m_chassis+Ebat/self.mspec*1000 #bet curb weight
        
        #Define loadprofile timestep
        self.delta_t = 1 #loadprofile timestep in seconds
        
        #Calculate payload distribution
        self.p_vw.drop(self.p_vw[self.p_vw.GVW*1000 > self.dt_m_max].index, inplace=True) #Remove vehicle weights above maximum weight, since these wouldn't have been legal
        self.p_vw.drop(self.p_vw[self.p_vw.GVW*1000 < self.dt_m_szm].index, inplace=True) #Remove vehicle weights below the curb weight
        self.p_vw.Chance = self.p_vw.Chance/sum(self.p_vw.Chance) #Recalculate probabilities

    def simulate_cons(self, m_profile):
        
        c_profile = deepcopy(m_profile)
        
        #Calculate payloads and vehicle weight based on battery size
        payloads = self.p_vw.GVW*1000 - self.dt_m_szm #Payload in t

        #Calculate share of tonne-km that can't be transported due to BET weight limit
        s_annual = sum(m_profile.distance) #Annual distance
        lost_tkm = sum(np.clip((self.mbet+payloads-self.bet_m_max)/1000,0,1)
                       *self.p_vw.Chance*payloads)*s_annual/1000
        tkm_tot = sum(self.p_vw.Chance*payloads)*s_annual/1000
        if lost_tkm>0:
            print(f"Warning: {lost_tkm:.0f}tkm can't be transported ({lost_tkm/tkm_tot*100:.2f}% of total)")
        
        #Adjust vehicle weights to reflect upper payload limit
        weights = [min(self.mbet+p,self.bet_m_max)/1000 for p in payloads]
        chances = (1-np.clip((self.mbet+payloads-self.bet_m_max)/1000,0,1))*self.p_vw.Chance
        chances = chances/(sum(chances))
        p_payload = pd.DataFrame({"GVW": weights, "Chance": chances})
        p_payload.drop(p_payload[p_payload["Chance"]==0].index, inplace=True)
        
        #Sample payloads
        payloads = [choice(p_payload["GVW"], p=p_payload["Chance"]) 
                      if s=="Driving" else 0 for s in c_profile["state"]] #sample payloads
        cons = [] #energy consumption
        pbats = [] #load profiles
        for i, (distance, duration, payload) in enumerate(zip(c_profile["distance"], c_profile["duration"], payloads)): 
            if distance==0:
                cons.append(0)
                pbats.append([])
            else:
                #Print progress statement
                print(f"Progress: {100*i/len(c_profile):.1f}%")
                
                #Select driving cycle based on average speed and crop to correct distance
                vavg = distance/duration
                if vavg > 70:
                    sim = Simulation(self.cycle_longhaul, distance)
                elif vavg > 40: 
                    sim = Simulation(self.cycle_regional, distance)
                else:
                    sim = Simulation(self.cycle_urban, distance)
                
                #Find scaling factor to match cycle duration
                try:
                    k = bisect(lambda k: duration - sim.run(self.bet, payload*1000, k)[3][-1]/3600, 0.1, 10)
                except: 
                    print(f"Warning profile could not be scaled for profile index {i}")
                    break
                
                #Simulate battery power and energy consumption
                con, v_avg, s, t, v, p, pbat = sim.run(self.bet, payload*1000, k) 
                
                #Interpolate to loadprofile timestep
                pbat_intp = np.interp(np.arange(0,t[-1],self.delta_t), t, pbat) 
                
                cons.append(con)
                pbats.append(pbat_intp)
               
        #Add to profile and safe
        c_profile["GVW"] = payloads
        c_profile["cons"] = cons
        c_profile["pbat"] = pbats

        with open("results/consumption.pickle",'wb') as f: pickle.dump(c_profile, f) #save as pickle file
        
        return c_profile

    def plot_weight_dist(self):
        
        fig, ax = plt.subplots(1,1, figsize=(4, 3))
        ax.bar(self.p_vw.GVW, self.p_vw.Chance)
        ax.set_xlabel("Vehicle weight in t")
        ax.set_ylabel("Chance")
        fig.tight_layout()
        
    def plot_drivingcycles(self):
        
        fig, axs = plt.subplots(3, 1, sharex = "all", figsize=(10, 5.33))
        axs[0].plot(self.cycle_longhaul["<s>"]/1000, self.cycle_longhaul["<v>"])
        axs[1].plot(self.cycle_regional["<s>"]/1000, self.cycle_regional["<v>"])
        axs[2].plot(self.cycle_urban["<s>"]/1000, self.cycle_urban["<v>"])
        axs[2].set_xlabel("Distance in km ")
        for ax in axs: ax.set_ylabel("Speed in km/h")
        fig.tight_layout()
        
if __name__ == "__main__":
    import os
    if os.getcwd().split("\\")[-1] == "modules":
        os.chdir(("..")) #Change to parent directory for correct paths
    m_profile = pd.read_csv("results/mobility")
    cons = Consumption(720)
    cons.simulate_cons(m_profile)
    