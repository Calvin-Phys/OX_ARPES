vars = evalin('base','who');

columnNames = {'Name' 'Type' 'Hv' 'Polarisation' 'PassEnergy' 'Mode' 'Temperature'};
data = cell(length(vars),7);
for i = 1:length(vars)
    var = evalin('base',vars{i});
    data{i,1} = vars{i};
    data{i,2} = class(var);
    try
        data{i,3} = var.info.photon_energy;
        data{i,4} = var.info.polarization;
        data{i,5} = var.info.pass_energy;
        data{i,6} = var.info.acquisition_mode;
        data{i,7} = var.info.temperature;
    catch
    end
    
end
results = cell2table(data);
results.Properties.VariableNames = columnNames;
