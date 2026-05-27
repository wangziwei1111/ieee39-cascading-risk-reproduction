function main_validate_paper_table_4_1()
%MAIN_VALIDATE_PAPER_TABLE_4_1 校验论文表4-1线路初始停运概率录入文件。
% 输入：
%   无。读取 data/line_initial_outage_probability_paper_table_4_1.csv。
% 输出：
%   results/tables/paper_table_4_1_probability_validated.csv
%   results/logs/paper_table_4_1_validation_log.txt
% 物理含义：
%   论文表4-1给出的线路初始停运概率用于事故链样本的全局权重。该脚本只校验
%   用户手动录入的数据是否完整、非负并与当前case39线路拓扑一致；若仍为NaN，
%   必须报错，不能自动编造概率。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

cfg = base_config();
cfg.results_table_dir = fullfile(project_root, cfg.results_table_dir);
cfg.results_log_dir = fullfile(project_root, cfg.results_log_dir);
cfg.initial_fault_probability_mode = 'paper_table_4_1';
cfg.initial_fault_probability_file = fullfile(project_root, 'data', ...
    'line_initial_outage_probability_paper_table_4_1.csv');
cfg.export_probability_template_if_missing = false;

if ~exist(cfg.results_table_dir, 'dir')
    mkdir(cfg.results_table_dir);
end
if ~exist(cfg.results_log_dir, 'dir')
    mkdir(cfg.results_log_dir);
end

log_path = fullfile(cfg.results_log_dir, 'paper_table_4_1_validation_log.txt');
log_lines = strings(0, 1);
try
    log_lines(end + 1) = "论文表4-1线路初始停运概率校验开始：" + string(datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    log_lines(end + 1) = "概率文件：" + string(cfg.initial_fault_probability_file);

    require_matpower(cfg);
    base_mpc = build_case39_base(cfg);
    scenario = scenario_config();
    [mpc, ~] = apply_renewable_scenario(base_mpc, scenario);

    probability_table = load_initial_line_probabilities(cfg, mpc);
    if height(probability_table) ~= size(mpc.branch, 1)
        error('表4-1校验结果行数不是46条。');
    end
    if any(isnan(probability_table.initial_outage_probability)) || ...
            any(probability_table.initial_outage_probability < 0)
        error('请先根据论文表4-1填写线路初始停运概率，不能自动编造。');
    end

    validated_csv = fullfile(cfg.results_table_dir, 'paper_table_4_1_probability_validated.csv');
    save_result_table(probability_table, validated_csv, true);

    log_lines(end + 1) = "校验通过：线路数量 = " + height(probability_table);
    log_lines(end + 1) = "归一化权重总和 = " + sum(probability_table.normalized_weight);
    log_lines(end + 1) = "结果已写入：" + string(validated_csv);
    log_lines(end + 1) = "论文表4-1线路初始停运概率校验结束：" + string(datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    write_log(log_path, log_lines);
    fprintf('%s\n', log_lines);
catch ME
    log_lines(end + 1) = "校验失败：" + string(ME.message);
    log_lines(end + 1) = "请先根据论文表4-1填写线路初始停运概率，不能自动编造。";
    write_log(log_path, log_lines);
    fprintf('%s\n', log_lines);
    rethrow(ME);
end
end

function write_log(log_path, log_lines)
%WRITE_LOG 写出校验日志。
% 输入：
%   log_path - 日志文件路径。
%   log_lines - 字符串数组，每行一条日志。
% 输出：
%   无。
fid = fopen(log_path, 'w', 'n', 'UTF-8');
if fid < 0
    error('无法写入日志文件：%s', log_path);
end
cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
for i = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines(i));
end
end
