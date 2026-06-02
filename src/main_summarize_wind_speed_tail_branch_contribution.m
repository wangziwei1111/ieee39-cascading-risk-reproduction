function main_summarize_wind_speed_tail_branch_contribution()
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
T = readtable(fullfile(out_root, 'wind_speed_var_tail_attribution.csv'), 'TextType', 'string');
keys = unique(T(:, {'parameter_set_id','scenario_id','metric_name','initial_branch'}), 'rows');
rows = cell(height(keys), 1);
for i = 1:height(keys)
    mask = T.parameter_set_id == keys.parameter_set_id(i) & T.scenario_id == keys.scenario_id(i) & ...
        T.metric_name == keys.metric_name(i) & T.initial_branch == keys.initial_branch(i);
    G = T(mask, :);
    rows{i} = table(keys.parameter_set_id(i), keys.scenario_id(i), keys.metric_name(i), keys.initial_branch(i), ...
        height(G), sum(G.R_metric_display, 'omitnan'), mean(G.R_metric_display, 'omitnan'), max(G.R_metric_display, [], 'omitnan'), ...
        mean(G.initial_line_probability, 'omitnan'), mean(G.chain_transition_probability, 'omitnan'), ...
        mean(G.basic_LLR, 'omitnan'), mean(G.basic_LFOR, 'omitnan'), mean(G.basic_NVOR, 'omitnan'), ...
        mean(compute_cri_display(G), 'omitnan'), NaN, "tail contribution grouped by initial branch", ...
        'VariableNames', {'parameter_set_id','scenario_id','metric_name','initial_branch','tail_sample_count', ...
        'tail_risk_sum','tail_risk_mean','tail_risk_max','mean_initial_line_probability','mean_chain_transition_probability', ...
        'mean_basic_LLR','mean_basic_LFOR','mean_basic_NVOR','mean_CRI_display','dominance_rank','note'});
end
S = vertcat(rows{:});
S = assign_rank(S);
writetable(S, fullfile(out_root, 'wind_speed_tail_branch_contribution_summary.csv'));
writetable(build_delta(S), fullfile(out_root, 'wind_speed_tail_branch_delta_11_28_vs_12_00.csv'));
end

function cri = compute_cri_display(G)
scale = G.total_chain_probability_display;
cri = scale .* (0.6 * G.basic_LLR + 0.2 * G.basic_LFOR + 0.2 * G.basic_NVOR);
end

function S = assign_rank(S)
for p = unique(S.parameter_set_id)'
    for s = unique(S.scenario_id)'
        for m = unique(S.metric_name)'
            mask = S.parameter_set_id == p & S.scenario_id == s & S.metric_name == m;
            [~, order] = sort(S.tail_risk_sum(mask), 'descend');
            idx = find(mask);
            ranks = nan(sum(mask), 1);
            ranks(order) = 1:sum(mask);
            S.dominance_rank(idx) = ranks;
        end
    end
end
end

function D = build_delta(S)
rows = {};
all_keys = unique(S(:, {'parameter_set_id','metric_name','initial_branch'}), 'rows');
for i = 1:height(all_keys)
    a = findrow(S, all_keys(i,:), "wind_speed_11_28");
    b = findrow(S, all_keys(i,:), "wind_speed_12_00");
    tail_count_11 = getv(a, 'tail_sample_count'); tail_count_12 = getv(b, 'tail_sample_count');
    risk_11 = getv(a, 'tail_risk_mean'); risk_12 = getv(b, 'tail_risk_mean');
    prob_11 = getv(a, 'mean_chain_transition_probability'); prob_12 = getv(b, 'mean_chain_transition_probability');
    sev_11 = severity_mean(a, string(all_keys.metric_name(i))); sev_12 = severity_mean(b, string(all_keys.metric_name(i)));
    dp = prob_12 - prob_11; ds = sev_12 - sev_11; dr = risk_12 - risk_11;
    driver = classify_driver(dp, ds, tail_count_11, tail_count_12);
    rows{end+1,1} = table(all_keys.parameter_set_id(i), all_keys.metric_name(i), all_keys.initial_branch(i), ...
        tail_count_11, tail_count_12, risk_11, risk_12, prob_11, prob_12, sev_11, sev_12, ...
        dr, dp, ds, driver, "11.28 vs 12.00 tail branch diagnostic; no rerun", ...
        'VariableNames', {'parameter_set_id','metric_name','initial_branch','tail_count_11_28','tail_count_12_00', ...
        'tail_risk_mean_11_28','tail_risk_mean_12_00','chain_probability_mean_11_28','chain_probability_mean_12_00', ...
        'severity_mean_11_28','severity_mean_12_00','delta_tail_risk_mean','delta_chain_probability','delta_severity', ...
        'likely_driver','note'}); %#ok<AGROW>
end
D = vertcat(rows{:});
end

function row = findrow(S, key, scenario)
mask = S.parameter_set_id == key.parameter_set_id & S.metric_name == key.metric_name & ...
    S.initial_branch == key.initial_branch & S.scenario_id == scenario;
row = S(mask, :);
end

function v = getv(row, name)
if isempty(row), v = NaN; else, v = row.(name)(1); end
end

function v = severity_mean(row, metric)
if isempty(row), v = NaN; return; end
switch metric
    case "SLLR", v = row.mean_basic_LLR(1);
    case "SLFOR", v = row.mean_basic_LFOR(1);
    case "SNVOR", v = row.mean_basic_NVOR(1);
    otherwise, v = row.mean_CRI_display(1) ./ max(row.mean_chain_transition_probability(1) .* row.mean_initial_line_probability(1) ./ 1e-4, eps);
end
end

function driver = classify_driver(dp, ds, c11, c12)
if isnan(c11) || isnan(c12) || c11 ~= c12
    driver = "initial_branch_composition_change";
elseif dp > 0 && ds > 0
    driver = "both_probability_and_severity";
elseif dp > 0
    driver = "chain_probability_increase";
elseif ds > 0
    driver = "severity_increase";
else
    driver = "no_clear_driver";
end
end
