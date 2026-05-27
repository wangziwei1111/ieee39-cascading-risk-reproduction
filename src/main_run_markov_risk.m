function main_run_markov_risk()
%MAIN_RUN_MARKOV_RISK 基于Markov事故链样本计算经验VaR风险指标。
% 输入：
%   无。读取results/tables/markov_chain_summary.csv。
% 输出：
%   results/tables/markov_risk_samples.csv
%   results/tables/markov_var_metrics.csv
%   results/tables/markov_var_by_initial_fault.csv
%   results/logs/markov_risk_log.txt
% 物理含义：
%   将已生成的多条事故链样本转化为经验VaR风险指标。当前每条事故链
%   等权，不使用论文表4-1初始故障概率，也不做概率密度拟合。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

cfg = base_config();
cfg.results_table_dir = fullfile(project_root, cfg.results_table_dir);
cfg.results_log_dir = fullfile(project_root, cfg.results_log_dir);
cfg.results_figure_dir = fullfile(project_root, cfg.results_figure_dir);
cfg.initial_fault_probability_file = fullfile(project_root, cfg.initial_fault_probability_file);

if ~exist(cfg.results_table_dir, 'dir')
    mkdir(cfg.results_table_dir);
end
if ~exist(cfg.results_log_dir, 'dir')
    mkdir(cfg.results_log_dir);
end

log_path = fullfile(cfg.results_log_dir, 'markov_risk_log.txt');
if exist(log_path, 'file')
    delete(log_path);
end
diary(log_path);
diary on;
cleanup_obj = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('Markov经验VaR风险计算开始：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf('VaR方法：%s，置信水平：%s\n', cfg.var_method, mat2str(cfg.var_confidence_levels));
fprintf('样本权重模式：%s，初始故障概率模式：%s\n', ...
    string(cfg.var_use_chain_weights), cfg.initial_fault_probability_mode);

summary_csv = fullfile(cfg.results_table_dir, 'markov_chain_summary.csv');
if ~exist(summary_csv, 'file')
    error('找不到Markov事故链汇总表：%s。请先运行main_run_markov_line。', summary_csv);
end

chain_summary_table = readtable(summary_csv);
require_matpower(cfg);
base_mpc = build_case39_base(cfg);
initial_probability_table = load_initial_line_probabilities(cfg, base_mpc);
risk_samples = build_markov_risk_samples(chain_summary_table, cfg, initial_probability_table);
markov_var_table = calc_markov_var_metrics(risk_samples, cfg);
initial_fault_var_table = calc_markov_var_by_initial_fault(risk_samples, cfg);

risk_samples_csv = fullfile(cfg.results_table_dir, 'markov_risk_samples.csv');
var_metrics_csv = fullfile(cfg.results_table_dir, 'markov_var_metrics.csv');
by_initial_csv = fullfile(cfg.results_table_dir, 'markov_var_by_initial_fault.csv');

save_result_table(risk_samples, risk_samples_csv);
save_result_table(markov_var_table, var_metrics_csv);
save_result_table(initial_fault_var_table, by_initial_csv);

plot_markov_var_summary(markov_var_table, initial_fault_var_table, cfg);

fprintf('风险样本行数：%d\n', height(risk_samples));
fprintf('全局VaR指标已写入：%s\n', var_metrics_csv);
fprintf('初始线路分组VaR指标已写入：%s\n', by_initial_csv);
fprintf('风险样本已写入：%s\n', risk_samples_csv);
disp(markov_var_table);
fprintf('Markov经验VaR风险计算结束：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
end
