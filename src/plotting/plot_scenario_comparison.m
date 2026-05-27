function plot_scenario_comparison(scenario_root)
%PLOT_SCENARIO_COMPARISON 绘制场景扫描CRI对比图。
% 输入：
%   scenario_root - results/scenarios目录。
% 输出：
%   图像文件保存到 results/scenarios/figures。
% 物理含义：
%   用0.95置信水平下的CRI对比不同新能源接入方式和容量设置，仅用于场景框架检查。

summary_path = fullfile(scenario_root, 'scenario_result_summary.csv');
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
title('场景CRI对比（smoke test）');
legend({'basic', 'weighted', 'paper formula'}, 'Location', 'best');
saveas(fig, fullfile(fig_dir, 'scenario_cri_comparison.png'));
close(fig);

is_penetration = startsWith(string(summary_table.scenario_id), "distributed_wind_") & ...
    endsWith(string(summary_table.scenario_id), "pct");
penetration_table = summary_table(is_penetration, :);
if height(penetration_table) >= 3
    ratios = extract_penetration_ratio(penetration_table.scenario_id);
    [ratios, order] = sort(ratios);
    fig = figure('Visible', 'off', 'Color', 'w');
    plot(ratios * 100, penetration_table.paper_CRI_095(order), '-o', 'LineWidth', 1.5);
    grid on;
    xlabel('新能源渗透率 (%)');
    ylabel('paper formula CRI (\sigma=0.95)');
    title('新能源渗透率-CRI曲线');
    saveas(fig, fullfile(fig_dir, 'penetration_cri_curve.png'));
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
