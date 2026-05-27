function main_check_scenario_outputs()
%MAIN_CHECK_SCENARIO_OUTPUTS 检查场景扫描smoke test输出与状态语义。
% 输入：
%   无。
% 输出：
%   无；检查失败直接error。
% 物理含义：
%   区分“程序跑完”和“paper_formula可用于论文对照”。diagnostic_only不能被误判为全有效成功。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();
scenario_root = fullfile(project_root, cfg.scenario_results_root);
summary_path = fullfile(scenario_root, 'scenario_batch_summary_smoke.csv');

if ~exist(summary_path, 'file')
    error('缺少smoke批量汇总表：%s', summary_path);
end
summary_table = readtable(summary_path);
if height(summary_table) < 3
    error('smoke批量汇总表场景数不足，当前%d行。', height(summary_table));
end

required_fields = {'run_status', 'basic_result_status', 'weighted_result_status', ...
    'paper_result_status', 'overall_status', 'note'};
missing = setdiff(required_fields, summary_table.Properties.VariableNames);
if ~isempty(missing)
    error('scenario_batch_summary_smoke缺少状态字段：%s', strjoin(missing, ', '));
end

required_subdirs = {'tables', 'logs', 'chains', 'figures', 'config'};
required_tables_for_success = {'markov_chain_summary.csv', 'markov_var_metrics.csv', ...
    'markov_var_metrics_weighted.csv', 'markov_var_metrics_paper_severity.csv', ...
    'markov_paper_invalid_stage_summary.csv'};

diagnostic_ids = strings(0, 1);
for i = 1:height(summary_table)
    scenario_id = string(summary_table.scenario_id(i));
    scenario_dir = fullfile(scenario_root, scenario_id);
    if ~exist(scenario_dir, 'dir')
        error('场景目录不存在：%s', scenario_dir);
    end
    for k = 1:numel(required_subdirs)
        subdir = fullfile(scenario_dir, required_subdirs{k});
        if ~exist(subdir, 'dir')
            error('场景子目录不存在：%s', subdir);
        end
    end

    run_status = string(summary_table.run_status(i));
    paper_status = string(summary_table.paper_result_status(i));
    overall_status = string(summary_table.overall_status(i));
    note_value = string(summary_table.note(i));

    if run_status == "failed"
        if strlength(note_value) == 0
            error('场景%s程序失败但未记录note。', scenario_id);
        end
        continue;
    end

    for k = 1:numel(required_tables_for_success)
        table_path = fullfile(scenario_dir, 'tables', required_tables_for_success{k});
        if ~exist(table_path, 'file')
            error('场景%s缺少结果表：%s', scenario_id, table_path);
        end
        if height(readtable(table_path)) == 0
            error('场景%s结果表为空：%s', scenario_id, table_path);
        end
    end

    invalid_ratio = summary_table.invalid_stage_ratio(i);
    if isnan(invalid_ratio)
        error('场景%s的invalid_stage_ratio为NaN。', scenario_id);
    end

    if isnan(summary_table.paper_CRI_095(i))
        if ~(paper_status == "diagnostic_only" || paper_status == "failed" || paper_status == "not_available")
            error('场景%s paper_CRI_095为NaN，但paper_result_status=%s。', scenario_id, paper_status);
        end
        if overall_status == "success_all_valid"
            error('场景%s paper_CRI_095为NaN，不能标记为success_all_valid。', scenario_id);
        end
    end

    paper_var_path = fullfile(scenario_dir, 'tables', 'markov_var_metrics_paper_severity.csv');
    paper_var = readtable(paper_var_path);
    if ~ismember('result_status', paper_var.Properties.VariableNames)
        error('场景%s的paper VaR缺少result_status字段。', scenario_id);
    end
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
        if overall_status ~= "success_all_valid"
            error('场景%s paper valid时overall_status应为success_all_valid。', scenario_id);
        end
    elseif paper_status == "diagnostic_only"
        diagnostic_ids(end + 1, 1) = scenario_id; %#ok<AGROW>
        if ~any(paper_rows_status == "diagnostic_only")
            error('场景%s汇总为diagnostic_only，但paper VaR无diagnostic_only行。', scenario_id);
        end
        if strlength(note_value) == 0
            error('场景%s diagnostic_only但note为空。', scenario_id);
        end
        invalid_summary_path = fullfile(scenario_dir, 'tables', 'markov_paper_invalid_stage_summary.csv');
        invalid_summary = readtable(invalid_summary_path);
        if invalid_summary.invalid_stage_ratio(1) <= cfg.paper_max_invalid_chain_ratio_for_var && ...
                ~contains(note_value, "threshold")
            error('场景%s diagnostic_only但无效阶段比例未超过阈值且note未说明其他原因。', scenario_id);
        end
        if overall_status ~= "success_with_diagnostic_paper"
            error('场景%s diagnostic_only时overall_status应为success_with_diagnostic_paper。', scenario_id);
        end
    end
end

overall = string(summary_table.overall_status);
fprintf('场景扫描smoke自检通过。\n');
fprintf('smoke场景数：%d\n', height(summary_table));
fprintf('success_all_valid 数量：%d\n', sum(overall == "success_all_valid"));
fprintf('success_with_diagnostic_paper 数量：%d\n', sum(overall == "success_with_diagnostic_paper"));
fprintf('failed 数量：%d\n', sum(overall == "failed"));
fprintf('diagnostic_only 场景列表：%s\n', strjoin(diagnostic_ids, ', '));
end
