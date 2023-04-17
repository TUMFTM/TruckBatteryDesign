append!(LOAD_PATH, [string(pwd(),"\\Step2_model_parametrization\\Model\\Modules"), 
                    string(pwd(),"\\Step2_model_parametrization\\Model\\Inputs"),
                    string(pwd(),"\\Step2_model_parametrization\\Validation")])
using DelimitedFiles, Interpolations, DataFrames, Statistics, Cell, Plots, StatsPlots
using BatteryModel, Downsampler

function validate(filename; generateplots=false)
    println("Validation based on $filename measurements")

    ## Read inputs
    data_raw = readdlm("Step2_model_parametrization\\Validation\\Profiles\\$filename.csv",',',header=true)
    data= DataFrame(data_raw[1], vec(data_raw[2]))#[1:48602,:]

    ## Process inputs
    t_raw = (data.t.-data.t[1])/1000
    fP = LinearInterpolation(t_raw, data.P, extrapolation_bc = Flat())
    if "Ta" in names(data)
        data_Ta_nonan =  data[(!isnan).(data.Ta),:]
        t_raw_Ta_nonan = (data_Ta_nonan.t.-data_Ta_nonan.t[1])/1000
        fTa = LinearInterpolation(t_raw_Ta_nonan, data_Ta_nonan.Ta, extrapolation_bc = Flat())
    else
        fTa = LinearInterpolation(t_raw, fill(data.Tmean[1], length(t_raw)), extrapolation_bc = Flat())
    end

    #Determine starting points
    fUocv = Cell.ocv_interpolant()
    Uocv = fUocv.itp.itp;
    SOC = fUocv.itp.ranges
    fSOC = LinearInterpolation((Uocv,), collect(SOC[1]))
    SOC0 = fSOC(data.Umean[1])
    T0 = data.Tmean[1]

    ## Run simulation
    dt = 0.1 #timestep
    t_measured_end = ceil(t_raw[end]/dt)*dt #maximum simulation time  
    t_sim = 0:dt:t_measured_end
    P = fP(t_sim)
    Ta = fTa(t_sim)
    ncells = 2*108 #2p108s configuration [Wassiliadis et al.]
    mhousing = 125 # Mass of non-cell battery components in kg [Wassiliadis et al.]
    k_out = 10.2973 #Heat tansfer coefficient between housing and ambient in W/K [Measured for VW ID.3]
    Pcooler = 800 #604 #Installed electric cooling power in W [König et al.]
    Tcool_on = 33 #Threshold at which the cooling system is activated [Approximated from measurements]
    Tcool_off = 31 #Threshold at which the cooling system is deactivated [Approximated from measurements]
    if filename == "Interurban_30deg" 
        Tcool_on = 32.5 #Threshold at which the cooling system is activated [Approximated from measurements]
        Tcool_off = 31.5 #Threshold at which the cooling system is deactivated [Approximated from measurements]
    elseif filename == "Urban_30deg"
        Tcool_on = 32.8 #Threshold at which the cooling system is activated [Approximated from measurements]
        Tcool_off = 31.8 #Threshold at which the cooling system is deactivated [Approximated from measurements]
    end
    res = sim(Ta, P, dt, ncells, mhousing, k_out, Pcooler, Tcool_on, Tcool_off; Tstart = T0, SOCstart = SOC0, tend = t_measured_end, fulloutput=true)

    #Determine voltage error
    fV = LinearInterpolation(t_raw, data.Umean, extrapolation_bc = Flat())
    Vmeas = fV(t_sim[1:length(res["Vcell"])])
    ΔV = (res["Vcell"]-Vmeas)*1000
    
    #Determine temperature error
    data_T_nonan =  data[(!isnan).(data.Tmean),:]
    t_raw_T_nonan = (data_T_nonan.t.-data_T_nonan.t[1])/1000
    fT = LinearInterpolation(t_raw_T_nonan, data_T_nonan.Tmean, extrapolation_bc=Flat())
    Tmeas = fT(t_sim[1:length(res["Ts"])])
    ΔT = res["Ts"]-Tmeas

    #Save to .csv for violin plot
    open("Step2_model_parametrization\\Validation\\Results\\$(filename)_Verror.txt", "w") do io
        writedlm(io, ΔV)
    end

    open("Step2_model_parametrization\\Validation\\Results\\$(filename)_Terror.txt", "w") do io
        writedlm(io, ΔT)
    end

    #Downsample and save for transient plots
    downsample_and_save(t_raw./3600, data.Umin, 1000, "Step2_model_parametrization\\Validation\\Results\\$(filename)_Umin")
    downsample_and_save(t_raw./3600, data.Umax, 1000, "Step2_model_parametrization\\Validation\\Results\\$(filename)_Umax")
    downsample_and_save(t_sim./3600, res["Vcell"], 1000, "Step2_model_parametrization\\Validation\\Results\\$(filename)_Usim")
    downsample_and_save(t_sim./3600, ΔV, 1000, "Step2_model_parametrization\\Validation\\Results\\$(filename)_Uerror_sampled")

    downsample_and_save(t_raw./3600, data.Tmin, 1000, "Step2_model_parametrization\\Validation\\Results\\$(filename)_Tmin")
    downsample_and_save(t_raw./3600, data.Tmax, 1000, "Step2_model_parametrization\\Validation\\Results\\$(filename)_Tmax")
    downsample_and_save(t_sim./3600, res["Ts"], 1000, "Step2_model_parametrization\\Validation\\Results\\$(filename)_Ts")
    downsample_and_save(t_sim./3600, res["Tc"], 1000, "Step2_model_parametrization\\Validation\\Results\\$(filename)_Tc")
    downsample_and_save(t_sim./3600, res["Th"], 1000, "Step2_model_parametrization\\Validation\\Results\\$(filename)_Th")
    downsample_and_save(t_sim./3600, ΔT, 1000, "Step2_model_parametrization\\Validation\\Results\\$(filename)_Terror_sampled")

    if generateplots

        #Plot comparison
        l = @layout [a{0.7h}; b{0.3h}]
        p1 = plot(layout=l)
        # plot!(p1, subplot=1, t_raw/3600, data.Umin, fillrange = data.Umax, lw = 0, fillalpha = 0.35, label = "Measurements")
        plot!(p1, subplot=1, t_raw/3600, data.Umean, label = "Measurements")
        plot!(p1, subplot=1, t_sim[1:end-1]/3600, res["Vcell"], xformatter=_->"", ylabel="Voltage in V", label="Simulation")
        plot!(p1, subplot=2, t_sim[1:end-1]/3600, ΔV, xlabel = "time in hours", ylabel="Error in mV", legend=false)
        plot!(p1, size=(800,400))
        plot!(p1, left_margin=5*Plots.PlotMeasures.mm, bottom_margin=5*Plots.PlotMeasures.mm)
        if data.Umean[end]>4
            plot!(legend=:bottomright)
        end
        savefig(p1, "Step2_model_parametrization\\Validation\\Results\\$(filename)_voltage.png")

        #Plot comparison
        l = @layout [a{0.7h}; b{0.3h}]
        p2 = plot(layout=l)
        plot!(p2, subplot=1, t_raw/3600, data.Tmin, fillrange = data.Tmax, lw = 0, fillalpha = 0.35, label = "Measurements")
        plot!(p2, subplot=1, t_sim/3600, res["Ts"], label="Simulation Sensor")
        plot!(p2, subplot=1, t_sim/3600, res["Tc"], label="Simulation Cells")
        plot!(p2, subplot=1, t_sim/3600, res["Th"], label="Simulation Housing")
        plot!(p2, legend=:bottomright)
        plot!(p2, subplot=2, t_sim/3600, ΔT, xlabel="Time in hours", ylabel="Error in °C", legend=false)
        plot!(p2, size=(800,400))
        plot!(p2, left_margin=5*Plots.PlotMeasures.mm, bottom_margin=5*Plots.PlotMeasures.mm)
        savefig(p2, "Step2_model_parametrization\\Validation\\Results\\$(filename)_temperature.png")

    end

    return Dict("ΔV" => ΔV, "ΔT" => ΔT)
end

profiles = ["Urban_15deg", "Urban_30deg", 
            "Interurban_15deg", "Interurban_30deg", 
            "Highway_15deg", "Highway_30deg", 
            "Wallbox_charging_0-100_VW_11kw", "Fast_charging_0-100_VW_warm"]

res = Dict(p => validate(p) for p in profiles)

#Display results as table
res_table = DataFrame(
    profile = profiles,
    ΔV_max = [maximum(abs.(res[p]["ΔV"])) for p in profiles],
    ΔV_avg = [mean(abs.(res[p]["ΔV"])) for p in profiles],
    ΔT_max = [maximum(abs.(res[p]["ΔT"])) for p in profiles],
    ΔT_avg = [mean(abs.(res[p]["ΔT"])) for p in profiles]
)
