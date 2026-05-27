function comparison_table = compare_trip_record_vs_base(scenario_root)
%COMPARE_TRIP_RECORD_VS_BASE 对比record-only场景与3000MW基准场景CRI。
% 输入：
%   scenario_root - results/scenarios目录。
% 输出：
%   comparison_table - basic/weighted/paper三类VaR的CRI差异表。
% 物理含义：
%   record-only不应改变线路Markov抽样路径；若CRI存在差异，应优先检查随机数
%   序列或场景运行配置，而不是将差异解释为真实新能源脱网影响。

if nargin < 1 || isempty(scenario_root)
    project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    cfg = base_config();
    scenario_root = fullfile(project_root, cfg.scenario_results_root);
end

base_dir = fullfile(scenario_root, 'distributed_wind_3000mw_base', 'tables');
trip_dir = fullfile(scenario_root, 'distributed_wind_40pct_trip_record_only', 'tables');
metric_files = {'markov_var_metrics.csv', 'markov_var_metrics_weighted.csv', 'markov_var_metrics_paper_severity.csv'};
metric_names = {'basic', 'weighted', 'paper_formula'};

rows = {};
for k = 1:numel(metric_files)
    base_tbl = readtable(fullfile(base_dir, metric_files{k}));
    trip_tbl = readtable(fullfile(trip_dir, metric_files{k}));
    sigmas = base_tbl.sigma;
    trip_tbl = sortrows(trip_tbl, 'sigma');
    base_tbl = sortrows(base_tbl, 'sigma');
    delta = trip_tbl.CRI - base_tbl.CRI;
    note = repmat("record_only should not change line cascade; investigate RNG/config if delta is not near zero", numel(sigmas), 1);
    rows{end + 1, 1} = table(repmat(string(metric_names{k}), numel(sigmas), 1), sigmas, ...
        base_tbl.CRI, trip_tbl.CRI, delta, note, ...
        'VariableNames', {'metric_type', 'sigma', 'base_CRI', 'trip_record_CRI', 'delta_CRI', 'note'}); %#ok<AGROW>
end

comparison_table = vertcat(rows{:});
save_result_table(comparison_table, fullfile(scenario_root, 'renewable_trip_record_comparison.csv'), true);
end
