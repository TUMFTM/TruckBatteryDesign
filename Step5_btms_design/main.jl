append!(LOAD_PATH, [string(pwd(),"\\Step2_model_parametrization\\Model\\Modules"), 
                    string(pwd(),"\\Step2_model_parametrization\\Model\\Inputs"), 
                    string(pwd(),"\\Step4_lifetime_simulation\\Inputs")])
using JLD, Dates, DelimitedFiles
using Preprocessing, BatteryModel, Plots#, Visualization

## Define use case
dt = 10 #timestep in seconds
Ta = load_temperatureprofile("Germany_2017", dt)
P = load_powerprofile("Truck", dt)
Escale = 616/64.86 #Scaling factor between VW ID.3 and truck [Wassiliadis et al.]
ncells = 2*108*Escale #scaled linearly with battery size [Wassiliadis et al.]
mhousing = 125*Escale #scaled linearly with battery size [Wassiliadis et al.]
k_out = 10.2973*Escale^(2/3) #scaled linearly with battery size [Own measurement]

# Run simulation
P_coolers = (0:0.2:2).*800*Escale
T_cool_ons = 25:40
T_cool_offs = T_cool_ons .-2
res = Dict()
for P_cooler in P_coolers
    res[P_cooler] = Dict()
    for (T_cool_on, T_cool_off) in zip(T_cool_ons, T_cool_offs)
        #Print simulation status
        println("P_cooler: $P_cooler, Cooling threshold: $T_cool_on")

        #Execute method
        res[P_cooler][T_cool_on] = sim(Ta, P, dt, ncells, mhousing, k_out, P_cooler, T_cool_on, T_cool_off)
    end
end

timestamp = Dates.format(now(),"YYYYmmdd_HHMM")
save("Step5_btms_design\\Results\\res_$timestamp.jld", Dict("res"=>res))

Tmaxs = hcat([[res[P_cooler][T_cool_on]["Tmax"] for P_cooler in P_coolers] for T_cool_on in T_cool_ons]...)
Tavgs = hcat([[res[P_cooler][T_cool_on]["Tavg"] for P_cooler in P_coolers] for T_cool_on in T_cool_ons]...)
ΔTmaxs = hcat([[res[P_cooler][T_cool_on]["ΔTmax"] for P_cooler in P_coolers] for T_cool_on in T_cool_ons]...)
teols = hcat([[res[P_cooler][T_cool_on]["teol"] for P_cooler in P_coolers] for T_cool_on in T_cool_ons]...)

writedlm("Step5_btms_design\\Results\\Tmaxs.csv", Tmaxs,',')
writedlm("Step5_btms_design\\Results\\Tavgs.csv", Tavgs,',')
writedlm("Step5_btms_design\\Results\\Delta.csv", ΔTmaxs,',')
writedlm("Step5_btms_design\\Results\\teols.csv", teols,',')
