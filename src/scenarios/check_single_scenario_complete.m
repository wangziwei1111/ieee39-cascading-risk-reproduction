function [is_complete, completion_status, missing_files, note] = check_single_scenario_complete(scenario_id, scenario_root, expected_options)
%CHECK_SINGLE_SCENARIO_COMPLETE 检查单个场景输出是否完整且满足复用条件。
% 输入：
%   scenario_id - 场景编号。
%   scenario_root - results/scenarios目录。
%   expected_options - 可选结构体，含expected_markov_trials_per_initial_fault、expected_batch_mode、allow_smoke_reuse。
% 输出：
%   is_complete - 是否具备完整且允许复用的输出。
%   completion_status - all_valid_complete/diagnostic_paper_complete/incomplete_trial_count_mismatch/incomplete。
%   missing_files - 缺失文件列表字符串。
%   note - 诊断说明。
% 物理含义：
%   断点续跑不仅检查文件齐全，还检查Markov样本数是否与当前批次一致，避免5-trial smoke结果混入20-trial扫描。

if nargin < 3 || isempty(expected_options)
    expected_options = struct();
end
if ~isfield(expected_options, 'allow_smoke_reuse')
    expected_options.allow_smoke_reuse = true;
end

scenario_dir = fullfile(scenario_root, scenario_id);
required_files = { ...
    fullfile('tables', 'basecase_validation.csv'), ...
    fullfile('tables', 'minimal_result.csv'), ...
    fullfile('tables', 'markov_chain_summary.csv'), ...
    fullfile('tables', 'markov_var_metrics.csv'), ...
    fullfile('tables', 'markov_var_metrics_weighted.csv'), ...
    fullfile('tables', 'markov_var_metrics_paper_severity.csv'), ...
    fullfile('tables', 'markov_paper_invalid_stage_summary.csv'), ...
    fullfile('tables', 'var_uniform_vs_weighted_comparison.csv'), ...
    fullfile('tables', 'basic_vs_paper_severity_comparison.csv'), ...
    fullfile('chains', 'markov_chain_records.mat'), ...
    fullfile('config', 'scenario_used.mat'), ...
    fullfile('config', 'cfg_used.mat'), ...
    fullfile('logs', 'scenario_run_log.txt') ...
    };

missing = strings(0, 1);
for k = 1:numel(required_files)
    file_path = fullfile(scenario_dir, required_files{k});
    if ~exist(file_path, 'file')
        missing(end + 1, 1) = string(required_files{k}); %#ok<AGROW>
    end
end

if ~isempty(missing)
    is_complete = false;
    completion_status = "incomplete";
    missing_files = strjoin(missing, '; ');
    note = "missing required files";
    return;
end

[existing_trials, trial_note] = read_existing_trial_count(scenario_dir);
if isfield(expected_options, 'expected_markov_trials_per_initial_fault') && ...
        ~isempty(expected_options.expected_markov_trials_per_initial_fault)
    expected_trials = expected_options.expected_markov_trials_per_initial_fault;
    trial_mismatch = existing_trials ~= expected_trials;
    if expected_options.allow_smoke_reuse && existing_trials >= expected_trials
        trial_mismatch = false;
    end
    if trial_mismatch
        is_complete = false;
        completion_status = "incomplete_trial_count_mismatch";
        missing_files = "";
        note = sprintf('existing_trials=%g expected_trials=%g; %s', existing_trials, expected_trials, trial_note);
        return;
    end
end
if ~expected_options.allow_smoke_reuse && existing_trials == 5 && ...
        isfield(expected_options, 'expected_markov_trials_per_initial_fault') && ...
        expected_options.expected_markov_trials_per_initial_fault ~= 5
    is_complete = false;
    completion_status = "incomplete_trial_count_mismatch";
    missing_files = "";
    note = sprintf('smoke reuse is not allowed; existing_trials=%g expected_trials=%g', ...
        existing_trials, expected_options.expected_markov_trials_per_initial_fault);
    return;
end

paper_path = fullfile(scenario_dir, 'tables', 'markov_var_metrics_paper_severity.csv');
try
    paper_var = readtable(paper_path);
    if ~ismember('result_status', paper_var.Properties.VariableNames)
        is_complete = false;
        completion_status = "incomplete";
        missing_files = "";
        note = "paper result_status column missing";
        return;
    end
    statuses = string(paper_var.result_status);
    if any(statuses == "diagnostic_only")
        is_complete = true;
        completion_status = "diagnostic_paper_complete";
        note = read_note_from_paper_var(paper_var);
    elseif all(statuses == "valid")
        is_complete = true;
        completion_status = "all_valid_complete";
        note = sprintf('existing_trials=%g matches expected trials', existing_trials);
    else
        is_complete = false;
        completion_status = "incomplete";
        note = "paper result_status is neither valid nor diagnostic_only";
    end
catch ME
    is_complete = false;
    completion_status = "incomplete";
    note = "cannot read paper VaR: " + string(ME.message);
end
missing_files = "";
end

function [trials, note] = read_existing_trial_count(scenario_dir)
trials = NaN;
note = "";
cfg_path = fullfile(scenario_dir, 'config', 'cfg_used.mat');
if exist(cfg_path, 'file')
    data = load(cfg_path, 'cfg');
    if isfield(data, 'cfg') && isfield(data.cfg, 'markov_num_trials_per_initial_fault')
        trials = data.cfg.markov_num_trials_per_initial_fault;
        note = "read from cfg_used.mat";
        return;
    end
end
summary_path = fullfile(scenario_dir, 'tables', 'markov_chain_summary.csv');
if exist(summary_path, 'file')
    summary = readtable(summary_path);
    if ismember('initial_branch', summary.Properties.VariableNames)
        trials = height(summary) / numel(unique(summary.initial_branch));
        note = "inferred from markov_chain_summary.csv";
        return;
    end
end
note = "unable to read existing trial count";
end

function note = read_note_from_paper_var(paper_var)
if ismember('note', paper_var.Properties.VariableNames)
    idx = find(string(paper_var.result_status) == "diagnostic_only", 1);
    if isempty(idx)
        note = "";
    else
        note = string(paper_var.note(idx));
    end
else
    note = "paper_formula diagnostic_only";
end
end
