function main_compare_full_event_formal_var_to_paper_targets()
%MAIN_COMPARE_FULL_EVENT_FORMAL_VAR_TO_PAPER_TARGETS Compare sigma=0.95 full-event metrics to paper targets.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
metrics = readtable(fullfile(out_root, 'full_event_formal_var_metrics.csv'), 'TextType', 'string');
targets = readtable(fullfile(project_root, 'results', 'calibration', 'diagnostics', 'calibration_target_benchmark_candidate_v2.csv'), 'TextType', 'string');
targets = targets(targets.recommended_use == 1 & abs(targets.confidence_sigma - 0.95) < 1e-9, :);
M = metrics(metrics.sample_variant == "full_event_chain_risk_display" & abs(metrics.sigma - 0.95) < 1e-9, :);
parameter_sets = unique(M.parameter_set_id, 'stable');
rows = {};
for p = 1:numel(parameter_sets)
    for t = 1:height(targets)
        metric_name = map_target_metric(targets.metric_name(t));
        sim = M(M.parameter_set_id == parameter_sets(p) & M.scenario_id == targets.scenario_id(t) & M.metric_name == metric_name, :);
        if isempty(sim)
            sim_value = NaN;
            status = "missing_sim";
        else
            sim_value = sim.var_value(1);
            status = classify_gap(sim_value, targets.paper_value(t));
        end
        abs_gap = abs(sim_value - targets.paper_value(t));
        rel_gap = abs_gap / (abs(targets.paper_value(t)) + 1e-6);
        rows{end+1,1} = table(parameter_sets(p), targets.target_group(t), targets.scenario_id(t), metric_name, ...
            0.95, targets.paper_value(t), sim_value, abs_gap, rel_gap, ...
            targets.paper_value(t) / (sim_value + 1e-6), status, ...
            "Full-event formal pilot comparison; benchmark calibrated parameters are not original paper parameters.", ...
            'VariableNames', {'parameter_set_id','target_group','scenario_id','metric_name','sigma','paper_value', ...
            'sim_var_value','absolute_gap','relative_gap','ratio_paper_to_sim','match_status','note'}); %#ok<AGROW>
    end
end
gap = vertcat(rows{:});
writetable(gap, fullfile(out_root, 'full_event_formal_var_to_paper_gap.csv'));
fprintf('full-event gap table written: %s\n', out_root);
end

function metric = map_target_metric(metric)
if metric == "CRI"
    metric = "CRI_recomputed";
end
end

function status = classify_gap(sim_value, paper_value)
if isnan(sim_value) || isnan(paper_value)
    status = "missing_sim";
    return;
end
rel = abs(sim_value - paper_value) / (abs(paper_value) + 1e-6);
if rel < 0.25
    status = "close";
elseif rel < 1.0
    status = "same_order";
else
    status = "wrong_scale";
end
end
