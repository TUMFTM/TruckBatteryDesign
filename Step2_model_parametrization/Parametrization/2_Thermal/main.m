close all
clearvars
clc

addpath(genpath(cd))

VW = load('VW_ID3.mat');

%% Postprocessing
Tmin = timeseries(VW.Tmin.Data(VW.Pbat.Data==0), VW.Tmin.Time(VW.Pbat.Data==0)-VW.Tmin.Time(find(VW.Pbat.Data==0,1)));
Tmax = timeseries(VW.Tmax.Data(VW.Pbat.Data==0), VW.Tmax.Time(VW.Pbat.Data==0)-VW.Tmin.Time(find(VW.Pbat.Data==0,1)));
i_Ta = find(VW.Ta.Time<VW.Ta.Time(end)-Tmin.Time(end),1,'last');
Ta = timeseries(VW.Ta.Data(i_Ta:end), VW.Ta.Time(i_Ta:end)-VW.Ta.Time(i_Ta));

%% Fancy Curve fit
Tmeas = timeseries(mean([Tmin.Data, Tmax.Data],2), Tmin.Time); %Average measured temperature
mcell = 1.101; %Cell weight in kg [Wassiliadis et al.]
ncells = 2*108; %2p108s configuration [Wassiliadis et al.]
cp_cell = 1045; %Cell specific heat capacity J/kg/K [Average of NMC/C pouch cells reported by Steinhardt et al.]
mhousing = 125; %Mass of non-cell battery components in kg [Wassiliadis et al.]
cp_Alu = 896; %Specific heat capacity of aluminium [Lienhardt]
c = mcell*ncells*cp_cell + mhousing*cp_Alu; %Estimated heat capacity J/K
k = fminsearch(@(k) 1-myfit(Tmeas, Ta, k, c),11); 
Rsq = myfit(Tmeas, Ta, k, c); 
disp("Heat transfer coefficient: " + k + " W/K")
%% Plot curve fit
Tsim = TM(Tmeas, Ta, k, c);

figure
hold on
plot(Ta)
plot(Tmin)
plot(Tmax)
plot(Ta.Time, Tsim)
title("VW ID.3")
legend(["Ambient", "Tmin", "Tmax", "Tfit"], "Location", "southeast")
xlabel("Time in hours")
ylabel("Temperature in °C")

%% Functions
function Rsq = myfit(Tmeas, Ta, k, c)
    Tsim = TM(Tmeas, Ta, k,c);
    Tsim_intp = interp1(Ta.Time, Tsim, Tmeas.Time);
    Rsq = 1-sum((Tmeas.Data-Tsim_intp).^2)/sum((Tmeas.Data-mean(Tmeas.Data)).^2);
end

function Tsim = TM(Tmeas, Ta, k, c)
    Tsim = zeros(size(Ta.Data));
    Tsim(1) = Tmeas.Data(1);
    for i = 1:length(Ta.Data)-1
        Tsim(i+1) = Tsim(i) + (Ta.Data(i)-Tsim(i))*3600*(Ta.Time(i+1)-Ta.Time(i))*k/c;
    end
end
