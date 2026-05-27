function main_compare_basic_vs_paper_severity()
%MAIN_COMPARE_BASIC_VS_PAPER_SEVERITY 对比basic与paper_formula VaR结果。
% 输入：
%   无。读取markov_var_metrics.csv和markov_var_metrics_paper_severity.csv。
% 输出：
%   results/tables/basic_vs_paper_severity_comparison.csv
%   results/figures/basic_vs_paper_cri_comparison.png
% 物理含义：
%   basic指标用于流程验证；paper_formula指标按论文公式和line-only阶段概率计算。
%   二者量纲和概率处理方式不同，该对照用于说明公式切换对风险指标的影响。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

cfg = base_config();
cfg.results_table_dir = fullfile(project_root, cfg.results_table_dir);
cfg.results_figure_dir = fullfile(project_root, cfg.results_figure_dir);

basic_csv = fullfile(cfg.results_table_dir, 'markov_var_metrics.csv');
paper_csv = fullfile(cfg.results_table_dir, 'markov_var_metrics_paper_severity.csv');
if ~exist(basic_csv, 'file')
    error('找不到basic VaR结果：%s，请先运行main_run_markov_risk。', basic_csv);
end
if ~exist(paper_csv, 'file')
    error('找不到paper_formula VaR结果：%s，请先运行main_run_markov_risk_paper_severity。', paper_csv);
end

basic_table = sortrows(readtable(basic_csv), 'sigma');
paper_table = sortrows(readtable(paper_csv), 'sigma');
if height(basic_table) ~= height(paper_table) || any(abs(basic_table.sigma - paper_table.sigma) > 1e-12)
    error('basic与paper_formula VaR结果的sigma列表不一致。');
end

delta_SLLR = paper_table.SLLR - basic_table.SLLR;
delta_SLFOR = paper_table.SLFOR - basic_table.SLFOR;
delta_SNVOR = paper_table.SNVOR - basic_table.SNVOR;
delta_CRI = paper_table.CRI - basic_table.CRI;

comparison_table = table(basic_table.sigma, ...
    basic_table.SLLR, paper_table.SLLR, delta_SLLR, ...
    basic_table.SLFOR, paper_table.SLFOR, delta_SLFOR, ...
    basic_table.SNVOR, paper_table.SNVOR, delta_SNVOR, ...
    basic_table.CRI, paper_table.CRI, delta_CRI, ...
    'VariableNames', {'sigma', ...
    'basic_SLLR', 'paper_SLLR', 'delta_SLLR', ...
    'basic_SLFOR', 'paper_SLFOR', 'delta_SLFOR', ...
    'basic_SNVOR', 'paper_SNVOR', 'delta_SNVOR', ...
    'basic_CRI', 'paper_CRI', 'delta_CRI'});

comparison_csv = fullfile(cfg.results_table_dir, 'basic_vs_paper_severity_comparison.csv');
save_result_table(comparison_table, comparison_csv, true);

if ~exist(cfg.results_figure_dir, 'dir')
    mkdir(cfg.results_figure_dir);
end
fig = figure('Visible', 'off', 'Color', 'w');
plot(comparison_table.sigma, comparison_table.basic_CRI, '-o', 'LineWidth', 1.8);
hold on;
plot(comparison_table.sigma, comparison_table.paper_CRI, '-s', 'LineWidth', 1.8);
grid on;
xlabel('置信水平 sigma');
ylabel('CRI');
title('basic与paper formula VaR-CRI对比');
legend({'basic', 'paper formula line-only'}, 'Location', 'best');
saveas(fig, fullfile(cfg.results_figure_dir, 'basic_vs_paper_cri_comparison.png'));
close(fig);

fprintf('basic与paper_formula严重度对照表已写入：%s\n', comparison_csv);
end
