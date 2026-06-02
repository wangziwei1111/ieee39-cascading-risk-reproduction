function main_diagnose_wind_speed_component_severity_delta()
root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun');
psets = ["high_hidden_failure","benchmark_calibrated_seed"];
rows = {};
for p = 1:numel(psets)
    A = suffix(readtable(fullfile(out_root, psets(p), 'wind_speed_11_28', 'tables', 'markov_chain_summary.csv'), 'TextType', 'string'), "11");
    B = suffix(readtable(fullfile(out_root, psets(p), 'wind_speed_12_00', 'tables', 'markov_chain_summary.csv'), 'TextType', 'string'), "12");
    J = innerjoin(A, B, 'Keys', {'initial_branch','trial_id'});
    for i = 1:height(J)
        dLLR = J.basic_LLR_12(i)-J.basic_LLR_11(i);
        dLFOR = J.basic_LFOR_12(i)-J.basic_LFOR_11(i);
        dNVOR = J.basic_NVOR_12(i)-J.basic_NVOR_11(i);
        dCRI = J.basic_CRI_12(i)-J.basic_CRI_11(i);
        dLoad = J.total_load_shed_frac_12(i)-J.total_load_shed_frac_11(i);
        dLine = J.max_line_loading_pu_12(i)-J.max_line_loading_pu_11(i);
        dVolt = J.max_voltage_deviation_pu_12(i)-J.max_voltage_deviation_pu_11(i);
        rows{end+1,1} = table(psets(p), J.initial_branch(i), J.trial_id(i), dLLR, dLFOR, dNVOR, dCRI, dLoad, dLine, dVolt, ...
            NaN, NaN, classify(dLoad,dLine,dVolt), "paired severity delta from component diagnostic rerun", ...
            'VariableNames', {'parameter_set_id','initial_branch','trial_id','delta_basic_LLR','delta_basic_LFOR','delta_basic_NVOR', ...
            'delta_basic_CRI','delta_total_load_shed_frac','delta_max_line_loading_pu','delta_max_voltage_deviation_pu', ...
            'delta_overloaded_branch_count','delta_voltage_violation_bus_count','severity_driver','note'}); %#ok<AGROW>
    end
end
writetable(vertcat(rows{:}), fullfile(out_root, 'wind_speed_component_severity_delta.csv'));
end

function T = suffix(T, suf)
keep = {'initial_branch','trial_id','basic_LLR','basic_LFOR','basic_NVOR','basic_CRI','total_load_shed_frac', ...
    'max_line_loading_pu','max_voltage_deviation_pu'};
T = T(:, keep);
for i = 3:numel(keep)
    idx = find(strcmp(T.Properties.VariableNames, keep{i}),1);
    T.Properties.VariableNames{idx} = char(string(keep{i}) + "_" + suf);
end
end

function s = classify(dLoad,dLine,dVolt)
flags = [dLoad>1e-9,dLine>1e-9,dVolt>1e-9];
if sum(flags)>1
    s = "mixed_severity_increase";
elseif flags(1)
    s = "load_shed_increase";
elseif flags(2)
    s = "line_overload_increase";
elseif flags(3)
    s = "voltage_violation_increase";
else
    s = "no_severity_increase";
end
end
