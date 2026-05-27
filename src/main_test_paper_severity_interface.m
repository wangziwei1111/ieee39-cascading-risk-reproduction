function main_test_paper_severity_interface()
%MAIN_TEST_PAPER_SEVERITY_INTERFACE 测试论文严重度函数安全接口。
% 输入：
%   无。读取 markov_chain_summary.csv。
% 输出：
%   results/logs/paper_severity_interface_log.txt
%   results/tables/severity_formula_status.csv
% 物理含义：
%   确认basic严重度可正常计算，同时确认paper公式未核对前不会静默输出伪结果。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

cfg = base_config();
cfg.results_table_dir = fullfile(project_root, cfg.results_table_dir);
cfg.results_log_dir = fullfile(project_root, cfg.results_log_dir);
cfg.severity_mode = 'both';
cfg.enable_paper_severity = true;

if ~exist(cfg.results_table_dir, 'dir')
    mkdir(cfg.results_table_dir);
end
if ~exist(cfg.results_log_dir, 'dir')
    mkdir(cfg.results_log_dir);
end

log_path = fullfile(cfg.results_log_dir, 'paper_severity_interface_log.txt');
status_csv = fullfile(cfg.results_table_dir, 'severity_formula_status.csv');
log_lines = strings(0, 1);

try
    summary_csv = fullfile(cfg.results_table_dir, 'markov_chain_summary.csv');
    if ~exist(summary_csv, 'file')
        error('找不到Markov事故链汇总表：%s。请先运行main_run_markov_line。', summary_csv);
    end
    chain_summary_table = readtable(summary_csv);

    basic_table = calc_basic_chain_severity(chain_summary_table, cfg);
    if height(basic_table) ~= height(chain_summary_table)
        error('basic严重度行数与事故链汇总行数不一致。');
    end
    log_lines(end + 1) = "basic严重度接口正常。";

    try
        calc_paper_chain_severity(chain_summary_table, cfg);
        if ~cfg.paper_severity_formula_confirmed
            error('paper公式未确认时不应成功计算。');
        end
        log_lines(end + 1) = "paper严重度公式已确认并可计算。";
    catch ME
        if cfg.paper_severity_formula_confirmed
            rethrow(ME);
        end
        log_lines(end + 1) = "捕获预期错误：" + string(ME.message);
        log_lines(end + 1) = "paper严重度公式尚未确认，需要用户补充论文公式后才能启用paper_formula。";
    end

    risk_samples_preview = build_markov_risk_samples(chain_summary_table, cfg, []);
    compare_basic_and_paper_severity(risk_samples_preview, status_csv);
    log_lines(end + 1) = "严重度公式状态表已写入：" + string(status_csv);
    write_log(log_path, log_lines);
    fprintf('%s\n', log_lines);
catch ME
    log_lines(end + 1) = "paper严重度接口测试失败：" + string(ME.message);
    write_log(log_path, log_lines);
    fprintf('%s\n', log_lines);
    rethrow(ME);
end
end

function write_log(log_path, log_lines)
%WRITE_LOG 写出paper严重度接口测试日志。
fid = fopen(log_path, 'w', 'n', 'UTF-8');
if fid < 0
    error('无法写入日志文件：%s', log_path);
end
cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
for i = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines(i));
end
end
