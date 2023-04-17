module ElectricModel
using Cell
export powerlim, electricmodel

const SOC_max = 0.97 # Lower SOC limit [ID3 Paper]
const SOC_min = 0.041 # Lower SOC limit [ID3 Paper]

## Functions
function electricmodel(Pcell, Uocv, Q, R0, R1, C1, SOC, V1, dt)
    
    #Equivalent circuit model with one RC elements
    Ibat = (-(Uocv+V1)+sqrt((Uocv+V1)^2+4R0*Pcell))/2R0 #Cell current in A
    Crate = Ibat/Q #Cell C-rate in 1/h
    ΔV = Ibat*R0+V1 #Voltage drop over impedance
    Ploss = Ibat*ΔV #Generated ohmic losses in W
    Vcell = Uocv+ΔV #Cell terminal voltage
    SOC_new = SOC + Crate*dt/3600 #New cell SOC in pu
    V1_new = V1+(Ibat/C1-V1/R1/C1)*dt

    return Crate, Ploss, SOC_new, V1_new, Vcell, Ibat
end

function powerlim(Uocv, R0, V1, Q, SOC, dt)
    #Discharging power limit
    Imin_SOC = min(0,(SOC_min-SOC)*3600*Q/dt) #Current limit based on minimum SOC
    Imin_V = (Cell.Umin-Uocv-V1)/R0 #Current limit based on minimum voltage
    Imin = max(Imin_V, Imin_SOC, Cell.Imin_cont) #Discharge current limit
    Pmin = (Uocv+V1+R0*Imin)*Imin #Discharge power limit

    #Charging power limit
    Imax_SOC = max(0,(SOC_max-SOC)*3600*Q/dt) #Current limit based on maximum SOC
    Imax_V = (Cell.Umax-Uocv-V1)/R0 #Current limit based on maximum voltage
    Imax = min(Imax_V, Imax_SOC, Cell.Imax_cont) #Charge current limit
    Pmax = (Uocv+V1+R0*Imax)*Imax #Charge power limit

    return Pmin, Pmax
end
end
