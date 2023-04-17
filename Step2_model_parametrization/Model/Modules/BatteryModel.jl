module BatteryModel
using Statistics
using ControlAlgorithm, ElectricModel, ThermalModel, Cell
export sim

## Constants
const Qloss_EOL = 0.2 # EOL criterium [Assumption]
const Tlimit = 60 #Maximum temperature [Assumption]

## Simulation
function sim(Ta, Pdem, dt, ncells, mhousing, k_out, Pcooler, Tcool_on, Tcool_off; Tstart = nothing, SOCstart = nothing, tend = 3600*24*365*20, socend = nothing, fulloutput = false)

    #Set start SOC and temperature if not defined 
    if isnothing(Tstart) Tstart = Ta[1] end
    if isnothing(SOCstart) SOCstart = ElectricModel.SOC_max end
    
    #Generate ocv and internal resistance interpolation functions
    fUocv = Cell.ocv_interpolant()
    fR0_ch, fR1_ch, fC1_ch, fR0_dch, fR1_dch, fC1_dch = Cell.Ri_interpolants()

    #Top level calculations
    C_housing = (mhousing-ThermalModel.m_sens*ncells)*ThermalModel.cp_alu #Housing heat capacity in J/K []
    
    #Preallocate variables that are logged every simulation timestep
    maxsteps = Int(round(tend/dt)+1) #Maximum number of steps in simulation
    SOC = Vector{Float64}(undef,maxsteps) #SOC
    V1 = Vector{Float64}(undef,maxsteps) #Voltage drop over first RC element
    Tc = Vector{Float64}(undef,maxsteps) #Cell temperature
    Th = Vector{Float64}(undef,maxsteps) #Housing temperature
    Ts = Vector{Float64}(undef,maxsteps) #Temperature sensor temperature
    Vcell = Vector{Float64}(undef,maxsteps) #Cell terminal voltage
    Icell = Vector{Float64}(undef,maxsteps) #Cell current
    Crate = Vector{Float64}(undef,maxsteps) #Preallocate Crate
    Pcell = Vector{Float64}(undef,maxsteps) #power drawn from grid
    Ploss = Vector{Float64}(undef,maxsteps) #ohmic losses energy consumption
    Qloss_cal = Vector{Float64}(undef,maxsteps) #calendaric capacity loss
    Qloss_cyc = Vector{Float64}(undef,maxsteps) #cyclic capacity loss
    k_T = Vector{Float64}(undef,maxsteps) #Temperature aging factor
    k_V = Vector{Float64}(undef,maxsteps) #Voltage aging factor 
    k_∅V = Vector{Float64}(undef,maxsteps) #Average cycling voltage aging factor
    k_DOD = Vector{Float64}(undef,maxsteps) #DOD aging factor
    Rinc_cal = Vector{Float64}(undef,maxsteps) #calendaric internal resistance increase
    Rinc_cyc = Vector{Float64}(undef,maxsteps) #cyclic internal resistance increase

    #Set starting conditions of all states
    SOC[1] = SOCstart #Initial SOC
    V1[1] = 0 #Initial voltage drop over RC element
    Tc[1] = Tstart #Initial cell temperature
    Th[1] = Tstart #Initial housing temperature
    Ts[1] = Tstart #Starting temperature temperature sensor
    Cooling_on = false #Cooling system is off initially
    Rinc_cal[1] = 0 #Initial calendaric resistance increase
    Rinc_cyc[1] = 0 #Initial cyclic resistance increase
    Qloss_cal[1] = 0 #Initial calendaric capacity loss
    Qloss_cyc[1] = 0 #Initial cyclic capacity loss
    prev_Isign = -1 #Initial sign of cell current
    rainflow_SOCs = [SOCstart] #Initial vector with SOC extrema
    iend = maxsteps #Fallback cropping index in case EOL criterion is not reached
    for i = 1:maxsteps-1

        #Get corresponding index of power and ambient temperature profiles
        iP = (i-1)%length(Pdem)+1 #power profile iterator
        iT = (i-1)%length(Ta)+1 #ambient temperature iterator

        #Determine battery characteristics based on current state
        Uocv = fUocv(SOC[i])
        Q = Cell.Qnom*(1 - Qloss_cal[i] - Qloss_cyc[i])
        if Pdem[iP]<=0
            R0 = fR0_dch(Tc[i], SOC[i]) * (1+Rinc_cal[i]+Rinc_cyc[i])
            R1 = fR1_dch(Tc[i], SOC[i]) * (1+Rinc_cal[i]+Rinc_cyc[i])
            C1 = fC1_dch(Tc[i], SOC[i]) / (1+Rinc_cal[i]+Rinc_cyc[i]) #RC capacitance increases with aging to maintain the same RC time
        else
            R0 = fR0_ch(Tc[i], SOC[i]) * (1+Rinc_cal[i]+Rinc_cyc[i])
            R1 = fR1_ch(Tc[i], SOC[i]) * (1+Rinc_cal[i]+Rinc_cyc[i])
            C1 = fC1_ch(Tc[i], SOC[i]) / (1+Rinc_cal[i]+Rinc_cyc[i]) #RC capacitance increases with aging to maintain the same RC time
        end

        #Calculate power limits
        Pmin, Pmax = powerlim(Uocv, R0, V1[i], Q, SOC[i], dt)

        #Allocate driving, charging and BTMS power
        Pcell[i], Pcool, Pheat, Cooling_on = control(Pdem[iP], Pmin, Pmax, Ts[i], Cooling_on, ncells, Pcooler, Tcool_on, Tcool_off)

        #Electric model
        Crate[i], Ploss[i], SOC[i+1], V1[i+1], Vcell[i], Icell[i] = electricmodel(Pcell[i], Uocv, Q, R0, R1, C1, SOC[i], V1[i], dt)        
        
        #Thermal model
        Tc[i+1], Th[i+1], Ts[i+1] = thermalmodel(Ta[iT], Tc[i], Th[i], Ts[i], Ploss[i], Pcool, Pheat, ncells, k_out, C_housing, dt)

        #Calendaric aging
        Qloss_cal[i+1], Rinc_cal[i+1], k_T[i], k_V[i] = aging_cal(Qloss_cal[i], Rinc_cal[i], Tc[i], Uocv, dt)

        #Cyclic aging (only updated after completing a half cycle)
        if abs(sign(Icell[i]) - prev_Isign) == 2
            prev_Isign = sign(Icell[i])
            push!(rainflow_SOCs, SOC[i])
            Qloss_cyc[i+1], Rinc_cyc[i+1], rainflow_SOCs, k_DOD[i], k_∅V[i] = aging_cyc(Qloss_cyc[i], Rinc_cyc[i], rainflow_SOCs, fUocv)
        else 
            Qloss_cyc[i+1] = Qloss_cyc[i]
            Rinc_cyc[i+1] = Rinc_cyc[i]
        end

        #Check if EOL condition was reached
        if (Qloss_cal[i+1] + Qloss_cyc[i+1]) > Qloss_EOL
            iend = i+1
            break
        end

        #Check if SOC condition was reached
        if !isnothing(socend)
            if SOC[i+1] >= socend
                iend = i+1
                break
            end
        end
    end

    #Crop outputs
    SOC = SOC[1:iend]
    V1 = V1[1:iend]
    Tc = Tc[1:iend]
    Th = Th[1:iend]
    Ts = Ts[1:iend]
    Qloss_cal = Qloss_cal[1:iend]
    Qloss_cyc = Qloss_cyc[1:iend]
    Rinc_cal = Rinc_cal[1:iend]
    Rinc_cyc = Rinc_cyc[1:iend]
    Vcell = Vcell[1:iend-1]
    Icell = Icell[1:iend-1]
    Crate = Crate[1:iend-1]
    Pcell = Pcell[1:iend-1]
    Ploss = Ploss[1:iend-1]
    k_T = k_T[1:iend]
    k_V = k_V[1:iend]
    k_∅V = k_∅V[1:iend]
    k_DOD = k_DOD[1:iend]

    #Compute results
    teol = iend*dt #battery lifetime in seconds
    teol_a = teol/3600/24/365 #battery lifetime in years
    eta = 1 .- Ploss./Pcell #Charging efficiency
    eta[eta.>1] = 1 ./eta[eta.>1] #Discharging efficiency
    FEC = sum(abs.(Crate))*dt/3600/2/teol_a/365 #Average full equivalent cycles per day
    ΔTmax = maximum(abs.(Tc.-Th)) #Maximum temperature difference within cell

    #write top level outputs to result
    res = Dict()
    res["teol"] = teol_a
    res["FEC"] = FEC
    res["SOC_min"] = minimum(SOC)
    res["SOC_avg"] = mean(SOC)
    res["Tmin"] = minimum(Tc)
    res["Tmax"] = maximum(Tc)
    res["Tavg"] = mean(Tc)
    res["ΔTmax"] = ΔTmax
    res["Crate_avg"] = mean(abs.(Crate))
    res["eta_avg"] = mean(filter(!isnan, eta))
    res["Qloss_cal_end"] = Qloss_cal[end]
    res["Qloss_cyc_end"] = Qloss_cyc[end]
    res["Rinc_cal_end"] = Rinc_cal[end]
    res["Rinc_cyc_end"] = Rinc_cyc[end]
    res["Rinc_tot_end"] = Rinc_cal[end]+Rinc_cyc[end]

    if fulloutput #not saving the full result by default to prevent OutOfMemoryError
        res["SOC"] = SOC
        res["V1"] = V1
        res["Tc"] = Tc
        res["Th"] = Th
        res["Ts"] = Ts
        res["Qloss_cal"] = Qloss_cal
        res["Qloss_cyc"] = Qloss_cyc
        res["Vcell"] = Vcell
        res["Icell"] = Icell
        res["Crate"] = Crate
        res["Pbat"] = Pcell*ncells
        res["Ploss"] = Ploss
        res["k_T"] = k_T
        res["k_V"] = k_V
        res["k_∅V"] = k_∅V
        res["k_DOD"] = k_DOD
        res["Rinc_cal"] = Rinc_cal
        res["Rinc_cyc"] = Rinc_cyc
        res["eta"] = eta
    end

    return res
end
end