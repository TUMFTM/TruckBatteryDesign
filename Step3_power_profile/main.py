# -*- coding: utf-8 -*-
"""
Created on Fri Sep 23 13:03:42 2022

@author: ga78tas
"""
from modules.mobility import Mobility
from modules.consumption import Consumption
from modules.charging import Charging

Ebat = 616 #Calculated battery size for selected cell
mobility = Mobility()
cons = Consumption(Ebat)
charging = Charging(Ebat)

#%% Generate mobility pattern
mobility.plot_ntrips()
mobility.plot_departures()
mobility.plot_distanceduration()
mobility.plot_resttimes()

m_profile = mobility.gen_profile()

mobility.print_metrics(m_profile)
mobility.plot_trip_mileage_distr(m_profile)
mobility.plot_daily_distance_distr(m_profile)

#%% Generate load profile
cons.plot_weight_dist()
cons.plot_drivingcycles()

c_profile = cons.simulate_cons(m_profile)

#%% Assign chargers
charging.plot_chargeravailability()

p_profile = charging.assign_chargers(c_profile)
p_bat = charging.gen_loadprofile(p_profile)

charging.plot_chargerusage(p_profile)
charging.plot_soc(p_profile)
charging.print_metrics(p_profile)
charging.plot_pbat(p_bat)