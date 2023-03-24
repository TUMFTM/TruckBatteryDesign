clearvars
close all
clc

addpath(genpath(cd))

%Contact: olaf.teichert@tum.de

%% Read data

Umin = 2.5; %Voltage limit for detecting CV phase
Umax = 4.2; %Voltage limit for detecting CV phase

data_0 = load('Input\VW_78Ah_1828_HPPC_3C_9steps_0deg.mat');
data_20 = load('Input\VW_78Ah_1794_HPPC_3C_9steps_20deg.mat');
data_40 = load('Input\VW_78Ah_1856_HPPC_3C_9steps_40deg.mat');

Ts = [0, 20, 40]; %Temperatures
Crates = [-2, -1, -0.5, 0.5, 1, 2]; %Crates
pulselines = [57, 47, 37, 32, 42, 52]; %Crate line numbers
SOCs = 10:10:90; %SOC test points
cycles = 1:9; %SOC cycle numbers
ts = [0.001, 0.02, 0.1, 1, 5, 10, 30]; %Pulse durations at which to determine the resistance

%% Extract pulse resistances from measurement
R = zeros(length(Ts), length(SOCs), length(Crates), length(ts));
tpulse = cell(length(Ts), length(SOCs), length(Crates));
Rpulse = cell(length(Ts), length(SOCs), length(Crates));
for i = 1:length(Ts)
    Dataset = eval(sprintf('data_%.0f.Dataset', Ts(i)));
    for j = 1:length(SOCs)
        for k = 1:length(Crates)
            t_pulse_raw = Dataset.Timeh(Dataset.Line==pulselines(k) & Dataset.CycCount == cycles(j));
            t_pulse = 3600*(t_pulse_raw-t_pulse_raw(1));
            I_pulse = Dataset.IA(Dataset.Line==pulselines(k) & Dataset.CycCount == cycles(j));
            U_pulse = Dataset.UV(Dataset.Line==pulselines(k) & Dataset.CycCount == cycles(j));
            
            if any(U_pulse<Umin | U_pulse>Umax)
                R(i,j,k,:) = NaN;
                fprintf("CV phase detected for %.0f°C, %2.0f%% SOC at %.1f C\n", Ts(i), SOCs(j), Crates(k))
            else
                R_pulse = (U_pulse(1)-U_pulse)./(I_pulse(1)-I_pulse);
                R(i,j,k,:) = interp1(t_pulse,R_pulse,ts,'nearest');
                tpulse{i,j,k} = t_pulse;
                Rpulse{i,j,k} = R_pulse;
            end
        end
    end
end

%% Fit ECM with 1RC element
oneRC_fit = fittype(@(R0,R1,C1,x) R0+R1*(1-exp(-x/R1/C1)));
i_crates = [3,4]; %-0.5C and 0.5C
R0 = zeros(length(Ts), length(SOCs), length(i_crates));
R1 = zeros(length(Ts), length(SOCs), length(i_crates));
C1 = zeros(length(Ts), length(SOCs), length(i_crates));
Rsq = zeros(length(Ts), length(SOCs), length(i_crates));
for i=1:length(Ts)
    for j=1:length(SOCs)
        for k=1:length(i_crates)
            tmeas = tpulse{i,j,i_crates(k)}(2:end);
            Rmeas = 1000*Rpulse{i,j,i_crates(k)}(2:end);
            [fitted_curve,gof] = fit(tmeas,Rmeas,oneRC_fit, ...
                'StartPoint',[1 1 25], ...
                'lower',[0 0 0], ...
                'upper', [5, 5, inf]);
            coeffvals = coeffvalues(fitted_curve);
            R0(i,j,k) = coeffvals(1)/1000;
            R1(i,j,k) = coeffvals(2)/1000;
            C1(i,j,k) = coeffvals(3)*1000;
            Rsq(i,j,k) = gof.rsquare;
        end
    end
end

Rtot = R0+R1; %Assymptotic resistance in mOhm
tRC = R1.*C1; %RC time in seconds

%% Save results
writematrix(Rsq(:,:,1), "Results\Rsq_dch.csv")
writematrix(R0(:,:,1), "Results\R0_dch.csv")
writematrix(R1(:,:,1), "Results\R1_dch.csv")
writematrix(C1(:,:,1), "Results\C1_dch.csv")
writematrix(Rtot(:,:,1), "Results\Rtot_dch.csv")
writematrix(tRC(:,:,1), "Results\tRC_dch.csv")
writematrix(Rsq(:,:,2), "Results\Rsq_ch.csv")
writematrix(R0(:,:,2), "Results\R0_ch.csv")
writematrix(R1(:,:,2), "Results\R1_ch.csv")
writematrix(C1(:,:,2), "Results\C1_ch.csv")
writematrix(Rtot(:,:,2), "Results\Rtot_ch.csv")
writematrix(tRC(:,:,2), "Results\tRC_ch.csv")

%% Generate plots

%Plot pulse
preoffset = 5;
postoffset = 1000;
interval = 1;
i1 = find(data_20.Dataset.Line==37 & data_20.Dataset.CycCount == 5, 1); %Start of pulse
i2 = find(data_20.Dataset.Line==37 & data_20.Dataset.CycCount == 5, 1, 'last'); %End of pulse
t = (data_20.Dataset.Timeh(i1-preoffset:interval:i2+postoffset)-data_20.Dataset.Timeh(i1))*3600; %Pulse duration
I = data_20.Dataset.IA(i1-preoffset:interval:i2+postoffset);
U = data_20.Dataset.UV(i1-preoffset:interval:i2+postoffset);

figure
hold on
plot(t,I)
xlabel("Time in seconds")
ylabel("Current in Ampere")
grid on
yyaxis right
plot(t,U)
ylabel("Voltage in V")

%Plot fit
tsim = 0:30;
Rsim = R0(2, 5, 1)+R1(2, 5, 1)*(1-exp(-tsim/R1(2, 5, 1)/C1(2, 5, 1)));

figure
hold on
plot(tpulse{2, 5, 3}, 1000*Rpulse{2, 5, 3})
plot(tsim,1000*Rsim)
xlabel("Time in seconds")
ylabel("Resistance in mOhm")
legend(["Measurement", "Fit"], 'Location', 'northwest')
text(15, 1.4, "R^2: " + num2str(Rsq(2, 5, 1)))
title("1RC fit at 20°C, 50% SOC and -0.5C")

%Countourplots
figure
contourf(SOCs,Ts, 1000*R0(:,:,1))
xlabel("SOC in %")
ylabel("Temperature in °C")
c = colorbar;
ylabel(c,'R0 in mOhm')

figure
contourf(SOCs,Ts, 1000*R0(:,:,2))
xlabel("SOC in %")
ylabel("Temperature in °C")
c = colorbar;
ylabel(c,'R0 in mOhm')

figure
contourf(SOCs,Ts, 1000*R1(:,:,1))
xlabel("SOC in %")
ylabel("Temperature in °C")
c = colorbar;
ylabel(c,'R1 in mOhm')

figure
contourf(SOCs,Ts, 1000*R1(:,:,2))
xlabel("SOC in %")
ylabel("Temperature in °C")
c = colorbar;
ylabel(c,'R1 in mOhm')

figure
contourf(SOCs,Ts, C1(:,:,1)/1000)
xlabel("SOC in %")
ylabel("Temperature in °C")
c = colorbar;
ylabel(c,'C1 in kF')

figure
contourf(SOCs,Ts, C1(:,:,2)/1000)
xlabel("SOC in %")
ylabel("Temperature in °C")
c = colorbar;
ylabel(c,'C1 in kF')

figure
contourf(SOCs,Ts, Rsq(:,:,1))
title("1RC Discharge fit")
xlabel("SOC in %")
ylabel("Temperature in °C")
c = colorbar;
ylabel(c,'R^2')

figure
contourf(SOCs,Ts, Rsq(:,:,2))
title("1RC Charge fit")
xlabel("SOC in %")
ylabel("Temperature in °C")
c = colorbar;
ylabel(c,'R^2')
