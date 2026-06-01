function main_diagnose_calibration_trend_alignment()
%MAIN_DIAGNOSE_CALIBRATION_TREND_ALIGNMENT Compare paper and pilot trend directions.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'calibration', 'diagnostics');
sim_metrics = read_csv(fullfile(project_root, 'results', 'calibration', 'pilot', 'calibration_pilot_sim_metrics.csv'));
targets = read_csv(fullfile(project_root, 'paper_inputs', 'filled', 'calibration_target_benchmark.csv'));

parameter_sets = unique(sim_metrics.parameter_set_id);
metric_names = unique(sim_metrics.metric_name);
rows = {};
for p = 1:numel(parameter_sets)
    for m = 1:numel(metric_names)
        rows{end + 1, 1} = compare_pair(parameter_sets(p), "topology_compare", metric_names(m), ...
            "concentrated_bus34", "distributed_30_39", sim_metrics, targets); %#ok<AGROW>
        rows{end + 1, 1} = compare_pair(parameter_sets(p), "wind_speed_scan", metric_names(m), ...
            "wind_speed_11_28", "wind_speed_12_00", sim_metrics, targets); %#ok<AGROW>
        rows{end + 1, 1} = compare_sequence(parameter_sets(p), "penetration_scan", metric_names(m), ...
            ["penetration_40pct","penetration_60pct","penetration_80pct"], sim_metrics, targets); %#ok<AGROW>
    end
end
trend = vertcat(rows{:});
save_result_table(trend, fullfile(out_dir, 'calibration_trend_alignment.csv'), true);

summary_rows = cell(numel(parameter_sets), 1);
for p = 1:numel(parameter_sets)
    sub = trend(trend.parameter_set_id == parameter_sets(p), :);
    direction_test_count = height(sub);
    matched_direction_count = sum(sub.trend_status == "matched_direction");
    opposite_direction_count = sum(sub.trend_status == "opposite_direction");
    flat_sim_count = sum(sub.trend_status == "flat_sim");
    trend_match_rate = matched_direction_count / max(direction_test_count, 1);
    if trend_match_rate >= 0.75
        recommendation = "trend_ok_scale_or_metric_source_check_next";
    elseif trend_match_rate >= 0.50
        recommendation = "mixed_trend_check_scenario_and_metric_definition";
    else
        recommendation = "do_not_proceed_to_parameter_local_search";
    end
    summary_rows{p} = table(parameter_sets(p), direction_test_count, matched_direction_count, ...
        opposite_direction_count, flat_sim_count, trend_match_rate, recommendation, ...
        'VariableNames', {'parameter_set_id','direction_test_count','matched_direction_count', ...
        'opposite_direction_count','flat_sim_count','trend_match_rate','recommendation'});
end
summary = vertcat(summary_rows{:});
save_result_table(summary, fullfile(out_dir, 'calibration_trend_alignment_summary.csv'), true);
end

function row = compare_pair(parameter_set_id, target_group, metric_name, scenario_a, scenario_b, sim_metrics, targets)
[paper_a, sim_a] = get_values(parameter_set_id, target_group, metric_name, scenario_a, sim_metrics, targets);
[paper_b, sim_b] = get_values(parameter_set_id, target_group, metric_name, scenario_b, sim_metrics, targets);
row = build_row(parameter_set_id, target_group, metric_name, paper_a, paper_b, sim_a, sim_b, ...
    scenario_a + "_to_" + scenario_b);
end

function row = compare_sequence(parameter_set_id, target_group, metric_name, scenarios, sim_metrics, targets)
paper = NaN(numel(scenarios), 1);
sim = NaN(numel(scenarios), 1);
for i = 1:numel(scenarios)
    [paper(i), sim(i)] = get_values(parameter_set_id, target_group, metric_name, scenarios(i), sim_metrics, targets);
end
row = build_row(parameter_set_id, target_group, metric_name, paper(1), paper(end), sim(1), sim(end), ...
    strjoin(scenarios, "_to_"));
end

function [paper_value, sim_value] = get_values(parameter_set_id, target_group, metric_name, scenario_id, sim_metrics, targets)
t = targets(targets.target_group == target_group & targets.scenario_id == scenario_id & targets.metric_name == metric_name, :);
s = sim_metrics(sim_metrics.parameter_set_id == parameter_set_id & sim_metrics.target_group == target_group & ...
    sim_metrics.scenario_id == scenario_id & sim_metrics.metric_name == metric_name, :);
paper_value = NaN;
sim_value = NaN;
if ~isempty(t), paper_value = t.paper_value(1); end
if ~isempty(s), sim_value = s.sim_value(1); end
end

function row = build_row(parameter_set_id, target_group, metric_name, paper_a, paper_b, sim_a, sim_b, label)
paper_delta = paper_b - paper_a;
sim_delta = sim_b - sim_a;
paper_direction = direction_name(paper_delta);
sim_direction = direction_name(sim_delta);
direction_match = paper_direction == sim_direction && paper_direction ~= "missing";
if any(isnan([paper_a, paper_b, sim_a, sim_b]))
    trend_status = "insufficient_points";
elseif abs(sim_delta) < 1e-9
    trend_status = "flat_sim";
elseif direction_match
    trend_status = "matched_direction";
else
    trend_status = "opposite_direction";
end
paper_relative_delta = paper_delta / max(abs(paper_a), eps);
sim_relative_delta = sim_delta / max(abs(sim_a), eps);
note = "comparison=" + string(label);
row = table(parameter_set_id, target_group, metric_name, paper_direction, sim_direction, ...
    direction_match, paper_delta, sim_delta, paper_relative_delta, sim_relative_delta, trend_status, note, ...
    'VariableNames', {'parameter_set_id','target_group','metric_name','paper_direction','sim_direction', ...
    'direction_match','paper_delta','sim_delta','paper_relative_delta','sim_relative_delta','trend_status','note'});
end

function d = direction_name(delta)
if isnan(delta)
    d = "missing";
elseif delta > 1e-9
    d = "increase";
elseif delta < -1e-9
    d = "decrease";
else
    d = "flat";
end
end

function tbl = read_csv(path)
opts = detectImportOptions(path, 'Delimiter', ',', 'TextType', 'string');
tbl = readtable(path, opts);
end
