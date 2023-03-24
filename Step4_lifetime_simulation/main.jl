append!(LOAD_PATH, [string(pwd(),"\\Step2_model_parametrization\\Modules"), 
                    string(pwd(),"\\Step2_model_parametrization\\Inputs\\cell"), 
                    string(pwd(),"\\Step4_lifetime_simulation\\Inputs")])
using Plots
using Preprocessing, BatteryModel

## Define use case
dt = 10 #timestep in seconds
Ta = load_temperatureprofile("Germany_2017", dt)
P = load_powerprofile("Truck", dt)
Tcool_on = 33 #Based on ID.3 data
Tcool_off = 31 #Based on VW ID.3 data
Escale = 616/64.9 #Scaling factor between VW ID.3 and truck [Wassiliadis et al.]
ncells = 2*108*Escale #scaled linearly with battery size [Wassiliadis et al.]
mhousing = 125*Escale #scaled linearly with battery size [Wassiliadis et al.]
k_out = 10.2973*Escale^(2/3) #scaled linearly with battery size [Own measurement]
Pcooler = 800*Escale #scaled linearly with battery size [Fitted to Fast-charging measurement]

## Run simulation
@time res_single = sim(Ta, P, dt, ncells, mhousing, k_out, Pcooler, Tcool_on, Tcool_off; fulloutput = true)

#Capacity loss plot
ttot = (0:3600*24*10:res_single["teol"]*365*24*3600-1)/3600/24/365
Q = 1 .- res_single["Qloss_cal"] - res_single["Qloss_cyc"]
plot(ttot, Q[1:360*24*10:end], legend=false, size = (72*12.44, 72*5.33))
xlabel!("Time in years")
ylabel!("Share of inital capacity")
plot!(left_margin=10Plots.PlotMeasures.mm, bottom_margin=10Plots.PlotMeasures.mm)
savefig("Step4_lifetime_simulation\\Results\\Capacityloss.svg")

#Annual temperature plot
t = range(0,12,length=365*2)
Tc_mins = [minimum(res_single["Tc"][(360*24*(n-1)+1):360*24*n]) for n in 1:365]
Tc_maxs = [maximum(res_single["Tc"][(360*24*(n-1)+1):360*24*n]) for n in 1:365]
Tc_minmaxs = collect(Iterators.flatten(zip(Tc_mins, Tc_maxs)))
Th_mins = [minimum(res_single["Th"][(360*24*(n-1)+1):360*24*n]) for n in 1:365]
Th_maxs = [maximum(res_single["Th"][(360*24*(n-1)+1):360*24*n]) for n in 1:365]
Th_minmaxs = collect(Iterators.flatten(zip(Th_mins, Th_maxs)))
plot(t, Ta[1:360*12:end], label="Ambient", size = (72*12.44, 72*5.33))
plot!(t, Tc_minmaxs, label="Cell")
plot!(t, Th_minmaxs, label="Housing")
xlabel!("Time in months")
ylabel!("Temperature in °C")
plot!(left_margin=10Plots.PlotMeasures.mm, bottom_margin=10Plots.PlotMeasures.mm)
plot!(legend=:bottom)
savefig("Step4_lifetime_simulation\\Results\\T_annual.svg")

#Annual Temperature, close-up
tday = (0:100:3600*24)/3600
i = findmax(res_single["Tc"][1:360*24*365])[2]
i1 = Int(floor(i/360/24))
i2 = Int(ceil(i/360/24))
p1 = plot(tday, Ta[360*24*i1:10:360*24*i2], label="Ambient")
plot!(p1, tday, res_single["Tc"][360*24*i1:10:360*24*i2], label="Cell")
plot!(p1, tday, res_single["Th"][360*24*i1:10:360*24*i2], label="Housing")
plot!(legend=:topright)
ylabel!(p1, "Temperature in °C")
p2 = plot(tday, res_single["Pbat"][360*24*i1:10:360*24*i2]/1000, label=nothing)
xlabel!(p2, "Time in hours")
ylabel!(p2, "Battery power in kW")
ptot = plot(p1, p2, layout = (2,1), link=:x, size = (72*12.44, 72*5.33))
plot!(ptot, left_margin=10Plots.PlotMeasures.mm, bottom_margin=5Plots.PlotMeasures.mm)
savefig("Step4_lifetime_simulation\\Results\\T_closeup.svg")
