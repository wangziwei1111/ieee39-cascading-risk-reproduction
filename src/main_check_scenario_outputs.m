function main_check_scenario_outputs(batch_mode)
%MAIN_CHECK_SCENARIO_OUTPUTS 检查指定场景批处理输出与状态语义。
% 输入：
%   batch_mode - 可选，默认smoke；例如 topology_compare。
% 输出：
%   无；检查失败直接error。
% 物理含义：
%   区分ran/skipped_existing/failed和paper valid/diagnostic_only，避免断点续跑误判。

if nargin < 1 || isempty(batch_mode)
    batch_mode = 'smoke';
end

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();
scenario_root = fullfile(project_root, cfg.scenario_results_root);
summary_path = fullfile(scenario_root, sprintf('scenario_batch_summary_%s.csv', batch_mode));

if ~exist(summary_path, 'file')
    error('缺少批量汇总表：%s', summary_path);
end
summary_table = readtable(summary_path);
if height(summary_table) == 0
    error('批量汇总表为空：%s', summary_path);
end

required_fields = {'execution_status', 'completion_status', 'run_status', ...
    'basic_result_status', 'weighted_result_status', 'paper_result_status', ...
    'overall_status', 'note', 'expected_markov_trials_per_initial_fault', ...
    'markov_trials_per_initial_fault', 'reuse_decision_reason'};
missing = setdiff(required_fields, summary_table.Properties.VariableNames);
if ~isempty(missing)
    error('批量汇总表缺少状态字段：%s', strjoin(missing, ', '));
end

diagnostic_ids = strings(0, 1);
for i = 1:height(summary_table)
    scenario_id = string(summary_table.scenario_id(i));
    execution_status = string(summary_table.execution_status(i));
    run_status = string(summary_table.run_status(i));
    paper_status = string(summary_table.paper_result_status(i));
    overall_status = string(summary_table.overall_status(i));
    note_value = string(summary_table.note(i));
    expected_trials = summary_table.expected_markov_trials_per_initial_fault(i);
    actual_trials = summary_table.markov_trials_per_initial_fault(i);

    if ~any(execution_status == ["ran", "skipped_existing", "failed"])
        error('场景%s execution_status非法：%s', scenario_id, execution_status);
    end

    if execution_status == "failed" || run_status == "failed"
        if strlength(note_value) == 0
            error('场景%s失败但note为空。', scenario_id);
        end
        continue;
    end

    if execution_status == "skipped_existing"
        expected_options = struct('expected_markov_trials_per_initial_fault', expected_trials, ...
            'expected_batch_mode', batch_mode, ...
            'allow_smoke_reuse', strcmp(batch_mode, 'smoke') || strcmp(batch_mode, 'topology_compare'));
        [is_complete, completion_status, missing_files, complete_note] = ...
            check_single_scenario_complete(scenario_id, scenario_root, expected_options);
        if ~is_complete
            error('场景%s标记为skipped_existing但完整性检查失败：%s %s', ...
                scenario_id, missing_files, complete_note);
        end
        if string(completion_status) == "incomplete_trial_count_mismatch"
            error('场景%s skipped_existing但trial数不匹配。', scenario_id);
        end
        if string(summary_table.completion_status(i)) ~= completion_status
            error('场景%s completion_status与完整性检查不一致。', scenario_id);
        end
        if ~contains(string(summary_table.reuse_decision_reason(i)), "matches expected") && ...
                ~contains(string(summary_table.reuse_decision_reason(i)), "threshold")
            error('场景%s skipped_existing但reuse_decision_reason未说明trial匹配或诊断原因。', scenario_id);
        end
    end

    if any(strcmp(batch_mode, {'penetration_scan', 'wind_speed_scan', 'all_full'})) && ...
            execution_status ~= "failed"
        if actual_trials ~= expected_trials
            error('场景%s属于%s，但actual_trials=%g expected_trials=%g，禁止混入smoke结果。', ...
                scenario_id, batch_mode, actual_trials, expected_trials);
        end
    end

    if isnan(summary_table.paper_CRI_095(i))
        if ~(paper_status == "diagnostic_only" || paper_status == "failed" || paper_status == "not_available")
            error('场景%s paper_CRI_095为NaN，但paper_result_status=%s。', scenario_id, paper_status);
        end
        if overall_status == "success_all_valid"
            error('场景%s paper_CRI_095为NaN，不能标记为success_all_valid。', scenario_id);
        end
    end

    paper_var_path = fullfile(scenario_root, scenario_id, 'tables', 'markov_var_metrics_paper_severity.csv');
    paper_var = readtable(paper_var_path);
    paper_rows_status = string(paper_var.result_status);
    idx095 = find(abs(paper_var.sigma - 0.95) < 1e-9, 1);
    if isempty(idx095)
        error('场景%s的paper VaR缺少sigma=0.95。', scenario_id);
    end

    if paper_status == "valid"
        if isnan(summary_table.paper_CRI_095(i)) || isinf(summary_table.paper_CRI_095(i))
            error('场景%s paper_result_status=valid但paper_CRI_095无效。', scenario_id);
        end
        if paper_rows_status(idx095) ~= "valid"
            error('场景%s汇总为valid，但paper VaR sigma=0.95不是valid。', scenario_id);
        end
    elseif paper_status == "diagnostic_only"
        diagnostic_ids(end + 1, 1) = scenario_id; %#ok<AGROW>
        if ~any(paper_rows_status == "diagnostic_only")
            error('场景%s汇总为diagnostic_only，但paper VaR无diagnostic_only行。', scenario_id);
        end
        if overall_status ~= "success_with_diagnostic_paper"
            error('场景%s diagnostic_only时overall_status必须是success_with_diagnostic_paper。', scenario_id);
        end
        if strlength(note_value) == 0
            error('场景%s diagnostic_only但note为空。', scenario_id);
        end
        invalid_summary = readtable(fullfile(scenario_root, scenario_id, 'tables', 'markov_paper_invalid_stage_summary.csv'));
        if invalid_summary.invalid_stage_ratio(1) <= cfg.paper_max_invalid_chain_ratio_for_var && ...
                ~contains(note_value, "threshold")
            error('场景%s diagnostic_only但无效阶段比例未超过阈值且note未说明其他原因。', scenario_id);
        end
    end
end

execution = string(summary_table.execution_status);
overall = string(summary_table.overall_status);
fprintf('场景批处理自检通过。\n');
fprintf('batch_mode：%s\n', batch_mode);
fprintf('场景数：%d\n', height(summary_table));
fprintf('ran 数量：%d\n', sum(execution == "ran"));
fprintf('skipped_existing 数量：%d\n', sum(execution == "skipped_existing"));
fprintf('failed 数量：%d\n', sum(execution == "failed"));
fprintf('success_all_valid 数量：%d\n', sum(overall == "success_all_valid"));
fprintf('success_with_diagnostic_paper 数量：%d\n', sum(overall == "success_with_diagnostic_paper"));
fprintf('diagnostic_only 场景列表：%s\n', strjoin(diagnostic_ids, ', '));
end
