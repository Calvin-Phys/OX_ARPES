function WF = get_beamline_workfunction(location,exp_date,hv,pass_energy)

    switch location
        case {'MAXIV','Bloch','MAXIV_Bloch'}
            if year(exp_date) < 2024
                x = [25 50 60 110 160 170];
                y = [4.3907 4.4095 4.4133 4.4667 4.5164 4.5193];
            else
                % x = [60 68 88 109 136 163 210 710];
                % y = [4.18 4.188 4.203 4.237 4.259 4.3 4.3 7.1];
                x = [60 210];
                y = [4.36 4.36];

            end
            WF = interp1(x,y,hv,'spline','extrap'); 

        case {'Cassiopee'}
            WF = 4.21;
        case {'SLS-SIS'}
            WF = 4.454;
        case {'1square'}
            WF = 4.5;
        otherwise
            WF = 4.44; 
    end

end

