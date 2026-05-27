function summary_table = collect_scenario_results(scenario_ids, scenario_root)
%COLLECT_SCENARIO_RESULTS 汇总多个场景的VaR和诊断结果。
% 输入：
%   scenario_ids - 场景编号cell数组；为空时自动读取scenario_root下的目录。
%   scenario_root - results/scenarios目录。
% 输出：
%   summary_table - 场景结果汇总表。
% 物理含义：
%   将每个场景的basic、weighted、paper_formula VaR和无效stage比例汇总，便于第4章横向对比。

if nargin < 2 || isempty(scenario_root)
    project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    cfg = base_config();
    scenario_root = fullfile(project_root, cfg.scenario_results_root);
end
if nargin < 1 || isempty(scenario_ids)
    listing = dir(scenario_root);
    scenario_ids = {listing([listing.isdir] & ~startsWith({listing.name}, '.')).name};
end

rows = {};
for k = 1:numel(scenario_ids)
    scenario_id = scenario_ids{k};
    table_dir = fullfile(scenario_root, scenario_id, 'tables');
    config_dir = fullfile(scenario_root, scenario_id, 'config');
    if ~exist(table_dir, 'dir')
        continue;
    end
    scenario = load_scenario_metadata(config_dir);
    basecase_converged = read_basecase_status(table_dir);
    chain_count = read_table_height(fullfile(table_dir, 'markov_chain_summary.csv'));
    invalid_stage_ratio = read_invalid_stage_ratio(table_dir);
    [paper_cri, paper_status, paper_note] = read_paper_cri_status(table_dir);
    basic_cri = read_cri(table_dir, 'markov_var_metrics.csv');
    weighted_cri = read_cri(table_dir, 'markov_var_metrics_weighted.csv');
    if paper_status == "valid"
        overall_status = "success_all_valid";
    elseif paper_status == "diagnostic_only"
        overall_status = "success_with_diagnostic_paper";
    else
        overall_status = "failed";
    end
    rows{end + 1, 1} = table(string(scenario_id), scenario.total_wind_capacity_mw, ...
        string(join_vector(scenario.wind_buses)), scenario.wind_speed_mps, ...
        string(scenario.renewable_dispatch_mode), basecase_converged, chain_count, invalid_stage_ratio, ...
        basic_cri, weighted_cri, paper_cri, paper_status, overall_status, paper_note, ...
        'VariableNames', {'scenario_id', 'total_wind_capacity_mw', 'wind_buses', 'wind_speed_mps', ...
        'renewable_dispatch_mode', 'basecase_converged', 'chain_count', 'invalid_stage_ratio', ...
        'basic_CRI_095', 'weighted_CRI_095', 'paper_CRI_095', ...
        'paper_result_status', 'overall_status', 'paper_note'});
end

if isempty(rows)
    summary_table = table();
else
    summary_table = vertcat(rows{:});
end
save_result_table(summary_table, fullfile(scenario_root, 'scenario_result_summary.csv'), true);
end

function scenario = load_scenario_metadata(config_dir)
mat_path = fullfile(config_dir, 'scenario_used.mat');
if exist(mat_path, 'file')
    data = load(mat_path, 'scenario');
    scenario = data.scenario;
else
    scenario = struct('total_wind_capacity_mw', NaN, 'wind_buses', [], ...
        'wind_speed_mps', NaN, 'renewable_dispatch_mode', '');
end
end

function ok = read_basecase_status(table_dir)
path = fullfile(table_dir, 'basecase_validation.csv');
if ~exist(path, 'file')
    ok = false;
    return;
end
tbl = readtable(path);
ok = logical(tbl.basecase_converged(1));
end

function n = read_table_height(path)
if exist(path, 'file')
    n = height(readtable(path));
else
    n = 0;
end
end

function value = read_invalid_stage_ratio(table_dir)
path = fullfile(table_dir, 'markov_paper_invalid_stage_summary.csv');
if ~exist(path, 'file')
    value = NaN;
    return;
end
tbl = readtable(path);
if ismember('invalid_stage_ratio', tbl.Properties.VariableNames)
    value = tbl.invalid_stage_ratio(1);
else
    value = NaN;
end
end

function value = read_cri(table_dir, file_name)
path = fullfile(table_dir, file_name);
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

function [value, status, note] = read_paper_cri_status(table_dir)
path = fullfile(table_dir, 'markov_var_metrics_paper_severity.csv');
value = NaN;
status = "not_available";
note = "";
if ~exist(path, 'file')
    return;
end
tbl = readtable(path);
if ~ismember('result_status', tbl.Properties.VariableNames)
    status = "failed";
    note = "paper result_status column missing";
    return;
end
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

function s = join_vector(v)
if isempty(v)
    s = "";
else
    s = strjoin(string(v(:).'), ',');
end
end
