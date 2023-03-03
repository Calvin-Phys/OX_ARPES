
% load log into table
log_table = NiGaablog;
items = log_table.Properties.VariableNames;
v_num = size(log_table,1);
p_num = size(log_table,2);

for i = 1:v_num
    if exist(log_table{i,1},'var') == 1
        for j = 2:p_num
            eval(append(log_table{i,1},'.info.(items{j}) = log_table{i,j};'));
        end
    else
        disp(append('Variable ',log_table{i,1}, ' is not found.'));
    end
end

