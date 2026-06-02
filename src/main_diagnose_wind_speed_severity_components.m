function main_diagnose_wind_speed_severity_components()
root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
psets = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scens = ["wind_speed_11_28","wind_speed_12_00"];
metrics = ["LLR","LFOR","NVOR","CRI"];
rows = {};
for p = 1:numel(psets)
    for s = 1:numel(scens)
        T = readtable(fullfile(out_root, psets(p), scens(s), 'tables', 'markov_chain_summary.csv'), 'TextType', 'string');
        for m = 1:numel(metrics)
            field = "basic_" + metrics(m);
            rows{end+1,1} = table(psets(p), scens(s), "S"+metrics(m), height(T), mean(T.(char(field)), 'omitnan'), ...
                median(T.(char(field)), 'omitnan'), quantile(T.(char(field)), 0.95), max(T.(char(field)), [], 'omitnan'), ...
                mean(T.total_load_shed_frac, 'omitnan'), quantile(T.total_load_shed_frac, 0.95), ...
                mean(T.max_line_loading_pu, 'omitnan'), quantile(T.max_line_loading_pu, 0.95), ...
                mean(T.max_voltage_deviation_pu, 'omitnan'), quantile(T.max_voltage_deviation_pu, 0.95), ...
                "basic_chain_summary_available", "Severity inputs from markov_chain_summary; diagnostic only.", ...
                'VariableNames', {'parameter_set_id','scenario_id','metric_name','sample_count','mean_basic_value', ...
                'median_basic_value','p95_basic_value','max_basic_value','mean_load_shed_frac','p95_load_shed_frac', ...
                'mean_max_line_loading_pu','p95_max_line_loading_pu','mean_max_voltage_deviation_pu', ...
                'p95_max_voltage_deviation_pu','severity_status','note'}); %#ok<AGROW>
        end
    end
end
writetable(vertcat(rows{:}), fullfile(out_root, 'wind_speed_severity_component_summary.csv'));
writetable(build_delta(out_root, psets), fullfile(out_root, 'wind_speed_severity_component_delta.csv'));
end

function D = build_delta(out_root, psets)
rows = {};
for p = 1:numel(psets)
    A = suffix_table(readtable(fullfile(out_root, psets(p), 'wind_speed_11_28', 'tables', 'markov_chain_summary.csv'), 'TextType', 'string'), "11");
    B = suffix_table(readtable(fullfile(out_root, psets(p), 'wind_speed_12_00', 'tables', 'markov_chain_summary.csv'), 'TextType', 'string'), "12");
    J = innerjoin(A, B, 'Keys', {'initial_branch','trial_id'});
    for i = 1:height(J)
        dLLR = J.basic_LLR_12(i) - J.basic_LLR_11(i);
        dLFOR = J.basic_LFOR_12(i) - J.basic_LFOR_11(i);
        dNVOR = J.basic_NVOR_12(i) - J.basic_NVOR_11(i);
        dCRI = J.basic_CRI_12(i) - J.basic_CRI_11(i);
        dLoad = J.total_load_shed_frac_12(i) - J.total_load_shed_frac_11(i);
        dLine = J.max_line_loading_pu_12(i) - J.max_line_loading_pu_11(i);
        dVolt = J.max_voltage_deviation_pu_12(i) - J.max_voltage_deviation_pu_11(i);
        rows{end+1,1} = table(psets(p), J.initial_branch(i), J.trial_id(i), dLLR, dLFOR, dNVOR, dCRI, dLoad, dLine, dVolt, ...
            string(J.terminated_reason_11(i)), string(J.terminated_reason_12(i)), classify_severity(dLoad, dLine, dVolt), ...
            "Paired chain severity delta; diagnostic only.", ...
            'VariableNames', {'parameter_set_id','initial_branch','trial_id','delta_basic_LLR','delta_basic_LFOR', ...
            'delta_basic_NVOR','delta_basic_CRI','delta_total_load_shed_frac','delta_max_line_loading_pu', ...
            'delta_max_voltage_deviation_pu','terminated_reason_11_28','terminated_reason_12_00','severity_driver','note'}); %#ok<AGROW>
    end
end
D = vertcat(rows{:});
end

function T = suffix_table(T, suffix)
keep = {'initial_branch','trial_id','terminated_reason','basic_LLR','basic_LFOR','basic_NVOR','basic_CRI', ...
    'total_load_shed_frac','max_line_loading_pu','max_voltage_deviation_pu'};
T = T(:, keep);
for i = 3:numel(keep)
    idx = find(strcmp(T.Properties.VariableNames, keep{i}), 1);
    T.Properties.VariableNames{idx} = char(string(keep{i}) + "_" + suffix);
end
end

function s = classify_severity(dLoad, dLine, dVolt)
flags = [dLoad > 1e-9, dLine > 1e-9, dVolt > 1e-9];
if sum(flags) > 1
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
