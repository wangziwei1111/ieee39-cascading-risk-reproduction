function plot_paper_alignment_figures(table_dir, fig_dir)
%PLOT_PAPER_ALIGNMENT_FIGURES 绘制论文 benchmark 与当前复现结果的静态对照图。
% 输入：
%   table_dir: paper_alignment/tables 目录
%   fig_dir: paper_alignment/figures 目录
% 输出：
%   table45_penetration_cri_paper_vs_reproduction.png
%   table44_topology_cri_paper_vs_reproduction.png
%   paper_alignment_status_matrix.png
% 物理含义：
%   图中展示的是当前参数下 raw comparison。论文 benchmark 单位为 10^-4，
%   当前复现值尚未完成最终单位/尺度对齐，因此图题中明确标注待校准。

if ~exist(fig_dir, 'dir')
    mkdir(fig_dir);
end
comparison = readtable(fullfile(table_dir, 'paper_vs_reproduction_comparison.csv'), 'Delimiter', ',', 'VariableNamingRule', 'preserve');
mapping = readtable(fullfile(table_dir, 'paper_to_reproduction_scenario_mapping.csv'), 'Delimiter', ',', 'VariableNamingRule', 'preserve');

plot_table45(comparison, fig_dir);
plot_table44(comparison, fig_dir);
plot_status_matrix(mapping, comparison, fig_dir);
end

function plot_table45(comparison, fig_dir)
rows = string(comparison.paper_table) == "Table 4-5" & string(comparison.metric_name) == "CRI";
sub = comparison(rows, :);
if isempty(sub)
    return;
end
paper_rows = unique(sub(:, {'paper_scenario_id','paper_value'}), 'rows');
penetration = parse_percent(string(paper_rows.paper_scenario_id));
[penetration, order] = sort(penetration);
paper_values = paper_rows.paper_value(order);

figure('Visible', 'off', 'Color', 'w');
plot(penetration, paper_values, '-o', 'LineWidth', 1.5, 'DisplayName', 'paper benchmark CRI (10^{-4})');
hold on;
plot_family(sub, "paper_formula", penetration, 'reproduction paper\_formula raw');
plot_family(sub, "weighted", penetration, 'reproduction weighted raw');
xlabel('新能源渗透率 (%)');
ylabel('CRI');
title('表4-5 渗透率 CRI 对照（raw comparison; unit alignment pending）');
legend('Location', 'northwest');
grid on;
saveas(gcf, fullfile(fig_dir, 'table45_penetration_cri_paper_vs_reproduction.png'));
close(gcf);
end

function plot_family(sub, family, penetration_ref, display_name)
rows = string(sub.metric_family) == family & (string(sub.comparison_status) == "comparable_with_caution" | string(sub.comparison_status) == "comparable");
fam = sub(rows, :);
if isempty(fam)
    return;
end
p = parse_percent(string(fam.paper_scenario_id));
[p, order] = sort(p);
values = fam.reproduction_value_raw(order);
values(isnan(values)) = NaN;
[~, idx] = ismember(p, penetration_ref);
aligned = NaN(size(penetration_ref));
aligned(idx(idx > 0)) = values(idx > 0);
plot(penetration_ref, aligned, '-s', 'LineWidth', 1.5, 'DisplayName', display_name);
end

function percent = parse_percent(ids)
percent = zeros(numel(ids), 1);
for i = 1:numel(ids)
    token = regexp(ids(i), '(\d+)pct', 'tokens', 'once');
    if isempty(token)
        percent(i) = NaN;
    else
        percent(i) = str2double(token{1});
    end
end
end

function plot_table44(comparison, fig_dir)
rows = string(comparison.paper_table) == "Table 4-4" & string(comparison.metric_name) == "CRI" & comparison.confidence_level == 0.95;
sub = comparison(rows, :);
if isempty(sub)
    return;
end
scenes = ["distributed_3000mw"; "centralized_3000mw"];
labels = ["分散式"; "集中式"];
paper_values = NaN(numel(scenes), 1);
paper_formula = NaN(numel(scenes), 1);
weighted = NaN(numel(scenes), 1);
for i = 1:numel(scenes)
    idx = string(sub.paper_scenario_id) == scenes(i);
    if any(idx)
        paper_values(i) = sub.paper_value(find(idx, 1));
    end
    idx_pf = idx & string(sub.metric_family) == "paper_formula" & ~strcmp(string(sub.comparison_status), "not_comparable_diagnostic_only");
    if any(idx_pf)
        paper_formula(i) = sub.reproduction_value_raw(find(idx_pf, 1));
    end
    idx_w = idx & string(sub.metric_family) == "weighted";
    if any(idx_w)
        weighted(i) = sub.reproduction_value_raw(find(idx_w, 1));
    end
end
figure('Visible', 'off', 'Color', 'w');
bar(categorical(labels), [paper_values, paper_formula, weighted]);
ylabel('CRI');
title('表4-4 接入方式 CRI 对照（centralized diagnostic\_only 不画为0）');
legend({'paper benchmark (10^{-4})','reproduction paper\_formula raw','reproduction weighted raw'}, 'Location', 'northwest');
grid on;
saveas(gcf, fullfile(fig_dir, 'table44_topology_cri_paper_vs_reproduction.png'));
close(gcf);
end

function plot_status_matrix(mapping, comparison, fig_dir)
tables = unique(string(mapping.paper_table), 'stable');
groups = ["Table 4-2"; "Table 4-4"; "Table 4-5"; "Table 4-6"];
status_score = zeros(numel(groups), 1);
status_label = strings(numel(groups), 1);
for i = 1:numel(groups)
    statuses = string(comparison.comparison_status(string(comparison.paper_table) == groups(i)));
    if any(statuses == "comparable")
        status_score(i) = 4; status_label(i) = "comparable";
    elseif any(statuses == "comparable_with_caution")
        status_score(i) = 3; status_label(i) = "caution";
    elseif any(statuses == "not_comparable_model_missing")
        status_score(i) = 2; status_label(i) = "model_missing";
    elseif any(statuses == "not_comparable_missing_reproduction")
        status_score(i) = 1; status_label(i) = "missing";
    else
        status_score(i) = 0; status_label(i) = "other";
    end
end
figure('Visible', 'off', 'Color', 'w');
bar(categorical(groups), status_score);
ylim([0 4.5]);
ylabel('状态编码');
title('论文 benchmark 对照状态矩阵');
grid on;
for i = 1:numel(groups)
    text(i, status_score(i) + 0.15, status_label(i), 'HorizontalAlignment', 'center');
end
saveas(gcf, fullfile(fig_dir, 'paper_alignment_status_matrix.png'));
close(gcf);
end
