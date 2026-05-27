function [is_complete, completion_status, missing_files, note] = check_single_scenario_complete(scenario_id, scenario_root)
%CHECK_SINGLE_SCENARIO_COMPLETE 检查单个场景输出是否完整。
% 输入：
%   scenario_id - 场景编号。
%   scenario_root - results/scenarios目录。
% 输出：
%   is_complete - 是否具备完整可复核输出。
%   completion_status - all_valid_complete/diagnostic_paper_complete/incomplete。
%   missing_files - 缺失文件列表字符串。
%   note - 诊断说明。
% 物理含义：
%   diagnostic_only表示场景运行完整但paper_formula不可用于论文对照；它可断点续跑跳过，
%   但不能被当成all_valid_complete。

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
        note = "";
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
