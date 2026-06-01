function main_compare_formal_var_pilot_to_paper_targets()
%MAIN_COMPARE_FORMAL_VAR_PILOT_TO_PAPER_TARGETS Compare formal pilot VaR to paper targets.

project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'formal_var_pilot');
M = readtable(fullfile(out_root, 'formal_scenario_aligned_var_metrics.csv'), 'TextType', 'string', 'Delimiter', ',');
Tgt = readtable(fullfile(project_root, 'results', 'calibration', 'diagnostics', 'calibration_target_benchmark_candidate_v2.csv'), 'TextType', 'string', 'Delimiter', ',');
Tgt = Tgt(Tgt.recommended_use == 1 & abs(Tgt.confidence_sigma - 0.95) < 1e-9, :);
parameter_sets = unique(M.parameter_set_id, 'stable');
rows = {};
for p = 1:numel(parameter_sets)
    for i = 1:height(Tgt)
        target_metric = string(Tgt.metric_name(i));
        metric_sources = target_metric;
        if target_metric == "CRI"
            metric_sources = ["CRI_recomputed_from_var","CRI_basic"];
        end
        for ms = 1:numel(metric_sources)
            sim_metric = metric_sources(ms);
            idx = M.parameter_set_id == parameter_sets(p) & M.scenario_id == Tgt.scenario_id(i) & ...
                abs(M.sigma - 0.95) < 1e-9 & M.scale_variant == "paper_table_display" & ...
                M.metric_name == sim_metric;
            if any(idx)
                sim_value = M.var_value(find(idx, 1));
                abs_gap = sim_value - Tgt.paper_value(i);
                rel_gap = abs(abs_gap) / (abs(Tgt.paper_value(i)) + 1e-6);
                ratio = Tgt.paper_value(i) / (sim_value + 1e-6);
                status = classify_gap(rel_gap);
                note = "sigma=0.95 paper_table_display comparison; no hidden unit scaling";
            else
                sim_value = NaN; abs_gap = NaN; rel_gap = NaN; ratio = NaN;
                status = "missing_sim";
                note = "missing formal pilot metric";
            end
            rows(end + 1, :) = {parameter_sets(p), Tgt.target_group(i), Tgt.scenario_id(i), ...
                target_metric, sim_metric, 0.95, Tgt.paper_value(i), sim_value, abs_gap, ...
                rel_gap, ratio, status, note}; %#ok<AGROW>
        end
    end
end
G = cell2table(rows, 'VariableNames', {'parameter_set_id','target_group','scenario_id', ...
    'metric_name','metric_source','sigma','paper_value','sim_var_value','absolute_gap', ...
    'relative_gap','ratio_paper_to_sim','match_status','note'});
writetable(G, fullfile(out_root, 'formal_var_pilot_to_paper_gap.csv'));
fprintf('Wrote %s\n', fullfile(out_root, 'formal_var_pilot_to_paper_gap.csv'));
end

function status = classify_gap(relative_gap)
if isnan(relative_gap)
    status = "missing_sim";
elseif relative_gap < 0.25
    status = "close";
elseif relative_gap < 1.0
    status = "same_order";
else
    status = "wrong_scale";
end
end
