# -*- coding: utf-8 -*-
"""
Created on Tue Aug 16 15:28:23 2022

@author: ga78tas
"""

import pandas as pd
import numpy as np
from numpy.random import choice
import matplotlib.pyplot as plt

class Mobility():
    
    def __init__(self):
        self.p_dep = pd.read_csv("inputs/departuretime.csv") #departure time distribution
        self.p_ntrips = pd.read_csv("inputs/ntrips.csv") #number of trips distribution
        self.p_dist_duration = pd.read_csv("inputs/dist_duration.csv") #distance duration distribution
        self.p_trest = pd.read_csv("inputs/trest.csv") #rest time distribution
        
        #Rules
        self.t_max_day = 10 #Maximum daily driving time
        self.t_max_drive_wo_rest = 4.5 #Maximum driving time without rest period
        self.t_home_min = 6 #Minimum time at the home time (required to allow recharging the battery)
        
        #Duration
        self.days = 10#365 #one year
        
        #Postprocessing: Remove the probability of a single trip per day to ensure the truck returns to the depot overnight
        self.p_ntrips.loc[self.p_ntrips["Number"] == 1, "Chance_week"] = 0
        self.p_ntrips.loc[self.p_ntrips["Number"] == 1, "Chance_weekend"] = 0
        self.p_ntrips["Chance_week"] = self.p_ntrips["Chance_week"]/sum(self.p_ntrips["Chance_week"])
        self.p_ntrips["Chance_weekend"] = self.p_ntrips["Chance_weekend"]/sum(self.p_ntrips["Chance_weekend"])
        
        #Postprocessing: Adjust mean duration of last bin 
        self.p_dist_duration.loc[self.p_dist_duration["mean_duration"] ==285, "mean_duration"] = 270
        
        #Postprocessing: Remove bins with too high and too low speeds
        v  = self.p_dist_duration["mean_distance"]/self.p_dist_duration["mean_duration"]*60
        self.p_dist_duration.loc[v > 85, "Chance"] = 0
        self.p_dist_duration.loc[v < 15, "Chance"] = 0
        self.p_dist_duration["Chance"] = self.p_dist_duration["Chance"]/sum(self.p_dist_duration["Chance"])
        
    def gen_profile(self):
        
        state = ["Home"]
        distance = [0]
        duration = [0]
        
        for day in range(self.days):
            
            #Sample number of trips
            if day == self.days-1:
                ntrip = 0 #no trips on the last day of the year to ensure a continuous load profile
            elif day%7<=5: #Weekday
                ntrip = choice(self.p_ntrips["Number"], p=self.p_ntrips["Chance_week"])
            else: #Weekend
                ntrip = choice(self.p_ntrips["Number"], p=self.p_ntrips["Chance_weekend"])
                
            if ntrip ==0:
                duration[-1] += 24
            elif duration[-1] < self.t_home_min-23: #Trip plus rest durations were so long that the next day is skipped
                duration[-1] += 24
            else: 
                #Sample departure time
                if duration[-1] < self.t_home_min: #Enforce minimum stay at home duration
                    dep_corr = self.p_dep.drop(self.p_dep[self.p_dep["Departure"]<(self.t_home_min-duration[-1])].index) #Avoid departure times before the return of last days trip
                    dep_corr["Chance"] = dep_corr["Chance"]/sum(dep_corr["Chance"]) #Adjust chances
                    dtime = choice(dep_corr["Departure"], p=dep_corr["Chance"]) #sample departure time
                else:
                    dtime = choice(self.p_dep["Departure"], p=self.p_dep["Chance"]) #sample departure time
                    
                #Add time before departure to duration spend at home
                duration[-1] += dtime 
                
                #Sample trip distances & durations until max driving time is met
                t_tot = np.inf
                i = 0
                while t_tot>self.t_max_day: 
                    ixs = [choice(len(self.p_dist_duration), p = self.p_dist_duration["Chance"]) for _ in range(ntrip)] #sample index from distance duration matrix
                    distances = self.p_dist_duration.iloc[ixs]["mean_distance"].values #get distance
                    durations = self.p_dist_duration.iloc[ixs]["mean_duration"].values/60 #get duration in h
                    t_tot = sum(durations)
                    
                    #Infinite loop backstop
                    i += 1
                    if i > 100:
                        print("Max. driving duration not met after 100 iterations")
                    
                #Assign rest durations until legal driving period is not exceeded
                rest_regulations_met = False
                i = 0
                while rest_regulations_met == False:
                    
                    trests = [choice(self.p_trest["mean_rest_time"], p=self.p_trest["Chance"]) 
                              for _ in range(ntrip-1)] #Sample rest durations
                    
                    #Check if legal driving period is exceeded
                    t_drive_wo_rest = 0 #driving time without rest
                    t_drives_wo_rest = [] #list of driving times without rest
                    for t_drive, trest in zip(durations[:-1], trests):
                        t_drive_wo_rest += t_drive #add driving time of trip to driving time without rest
                        if trest>45:
                            t_drives_wo_rest.append(t_drive_wo_rest)
                            t_drive_wo_rest = 0 #reset driving time without rest
                    
                    t_drives_wo_rest.append(t_drive_wo_rest + durations[-1]) #Add drive after last stop
        
                    if all([t<=self.t_max_drive_wo_rest for t in t_drives_wo_rest]): #if all driving times without rest were lower than the maximum driving time without rest
                        rest_regulations_met = True 
                            
                    #Infinite loop backstop
                    i += 1
                    if i > 100:
                        import pdb; pdb.set_trace()
                        print("Legal rest duration not met after 100 iterations")
                        
                #Add trips and stops to list
                for dist, dur, trest in zip(distances[:-1], durations[:-1], trests):
                    #Add drive
                    state.append("Driving")
                    distance.append(dist)
                    duration.append(dur)
                    
                    #Add stop
                    state.append("Away")
                    distance.append(0)
                    duration.append(trest/60)           
                    
                #Add final drive
                state.append("Driving")
                distance.append(distances[-1])
                duration.append(durations[-1])
                
                #Add final stop at home
                state.append("Home")
                distance.append(0)
                duration.append((day+1)*24-sum(duration))
        
        tend = np.cumsum(duration)%24
        tstart = np.append([0], tend[:-1])
        
        #%% Write to dataframe and csv
        profile = pd.DataFrame({"tstart": tstart, 
                                "tend": tend, 
                                "state": state,
                                "distance": distance,
                                "duration":duration})
        
        profile.to_csv("results/mobility", index=False)
        
        return profile

    def plot_departures(self):
                
        fig, ax = plt.subplots(1,1, figsize=(4, 3))
        ax.bar(self.p_dep["Departure"], self.p_dep["Chance"])
        ax.set_xlabel("Departure time first trip in h")
        ax.set_ylabel("Chance")
        fig.tight_layout()
        fig.savefig("results/figures/departure_times.svg")

    def plot_ntrips(self):        
        fig, ax = plt.subplots(1,1, figsize=(4, 3))
        self.p_ntrips.plot(ax = ax, x = "Number", y = ["Chance_week", "Chance_weekend"], kind="bar")
        fig.tight_layout()
        fig.savefig("results/figures/ntrips.svg")

    def plot_resttimes(self):
        fig, ax = plt.subplots(1,1, figsize=(4, 3))
        ax.bar(self.p_trest["mean_rest_time"], self.p_trest["Chance"], width=20)
        ax.set_xlabel("Stop time in minutes")
        ax.set_ylabel("Chance")
        ax.vlines(45, 0, max(self.p_trest["Chance"]), colors="red", linestyle="dashed" )
        fig.tight_layout()
        fig.savefig("results/figures/resttimes.svg")

    def plot_distanceduration(self):
        fig, ax = plt.subplots(1,1, figsize=(5, 4), subplot_kw={'projection': '3d'})
        ax.bar3d(self.p_dist_duration["mean_distance"], 
                 self.p_dist_duration["mean_duration"], 
                 np.zeros_like(self.p_dist_duration["Chance"]),
                 20,20,
                 self.p_dist_duration["Chance"])
        ax.set_xlabel("Distance in km")
        ax.set_ylabel("Duration in minutes")
        ax.set_zlabel("Chance")
        fig.tight_layout()
        fig.savefig("results/figures/dist_duration.svg")

    def print_metrics(self, profile):
        s_annual = sum(profile.distance)*365/self.days
        s_max = max(profile.distance)
        t_max = max(profile[profile.state=="Driving"].duration)
        t_driving = sum(profile[profile.state=="Driving"].duration)
        t_breaks = sum(profile[profile.state=="Away"].duration)
        t_home = sum(profile[profile.state=="Home"].duration)
        print(f"annual_mileage: {s_annual}km")
        print(f"furthest trip: {s_max}km")
        print(f"longest trip: {t_max}h")
        print(f"time spent driving: {t_driving:.0f}h")
        print(f"time stopped at break: {t_breaks:.0f}h")
        print(f"time at home: {t_home:.0f}h")

    def plot_trip_mileage_distr(self, profile):
        distance_distr = profile[profile.state=="Driving"].distance.value_counts().sort_index()
        mileage_distr = distance_distr*distance_distr.index
        
        fig, ax = plt.subplots(1,1, figsize=(12.41, 5.33))
        ax.plot(distance_distr.index, distance_distr.cumsum()/distance_distr.sum())
        ax.plot(mileage_distr.index, mileage_distr.cumsum()/mileage_distr.sum())
        ax.set_xlim(0,400)
        ax.set_ylim(0,1)
        ax.set_xlabel("distance in km")
        ax.set_ylabel("cumulative share")
        ax.legend(["Trips", "Mileage"])
        ax.grid(True)
        fig.savefig("results/figures/trips_mileage_distribution.svg")

    def plot_daily_distance_distr(self, profile):
        ihome = profile[profile["state"] == "Home"].index #Index of profile rows where the vehicle is at the home depot
        sdays = [sum(profile.loc[i1:i2, "distance"]) for i1, i2 in zip(ihome[:-1], ihome[1:])]
        
        fig, ax = plt.subplots(1,1, figsize=(12.41, 5.33))
        ax.hist(sdays, bins=np.arange(0, max(sdays), 30), rwidth=0.8)
        ax.set_xlabel("Daily driving distance in km")
        ax.set_ylabel("Nr of days")
        fig.savefig("results/figures/dailydistance.svg")
        
if __name__ == "__main__":
    import os
    if os.getcwd().split("\\")[-1] == "modules":
        os.chdir(("..")) #Change to parent directory for correct paths
    mobility = Mobility()
    profile = mobility.gen_profile()