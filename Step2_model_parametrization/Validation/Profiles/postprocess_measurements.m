clearvars
close all
clc

addpath(genpath(cd))

%% Export files

filenames = ["Wallbox_charging_0-100_VW_11kw", "Fast_charging_0-100_VW_warm", ...
            "Highway_30deg", "Highway_15deg",... 
            "Interurban_30deg", "Interurban_15deg",...
            "Urban_30deg", "Urban_15deg"];

for i=1:length(filenames)
    disp("Exporting "+filenames(i))
    export_data(filenames(i))
end

%% Export function
function export_data(filename)
    
    filename_char = char(filename);
    if filename_char(1:5) == "Urban" %Concatenate urban profiles
        load(filename+"_part1.mat")
        data1 = array2table(data, "VariableNames", cellstr(columns));
        data1.hv_battery_current(end) = 0;
        load(filename+"_part2.mat")
        data2 = array2table(data, "VariableNames", cellstr(columns));
        data2.hv_battery_current(1) = 0;
        data = [data1; data2];
    else
        load(filename+".mat")
        data = array2table(data, 'VariableNames', cellstr(columns));
    end
    
    %Remove too long logging data from wallbox charge
    if filename == "Wallbox_charging_0-100_VW_11kw"
        data = data(1:197167,:);
    end

    %cell voltages
    U = zeros(108, height(data));
    for i=1:108 
        U(i,:) = eval(sprintf("data.cell_voltage_%d",i));
    end

    %pack temperatures
    Temp = zeros(18, height(data));
    for i=1:18 
        Temp(i,:) = eval(sprintf("data.pack_temp_%d",i));
    end

    %Reduce filesize by limiting data to data of interest
    data_lean = table();
    data_lean.t = data.time;
    data_lean.soc = data.hv_soc;
    data_lean.Umin = min(U)';
    data_lean.Umax = max(U)';
    data_lean.Umean = mean(U,'omitnan')';
    data_lean.I = data.hv_battery_current;
    data_lean.Tmin = min(Temp)';
    data_lean.Tmax = max(Temp)';
    data_lean.Tmean = mean(Temp)';
    data_lean.Tcoolant = data.hv_battery_temp_inlet;
    data_lean.P = data.hv_battery_current.*data_lean.Umean.*108;
    if ismember("ambient_air_temp", data.Properties.VariableNames)
        data_lean.Ta = data.ambient_air_temp;
    end
    
    %Drop lines missing power
    data_lean = data_lean(~ismissing(data_lean.P),:);
    
    %write to csv
    writetable(data_lean,filename+".csv")
end