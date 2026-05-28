function main_check_final_summary()
%MAIN_CHECK_FINAL_SUMMARY 复核第4章最终汇总结果包。
% 输入：
%   无。仅读取results/final_summary，不运行仿真。
% 输出：
%   results/final_summary/logs/final_summary_check_log.txt。
% 物理含义：
%   防止legacy/smoke/diagnostic_only/record_only结果在论文图表中被误用。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();
scenario_root = fullfile(project_root, cfg.scenario_results_root);
final_root = fullfile(project_root, 'results', 'final_summary');
table_dir = fullfile(final_root, 'tables');
figure_dir = fullfile(final_root, 'figures');
log_dir = fullfile(final_root, 'logs');
if ~exist(log_dir, 'dir')
    mkdir(log_dir);
end
log_file = fullfile(log_dir, 'final_summary_check_log.txt');
fid = fopen(log_file, 'w');
cleaner = onCleanup(@() fclose(fid));

overview = require_table(table_dir, 'final_scenario_overview.csv');
topology = require_table(table_dir, 'final_topology_comparison.csv');
penetration = require_table(table_dir, 'final_penetration_scan.csv');
wind_speed = require_table(table_dir, 'final_wind_speed_scan.csv');
trip = require_table(table_dir, 'final_renewable_trip_record.csv');
validity = require_table(table_dir, 'final_metric_validity_matrix.csv');
key_results = require_table(table_dir, 'final_thesis_key_results.csv');

assert_nonempty(overview, 'final_scenario_overview.csv');
assert_nonempty(topology, 'final_topology_comparison.csv');
assert_nonempty(validity, 'final_metric_validity_matrix.csv');
assert_nonempty(key_results, 'final_thesis_key_results.csv');

expected_chain_count = 46 * cfg.markov_num_trials_per_initial_fault;
if any(overview.markov_trials_per_initial_fault ~= cfg.markov_num_trials_per_initial_fault)
    error('final_scenario_overview.csv 中存在非正式 trial 数结果。');
end
if any(overview.chain_count ~= expected_chain_count)
    error('final_scenario_overview.csv 中存在 chain_count 非 %d 的结果。', expected_chain_count);
end
if any(string(overview.scenario_id) == "distributed_wind_40pct")
    error('final_scenario_overview.csv 不得包含 legacy distributed_wind_40pct。');
end
if any(string(overview.batch_mode) == "smoke")
    error('final_scenario_overview.csv 不得包含 smoke 结果。');
end

required_topology = ["no_renewable_base", "distributed_wind_3000mw_base", "centralized_wind_40pct"];
if ~all(ismember(required_topology, string(topology.scenario_id)))
    error('final_topology_comparison.csv 缺少正式拓扑对比场景。');
end
topology_summary_path = fullfile(scenario_root, 'scenario_batch_summary_topology_compare.csv');
if ~exist(topology_summary_path, 'file')
    error('缺少 topology_compare 汇总表：%s', topology_summary_path);
end
topology_summary = readtable(topology_summary_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
for k = 1:numel(required_topology)
    idx = string(topology_summary.scenario_id) == required_topology(k);
    if ~any(idx)
        error('topology_compare 汇总表缺少场景：%s', required_topology(k));
    end
    if any(topology_summary.markov_trials_per_initial_fault(idx) ~= cfg.markov_num_trials_per_initial_fault)
        error('topology_compare 场景 %s 不是正式 %d-trial 结果。', ...
            required_topology(k), cfg.markov_num_trials_per_initial_fault);
    end
end

if any(string(penetration.scenario_id) == "distributed_wind_40pct")
    error('final_penetration_scan.csv不得包含legacy distributed_wind_40pct。');
end
if any(diff(penetration.total_wind_capacity_mw) <= 0)
    error('final_penetration_scan.csv容量必须单调递增。');
end
if any(isnan(wind_speed.total_wind_output_mw))
    error('final_wind_speed_scan.csv中total_wind_output_mw不得为NaN。');
end
if any(strlength(string(trip.record_only_conclusion)) == 0)
    error('final_renewable_trip_record.csv中record_only结论不得为空。');
end
if any(string(overview.paper_result_status) == "diagnostic_only" & overview.paper_CRI_095 == 0)
    error('diagnostic_only场景的paper_CRI不得填0。');
end
if any(contains(string(key_results.scenario_or_group), "smoke"))
    error('final_thesis_key_results不得把smoke结果作为最终结果。');
end
if any(contains(string(key_results.caution), "5-trial"))
    error('final_thesis_key_results 不得引用 5-trial smoke/topology 结果。');
end

required_figures = {'final_topology_cri_comparison.png', ...
    'final_penetration_cri_curve.png', ...
    'final_wind_speed_power_and_cri.png', ...
    'final_renewable_trip_probability.png', ...
    'final_invalid_stage_ratio.png'};
for k = 1:numel(required_figures)
    fig_path = fullfile(figure_dir, required_figures{k});
    if ~exist(fig_path, 'file')
        error('缺少最终图：%s', fig_path);
    end
end

fprintf(fid, 'Final summary check passed.\n');
fprintf(fid, 'scenario_overview_rows=%d\n', height(overview));
fprintf(fid, 'topology_rows=%d\n', height(topology));
fprintf(fid, 'penetration_rows=%d\n', height(penetration));
fprintf(fid, 'wind_speed_rows=%d\n', height(wind_speed));
fprintf(fid, 'renewable_trip_record_rows=%d\n', height(trip));
fprintf(fid, 'figures_checked=%d\n', numel(required_figures));
fprintf('Final summary check passed: %s\n', log_file);
end

function tbl = require_table(table_dir, file_name)
path = fullfile(table_dir, file_name);
if ~exist(path, 'file')
    error('缺少最终汇总表：%s', path);
end
tbl = readtable(path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
end

function assert_nonempty(tbl, name)
if height(tbl) == 0
    error('%s为空。', name);
end
end
