function DP0 = ox_energy_intensity_distribution(ARPES_DATA)
%PLOT_DISTRIBUTION_PROFILE Summary of this function goes here
%   Detailed explanation goes here
    q = 0.05:0.1:0.95;
    Num_bin = 200;
    smooth_rangde = 5;

    V_max = max(ARPES_DATA.value,[],"all");
    edges = linspace(0,V_max,Num_bin+1);

    if ndims(ARPES_DATA.value) == 3
        Eaxis = ARPES_DATA.z;
        NN = zeros(length(Eaxis),Num_bin);
        for i=1:length(Eaxis)
            NN(i,:) = histcounts(ARPES_DATA.value(:,:,i),edges);

            n_data = sort(reshape(ARPES_DATA.value(:,:,i),1,[]));
            for j = 1:length(q)
                lowerbound(i,j) = n_data(round(q(j) *length(n_data)));
            end
        end
        
    else % ndims(ARPES_DATA.value) == 2
        Eaxis = ARPES_DATA.y;
        NN = zeros(length(Eaxis),Num_bin);

        for i=1:length(Eaxis)
            NN(i,:) = histcounts(ARPES_DATA.value(:,i),edges);

            n_data = sort(reshape(ARPES_DATA.value(:,i),1,[]));
            for j = 1:length(q)
                lowerbound(i,j) = n_data(round(q(j) *length(n_data)));
            end
        end

    end

    lowerbound_sm = movmean(lowerbound,smooth_rangde,1);

    % clear zeros
    NN(:,1) = 0;

    DP.x = edges(1:end-1);
    DP.y = Eaxis;
    DP.value = NN';
    DP0 = OxArpes_2D_Data(DP);
    DP0.name = 'eid';
    DP0.info = ARPES_DATA.info;
    DP0.info.eid_q = q;
    DP0.info.eid_nb = Num_bin;
    DP0.info.eid_sm = smooth_rangde;
    DP0.info.eid_bkgd = lowerbound_sm;

    DP0.x_name = 'Intensity';
    DP0.x_unit = 'a.u.';
    DP0.y_name = 'Energy';
    DP0.y_unit = 'eV';

end

