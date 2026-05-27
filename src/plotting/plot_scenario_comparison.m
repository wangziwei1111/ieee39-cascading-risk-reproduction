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

is_penetration = startsWith(string(summary_table.scenario_id), "distributed_wind_penetration_") & ...
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
    title({'新能源渗透率-CRI曲线', '渗透率定义：风电装机容量 / 系统总负荷，待校准', ...
        'diagnostic\_only 点未计入有效 paper 曲线'});
    legend({'basic', 'weighted', 'paper formula'}, 'Location', 'best');
    batch_curve = fullfile(fig_dir, sprintf('penetration_cri_curve_%s.png', batch_mode));
    saveas(fig, batch_curve);
    if string(batch_mode) == "penetration_scan"
        if any(diff(ratios) <= 0)
            error('penetration ratio is not strictly increasing.');
        end
        saveas(fig, fullfile(fig_dir, 'penetration_cri_curve.png'));
    end
    close(fig);
end

is_wind_speed = startsWith(string(summary_table.scenario_id), "wind_speed_") & ...
    endsWith(string(summary_table.scenario_id), "mps");
wind_table = summary_table(is_wind_speed, :);
if height(wind_table) >= 3
    speeds = extract_wind_speed(wind_table.scenario_id);
    [speeds, order] = sort(speeds);

    fig = figure('Visible', 'off', 'Color', 'w');
    plot(speeds, wind_table.basic_CRI_095(order), '-o', 'LineWidth', 1.5);
    hold on;
    plot(speeds, wind_table.weighted_CRI_095(order), '-s', 'LineWidth', 1.5);
    plot(speeds, wind_table.paper_CRI_095(order), '-^', 'LineWidth', 1.5);
    grid on;
    xlabel('风速 (m/s)');
    ylabel('CRI (\sigma=0.95)');
    title({'不同风速下风险指标变化（3000MW装机，实际出力由风速曲线决定）', ...
        'paper\_formula diagnostic\_only 点未计入有效 paper 曲线'});
    legend({'basic', 'weighted', 'paper formula'}, 'Location', 'best');
    saveas(fig, fullfile(fig_dir, 'wind_speed_cri_curve.png'));
    close(fig);

    if ismember('total_wind_output_mw', wind_table.Properties.VariableNames)
        fig = figure('Visible', 'off', 'Color', 'w');
        plot(speeds, wind_table.total_wind_output_mw(order), '-o', 'LineWidth', 1.5);
        grid on;
        xlabel('风速 (m/s)');
        ylabel('实际风电出力 (MW)');
        title('风速-实际风电出力检查（3000MW装机）');
        saveas(fig, fullfile(fig_dir, 'wind_speed_power_curve_check.png'));
        close(fig);
    end
end

if string(batch_mode) == "renewable_trip_record"
    trip_detail_path = fullfile(scenario_root, 'distributed_wind_40pct_trip_record_only', ...
        'tables', 'wind_trip_probability_details.csv');
    if exist(trip_detail_path, 'file')
        trip_detail = readtable(trip_detail_path);
        if height(trip_detail) > 0
            wind_buses = unique(trip_detail.wind_bus);
            max_prob = nan(numel(wind_buses), 1);
            p95_prob = nan(numel(wind_buses), 1);
            for k = 1:numel(wind_buses)
                rows = trip_detail.wind_bus == wind_buses(k);
                probs = trip_detail.trip_probability(rows);
                max_prob(k) = max(probs, [], 'omitnan');
                p95_prob(k) = percentile_local(probs, 95);
            end
            fig = figure('Visible', 'off', 'Color', 'w');
            bar(categorical(string(wind_buses)), [max_prob, p95_prob]);
            grid on;
            xlabel('风电接入节点');
            ylabel('脱网概率诊断值');
            title({'风机电压脱网概率诊断', '仅记录概率，未实际触发脱网'});
            legend({'max', 'p95'}, 'Location', 'best');
            saveas(fig, fullfile(fig_dir, 'renewable_trip_probability_summary.png'));
            close(fig);
        end
    end
end
end

function ratios = extract_penetration_ratio(ids)
ids = string(ids);
ratios = nan(numel(ids), 1);
for k = 1:numel(ids)
    token = regexp(char(ids(k)), 'distributed_wind_penetration_(\d+)pct', 'tokens', 'once');
    if ~isempty(token)
        ratios(k) = str2double(token{1}) / 100;
    end
end
end

function speeds = extract_wind_speed(ids)
ids = string(ids);
speeds = nan(numel(ids), 1);
for k = 1:numel(ids)
    token = regexp(char(ids(k)), 'wind_speed_(\d+)mps', 'tokens', 'once');
    if ~isempty(token)
        speeds(k) = str2double(token{1});
    end
end
end

function value = percentile_local(x, p)
x = sort(x(~isnan(x)));
if isempty(x)
    value = NaN;
    return;
end
idx = max(1, min(numel(x), ceil(p / 100 * numel(x))));
value = x(idx);
end
