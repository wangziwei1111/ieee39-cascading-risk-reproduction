function main_run_markov_risk_weighted()
%MAIN_RUN_MARKOV_RISK_WEIGHTED 使用论文表4-1初始故障概率计算加权VaR。
% 输入：
%   无。读取 markov_chain_summary.csv 和用户填写的表4-1概率文件。
% 输出：
%   results/tables/markov_risk_samples_weighted.csv
%   results/tables/markov_var_metrics_weighted.csv
%   results/tables/markov_var_by_initial_fault_weighted.csv
%   results/logs/markov_risk_weighted_log.txt
% 物理含义：
%   该入口把论文表4-1线路初始停运概率映射到每条Markov事故链样本，
%   用加权经验分位数计算全局VaR。若表4-1尚未填写，必须停止并报错。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

cfg = base_config();
cfg.results_table_dir = fullfile(project_root, cfg.results_table_dir);
cfg.results_log_dir = fullfile(project_root, cfg.results_log_dir);
cfg.initial_fault_probability_mode = 'paper_table_4_1';
cfg.initial_fault_probability_file = fullfile(project_root, 'data', ...
    'line_initial_outage_probability_paper_table_4_1.csv');
cfg.var_use_chain_weights = true;
cfg.export_probability_template_if_missing = false;

if ~exist(cfg.results_table_dir, 'dir')
    mkdir(cfg.results_table_dir);
end
if ~exist(cfg.results_log_dir, 'dir')
    mkdir(cfg.results_log_dir);
end

log_path = fullfile(cfg.results_log_dir, 'markov_risk_weighted_log.txt');
log_lines = strings(0, 1);
try
    log_lines(end + 1) = "Markov加权经验VaR风险计算开始：" + string(datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    log_lines(end + 1) = "初始故障概率模式：paper_table_4_1";
    log_lines(end + 1) = "样本权重模式：true";

    summary_csv = fullfile(cfg.results_table_dir, 'markov_chain_summary.csv');
    if ~exist(summary_csv, 'file')
        error('找不到Markov事故链汇总表：%s。请先运行main_run_markov_line。', summary_csv);
    end

    require_matpower(cfg);
    base_mpc = build_case39_base(cfg);
    scenario = scenario_config();
    [mpc, ~] = apply_renewable_scenario(base_mpc, scenario);
    initial_probability_table = load_initial_line_probabilities(cfg, mpc);

    chain_summary_table = readtable(summary_csv);
    risk_samples = build_markov_risk_samples(chain_summary_table, cfg, initial_probability_table);
    markov_var_table = calc_markov_var_metrics(risk_samples, cfg);
    initial_fault_var_table = calc_markov_var_by_initial_fault(risk_samples, cfg);

    risk_samples_csv = fullfile(cfg.results_table_dir, 'markov_risk_samples_weighted.csv');
    var_metrics_csv = fullfile(cfg.results_table_dir, 'markov_var_metrics_weighted.csv');
    by_initial_csv = fullfile(cfg.results_table_dir, 'markov_var_by_initial_fault_weighted.csv');

    save_result_table(risk_samples, risk_samples_csv, true);
    save_result_table(markov_var_table, var_metrics_csv, true);
    save_result_table(initial_fault_var_table, by_initial_csv, true);

    log_lines(end + 1) = "风险样本行数：" + height(risk_samples);
    log_lines(end + 1) = "样本权重总和：" + sum(risk_samples.sample_weight);
    log_lines(end + 1) = "加权全局VaR指标已写入：" + string(var_metrics_csv);
    log_lines(end + 1) = "加权分初始线路VaR指标已写入：" + string(by_initial_csv);
    log_lines(end + 1) = "Markov加权经验VaR风险计算结束：" + string(datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    write_log(log_path, log_lines);
    fprintf('%s\n', log_lines);
    disp(markov_var_table);
catch ME
    log_lines(end + 1) = "加权VaR计算失败：" + string(ME.message);
    write_log(log_path, log_lines);
    fprintf('%s\n', log_lines);
    rethrow(ME);
end
end

function write_log(log_path, log_lines)
%WRITE_LOG 写出加权VaR运行日志。
fid = fopen(log_path, 'w', 'n', 'UTF-8');
if fid < 0
    error('无法写入日志文件：%s', log_path);
end
cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
for i = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines(i));
end
end
