function main_score_chain_risk_var_alignment()
%MAIN_SCORE_CHAIN_RISK_VAR_ALIGNMENT Score chain-risk VaR alignment.

project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'formal_var_pilot');
G = readtable(fullfile(out_root, 'formal_chain_risk_var_to_paper_gap.csv'), 'TextType', 'string', 'Delimiter', ',');
keys = unique(G(:, {'parameter_set_id','sample_variant','metric_source'}), 'rows', 'stable');
rows = {};
for k = 1:height(keys)
    mask = G.parameter_set_id == keys.parameter_set_id(k) & G.sample_variant == keys.sample_variant(k) & ...
        G.metric_source == keys.metric_source(k) & ~isnan(G.relative_gap);
    D = G(mask, :);
    valid_count = height(D);
    mean_gap = mean(abs(D.relative_gap), 'omitnan');
    median_gap = median(abs(D.relative_gap), 'omitnan');
    topo = direction_pair(D, "concentrated_bus34", "distributed_30_39");
    wind = direction_pair(D, "wind_speed_11_28", "wind_speed_12_00");
    pen = direction_penetration(D);
    trends = [topo, wind, pen];
    trend_rate = mean(trends(~isnan(trends)));
    rec = classify(keys.sample_variant(k), valid_count, trend_rate, median_gap);
    rows(end + 1, :) = {keys.parameter_set_id(k), keys.sample_variant(k), keys.metric_source(k), ...
        valid_count, mean_gap, median_gap, topo, wind, pen, trend_rate, NaN, rec}; %#ok<AGROW>
end
S = cell2table(rows, 'VariableNames', {'parameter_set_id','sample_variant','metric_name', ...
    'valid_target_count','mean_abs_relative_gap','median_abs_relative_gap', ...
    'topology_direction_match','wind_speed_direction_match','penetration_direction_match', ...
    'overall_trend_match_rate','score_rank','recommendation'});
[~, order] = sortrows([double(S.recommendation ~= "candidate_metric_for_calibration"), ...
    -S.overall_trend_match_rate, S.median_abs_relative_gap], [1 2 3]);
rank = NaN(height(S), 1);
rank(order) = (1:height(S)).';
S.score_rank = rank;
writetable(S, fullfile(out_root, 'formal_chain_risk_var_score_summary.csv'));
fprintf('Wrote %s\n', fullfile(out_root, 'formal_chain_risk_var_score_summary.csv'));
end

function ok = direction_pair(D, high_scenario, low_scenario)
v_high = value_for(D, high_scenario);
v_low = value_for(D, low_scenario);
if isnan(v_high) || isnan(v_low)
    ok = NaN;
else
    ok = double(v_low < v_high);
end
end

function ok = direction_penetration(D)
v40 = value_for(D, "penetration_40pct");
v60 = value_for(D, "penetration_60pct");
v80 = value_for(D, "penetration_80pct");
if any(isnan([v40, v60, v80]))
    ok = NaN;
else
    ok = double(v40 <= v60 && v60 <= v80);
end
end

function v = value_for(D, scenario_id)
idx = find(D.scenario_id == scenario_id, 1);
if isempty(idx)
    v = NaN;
else
    v = D.sim_var_value(idx);
end
end

function rec = classify(variant, valid_count, trend_rate, median_gap)
if valid_count < 7 || isnan(trend_rate)
    rec = "insufficient_targets";
elseif variant == "severity_only"
    rec = "severity_only_not_paper_risk";
elseif variant == "transition_probability_weighted"
    rec = "candidate_but_missing_transition_probability";
elseif trend_rate < 0.5
    rec = "wrong_trend";
elseif trend_rate >= 0.75 && median_gap < 1.0 && variant == "initial_probability_weighted_display"
    rec = "candidate_metric_for_calibration";
elseif trend_rate >= 0.75 && variant == "initial_probability_weighted_display"
    rec = "candidate_but_missing_transition_probability";
elseif median_gap >= 1.0
    rec = "wrong_scale";
else
    rec = "not_recommended";
end
end
