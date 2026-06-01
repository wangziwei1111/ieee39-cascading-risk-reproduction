function main_compare_severity_vs_risk_weighted_var()
%MAIN_COMPARE_SEVERITY_VS_RISK_WEIGHTED_VAR Compare severity-only and risk-weighted VaR.

project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'formal_var_pilot');
M = readtable(fullfile(out_root, 'formal_chain_risk_var_metrics.csv'), 'TextType', 'string', 'Delimiter', ',');
G = readtable(fullfile(out_root, 'formal_chain_risk_var_to_paper_gap.csv'), 'TextType', 'string', 'Delimiter', ',');
keys = unique(M(:, {'parameter_set_id','scenario_id','sigma','metric_name'}), 'rows', 'stable');
rows = {};
for k = 1:height(keys)
    sev = value_for(M, keys(k, :), "severity_only");
    weighted = value_for(M, keys(k, :), "initial_probability_weighted_display");
    if isnan(sev) || isnan(weighted)
        interp = "insufficient_data";
    else
        sev_gap = gap_for(G, keys(k, :), "severity_only");
        weighted_gap = gap_for(G, keys(k, :), "initial_probability_weighted_display");
        if ~isnan(sev_gap) && ~isnan(weighted_gap) && weighted_gap < sev_gap
            interp = "weighting_improves_paper_alignment";
        elseif ~isnan(sev_gap) && ~isnan(weighted_gap) && weighted_gap > sev_gap
            interp = "weighting_worsens_paper_alignment";
        elseif sign(sev) ~= sign(weighted)
            interp = "weighting_changes_trend";
        else
            interp = "weighting_changes_scale_only";
        end
    end
    delta = weighted - sev;
    rel = abs(delta) / (abs(sev) + 1e-6);
    rows(end + 1, :) = {keys.parameter_set_id(k), keys.scenario_id(k), ...
        keys.metric_name(k), keys.sigma(k), sev, weighted, delta, rel, interp}; %#ok<AGROW>
end
T = cell2table(rows, 'VariableNames', {'parameter_set_id','scenario_id','metric_name', ...
    'sigma','severity_only_var','initial_probability_weighted_display_var','delta', ...
    'relative_delta','interpretation'});
writetable(T, fullfile(out_root, 'severity_vs_risk_weighted_var_comparison.csv'));
fprintf('Wrote %s\n', fullfile(out_root, 'severity_vs_risk_weighted_var_comparison.csv'));
end

function v = value_for(M, key, variant)
idx = M.parameter_set_id == key.parameter_set_id & M.scenario_id == key.scenario_id & ...
    abs(M.sigma - key.sigma) < 1e-9 & M.metric_name == key.metric_name & M.sample_variant == variant;
if any(idx)
    v = M.var_value(find(idx, 1));
else
    v = NaN;
end
end

function g = gap_for(G, key, variant)
idx = G.parameter_set_id == key.parameter_set_id & G.scenario_id == key.scenario_id & ...
    abs(G.sigma - key.sigma) < 1e-9 & G.metric_source == key.metric_name & G.sample_variant == variant;
if any(idx)
    g = G.relative_gap(find(idx, 1));
else
    g = NaN;
end
end
