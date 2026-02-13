function data_out = ox_apply_fermi_shift_extended(KZ_DATA, EF_curve)

data_out = KZ_DATA;

E = KZ_DATA.z(:)';
dE = mean(diff(E));

max_shift = max(abs(EF_curve));
margin = max_shift + 2*dE;

E_ext = (min(E)-margin) : dE : (max(E)+margin);

Nhv = size(KZ_DATA.value,1);
Nky = size(KZ_DATA.value,2);

value_new = zeros(Nhv, Nky, length(E_ext));

for ihv = 1:Nhv

    EF_i = EF_curve(ihv);
    slice = squeeze(KZ_DATA.value(ihv,:,:));  % (ky, E)

    slice_ext = zeros(Nky, length(E_ext));

    for ky_idx = 1:Nky
        slice_ext(ky_idx,:) = interp1(E, ...
            slice(ky_idx,:), ...
            E_ext, ...
            'pchip', 0);
    end

    slice_shift = zeros(size(slice_ext));

    for ky_idx = 1:Nky
        slice_shift(ky_idx,:) = interp1(E_ext, ...
            slice_ext(ky_idx,:), ...
            E_ext + EF_i, ...
            'pchip', 0);
    end

    value_new(ihv,:,:) = slice_shift;

end

data_out.value = value_new;
data_out.z = E_ext;

end
