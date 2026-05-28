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
cfg = base_config(); %#ok<NASGU>
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
penetration = require_table(table_dir, 'final_penetration_scan.csv');
wind_speed = require_table(table_dir, 'final_wind_speed_scan.csv');
trip = require_table(table_dir, 'final_renewable_trip_record.csv');
validity = require_table(table_dir, 'final_metric_validity_matrix.csv');
key_results = require_table(table_dir, 'final_thesis_key_results.csv');

assert_nonempty(overview, 'final_scenario_overview.csv');
assert_nonempty(validity, 'final_metric_validity_matrix.csv');
assert_nonempty(key_results, 'final_thesis_key_results.csv');

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
