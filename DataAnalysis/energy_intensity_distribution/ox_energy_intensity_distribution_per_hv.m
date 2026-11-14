function DP0 = ox_energy_intensity_distribution_per_hv(ARPES_DATA)
%PLOT_DISTRIBUTION_PROFILE Summary of this function goes here
%   Detailed explanation goes here
    q = 0.05:0.1:0.95;
    Num_bin = 200;
    smooth_rangde = 5;

    if ~isa(ARPES_DATA,'OxA_KZ')
        error('OxArpes:InvalidDataType', 'Input must be an OxA_KZ object.');
    end
    ARPES_DATA.validate();

    finiteValues = double(ARPES_DATA.value(isfinite(ARPES_DATA.value)));
    if isempty(finiteValues)
        error('OxArpes:NoFiniteIntensity', 'Input data contain no finite intensity values.');
    end
    V_min = min(finiteValues);
    V_max = max(finiteValues);
    if V_min == V_max
        delta = max(1,abs(V_min))*eps*16;
        V_min = V_min-delta;
        V_max = V_max+delta;
    end
    edges = linspace(V_min,V_max,Num_bin+1);
    Eaxis = ARPES_DATA.z;
    NN = zeros(length(ARPES_DATA.x),Num_bin,length(Eaxis));
    lowerbound = zeros(length(ARPES_DATA.x), length(Eaxis), length(q));

    for hv_idx = 1:length(ARPES_DATA.x)

        for i=1:length(Eaxis)
            slice = double(ARPES_DATA.value(hv_idx,:,i));
            NN(hv_idx,:,i) = histcounts(slice(isfinite(slice)),edges);

            n_data = sort(slice(isfinite(slice)));
            for j = 1:length(q)
                if ~isempty(n_data)
                    lowerbound(hv_idx,i,j) = n_data(max(1, min(length(n_data), round(q(j) * length(n_data)))));
                else
                    lowerbound(hv_idx,i,j) = NaN;
                end
            end
        end
        
    end

    lowerbound_sm = movmean(lowerbound,smooth_rangde,2);

    zeroBin = find(edges(1:end-1) <= 0 & edges(2:end) > 0,1);
    if ~isempty(zeroBin)
        NN(:,zeroBin,:) = 0;
    end

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

