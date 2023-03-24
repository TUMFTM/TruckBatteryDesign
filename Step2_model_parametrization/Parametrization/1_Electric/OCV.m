clearvars
close all
clc

addpath(genpath(cd))

%% Generate OCV Curve

load("Input\VW_78Ah_1964_pOCV_C40_20deg.mat")

Uc = Dataset.U(Dataset.Line==5); %1/50C charge voltage
Ud = Dataset.U(Dataset.Line==4); %1/50C discharge voltage
Qc = abs(Dataset.AhStep(find(Dataset.Line==5,1,'last'))); %Capacity in charge direction
Qd = abs(Dataset.AhStep(find(Dataset.Line==4,1,'last'))); %Capacity in discharge direction
SOCc = Dataset.AhStep(Dataset.Line==5)/Qc; %Charge SOC
SOCd = 1+Dataset.AhStep(Dataset.Line==4)/Qd; %Discharge SOC

SOC = 0:0.01:1; %SOC values of HPPC tests
Uc_int = interp1(SOCc,Uc,SOC); %Interpolate charge voltage to SOC values of HPPC test
Ud_int = interp1(SOCd,Ud,SOC); %Interpolate discharge voltage to SOC values of HPPC test
Uocv = mean([Uc_int; Ud_int], "omitnan"); %Calculate OCV voltage at SOC values of HPPC test

%% Generate plot

figure
hold on
plot(SOC*100, Uc_int)
plot(SOC*100, Ud_int)
plot(SOC*100, Uocv)
xlabel("SOC in %")
ylabel("Voltage in V")
ylim([0, 4.5])
legend(["1/40C Charge", "1/40C Discharge", "Open-Circuit Voltage"], 'Location','best')
grid on

%% Save to file
writematrix(Uocv, "Results/Uocv.csv")
