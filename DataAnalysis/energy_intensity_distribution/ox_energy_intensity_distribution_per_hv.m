function DP0 = ox_energy_intensity_distribution_per_hv(ARPES_DATA)
%PLOT_DISTRIBUTION_PROFILE Summary of this function goes here
%   Detailed explanation goes here
    q = 0.05:0.1:0.95;
    Num_bin = 200;
    smooth_rangde = 5;

    if ~isa(ARPES_DATA,'OxA_KZ')
        return
    end

    V_max = max(ARPES_DATA.value,[],"all");
    edges = linspace(0,V_max,Num_bin+1);
    Eaxis = ARPES_DATA.z;
    NN = zeros(length(ARPES_DATA.x),Num_bin,length(Eaxis));
    lowerbound = zeros(length(ARPES_DATA.x), length(Eaxis), length(q));

    for hv_idx = 1:length(ARPES_DATA.x)

        for i=1:length(Eaxis)
            NN(hv_idx,:,i) = histcounts(ARPES_DATA.value(hv_idx,:,i),edges);

            n_data = sort(reshape(ARPES_DATA.value(hv_idx,:,i),1,[]));
            for j = 1:length(q)
                lowerbound(hv_idx,i,j) = n_data(max(1, min(length(n_data), round(q(j) * length(n_data)))));
            end
        end
        
    end

    lowerbound_sm = movmean(lowerbound,smooth_rangde,2);

    % clear zeros
    NN(:,1,:) = 0;

    DP.x = ARPES_DATA.x;
    DP.y = edges(1:end-1);
    DP.z = Eaxis;
    DP.value = NN;
    DP0 = OxArpes_3D_Data(DP);
    DP0.name = 'eid';
    DP0.info = ARPES_DATA.info;
    DP0.info.eid_q = q;
    DP0.info.eid_nb = Num_bin;
    DP0.info.eid_sm = smooth_rangde;
    DP0.info.eid_bkgd = lowerbound_sm;

    DP0.x_name = 'hv';
    DP0.x_unit = 'eV';
    DP0.y_name = 'Intensity';
    DP0.y_unit = 'a.u.';
    DP0.z_name = 'Energy';
    DP0.z_unit = 'eV';

end

