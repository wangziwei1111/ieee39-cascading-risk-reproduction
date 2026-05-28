function plot_final_summary_figures(final_root, cfg)
%PLOT_FINAL_SUMMARY_FIGURES 绘制第4章最终汇总图。
% 输入：
%   final_root - results/final_summary 目录。
%   cfg - 全局配置，用于读取 paper 无效阶段阈值。
% 输出：
%   results/final_summary/figures 下的论文可用 PNG 图。
% 物理含义：
%   仅根据 final_summary 表格作图，不重新运行任何仿真。

table_dir = fullfile(final_root, 'tables');
figure_dir = fullfile(final_root, 'figures');
if ~exist(figure_dir, 'dir')
    mkdir(figure_dir);
end

plot_topology(table_dir, figure_dir);
plot_penetration(table_dir, figure_dir);
plot_wind_speed(table_dir, figure_dir);
plot_trip_probability(table_dir, figure_dir);
plot_invalid_stage_ratio(table_dir, figure_dir, cfg);
end

function plot_topology(table_dir, figure_dir)
tbl = readtable(fullfile(table_dir, 'final_topology_comparison.csv'));
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 980, 460]);
x = 1:height(tbl);
bar(x, [tbl.basic_CRI_095, tbl.weighted_CRI_095, tbl.paper_CRI_095]);
grid on;
set(gca, 'XTick', x, 'XTickLabel', tbl.scenario_id, 'XTickLabelRotation', 20);
ylabel('CRI (\sigma=0.95)');
title('Topology / connection-mode risk comparison');
legend({'basic', 'weighted', 'paper formula'}, 'Location', 'best');
saveas(fig, fullfile(figure_dir, 'final_topology_cri_comparison.png'));
close(fig);
end

function plot_penetration(table_dir, figure_dir)
tbl = readtable(fullfile(table_dir, 'final_penetration_scan.csv'));
fig = figure('Visible', 'off', 'Color', 'w');
plot(tbl.penetration_percent, tbl.basic_CRI_095, '-o', 'LineWidth', 1.5);
hold on;
plot(tbl.penetration_percent, tbl.weighted_CRI_095, '-s', 'LineWidth', 1.5);
paper = tbl.paper_CRI_095;
paper(string(tbl.paper_result_status) ~= "valid") = NaN;
plot(tbl.penetration_percent, paper, '-^', 'LineWidth', 1.5);
grid on;
xlabel('Renewable penetration (%)');
ylabel('CRI (\sigma=0.95)');
title({'Penetration scan risk curve', 'Definition: wind capacity / system load, to be calibrated'});
legend({'basic', 'weighted', 'paper formula'}, 'Location', 'best');
saveas(fig, fullfile(figure_dir, 'final_penetration_cri_curve.png'));
close(fig);
end

function plot_wind_speed(table_dir, figure_dir)
tbl = readtable(fullfile(table_dir, 'final_wind_speed_scan.csv'));
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 980, 720]);
subplot(2, 1, 1);
plot(tbl.wind_speed_mps, tbl.total_wind_output_mw, '-o', 'LineWidth', 1.5);
grid on;
xlabel('Wind speed (m/s)');
ylabel('Wind output (MW)');
title('Wind speed vs. actual wind output (3000MW capacity)');
subplot(2, 1, 2);
plot(tbl.wind_speed_mps, tbl.basic_CRI_095, '-o', 'LineWidth', 1.5);
hold on;
plot(tbl.wind_speed_mps, tbl.weighted_CRI_095, '-s', 'LineWidth', 1.5);
paper = tbl.paper_CRI_095;
paper(string(tbl.paper_result_status) ~= "valid") = NaN;
plot(tbl.wind_speed_mps, paper, '-^', 'LineWidth', 1.5);
grid on;
xlabel('Wind speed (m/s)');
ylabel('CRI (\sigma=0.95)');
title('Risk metrics under different wind speeds');
legend({'basic', 'weighted', 'paper formula'}, 'Location', 'best');
saveas(fig, fullfile(figure_dir, 'final_wind_speed_power_and_cri.png'));
close(fig);
end

function plot_trip_probability(table_dir, figure_dir)
detail_path = fullfile(fileparts(fileparts(table_dir)), 'scenarios', ...
    'distributed_wind_40pct_trip_record_only', 'tables', 'wind_trip_probability_details.csv');
if ~exist(detail_path, 'file')
    detail_path = fullfile(pwd, 'results', 'scenarios', ...
        'distributed_wind_40pct_trip_record_only', 'tables', 'wind_trip_probability_details.csv');
end
detail = readtable(detail_path);
wind_buses = unique(detail.wind_bus);
max_prob = nan(numel(wind_buses), 1);
p95_prob = nan(numel(wind_buses), 1);
for k = 1:numel(wind_buses)
    p = detail.trip_probability(detail.wind_bus == wind_buses(k));
    max_prob(k) = max(p, [], 'omitnan');
    p95_prob(k) = percentile_local(p, 95);
end
fig = figure('Visible', 'off', 'Color', 'w');
bar(categorical(string(wind_buses)), [max_prob, p95_prob]);
grid on;
xlabel('Wind connection bus');
ylabel('Trip probability diagnostic value');
title({'Wind voltage trip probability record', 'If no sample enters the trip region, the curve remains zero'});
legend({'max', 'p95'}, 'Location', 'best');
saveas(fig, fullfile(figure_dir, 'final_renewable_trip_probability.png'));
close(fig);
end

function plot_invalid_stage_ratio(table_dir, figure_dir, cfg)
overview = readtable(fullfile(table_dir, 'final_scenario_overview.csv'));
valid_rows = ~isnan(overview.invalid_stage_ratio);
tbl = overview(valid_rows, :);
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1200, 460]);
x = 1:height(tbl);
bar(x, tbl.invalid_stage_ratio);
hold on;
yline(cfg.paper_max_invalid_chain_ratio_for_var, 'r--', 'LineWidth', 1.5);
grid on;
set(gca, 'XTick', x, 'XTickLabel', tbl.scenario_id, 'XTickLabelRotation', 30);
ylabel('invalid stage ratio');
title('paper\_formula invalid-stage ratio diagnostic');
legend({'invalid stage ratio', 'threshold'}, 'Location', 'best');
saveas(fig, fullfile(figure_dir, 'final_invalid_stage_ratio.png'));
close(fig);
end

function value = percentile_local(x, p)
x = sort(x(~isnan(x)));
if isempty(x)
    value = NaN;
else
    value = x(max(1, min(numel(x), ceil(p / 100 * numel(x)))));
end
end
