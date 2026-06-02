function main_score_curve_fix_full_event_var_alignment()
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
gap = readtable(fullfile(out_root, 'full_event_var_to_paper_gap_after_curve_fix.csv'), 'TextType', 'string', 'Delimiter', ',');
parameter_sets = unique(gap.parameter_set_id, 'stable');
rows = {};
for p = 1:numel(parameter_sets)
    D = gap(gap.parameter_set_id == parameter_sets(p) & gap.match_status ~= "missing_sim", :);
    trend = [topology_match(D), wind_speed_match(D), penetration_match(D)];
    trend_rate = mean(trend(~isnan(trend)), 'omitnan');
    med_gap = median(abs(D.relative_gap), 'omitnan');
    mean_gap = mean(abs(D.relative_gap), 'omitnan');
    rows{end+1,1} = table(parameter_sets(p), height(D), mean_gap, med_gap, ...
        trend(1), trend(2), trend(3), trend_rate, NaN, classify_recommendation(trend_rate, med_gap, height(D)), ...
        'VariableNames', {'parameter_set_id','valid_target_count','mean_abs_relative_gap', ...
        'median_abs_relative_gap','topology_direction_match','wind_speed_direction_match', ...
        'penetration_direction_match','overall_trend_match_rate','score_rank','recommendation'}); %#ok<AGROW>
end
summary = vertcat(rows{:});
[~, order] = sortrows([summary.overall_trend_match_rate, -summary.median_abs_relative_gap], [-1, 2]);
rank = NaN(height(summary), 1); rank(order) = (1:height(summary)).';
summary.score_rank = rank;
writetable(summary, fullfile(out_root, 'full_event_var_score_summary_after_curve_fix.csv'));
end

function tf = topology_match(D)
tf = compare_pair(D, "concentrated_bus34", "distributed_30_39", "CRI_recomputed");
end
function tf = wind_speed_match(D)
tf = compare_pair(D, "wind_speed_11_28", "wind_speed_12_00", "CRI_recomputed");
end
function tf = penetration_match(D)
vals = scenario_values(D, ["penetration_40pct","penetration_60pct","penetration_80pct"], "CRI_recomputed");
papers = paper_values(D, ["penetration_40pct","penetration_60pct","penetration_80pct"], "CRI_recomputed");
if any(isnan(vals)) || any(isnan(papers)), tf = NaN; else, tf = double(sign(vals(3)-vals(1)) == sign(papers(3)-papers(1))); end
end
function tf = compare_pair(D, a, b, metric)
vals = scenario_values(D, [a,b], metric); papers = paper_values(D, [a,b], metric);
if any(isnan(vals)) || any(isnan(papers)), tf = NaN; else, tf = double(sign(vals(2)-vals(1)) == sign(papers(2)-papers(1))); end
end
function vals = scenario_values(D, scenarios, metric)
vals = NaN(1,numel(scenarios));
for i=1:numel(scenarios), row=D(D.scenario_id==scenarios(i)&D.metric_name==metric,:); if ~isempty(row), vals(i)=row.sim_var_value(1); end, end
end
function vals = paper_values(D, scenarios, metric)
vals = NaN(1,numel(scenarios));
for i=1:numel(scenarios), row=D(D.scenario_id==scenarios(i)&D.metric_name==metric,:); if ~isempty(row), vals(i)=row.paper_value(1); end, end
end
function rec = classify_recommendation(trend_rate, med_gap, valid_count)
if valid_count < 10 || isnan(trend_rate)
    rec = "insufficient_targets";
elseif trend_rate >= 0.75 && med_gap < 1.0
    rec = "candidate_for_limited_parameter_refinement";
elseif trend_rate >= 0.75
    rec = "candidate_but_metric_scale_needs_review";
elseif trend_rate < 0.5
    rec = "wrong_trend";
else
    rec = "wrong_scale";
end
end
