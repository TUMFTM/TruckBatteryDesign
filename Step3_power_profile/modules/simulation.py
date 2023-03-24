"""
Created on Sat Jul 17 12:43:30 2021

@author: olaf_
"""

import numpy as np
from numba import njit

class Simulation:
   
    def __init__(self, missionProfile, s_tot):
        
        # Driver parameters
        self.decmax = 1 # Maximum deceleration in m/s/s [VECTO]
        self.accmax = 1 # Maximum acceleration in m/s/s [VECTO]
        
        # Environmental constants
        self.g = 9.81 # Gravity constant in m/s/s [VECTO]
        self.rho = 1.188 # Air density in kg/m/m/m [VECTO]
        
        self.preprocessing(missionProfile, s_tot)
    
    def preprocessing(self, missionProfile, s_tot):
        
        # Unpack missionprofile        
        s = missionProfile["<s>"].values # Distance in m
        v = missionProfile["<v>"].values/3.6 # Speed in m/s
        grad = missionProfile["<grad>"].values # Gradient in %
        stop = missionProfile["<stop>"].values # Stop duration in s
        
        # Adjust length
        nrep = int(np.ceil(1000*s_tot/s[-1]))
        for _ in range(nrep): s = np.append(s, s[1:] + s[-1])
        s = s[s<=s_tot*1000]
        v = np.tile(v[1:], nrep)[:len(s)]
        v[-1] = 0 #make sure the vehicle stops at the end of the cycle
        grad = np.tile(grad[1:], nrep)[:len(s)]
        stop = np.tile(stop[1:], nrep)[:len(s)]    
    
        # Calculate distance step along route
        ds = np.diff(s)
        
        # Generate array with dec phases
        i2 = np.where(np.diff(v)<0)[0]+1 #ends of deceleration phases
        i1 = np.append([0], i2[:-1]) #start of deceleration phases
        v_target = np.zeros(len(v))
        for i1, i2 in zip(i1,i2):
            v_target[i1:i2] = np.minimum(
                v[i1:i2], # drive cycle speed
                np.sqrt(v[i2]**2+2*self.decmax*(s[i2]-s[i1:i2]))) #deceleration speed
                
        self.s = s
        self.v = v
        self.grad = grad
        self.stop = stop
        self.vtarget = v_target
        self.ds = ds

    def run(self, veh, gvw, k):
        
        #Adjust speed
        vtarget = self.vtarget*k #Scale speed with scaling factor
        
        return self._run(
            self.stop, self.ds, vtarget, self.grad, self.g, self.rho, self.accmax, 
            veh["fr"], veh["cd_a"], veh["motor_power"], veh["eta"], veh["p_aux"], gvw)

    @staticmethod
    @njit
    def _run(stop_arr, ds_arr, vtarget_arr, grad_arr, g, rho, accmax, fr, cd_a, motor_power, eta, p_aux, gvw):
        
        s = [0]
        t = [0]
        v = [0]
        p = []        
        for stop, ds, vtarget, grad in zip(stop_arr, ds_arr, vtarget_arr[1:], grad_arr):
            
            # If the vehicle is stopped, add extra entry to list
            if stop>0:
                s.append(s[-1])
                t.append(t[-1]+stop)
                v.append(0)
                p.append(0)   
            
            # Determine target acceleration
            atarget = (vtarget**2-v[-1]**2)/2/ds #target acceleration
            
            # Determine power limited maximum acceleration
            f_roll = gvw*g*fr*np.cos(np.arctan(grad/100)) #Rolling resistance in N
            f_drag = 0.5*rho*cd_a*v[-1]**2 #Drag resistance in N
            f_incl = gvw*g*np.sin(np.arctan(grad/100)) #Inclination resistance in N
            f_max = motor_power/v[-1] if v[-1]>0 else 1e9  #Max driving force in N
            apower = (f_max*eta-f_roll-f_drag-f_incl)/gvw #Max acceleration in m/s/s
            
            # Determine acceleration and new states
            a = min(atarget, apower, accmax) #Applied acceleration in m/s/s
            v_new = np.sqrt(v[-1]**2+2*a*ds) #New vehicle speed in m/s
            if np.isnan(v_new): v_new = 0 #Adjust for rounding errors that lead to NaN
            t_new = t[-1] + 2*ds/(v[-1]+v_new) #New time since start in s
            f_res = gvw*a+f_roll+f_drag+f_incl
            p_new = f_res*v[-1]*eta**np.sign(-f_res) #Applied power in W
            
            # Append new states to lists
            s.append(s[-1]+ds)
            t.append(t_new)
            v.append(v_new)
            p.append(p_new)
            
        p_bat = [max(p_mot, -motor_power) for p_mot in p] # Remove sections relying on mechanical breaking
        t_diff = [t2-t1 for t1, t2 in zip(t[:-1], t[1:])]
        e_con = [p*dt for p,dt in zip(p_bat, t_diff)]
        e_tot = sum(e_con)+p_aux*t[-1] # Calculate total energy demand
        con = e_tot/3600/s[-1] # Consumption in kWh/km
        v_avg = s[-1]/t[-1]*3.6 # Average speed in km/h
        p.append(0) # Append power value to create equal length lists
        p_bat = np.append(p_bat, 0)
        
        return con, v_avg, s, t, v, p, p_bat