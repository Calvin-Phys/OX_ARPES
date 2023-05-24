function WF = get_beamline_workfunction(location,hv,pe)

    switch location
        case {'MAXIV','Bloch','MAXIV_Bloch'}
            x = [25 50 60 110 160 170];
            y = [4.3907 4.4095 4.4133 4.4667 4.5164 4.5193];
            WF = interp1(x,y,hv,'spline','extrap'); 
        otherwise
            WF = 4.5; 
    end

end

