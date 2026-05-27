function main_check_scenario_outputs()
%MAIN_CHECK_SCENARIO_OUTPUTS 检查场景扫描smoke test输出。
% 输入：
%   无。
% 输出：
%   无；检查失败直接error。
% 物理含义：
%   确认每个smoke场景均在独立目录中生成Markov、VaR、paper_formula和诊断结果，避免静默跳过失败场景。

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

required_subdirs = {'tables', 'logs', 'chains', 'figures', 'config'};
required_tables = {'markov_chain_summary.csv', 'markov_var_metrics.csv', ...
    'markov_var_metrics_weighted.csv', 'markov_var_metrics_paper_severity.csv', ...
    'markov_paper_invalid_stage_summary.csv'};

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
    for k = 1:numel(required_tables)
        table_path = fullfile(scenario_dir, 'tables', required_tables{k});
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

    paper_var = readtable(fullfile(scenario_dir, 'tables', 'markov_var_metrics_paper_severity.csv'));
    if ismember('result_status', paper_var.Properties.VariableNames)
        valid_rows = string(paper_var.result_status) == "valid";
        if any(valid_rows) && any(isnan(paper_var.CRI(valid_rows)) | isinf(paper_var.CRI(valid_rows)))
            error('场景%s的有效paper VaR中存在NaN/Inf CRI。', scenario_id);
        end
    end

    status_value = string(summary_table.status(i));
    if status_value == "failed"
        note_value = string(summary_table.note(i));
        if strlength(note_value) == 0
            error('场景%s失败但未记录原因。', scenario_id);
        end
    end
end

fprintf('场景扫描smoke自检通过。\n');
fprintf('smoke场景数：%d\n', height(summary_table));
fprintf('场景目录根路径：%s\n', scenario_root);
fprintf('scenario_batch_summary_smoke 行数：%d\n', height(summary_table));
end
