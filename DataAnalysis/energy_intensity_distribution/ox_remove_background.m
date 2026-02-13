function NEW_DATA = ox_remove_background(ARPES_DATA, enrgy_ints_dst, q0)
        
        data = ARPES_DATA;
        eid = enrgy_ints_dst;

        [~, idx] = min(abs(eid.info.eid_q - q0));
        NEW_DATA = data;

        switch ndims(data.value)
            case 2
                bkgd = repmat(eid.info.eid_bkgd(:,idx),1,length(data.x));
                NEW_DATA.value = NEW_DATA.value - bkgd';
            case 3
                bkgd = repmat(eid.info.eid_bkgd(:,idx),1,length(data.x),length(data.y));
                NEW_DATA.value = NEW_DATA.value - permute(bkgd,[2 3 1]);
        end

        NEW_DATA.value(NEW_DATA.value<0) = 0;

end

