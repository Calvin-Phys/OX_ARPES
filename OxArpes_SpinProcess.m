% to be updated
data = Ga6_00002_88S;
% data.value = data.value*1E33;

cut1 = OxA_CUT(data.y,data.z,squeeze(data.value(1,:,:)) + squeeze(data.value(4,:,:)));
cut2 = OxA_CUT(data.y,data.z,squeeze(data.value(2,:,:)) + squeeze(data.value(3,:,:)));

sum_ = cut1;
sum_.value = cut1.value + cut2.value;

diff_ = cut1;
diff_.value = cut1.value - cut2.value;

pol_ = cut1;
pol_.value = diff_.value ./ sum_.value;

norm_ = cut1;
norm_.value = diff_.value .* sum_.value;
