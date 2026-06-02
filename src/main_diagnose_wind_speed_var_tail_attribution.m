function main_diagnose_wind_speed_var_tail_attribution()
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
parameter_sets = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scenario_ids = ["wind_speed_11_28","wind_speed_12_00"];
metrics = ["SLLR","SLFOR","SNVOR","CRI"];
sigma = 0.95;
rows = {};
for p = 1:numel(parameter_sets)
    for s = 1:numel(scenario_ids)
        path = fullfile(out_root, parameter_sets(p), scenario_ids(s), 'tables', 'markov_chain_summary.csv');
        if exist(path, 'file') ~= 2, continue; end
        T = readtable(path, 'TextType', 'string');
        R = compute_risk_columns(T);
        for m = 1:numel(metrics)
            metric = metrics(m);
            values = R.(metric);
            valid = ~isnan(values);
            var_value = quantile(values(valid), sigma);
            tail = values >= var_value;
            ranks = rank_desc(values);
            idx = find(tail);
            for k = 1:numel(idx)
                i = idx(k);
                rows{end+1,1} = table(parameter_sets(p), scenario_ids(s), metric, sigma, var_value, ...
                    T.initial_branch(i), T.trial_id(i), T.chain_depth(i), string(T.terminated_reason(i)), ...
                    ranks(i), true, values(i), T.basic_LLR(i), T.basic_LFOR(i), T.basic_NVOR(i), T.basic_CRI(i), ...
                    T.initial_line_probability(i), T.chain_transition_probability(i), ...
                    T.initial_line_probability(i) * T.chain_transition_probability(i) / 1e-4, ...
                    T.max_line_loading_pu(i), T.max_voltage_deviation_pu(i), T.total_load_shed_frac(i), ...
                    "sigma=0.95 tail sample from after-curve-fix full-event pilot; diagnostic only", ...
                    'VariableNames', {'parameter_set_id','scenario_id','metric_name','sigma','var_value', ...
                    'initial_branch','trial_id','chain_depth','terminated_reason','tail_rank','tail_flag', ...
                    'R_metric_display','basic_LLR','basic_LFOR','basic_NVOR','basic_CRI', ...
                    'initial_line_probability','chain_transition_probability','total_chain_probability_display', ...
                    'max_line_loading_pu','max_voltage_deviation_pu','total_load_shed_frac','note'}); %#ok<AGROW>
            end
        end
    end
end
out = vertcat(rows{:});
writetable(out, fullfile(out_root, 'wind_speed_var_tail_attribution.csv'));
end

function R = compute_risk_columns(T)
scale = T.initial_line_probability .* T.chain_transition_probability ./ 1e-4;
R.SLLR = scale .* T.basic_LLR;
R.SLFOR = scale .* T.basic_LFOR;
R.SNVOR = scale .* T.basic_NVOR;
R.CRI = 0.6 * R.SLLR + 0.2 * R.SLFOR + 0.2 * R.SNVOR;
end

function ranks = rank_desc(values)
[~, order] = sort(values, 'descend', 'MissingPlacement', 'last');
ranks = nan(size(values));
ranks(order) = 1:numel(values);
end
