module Cell
using DelimitedFiles, Interpolations, Statistics
export ocv_interpolant, Ri_interpolants, aging_cal, aging_cyc

## Constants
const Qnom = 78 # Cell nominal capacity in Ah [Wassiliadis et al.]
const Umin = 2.5 # Cell minimum voltage in V [Wassiliadis et al.]
const Umax = 4.2 # Cell maximum voltage in V [Wassiliadis et al.]
const Imax_cont = 1250 # Maximum charging current [Wassiliadis et al.]
const Imin_cont = -250 # Maximum discharge current [Based on Testplan Markus]
const mcell = 1.101 # Cell weight in kg [Wassiliadis et al.]
const cp_cell = 1045 #Cell specific heat capacity J/kg/K [Average of NMC/C pouch cells reported by Steinhardt et al.]
const C_cell = mcell*cp_cell #Cell heat capacity in J/K
const k_VW_Q = 0.425271804835512 #Reduced capacity fading rate resulting from fit to VW ID.3 measurements
const k_VW_R = 0.115328129947322 #Reduced resistance increase rate resulting from fit to VW ID.3 measurements
const k_Q_to_FEC = 2.05*2 #Factor to convert Schmalstieg model from capacity throughput to FEC

function ocv_interpolant()

    SOC = 0:0.01:1
	Uocv = vec(readdlm("Step2_model_parametrization\\Model\\Inputs\\Uocv.csv",','))
	fUocv = LinearInterpolation(SOC, Uocv)
    return fUocv
end

function Ri_interpolants()

    SOC = 0.1:0.1:0.9
    T = 0:20:40

    R0_ch = readdlm("Step2_model_parametrization\\Model\\Inputs\\R0_ch.csv",',');
    R1_ch = readdlm("Step2_model_parametrization\\Model\\Inputs\\R1_ch.csv",',');
    C1_ch = readdlm("Step2_model_parametrization\\Model\\Inputs\\C1_ch.csv",',');
    R0_dch = readdlm("Step2_model_parametrization\\Model\\Inputs\\R0_dch.csv",',');
    R1_dch = readdlm("Step2_model_parametrization\\Model\\Inputs\\R1_dch.csv",',');
    C1_dch = readdlm("Step2_model_parametrization\\Model\\Inputs\\C1_dch.csv",',');

    R0_ch_intp  = LinearInterpolation((T, SOC), R0_ch, extrapolation_bc = Flat())
    R1_ch_intp  = LinearInterpolation((T, SOC), R1_ch, extrapolation_bc = Flat())
    C1_ch_intp  = LinearInterpolation((T, SOC), C1_ch, extrapolation_bc = Flat())
    R0_dch_intp = LinearInterpolation((T, SOC), R0_dch, extrapolation_bc = Flat())
    R1_dch_intp = LinearInterpolation((T, SOC), R1_dch, extrapolation_bc = Flat())
    C1_dch_intp = LinearInterpolation((T, SOC), C1_dch, extrapolation_bc = Flat())
    
    return R0_ch_intp, R1_ch_intp, C1_ch_intp, R0_dch_intp, R1_dch_intp, C1_dch_intp 
end

function aging_cal(Qloss, Rinc, T, Uocv, dt)
    k_temp_Q = 1e6exp(-6976/(T+273.15))
    k_temp_R = 1e5exp(-5986/(T+273.15))

    k_U_Q = 7.543Uocv-23.75
    k_U_R = 5.27Uocv-16.32

    t_eq_Q = (Qloss/k_U_Q/k_VW_Q/k_temp_Q)^(4/3)
    t_eq_R = (Rinc/k_U_R/k_VW_R/k_temp_R)^(4/3)
    Qloss_new = k_VW_Q*k_U_Q*k_temp_Q*(t_eq_Q+dt/3600/24)^0.75
    Rinc_new =  k_VW_R*k_U_R*k_temp_R*(t_eq_R+dt/3600/24)^0.75

    return Qloss_new, Rinc_new, k_temp_Q, k_U_Q
end

function aging_cyc(Qloss, Rinc, rainflow_SOCs, fUocv)
    DODs, ∅SOCs, rainflow_SOCs = rfcounting(rainflow_SOCs) #Rainflow counting to determine effective DOD cycles
    
    ∅k_DOD_Q = 0
    ∅k_∅V_Q = 0
    for (DOD, ∅SOC) in zip(DODs, ∅SOCs)
        k_DOD_Q = 4.081e-3DOD
        k_DOD_R = 2.798e-4DOD
        k_∅V_Q = 7.348e-3(fUocv(∅SOC)-3.667)^2+7.6e-4
        k_∅V_R = 2.153e-4(fUocv(∅SOC)-3.725)^2-1.521e-5

        FECeq = (Qloss/k_VW_Q/(k_DOD_Q+k_∅V_Q))^2/k_Q_to_FEC
        Qloss = k_VW_Q*(k_DOD_Q+k_∅V_Q)*sqrt(k_Q_to_FEC*(FECeq+DOD))
        Rinc += k_VW_R*(k_DOD_R+k_∅V_R)*k_Q_to_FEC*DOD

        ∅k_DOD_Q += k_DOD_Q*DOD/sum(DODs)
        ∅k_∅V_Q += k_∅V_Q*DOD/sum(DODs)
    end

    return Qloss, Rinc, rainflow_SOCs, ∅k_DOD_Q, ∅k_∅V_Q
end

function rfcounting(rainflow_SOCs::Array{Float64,1})

    #Find DODs based on rainflow counting (https://doi.org/10.1016/0142-1123(82)90018-4)
    DODs = []
    ∅SOCs = []
    while length(rainflow_SOCs)>2
        newDOD = abs(rainflow_SOCs[end]-rainflow_SOCs[end-1])
        prevDOD = abs(rainflow_SOCs[end-1]-rainflow_SOCs[end-2])
        if newDOD >= prevDOD
            push!(DODs, prevDOD)
            push!(∅SOCs, (rainflow_SOCs[end-1]+rainflow_SOCs[end-2])/2)
            deleteat!(rainflow_SOCs, [length(rainflow_SOCs)-2, length(rainflow_SOCs)-1])
        else
            break
        end
    end

    return DODs[end:-1:1], ∅SOCs[end:-1:1], rainflow_SOCs
end
end
