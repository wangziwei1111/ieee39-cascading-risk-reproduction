function main_run_markov_line()
%MAIN_RUN_MARKOV_LINE 运行线路停运概率驱动的马尔可夫事故链搜索。
% 输入：
%   无。使用config/base_config.m和config/scenario_config.m中的配置。
% 输出：
%   results/tables/markov_chain_summary.csv - 每条事故链一行的汇总结果。
%   results/tables/markov_chain_stages.csv - 每条事故链逐级状态记录。
%   results/chains/markov_chain_records.mat - 保留完整候选线路表的MAT文件。
%   results/logs/markov_line_run_log.txt - 运行日志。
% 物理含义：
%   本入口在N-1基础上，根据线路负载率计算后续线路停运概率，通过随机
%   抽样形成多级N-1-1-...事故链。当前不计算论文VaR指标。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

cfg = base_config();
cfg.results_table_dir = fullfile(project_root, cfg.results_table_dir);
cfg.results_log_dir = fullfile(project_root, cfg.results_log_dir);
cfg.results_chain_dir = fullfile(project_root, cfg.results_chain_dir);
if isfield(cfg, 'results_figure_dir')
    cfg.results_figure_dir = fullfile(project_root, cfg.results_figure_dir);
end
scenario = scenario_config();

init_random_seed(cfg.markov_random_seed);

if ~exist(cfg.results_table_dir, 'dir')
    mkdir(cfg.results_table_dir);
end
if ~exist(cfg.results_log_dir, 'dir')
    mkdir(cfg.results_log_dir);
end
if ~exist(cfg.results_chain_dir, 'dir')
    mkdir(cfg.results_chain_dir);
end

log_path = fullfile(cfg.results_log_dir, 'markov_line_run_log.txt');
if exist(log_path, 'file')
    delete(log_path);
end
diary(log_path);
diary on;
cleanup_obj = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('线路马尔可夫事故链搜索开始：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf('场景：%s\n', scenario.name);
fprintf('新能源调度模式：%s\n', scenario.renewable_dispatch_mode);
fprintf('随机种子：%d\n', cfg.markov_random_seed);
fprintf('每个初始故障样本数：%d，最大深度：%d\n', ...
    cfg.markov_num_trials_per_initial_fault, cfg.markov_max_depth);

require_matpower(cfg);

base_mpc = build_case39_base(cfg);
[mpc, renewable_info] = apply_renewable_scenario(base_mpc, scenario);
faults = enumerate_initial_faults(mpc);

num_chains = height(faults) * cfg.markov_num_trials_per_initial_fault;
chain_cells = cell(num_chains, 1);
idx = 0;

for f = 1:height(faults)
    initial_branch = faults.branch_index(f);
    for trial_id = 1:cfg.markov_num_trials_per_initial_fault
        idx = idx + 1;
        chain_cells{idx} = search_cascade_markov_line( ...
            mpc, initial_branch, cfg, scenario, renewable_info, trial_id);
    end
    fprintf('已完成初始故障 %d/%d：branch %d (%d-%d)\n', ...
        f, height(faults), initial_branch, faults.from_bus(f), faults.to_bus(f));
end

chain_records = vertcat(chain_cells{:});

[chain_summary_table, chain_stage_table] = flatten_chain_records(chain_records, cfg);
candidate_detail_table = flatten_candidate_tables(chain_records);
candidate_summary_table = summarize_candidate_details(candidate_detail_table);
candidate_sample_table = build_candidate_sample(candidate_detail_table);
candidate_row_count = height(candidate_detail_table);
selected_candidate_count = 0;
max_candidate_loading = NaN;
max_candidate_probability = NaN;
if candidate_row_count > 0
    selected_candidate_count = sum(candidate_detail_table.trip_selected);
    max_candidate_loading = max(candidate_detail_table.loading_pu);
    max_candidate_probability = max(candidate_detail_table.outage_probability);
end

if candidate_row_count == 0 && sum(chain_stage_table.num_candidate_lines) > 0
    error('候选线路明细为空，但逐级结果中存在候选线路，请检查flatten_candidate_tables。');
end

summary_csv = fullfile(cfg.results_table_dir, 'markov_chain_summary.csv');
stage_csv = fullfile(cfg.results_table_dir, 'markov_chain_stages.csv');
candidate_csv = fullfile(cfg.results_table_dir, 'markov_candidate_details.csv');
candidate_summary_csv = fullfile(cfg.results_table_dir, 'markov_candidate_summary.csv');
candidate_sample_csv = fullfile(cfg.results_table_dir, 'markov_candidate_details_sample.csv');
candidate_chunk_dir = fullfile(cfg.results_table_dir, 'candidate_chunks');
candidate_manifest_csv = fullfile(cfg.results_table_dir, 'markov_candidate_details_manifest.csv');
records_mat = fullfile(cfg.results_chain_dir, 'markov_chain_records.mat');

save_result_table(chain_summary_table, summary_csv);
save_result_table(chain_stage_table, stage_csv);
if cfg.export_candidate_detail_full_csv
    save_result_table(candidate_detail_table, candidate_csv, true);
end
save_result_table(candidate_summary_table, candidate_summary_csv);
if cfg.export_candidate_detail_sample
    save_result_table(candidate_sample_table, candidate_sample_csv, true);
end
if cfg.export_candidate_detail_chunks
    manifest_table = save_table_chunks(candidate_detail_table, candidate_chunk_dir, ...
        'markov_candidate_details', cfg.candidate_detail_chunk_size);
    save_result_table(manifest_table, candidate_manifest_csv, true);
else
    manifest_table = table();
end
if cfg.export_candidate_detail_full_csv
    validate_candidate_csv(candidate_csv, candidate_detail_table);
end
validate_candidate_chunks(candidate_chunk_dir, manifest_table, candidate_detail_table, candidate_summary_table);
save(records_mat, 'chain_records', 'cfg', 'scenario', 'renewable_info', '-v7');

fprintf('候选线路明细行数：%d\n', candidate_row_count);
fprintf('抽中停运候选数量：%d\n', selected_candidate_count);
fprintf('候选线路最大负载率：%.6f\n', max_candidate_loading);
fprintf('候选线路最大停运概率：%.6f\n', max_candidate_probability);
fprintf('候选线路分块文件数量：%d\n', height(manifest_table));
fprintf('候选线路分块总行数：%d\n', sum(manifest_table.row_count));
fprintf('候选线路manifest路径：%s\n', candidate_manifest_csv);
fprintf('候选线路样本文件行数：%d\n', height(candidate_sample_table));
disp(candidate_summary_table);

fprintf('事故链汇总结果已写入：%s\n', summary_csv);
fprintf('事故链逐级结果已写入：%s\n', stage_csv);
fprintf('候选线路抽样明细已写入：%s\n', candidate_csv);
fprintf('候选线路抽样汇总已写入：%s\n', candidate_summary_csv);
fprintf('候选线路抽样样本已写入：%s\n', candidate_sample_csv);
fprintf('候选线路分块目录：%s\n', candidate_chunk_dir);
fprintf('事故链MAT记录已写入：%s\n', records_mat);
fprintf('终止原因统计：\n');
disp(groupsummary(chain_summary_table, 'terminated_reason'));
fprintf('线路马尔可夫事故链搜索结束：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
end

function candidate_sample_table = build_candidate_sample(candidate_detail_table)
%BUILD_CANDIDATE_SAMPLE 构造便于GitHub人工查看的候选线路样本表。
% 输入：
%   candidate_detail_table - 完整候选线路明细表。
% 输出：
%   candidate_sample_table - 全部抽中记录 + 概率排名前500的未抽中记录。
% 物理含义：
%   完整候选表较大，样本表用于快速检查高概率线路和抽中线路。

if isempty(candidate_detail_table) || height(candidate_detail_table) == 0
    candidate_sample_table = candidate_detail_table;
    return;
end

selected = candidate_detail_table(candidate_detail_table.trip_selected == 1, :);
unselected = candidate_detail_table(candidate_detail_table.trip_selected == 0, :);
unselected = sortrows(unselected, 'outage_probability', 'descend');
top_n = min(500, height(unselected));
candidate_sample_table = [selected; unselected(1:top_n, :)];
end

function validate_candidate_chunks(candidate_chunk_dir, manifest_table, candidate_detail_table, candidate_summary_table)
%VALIDATE_CANDIDATE_CHUNKS 校验候选线路明细分块文件。
% 输入：
%   candidate_chunk_dir - 分块目录。
%   manifest_table - 分块清单。
%   candidate_detail_table - 内存完整候选明细表。
%   candidate_summary_table - 候选汇总表。
% 输出：
%   无。任何不一致直接报错。
% 物理含义：
%   分块文件是大候选明细在GitHub上稳定复核的主要依据。

if isempty(manifest_table)
    error('候选线路分块manifest为空。');
end
if ~exist(candidate_chunk_dir, 'dir')
    error('候选线路分块目录不存在：%s', candidate_chunk_dir);
end

total_rows = 0;
has_selected = false;
max_prob = -Inf;
for i = 1:height(manifest_table)
    file_path = fullfile(candidate_chunk_dir, char(manifest_table.file_name(i)));
    if ~exist(file_path, 'file')
        error('候选线路分块文件不存在：%s', file_path);
    end
    bytes = get_file_bytes(file_path);
    if bytes ~= manifest_table.file_bytes(i)
        error('候选线路分块文件大小与manifest不一致：%s', file_path);
    end
    chunk = readtable(file_path);
    if height(chunk) ~= manifest_table.row_count(i)
        error('候选线路分块读回行数与manifest不一致：%s', file_path);
    end
    total_rows = total_rows + height(chunk);
    if any(chunk.trip_selected == 1)
        has_selected = true;
    end
    if ~isempty(chunk)
        max_prob = max(max_prob, max(chunk.outage_probability));
    end
end

if total_rows ~= height(candidate_detail_table)
    error('候选线路分块总行数%d与完整候选表%d不一致。', total_rows, height(candidate_detail_table));
end
if total_rows ~= candidate_summary_table.total_candidate_rows(1)
    error('候选线路分块总行数%d与summary总行数%d不一致。', ...
        total_rows, candidate_summary_table.total_candidate_rows(1));
end
if ~has_selected
    error('候选线路分块文件中未发现trip_selected=1记录。');
end
if max_prob <= 0
    error('候选线路分块文件最大停运概率异常。');
end
end

function validate_candidate_csv(candidate_csv, candidate_detail_table)
%VALIDATE_CANDIDATE_CSV 强制校验候选线路明细CSV落盘结果。
% 输入：
%   candidate_csv - 候选明细CSV路径。
%   candidate_detail_table - 内存中的候选明细表。
% 输出：
%   无。任何不一致直接报错。
% 物理含义：
%   防止日志显示内存表非空，但GitHub提交的CSV为空或损坏。

file_info = dir(candidate_csv);
fprintf('候选线路CSV文件大小：%d bytes\n', file_info.bytes);
candidate_readback = readtable(candidate_csv);
fprintf('候选线路CSV读回行数：%d\n', height(candidate_readback));

if height(candidate_detail_table) > 0 && height(candidate_readback) == 0
    error('候选线路CSV读回为空，但内存候选表非空。');
end
if height(candidate_readback) ~= height(candidate_detail_table)
    error('候选线路CSV读回行数%d与内存表行数%d不一致。', ...
        height(candidate_readback), height(candidate_detail_table));
end
if ~any(candidate_readback.trip_selected == 1)
    error('候选线路CSV中不存在trip_selected=1记录。');
end
end
