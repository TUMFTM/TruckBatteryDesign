module ControlAlgorithm
export control

const Theat = 15 #Threshold at which heating is switched on and off 
const Pheater = 800 #Installed heating power

function control(Pdem, Pmin, Pmax, T, Cooling_on, ncells, Pcooler, Tcool_on, Tcool_off)
    
    #When the vehicle is parked without a charger, the BTMS is switched off
    if Pdem == 0
        Cooling_on = false
        Heating_on = false
    else
        #Switch cooling on and off
        if T>Tcool_on
            Cooling_on = true
        elseif T<Tcool_off
            Cooling_on = false
        else
            Cooling_on = Cooling_on
        end

        #Switch heating on
        if T<Theat
            Heating_on = true
        else
            Heating_on = false
        end
    end

    #Limit cell power to power limits
    Pcool = Cooling_on*Pcooler
    Pheat = Heating_on*Pheater
    Pcell = clamp((Pdem-Pheat-Pcool)/ncells, Pmin, Pmax)

    return Pcell, Pcool, Pheat, Cooling_on
end
end
