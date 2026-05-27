function batch_summary = main_run_scenario_batch(batch_mode, run_options)
%MAIN_RUN_SCENARIO_BATCH 通用场景批处理入口，支持分组运行和断点续跑。
% 输入：
%   batch_mode - smoke/topology_compare/penetration_scan/wind_speed_scan/renewable_trip_record/all_full。
%   run_options - 运行选项，含resume_existing、force_rerun、markov_num_trials_per_initial_fault。
% 输出：
%   batch_summary - 本批次场景运行/跳过/失败汇总。
% 物理含义：
%   将耗时较长的第4章扫描拆分为可复核、可续跑的小批次。已有完整场景可跳过，
%   diagnostic_only代表运行完整但paper_formula不可用于论文对照。

if nargin < 1 || isempty(batch_mode)
    batch_mode = 'smoke';
end
if nargin < 2
    run_options = struct();
end

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();

run_options = fill_default_run_options(run_options, cfg, batch_mode);
if run_options.resume_existing && run_options.force_rerun
    error('resume_existing与force_rerun不能同时为true。');
end

require_matpower(cfg);
base_mpc = build_case39_base(cfg);
base_load_mw = sum(base_mpc.bus(:, 3));
scenarios = build_scenario_library(cfg, base_load_mw);
scenario_ids = select_scenarios_by_batch_mode(scenarios, batch_mode);
scenario_root = fullfile(project_root, cfg.scenario_results_root);
if ~exist(scenario_root, 'dir')
    mkdir(scenario_root);
end
expected_options = build_expected_options(run_options, batch_mode);

rows = cell(numel(scenario_ids), 1);
for k = 1:numel(scenario_ids)
    scenario_id = scenario_ids{k};
    scenario_dir = fullfile(scenario_root, scenario_id);
    [is_complete, completion_status, missing_files, complete_note] = ...
        check_single_scenario_complete(scenario_id, scenario_root, expected_options);
    existing_trials = read_existing_trials_for_batch(scenario_id, scenario_root);
    reuse_allowed = run_options.resume_existing && is_complete && ~run_options.force_rerun;
    reuse_decision_reason = string(complete_note);

    if run_options.force_rerun && exist(scenario_dir, 'dir')
        rmdir(scenario_dir, 's');
        is_complete = false;
        completion_status = "rerun_requested";
        reuse_allowed = false;
        reuse_decision_reason = "force_rerun=true";
    end

    if reuse_allowed
        scenario_result = read_existing_scenario_result(scenario_id, scenario_root, cfg);
        execution_status = "skipped_existing";
        note = complete_note;
    else
        try
            scenario_result = main_run_single_scenario(scenario_id, run_options);
            execution_status = "ran";
            existing_trials = scenario_result.markov_trials_per_initial_fault;
            [~, completion_status, missing_files, complete_note] = ...
                check_single_scenario_complete(scenario_id, scenario_root, expected_options);
            note = scenario_result.note;
            if strlength(string(note)) == 0
                note = complete_note;
            end
            if strlength(reuse_decision_reason) == 0
                reuse_decision_reason = "ran because existing result was absent or did not match expected trials";
            end
        catch ME
            scenario_result = init_failed_batch_result(scenario_id, cfg, ME);
            execution_status = "failed";
            completion_status = "incomplete";
            missing_files = "";
            note = string(ME.message);
            reuse_decision_reason = string(ME.message);
        end
    end

    rows{k} = add_batch_columns(struct2table(scenario_result), batch_mode, execution_status, ...
        completion_status, missing_files, note, run_options.markov_num_trials_per_initial_fault, ...
        existing_trials, reuse_allowed, reuse_decision_reason);
end

batch_summary = vertcat(rows{:});
summary_path = fullfile(scenario_root, sprintf('scenario_batch_summary_%s.csv', batch_mode));
save_result_table(batch_summary, summary_path, true);
collect_scenario_results(scenario_ids, scenario_root, batch_mode);
plot_scenario_comparison(scenario_root, batch_mode);
fprintf('场景批处理完成：%s\n', summary_path);
end

function expected_options = build_expected_options(run_options, batch_mode)
expected_options = struct();
expected_options.expected_markov_trials_per_initial_fault = run_options.markov_num_trials_per_initial_fault;
expected_options.expected_batch_mode = batch_mode;
if isfield(run_options, 'allow_smoke_reuse')
    expected_options.allow_smoke_reuse = logical(run_options.allow_smoke_reuse);
else
    expected_options.allow_smoke_reuse = strcmp(batch_mode, 'smoke') || ...
        (strcmp(batch_mode, 'topology_compare') && run_options.markov_num_trials_per_initial_fault == 5);
end
end

function run_options = fill_default_run_options(run_options, cfg, batch_mode)
if ~isfield(run_options, 'batch_mode')
    run_options.batch_mode = batch_mode;
end
if ~isfield(run_options, 'resume_existing')
    run_options.resume_existing = true;
end
if ~isfield(run_options, 'force_rerun')
    run_options.force_rerun = false;
end
if ~isfield(run_options, 'markov_num_trials_per_initial_fault')
    run_options.markov_num_trials_per_initial_fault = cfg.markov_num_trials_per_initial_fault;
end
if ~isfield(run_options, 'smoke_note')
    run_options.smoke_note = "batch_mode=" + string(batch_mode);
end
end

function row = add_batch_columns(result_table, batch_mode, execution_status, completion_status, missing_files, note, ...
    expected_trials, existing_trials, reuse_allowed, reuse_decision_reason)
result_table.batch_mode = repmat(string(batch_mode), height(result_table), 1);
result_table.execution_status = repmat(string(execution_status), height(result_table), 1);
result_table.completion_status = repmat(string(completion_status), height(result_table), 1);
result_table.expected_markov_trials_per_initial_fault = repmat(expected_trials, height(result_table), 1);
result_table.existing_markov_trials_per_initial_fault = repmat(existing_trials, height(result_table), 1);
result_table.reuse_allowed = repmat(logical(reuse_allowed), height(result_table), 1);
result_table.reuse_decision_reason = repmat(string(reuse_decision_reason), height(result_table), 1);
result_table.missing_files = repmat(string(missing_files), height(result_table), 1);
if strlength(string(result_table.note(1))) == 0 && strlength(string(note)) > 0
    result_table.note(1) = string(note);
end
front = {'scenario_id', 'batch_mode', 'execution_status', 'completion_status', ...
    'expected_markov_trials_per_initial_fault', 'existing_markov_trials_per_initial_fault', ...
    'reuse_allowed', 'reuse_decision_reason'};
remaining = setdiff(result_table.Properties.VariableNames, front, 'stable');
row = result_table(:, [front, remaining]);
end

function scenario_result = read_existing_scenario_result(scenario_id, scenario_root, cfg)
scenario_dir = fullfile(scenario_root, scenario_id);
scenario = load(fullfile(scenario_dir, 'config', 'scenario_used.mat'), 'scenario');
scenario = scenario.scenario;
cfg_used = cfg;
cfg_used_path = fullfile(scenario_dir, 'config', 'cfg_used.mat');
if exist(cfg_used_path, 'file')
    loaded_cfg = load(cfg_used_path, 'cfg');
    if isfield(loaded_cfg, 'cfg')
        cfg_used = loaded_cfg.cfg;
    end
end
basecase = readtable(fullfile(scenario_dir, 'tables', 'basecase_validation.csv'));
basecase_converged = logical(basecase.basecase_converged(1));

scenario_result = struct('scenario_id', string(scenario_id), ...
    'total_wind_capacity_mw', scenario.total_wind_capacity_mw, ...
    'wind_buses', join_vector(scenario.wind_buses), ...
    'wind_speed_mps', scenario.wind_speed_mps, ...
    'renewable_dispatch_mode', string(scenario.renewable_dispatch_mode), ...
    'total_wind_output_mw', get_scalar_from_basecase(basecase, 'total_wind_output_mw'), ...
    'wind_capacity_factor', calc_capacity_factor(get_scalar_from_basecase(basecase, 'total_wind_output_mw'), scenario.total_wind_capacity_mw), ...
    'basecase_slack_pg_mw', get_scalar_from_basecase(basecase, 'slack_pg_mw'), ...
    'basecase_overloaded_line_count', get_scalar_from_basecase(basecase, 'base_overloaded_line_count'), ...
    'basecase_voltage_violation_count', get_scalar_from_basecase(basecase, 'base_voltage_violation_count'), ...
    'markov_trials_per_initial_fault', cfg_used.markov_num_trials_per_initial_fault, ...
    'basecase_converged', basecase_converged, ...
    'chain_count', read_table_height(fullfile(scenario_dir, 'tables', 'markov_chain_summary.csv')), ...
    'invalid_stage_ratio', read_invalid_stage_ratio(scenario_dir), ...
    'basic_CRI_095', read_cri(fullfile(scenario_dir, 'tables', 'markov_var_metrics.csv')), ...
    'weighted_CRI_095', read_cri(fullfile(scenario_dir, 'tables', 'markov_var_metrics_weighted.csv')), ...
    'paper_CRI_095', NaN, ...
    'run_status', "success", ...
    'basic_result_status', "valid", ...
    'weighted_result_status', "valid", ...
    'paper_result_status', "not_available", ...
    'overall_status', "failed", ...
    'note', "");
[scenario_result.paper_CRI_095, scenario_result.paper_result_status, paper_note] = ...
    read_paper_status(fullfile(scenario_dir, 'tables', 'markov_var_metrics_paper_severity.csv'));
if scenario_result.paper_result_status == "valid"
    scenario_result.overall_status = "success_all_valid";
elseif scenario_result.paper_result_status == "diagnostic_only"
    scenario_result.overall_status = "success_with_diagnostic_paper";
    scenario_result.note = paper_note;
end
end

function result = init_failed_batch_result(scenario_id, cfg, ME)
result = struct('scenario_id', string(scenario_id), 'total_wind_capacity_mw', NaN, ...
    'wind_buses', "", 'wind_speed_mps', NaN, 'renewable_dispatch_mode', "", ...
    'total_wind_output_mw', NaN, 'wind_capacity_factor', NaN, ...
    'basecase_slack_pg_mw', NaN, 'basecase_overloaded_line_count', NaN, ...
    'basecase_voltage_violation_count', NaN, ...
    'markov_trials_per_initial_fault', cfg.markov_num_trials_per_initial_fault, ...
    'basecase_converged', false, 'chain_count', 0, 'invalid_stage_ratio', NaN, ...
    'basic_CRI_095', NaN, 'weighted_CRI_095', NaN, 'paper_CRI_095', NaN, ...
    'run_status', "failed", 'basic_result_status', "failed", ...
    'weighted_result_status', "failed", 'paper_result_status', "failed", ...
    'overall_status', "failed", 'note', string(ME.message));
end

function n = read_table_height(path)
if exist(path, 'file')
    n = height(readtable(path));
else
    n = 0;
end
end

function value = read_invalid_stage_ratio(scenario_dir)
path = fullfile(scenario_dir, 'tables', 'markov_paper_invalid_stage_summary.csv');
if exist(path, 'file')
    tbl = readtable(path);
    value = tbl.invalid_stage_ratio(1);
else
    value = NaN;
end
end

function value = read_cri(path)
if ~exist(path, 'file')
    value = NaN;
    return;
end
tbl = readtable(path);
idx = find(abs(tbl.sigma - 0.95) < 1e-9, 1);
if isempty(idx)
    value = NaN;
else
    value = tbl.CRI(idx);
end
end

function [value, status, note] = read_paper_status(path)
value = NaN;
status = "not_available";
note = "";
if ~exist(path, 'file')
    return;
end
tbl = readtable(path);
statuses = string(tbl.result_status);
if any(statuses == "diagnostic_only")
    status = "diagnostic_only";
elseif all(statuses == "valid")
    status = "valid";
else
    status = "failed";
end
idx = find(abs(tbl.sigma - 0.95) < 1e-9, 1);
if ~isempty(idx)
    value = tbl.CRI(idx);
    if ismember('note', tbl.Properties.VariableNames)
        note = string(tbl.note(idx));
    end
end
end

function trials = read_existing_trials_for_batch(scenario_id, scenario_root)
trials = NaN;
cfg_path = fullfile(scenario_root, scenario_id, 'config', 'cfg_used.mat');
if exist(cfg_path, 'file')
    data = load(cfg_path, 'cfg');
    if isfield(data, 'cfg') && isfield(data.cfg, 'markov_num_trials_per_initial_fault')
        trials = data.cfg.markov_num_trials_per_initial_fault;
        return;
    end
end
summary_path = fullfile(scenario_root, scenario_id, 'tables', 'markov_chain_summary.csv');
if exist(summary_path, 'file')
    tbl = readtable(summary_path);
    if ismember('initial_branch', tbl.Properties.VariableNames) && height(tbl) > 0
        trials = height(tbl) / numel(unique(tbl.initial_branch));
    end
end
end

function s = join_vector(v)
if isempty(v)
    s = "";
else
    s = strjoin(string(v(:).'), ',');
end
end

function value = get_scalar_from_basecase(basecase, field_name)
if ismember(field_name, basecase.Properties.VariableNames) && height(basecase) >= 1
    value = basecase.(field_name)(1);
else
    value = NaN;
end
end

function factor = calc_capacity_factor(output_mw, capacity_mw)
if capacity_mw > 0
    factor = output_mw / capacity_mw;
else
    factor = NaN;
end
end
