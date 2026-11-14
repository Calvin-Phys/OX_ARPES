function DP0 = ox_energy_intensity_distribution(ARPES_DATA)
%PLOT_DISTRIBUTION_PROFILE Summary of this function goes here
%   Detailed explanation goes here
    q = 0.05:0.1:0.95;
    Num_bin = 200;
    smooth_rangde = 5;

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

    if isa(ARPES_DATA,'OxArpes_3D_Data')
        Eaxis = ARPES_DATA.z;
        NN = zeros(length(Eaxis),Num_bin);
        lowerbound = nan(length(Eaxis),length(q));
        for i=1:length(Eaxis)
            slice = double(ARPES_DATA.value(:,:,i));
            NN(i,:) = histcounts(slice(isfinite(slice)),edges);

            lowerbound(i,:) = finite_quantiles(slice,q);
        end
        
    elseif isa(ARPES_DATA,'OxArpes_2D_Data')
        Eaxis = ARPES_DATA.y;
        NN = zeros(length(Eaxis),Num_bin);
        lowerbound = nan(length(Eaxis),length(q));

        for i=1:length(Eaxis)
            slice = double(ARPES_DATA.value(:,i));
            NN(i,:) = histcounts(slice(isfinite(slice)),edges);

            lowerbound(i,:) = finite_quantiles(slice,q);
        end

    end

    lowerbound_sm = movmean(lowerbound,smooth_rangde,1);

    % Treat exact zero as padding by clearing only the bin containing zero.
    zeroBin = find(edges(1:end-1) <= 0 & edges(2:end) > 0,1);
    if ~isempty(zeroBin)
        NN(:,zeroBin) = 0;
    else
        error('OxArpes:UnsupportedDimension', ...
            'Energy--intensity distributions support only 2-D and 3-D OX data objects.');
    end

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

function values = finite_quantiles(data,q)
    sorted = sort(double(data(isfinite(data))));
    values = nan(1,numel(q));
    if isempty(sorted)
        return
    end
    for iQ = 1:numel(q)
        index = max(1,min(numel(sorted),round(q(iQ)*numel(sorted))));
        values(iQ) = sorted(index);
    end
end

