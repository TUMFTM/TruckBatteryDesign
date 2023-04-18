# Battery design for battery-electric long-haul trucks

This repository provides the source-code to a five-step battery design method for battery-electric long-haul trucks. The method and results are documented in the dissertation by Olaf Teichert entitled "Battery design for battery-electric long-haul trucks". The five steps are: 
  - Cell selection
  - Battery model parametrization and validation
  - Power profile generation
  - Battery life simulation
  - Battery thermal management system design

## Cell selection

To reach cost-parity with diesel trucks, battery-electric trucks require fast-chargeable lithium-ion cells with a high energy density and cycle life, at a low specific cost. However, cells generally excel at only a fraction of these characteristics. To help select the optimal cell, I developed the techno-economic cell selection method. The folder "Step1_cell_selection" contains the source code to the method, which I used to select the optimal cell out of a database containing over 160 cells for a long-haul truck operating with a single driver in Germany. 

To run the code, you'll need a python distribution with the following packages: 
  - pandas
  - numpy
  - scipy
  - numba
  - matplotlib

The results and all figures are generated by executing the file main.py. The execution time on a 16GB RAM, 1.8GHz machine is less than 30 seconds.

## Battery model

To obtain a better estimate of the battery life for the selected cell under typical truck operating conditions, a battery model of the VW ID.3 is parametrized and validated on vehicle level. 

### Parametrization

The electric, thermal and aging components of the model are parametrized separately. To parametrize the electric model, the following open-source measurements need to be downloaded from https://doi.org/10.14459/2022mp1656314 and copied into the folder "Step2_model_parametrization\Parametrization\1_Electric\Input": 
- Data\02_Battery\04_OCV\VW_78Ah_1964_pOCV_C40_20deg.mat
- Data\02_Battery\06_HPPC\VW_78Ah_1828_HPPC_3C_9steps_0deg.mat
- Data\02_Battery\06_HPPC\VW_78Ah_1794_HPPC_3C_9steps_20deg.mat
- Data\02_Battery\06_HPPC\VW_78Ah_1856_HPPC_3C_9steps_40deg.mat

Subsequently, the matlab scripts "OCV.m" and "Resistance.m" can be executed to generate the ECM parametrization. Executing the scripts requires a matlab installation with the curve fitting toolbox. 

The curve fit of the thermal heat transfer to ambient is found by running the script "Step2_model_parametrization\Parametrization\2_Thermal\main.m". The aging model is parametrized by scaling an existing aging model with the same anode and cathode cell chemistry. The scaling factor is found using the "GRG Nonlinear" solver provided by excel. This solver needs to be added to the standard excel installation under "File -> Options -> Add-ins -> Solver Add-in". The solver is then availble under "Data/Analyze/Solver" and can be used to find the scaling factor in cells AB8 and AB12 that maximize the coefficient of determination in cells AD9 and AD13. 

### Validation

The obtained results from the electric parametrization must now be copied from "Step2_model_parametrization\Parametrization\1_Electric\Results" to "Step2_model_parametrization\Model\Inputs". The obtained heat transfer coefficient and the scaling coefficients of the aging model are already included in the model parametrization. 

The obtained model is validated using open-source measurements on vehicle level published by https://doi.org/10.14459/2022mp1656314. The following files need to be downloaded and saved to "Step2_model_parametrization\Validation\Inputs\Profiles": 
- Data\03_Vehicle\04_Charging_sequences\Fast_charging_0-100_VW_warm.csv
- Data\03_Vehicle\04_Charging_sequences\Wallbox_charging_0-100_VW_11kw.csv
- Data\03_Vehicle\06_Cycles\03_RealWorld_Driving\Real_driving_15deg\Highway_15deg.csv
- Data\03_Vehicle\06_Cycles\03_RealWorld_Driving\Real_driving_15deg\Interurban_15deg.csv
- Data\03_Vehicle\06_Cycles\03_RealWorld_Driving\Real_driving_15deg\Urban_15deg_part1.csv
- Data\03_Vehicle\06_Cycles\03_RealWorld_Driving\Real_driving_15deg\Urban_15deg_part2.csv
- Data\03_Vehicle\06_Cycles\03_RealWorld_Driving\Real_driving_30deg\Highway_30deg.csv
- Data\03_Vehicle\06_Cycles\03_RealWorld_Driving\Real_driving_30deg\Interurban_30deg.csv
- Data\03_Vehicle\06_Cycles\03_RealWorld_Driving\Real_driving_30deg\Urban_30deg_part1.csv
- Data\03_Vehicle\06_Cycles\03_RealWorld_Driving\Real_driving_30deg\Urban_30deg_part2.csv

To reduce the measurements to the relevant properties and concatenate the data from the two measurements with the urban speed profile the script "Step2_model_parametrization\Validation\Inputs\Profiles\postprocess_measurements.m" needs to be executed, which requires a matlab distribution. 

Finally, the results from the parametrized model and the measurements can be compared by running the script "Step2_model_parametrization\Validation\main.jl". Running the software requires a Julia distribution version 1.6.5 or above and the following packages: 
  - DelimitedFiles
  - Statistics
  - Interpolations
  - JLD
  - Plots
  - DataFrames
  - StatsPlots

The execution time on a 16GB RAM, 1.8GHz machine is less than 2 minutes. To generate a violinplot that compares all the results, the script "Step2_model_parametrization\Validation\violinplots.py" can be used, requiring a python distribution. Generating the violinplots takes about 1 minute. To inspect simulation errors for a specific cycle, the LaTeX-script "Step2_model_parametrization\Validation\LaTeX\Standalone.tex" generates a detailed plot optimized for powerpoint.  

## Power profile generation

To estimate battery life and safety under typical truck operating conditions, a power profile is required. The power profile should represent the typical power demand (driving) and supply (charging and regeneration) for battery-electric trucks. The code in the folder "Step3_power_profile" can be used to generate an annual load profile for battery-electric trucks, based on the method developed by Gaete-Morales et al. (An open tool for creating battery-electric vehicle time series from empirical data, emobpy). 

Running the software requires a python distribution with the following packages: 
  - numpy
  - numba
  - scipy
  - pandas
  - pickle

The power profile is generated by executing the main.py script. The execution time on a 16GB RAM, 1.8GHz machine is less than 15 minutes.

## Batterylife simulation

Based on the validated battery model and the generated power profile, the lifetime of the truck battery under typical operating conditions can be simulated. First, the generated loadprofile "Loadprofile_Truck.csv" needs to be copied from "Step3_power_profile\results" to "Step4_lifetime_simulation\Inputs". Subsequently, running the script "Step4_lifetime_simulation\main.jl" simulates battery operation over lifetime for the Munich ambient temperature. The execution time on a 16GB RAM, 1.8GHz machine is less than 2 minutes. Note that the results might differ slightly due to the stochastic nature of the load profile.

## Battery thermal management system design

In the last step of the battery design method, the impact of the battery thermal management system on the battery life and battery safety is investigated. Running the script "Step5_btms_design\main.jl" executes full factorial simulations of the impact of the installed cooling power and cooling threshold. The execution time on a 16GB RAM, 1.8GHz machine is less than 3 hours.