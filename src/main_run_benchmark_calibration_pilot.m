function main_run_benchmark_calibration_pilot()
%MAIN_RUN_BENCHMARK_CALIBRATION_PILOT Run small reverse-calibration pilot batches.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_root = fullfile(project_root, 'results', 'calibration', 'pilot');
if ~exist(out_root, 'dir'), mkdir(out_root); end

parameter_sets = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scenario_rows = {
"topology_compare","concentrated_bus34";
"topology_compare","distributed_30_39";
"wind_speed_scan","wind_speed_11_28";
"wind_speed_scan","wind_speed_12_00";
"penetration_scan","penetration_40pct";
"penetration_scan","penetration_60pct";
"penetration_scan","penetration_80pct"
};
scenario_table = cell2table(scenario_rows, 'VariableNames', {'target_group','scenario_id'});

all_metrics = {};
for p = 1:numel(parameter_sets)
    parameter_set_id = parameter_sets(p);
    cfg_seed = load_benchmark_calibration_parameter_set(base_config(), parameter_set_id);
    cfg_seed.markov_num_trials_per_initial_fault = 5;
    cfg_seed.markov_random_seed = cfg_seed.seed;
    cfg_seed.calibration_error_epsilon = 1e-6;
    scenario_root_rel = fullfile('results', 'calibration', 'pilot', char(parameter_set_id));

    for s = 1:height(scenario_table)
        scenario_id = string(scenario_table.scenario_id(s));
        scenario_dir = fullfile(project_root, scenario_root_rel, char(scenario_id));
        if exist(fullfile(scenario_dir, 'tables', 'markov_chain_summary.csv'), 'file') ~= 2
            run_options = struct();
            run_options.markov_num_trials_per_initial_fault = 5;
            run_options.scenario_results_root = scenario_root_rel;
            run_options.cfg_overrides = cfg_seed;
            run_options.smoke_note = "benchmark calibration pilot; not final benchmark";
            main_run_single_scenario(char(scenario_id), run_options);
        end
        all_metrics{end + 1, 1} = read_scenario_metrics(parameter_set_id, scenario_table.target_group(s), scenario_id, scenario_dir); %#ok<AGROW>
    end
end

sim_metrics = vertcat(all_metrics{:});
save_result_table(sim_metrics, fullfile(out_root, 'calibration_pilot_sim_metrics.csv'), true);

target_table = readtable(fullfile(project_root, 'paper_inputs', 'filled', 'calibration_target_benchmark.csv'), 'TextType', 'string');
detail_cells = cell(numel(parameter_sets), 1);
summary_cells = cell(numel(parameter_sets), 1);
for p = 1:numel(parameter_sets)
    parameter_set_id = parameter_sets(p);
    sim_subset = sim_metrics(sim_metrics.parameter_set_id == parameter_set_id, :);
    [score_total, detail] = compute_benchmark_calibration_error(sim_subset, target_table, base_config());
    detail.parameter_set_id = repmat(parameter_set_id, height(detail), 1);
    detail_cells{p} = movevars(detail, 'parameter_set_id', 'Before', 1);
    valid_target_count = sum(detail.match_status == "matched");
    score_topology = group_score(detail, "topology_compare");
    score_wind_speed = group_score(detail, "wind_speed_scan");
    score_penetration = group_score(detail, "penetration_scan");
    recommendation = classify_recommendation(parameter_set_id, score_total, valid_target_count, height(target_table));
    summary_cells{p} = table(parameter_set_id, valid_target_count, score_total, ...
        score_topology, score_wind_speed, score_penetration, NaN, recommendation, ...
        'VariableNames', {'parameter_set_id','valid_target_count','score_total', ...
        'score_topology','score_wind_speed','score_penetration','best_rank','recommendation'});
end
error_detail = vertcat(detail_cells{:});
score_summary = vertcat(summary_cells{:});
[~, order] = sort(score_summary.score_total, 'ascend', 'MissingPlacement', 'last');
rank = NaN(height(score_summary), 1);
rank(order) = (1:height(score_summary)).';
score_summary.best_rank = rank;
if any(rank == 1)
    score_summary.recommendation(rank == 1) = "best_seed_for_local_refinement";
end
save_result_table(error_detail, fullfile(out_root, 'calibration_pilot_error_detail.csv'), true);
save_result_table(score_summary, fullfile(out_root, 'calibration_pilot_score_summary.csv'), true);
end

function metrics = read_scenario_metrics(parameter_set_id, target_group, scenario_id, scenario_dir)
table_dir = fullfile(scenario_dir, 'tables');
paper_path = fullfile(table_dir, 'markov_var_metrics_paper_severity.csv');
weighted_path = fullfile(table_dir, 'markov_var_metrics_weighted.csv');
[source_tbl, source_file, note] = read_preferred_metric_table(paper_path, weighted_path);
metric_names = ["SLLR","SLFOR","SNVOR","CRI"];
rows = cell(numel(metric_names), 1);
for i = 1:numel(metric_names)
    sim_value = NaN;
    if ~isempty(source_tbl)
        idx = find(abs(source_tbl.sigma - 0.95) < 1e-9, 1);
        if ~isempty(idx) && ismember(metric_names(i), source_tbl.Properties.VariableNames)
            sim_value = source_tbl.(metric_names(i))(idx);
        end
    end
    rows{i} = table(parameter_set_id, string(target_group), string(scenario_id), metric_names(i), ...
        sim_value, string(source_file), string(note), ...
        'VariableNames', {'parameter_set_id','target_group','scenario_id','metric_name','sim_value','source_file','note'});
end
metrics = vertcat(rows{:});
end

function [tbl, source_file, note] = read_preferred_metric_table(paper_path, weighted_path)
tbl = table();
source_file = "";
note = "";
if exist(paper_path, 'file') == 2
    candidate = readtable(paper_path, 'TextType', 'string');
    if ismember('result_status', candidate.Properties.VariableNames) && all(candidate.result_status == "valid")
        tbl = candidate;
        source_file = paper_path;
        note = "paper_severity_valid";
        return;
    end
end
if exist(weighted_path, 'file') == 2
    tbl = readtable(weighted_path, 'TextType', 'string');
    source_file = weighted_path;
    note = "paper_severity_unavailable_used_weighted_basic_for_pilot";
end
end

function score = group_score(detail, group_name)
mask = detail.target_group == group_name & detail.match_status == "matched";
if any(mask)
    score = mean(detail.weighted_error(mask), 'omitnan');
else
    score = NaN;
end
end

function recommendation = classify_recommendation(parameter_set_id, score_total, valid_count, target_count)
if valid_count < target_count
    recommendation = "incomplete_targets";
elseif isnan(score_total)
    recommendation = "not_recommended";
elseif contains(parameter_set_id, "high")
    recommendation = "too_high_risk";
elseif contains(parameter_set_id, "low")
    recommendation = "too_low_risk";
else
    recommendation = "not_recommended";
end
end
