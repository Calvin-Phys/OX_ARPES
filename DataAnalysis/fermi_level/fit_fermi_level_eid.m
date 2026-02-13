data = A035_Ni3In2S2_3_cali_ksp_eid;

E = data.y;
I = data.info.eid_bkgd;

results = repmat(fit_fermi_edge_ox([],[]),1,length(data.info.eid_q));
for i=1:length(data.info.eid_q)
    results(i) = fit_fermi_edge_ox(data.y,data.info.eid_bkgd(:,i), ...
        'Temperature', data.info.temperature, ...
        'Resolution', 0.05,...
        'FitWindow',0.2,...
        'FixTemperature', true,...
        'FixResolution', false,...
        'Debug', false);
end

% plot
data.show();
hold on
for i = 1:size(data.info.eid_bkgd,2)
    plot(data.info.eid_bkgd(:,i),data.y);
    I_EF = interp1(data.y,data.info.eid_bkgd(:,i),results(i).EF,"linear");
    scatter(I_EF,results(i).EF);
end

