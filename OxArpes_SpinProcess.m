data = Au111_ref_17K_00004_42S;
data.value = data.value*1E33;

cut1 = OxA_CUT(data.y,data.z,squeeze(data.value(1,:,:)));
cut2 = OxA_CUT(data.y,data.z,squeeze(data.value(2,:,:)));

sum_ = cut1;
sum_.value = cut1.value + cut2.value;

diff_ = cut1;
diff_.value = cut1.value - cut2.value;

pol_ = cut1;
pol_.value = diff_.value ./ sum_.value;

norm_ = cut1;
norm_.value = diff_.value .* sum_.value;
