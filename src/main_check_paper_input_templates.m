function main_check_paper_input_templates()
%MAIN_CHECK_PAPER_INPUT_TEMPLATES 检查 paper_inputs 模板和校验汇总是否完整。
% 输入：
%   无。
% 输出：
%   paper_inputs/logs/check_paper_input_templates_log.txt
% 物理含义：
%   确保原文参数录入层已经准备好，且模板没有把工程参数冒充为原文已确认参数。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root = fullfile(project_root, 'paper_inputs');
template_dir = fullfile(root, 'templates');
log_dir = fullfile(root, 'logs');
if ~exist(log_dir, 'dir')
    mkdir(log_dir);
end
if ~exist(template_dir, 'dir')
    error('缺少模板目录：%s', template_dir);
end

required = {
    'paper_case39_bus_template.csv'
    'paper_case39_gen_template.csv'
    'paper_case39_branch_template.csv'
    'paper_line_initial_outage_probability_template.csv'
    'paper_line_subsequent_outage_model_template.csv'
    'paper_wind_trip_probability_model_template.csv'
    'paper_generator_outage_model_template.csv'
    'paper_state_probability_formula_template.csv'
    'paper_risk_severity_formula_template.csv'
    'paper_scenario_definition_template.csv'
    'paper_result_benchmark_template.csv'
    'paper_load_shedding_model_template.csv'
    };
for i = 1:numel(required)
    path = fullfile(template_dir, required{i});
    if ~exist(path, 'file')
        error('缺少模板文件：%s', path);
    end
    txt = fileread(path);
    if contains(txt, '自动填充为原文参数已确认') || contains(lower(txt), 'validated thesis parameter')
        error('模板包含禁止表述：%s', path);
    end
end

bus = readtable(fullfile(template_dir, 'paper_case39_bus_template.csv'));
gen = readtable(fullfile(template_dir, 'paper_case39_gen_template.csv'));
branch = readtable(fullfile(template_dir, 'paper_case39_branch_template.csv'));
if height(bus) == 0 || height(gen) == 0 || height(branch) == 0
    error('bus/gen/branch 模板必须非空。');
end
state = readtable(fullfile(template_dir, 'paper_state_probability_formula_template.csv'), 'Delimiter', ',', 'VariableNamingRule', 'preserve');
severity = readtable(fullfile(template_dir, 'paper_risk_severity_formula_template.csv'), 'Delimiter', ',', 'VariableNamingRule', 'preserve');
if ~all(ismember(["P_wt_Ek","P_ge_Ek","P_line_Ek","P_stage_Ek","P_chain"], string(state.probability_term)))
    error('状态概率模板缺少预置行。');
end
if ~all(ismember(["LLR","LFOR","NVOR","CRI","VaR"], string(severity.risk_term)))
    error('严重度模板缺少预置行。');
end

main_validate_paper_inputs(false);
summary_path = fullfile(root, 'validated', 'paper_input_validation_summary.csv');
if ~exist(summary_path, 'file')
    error('validate 脚本未生成 paper_input_validation_summary.csv。');
end
summary = readtable(summary_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
if height(summary) ~= numel(required)
    error('paper_input_validation_summary.csv 行数应为%d，当前为%d。', numel(required), height(summary));
end

log_file = fullfile(log_dir, 'check_paper_input_templates_log.txt');
fid = fopen(log_file, 'w', 'n', 'UTF-8');
cleaner = onCleanup(@() fclose(fid));
fprintf(fid, 'Paper input templates check passed.\n');
fprintf(fid, 'template_count=%d\n', numel(required));
fprintf(fid, 'bus_rows=%d\n', height(bus));
fprintf(fid, 'gen_rows=%d\n', height(gen));
fprintf(fid, 'branch_rows=%d\n', height(branch));
fprintf(fid, 'validation_rows=%d\n', height(summary));
fprintf('Paper input templates check passed: %s\n', log_file);
end
