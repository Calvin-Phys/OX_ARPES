function NEW_DATA = ox_remove_background(ARPES_DATA, enrgy_ints_dst, q0)
        ARPES_DATA.validate();
        validateattributes(q0, {'numeric'}, {'scalar','real','finite'});
        
        data = ARPES_DATA;
        eid = enrgy_ints_dst;

        [~, idx] = min(abs(eid.info.eid_q - q0));
        NEW_DATA = data;

        if isa(data,'OxArpes_2D_Data')
                bkgd = repmat(eid.info.eid_bkgd(:,idx),1,length(data.x));
                NEW_DATA.value = NEW_DATA.value - bkgd';
        elseif isa(data,'OxArpes_3D_Data')
                if ndims(eid.info.eid_bkgd) == 3
                    % Photon-energy-specific background: (hv, E, q).
                    bkgd = eid.info.eid_bkgd(:,:,idx);
                    bkgd = reshape(bkgd, size(bkgd,1), 1, size(bkgd,2));
                    NEW_DATA.value = NEW_DATA.value - bkgd;
                else
                    % One background curve shared by all x/y positions.
                    bkgd = reshape(eid.info.eid_bkgd(:,idx),1,1,[]);
                    NEW_DATA.value = NEW_DATA.value - bkgd;
                end
        else
            error('OxArpes:UnsupportedDimension', ...
                'Background removal supports only 2-D or 3-D OX data objects.');
        end

        NEW_DATA.value(NEW_DATA.value<0) = 0;

end

