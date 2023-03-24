module Preprocessing
using DelimitedFiles, Interpolations
export load_temperatureprofile, load_powerprofile

function load_temperatureprofile(City, dt)

    #Load data
    TempData = readdlm("Step4_lifetime_simulation\\Inputs\\climates\\$City.csv",',',skipstart=1)

    #Read out variables
    t_raw = TempData[:,1]
    Ta_raw = TempData[:,2]

    #Append start value of next year for correct interpolation
    push!(t_raw,t_raw[end]+3600)
    push!(Ta_raw,Ta_raw[1])

    #Map ambient temperature profile to timestep
    fT = LinearInterpolation(t_raw,Ta_raw)

    #Interpolate and write to Dict
    t = 0:dt:t_raw[end]-dt
    Ta = fT(t)

    return Ta
end

function load_powerprofile(Application, dt)

    #Load data
    P_raw = readdlm("Step4_lifetime_simulation\\Inputs\\loadprofiles\\$Application.csv",',')[1:end-1] #Skip last value, which is empty
    t_raw = 0:length(P_raw)-1 #Emobpy profile has 1s timesteps

    fP = LinearInterpolation(t_raw,P_raw)
    t = 0:dt:t_raw[end]
    P = fP(t)

    return P
end

end
