module ThermalModel
using Interpolations
using Cell
export thermalmodel

## constants
const cp_alu = 896 #Specific heat capacity of 6061-T6 Aluminum at 20°C in J/kg/K [Lienhard et al. A heat transfer textbook p.714]
const m_sens = 0.1#Mass of temperature sensors and peripherie [Assumption]
const C_s = cp_alu*m_sens #Heat capacity of temperature sensors
const COPheat = 4 #Heat pump [Schimpe et al.]
const COPcool = -3 #Cooling system [Schimpe et al.]
const Rc2s = 0.578 # Thermal resistance between the cell and the sensor in K/W [Alastair]
const Rc2h = 0.899 # Thermal resistance between the cell and the housing in K/W [Alastair]
const Rs2h = 2.151 # Thermal resistance between the sensor and the housing in K/W [Alastair]

function thermalmodel(Ta, Tc, Th, Ts, Ploss, Pcool, Pheat, ncells, k_out, C_housing, dt)

    #Cell temperature
    Tc_new = Tc + (Ploss + (Ts-Tc)/Rc2s + (Th-Tc)/Rc2h)*dt/Cell.C_cell

    #Temperature sensor
    Ts_new = Ts + ((Tc-Ts)/Rc2s + (Th-Ts)/Rs2h)*dt/C_s

    #Housing temperature
    Th_new = Th + (Pcool*COPcool + Pheat*COPheat + (Ts-Th)/Rs2h*ncells + (Tc-Th)/Rc2h*ncells + k_out*(Ta-Th))*dt/C_housing

    return Tc_new, Th_new, Ts_new
end
end
