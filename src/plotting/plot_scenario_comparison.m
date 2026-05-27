function plot_scenario_comparison(scenario_root, batch_mode)
%PLOT_SCENARIO_COMPARISON 绘制场景扫描CRI对比图。
% 输入：
%   scenario_root - results/scenarios目录。
%   batch_mode - 可选批处理模式，用于选择summary和输出文件名。
% 输出：
%   图像文件保存到 results/scenarios/figures。
% 物理含义：
%   paper_CRI为NaN时保留空值，不把diagnostic_only场景画成0。

if nargin < 2
    batch_mode = '';
end
if strlength(string(batch_mode)) > 0
    summary_path = fullfile(scenario_root, sprintf('scenario_result_summary_%s.csv', batch_mode));
    output_name = sprintf('scenario_cri_comparison_%s.png', batch_mode);
    title_suffix = sprintf('batch: %s', batch_mode);
else
    summary_path = fullfile(scenario_root, 'scenario_result_summary.csv');
    output_name = 'scenario_cri_comparison.png';
    title_suffix = 'latest summary';
end
if ~exist(summary_path, 'file')
    return;
end

summary_table = readtable(summary_path);
fig_dir = fullfile(scenario_root, 'figures');
if ~exist(fig_dir, 'dir')
    mkdir(fig_dir);
end

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1100, 480]);
x = 1:height(summary_table);
bar(x, [summary_table.basic_CRI_095, summary_table.weighted_CRI_095, summary_table.paper_CRI_095]);
grid on;
set(gca, 'XTick', x, 'XTickLabel', summary_table.scenario_id, 'XTickLabelRotation', 25);
ylabel('CRI (\sigma=0.95)');
title({'场景CRI对比', title_suffix, 'paper\_formula diagnostic\_only 场景未计入有效paper CRI比较'});
legend({'basic', 'weighted', 'paper formula'}, 'Location', 'best');
saveas(fig, fullfile(fig_dir, output_name));
close(fig);

is_penetration = startsWith(string(summary_table.scenario_id), "distributed_wind_") & ...
    endsWith(string(summary_table.scenario_id), "pct");
penetration_table = summary_table(is_penetration, :);
if height(penetration_table) >= 3
    ratios = extract_penetration_ratio(penetration_table.scenario_id);
    [ratios, order] = sort(ratios);
    fig = figure('Visible', 'off', 'Color', 'w');
    plot(ratios * 100, penetration_table.basic_CRI_095(order), '-o', 'LineWidth', 1.5);
    hold on;
    plot(ratios * 100, penetration_table.weighted_CRI_095(order), '-s', 'LineWidth', 1.5);
    plot(ratios * 100, penetration_table.paper_CRI_095(order), '-^', 'LineWidth', 1.5);
    grid on;
    xlabel('新能源渗透率 (%)');
    ylabel('CRI (\sigma=0.95)');
    title({'新能源渗透率-CRI曲线', 'diagnostic\_only 点未计入有效 paper 曲线'});
    legend({'basic', 'weighted', 'paper formula'}, 'Location', 'best');
    batch_curve = fullfile(fig_dir, sprintf('penetration_cri_curve_%s.png', batch_mode));
    saveas(fig, batch_curve);
    if string(batch_mode) == "penetration_scan"
        saveas(fig, fullfile(fig_dir, 'penetration_cri_curve.png'));
    end
    close(fig);
end
end

function ratios = extract_penetration_ratio(ids)
ids = string(ids);
ratios = nan(numel(ids), 1);
for k = 1:numel(ids)
    token = regexp(char(ids(k)), 'distributed_wind_(\d+)pct', 'tokens', 'once');
    if ~isempty(token)
        ratios(k) = str2double(token{1}) / 100;
    end
end
end
