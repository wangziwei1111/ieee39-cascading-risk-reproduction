function main_check_markov_outputs()
%MAIN_CHECK_MARKOV_OUTPUTS 自检Markov事故链与经验VaR输出文件。
% 输入：
%   无。读取results目录下已生成的CSV文件。
% 输出：
%   无。检查失败时报错；检查通过时打印中文报告。
% 物理含义：
%   在进入更复杂的论文对照前，先确认事故链样本、候选线路抽样明细和
%   经验VaR结果均完整可追溯。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

cfg = base_config();
cfg.results_table_dir = fullfile(project_root, cfg.results_table_dir);

summary_path = fullfile(cfg.results_table_dir, 'markov_chain_summary.csv');
stage_path = fullfile(cfg.results_table_dir, 'markov_chain_stages.csv');
candidate_path = fullfile(cfg.results_table_dir, 'markov_candidate_details.csv');
risk_sample_path = fullfile(cfg.results_table_dir, 'markov_risk_samples.csv');
var_path = fullfile(cfg.results_table_dir, 'markov_var_metrics.csv');
by_initial_path = fullfile(cfg.results_table_dir, 'markov_var_by_initial_fault.csv');

must_exist(summary_path);
must_exist(stage_path);
must_exist(candidate_path);
must_exist(risk_sample_path);
must_exist(var_path);
must_exist(by_initial_path);

summary_table = readtable(summary_path);
stage_table = readtable(stage_path);
candidate_table = readtable(candidate_path);
risk_samples = readtable(risk_sample_path);
var_table = readtable(var_path);
by_initial_table = readtable(by_initial_path);

expected_summary_rows = 46 * cfg.markov_num_trials_per_initial_fault;
if height(summary_table) ~= expected_summary_rows
    error('markov_chain_summary.csv行数应为%d，实际为%d。', expected_summary_rows, height(summary_table));
end
if isempty(stage_table)
    error('markov_chain_stages.csv为空。');
end
if isempty(candidate_table)
    error('markov_candidate_details.csv为空。');
end
if max(candidate_table.outage_probability) <= cfg.line_outage_p0
    error('候选线路最大停运概率未高于基础概率line_outage_p0。');
end
if ~any(candidate_table.trip_selected == 1)
    error('候选线路明细中不存在trip_selected=1的记录。');
end
if height(risk_samples) ~= height(summary_table)
    error('markov_risk_samples.csv行数应与markov_chain_summary.csv一致。');
end
required_sigmas = cfg.var_confidence_levels(:);
for i = 1:numel(required_sigmas)
    if ~any(abs(var_table.sigma - required_sigmas(i)) < 1e-12)
        error('markov_var_metrics.csv缺少sigma=%.2f。', required_sigmas(i));
    end
end
if height(by_initial_table) ~= 46
    error('markov_var_by_initial_fault.csv应包含46条初始线路，实际为%d。', height(by_initial_table));
end

fprintf('Markov输出自检通过。\n');
fprintf('事故链汇总行数：%d\n', height(summary_table));
fprintf('事故链逐级状态行数：%d\n', height(stage_table));
fprintf('候选线路明细行数：%d\n', height(candidate_table));
fprintf('抽中停运候选数量：%d\n', sum(candidate_table.trip_selected == 1));
fprintf('最大候选线路负载率：%.6f\n', max(candidate_table.loading_pu));
fprintf('最大候选线路停运概率：%.6f\n', max(candidate_table.outage_probability));
fprintf('风险样本行数：%d\n', height(risk_samples));
fprintf('VaR置信水平：%s\n', mat2str(var_table.sigma'));
fprintf('分初始线路风险行数：%d\n', height(by_initial_table));
end

function must_exist(path_text)
%MUST_EXIST 检查文件是否存在。
% 输入：
%   path_text - 文件路径。
% 输出：
%   无。文件不存在时报错。
% 物理含义：
%   输出文件缺失时应立即停止，避免后续误读旧结果。

if ~exist(path_text, 'file')
    error('缺少输出文件：%s', path_text);
end
end
