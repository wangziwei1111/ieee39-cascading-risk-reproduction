function plot_ols_benchmark_smoke_figures(root_dir)
%PLOT_OLS_BENCHMARK_SMOKE_FIGURES Plot OLS benchmark smoke diagnostics.
if nargin < 1 || isempty(root_dir)
    project_root = fileparts(fileparts(mfilename('fullpath')));
    root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
end
table_dir = fullfile(root_dir, 'tables');
figure_dir = fullfile(root_dir, 'figures');
if ~exist(figure_dir, 'dir')
    mkdir(figure_dir);
end

summary = readtable(fullfile(table_dir, 'ols_benchmark_smoke_summary.csv'));
bench = readtable(fullfile(table_dir, 'ols_smoke_vs_paper_benchmark.csv'));

plot_cri(summary, fullfile(figure_dir, 'ols_vs_simple_cri_comparison.png'));
plot_trigger_counts(summary, fullfile(figure_dir, 'ols_trigger_counts.png'));
plot_paper_compare(bench, fullfile(figure_dir, 'ols_smoke_vs_paper_cri.png'));
failure_path = fullfile(table_dir, 'ols_failure_summary.csv');
if exist(failure_path, 'file')
    plot_failure_types(readtable(failure_path), fullfile(figure_dir, 'ols_failure_type_summary.png'));
end
robust_path = fullfile(table_dir, 'ols_solver_robustness_test.csv');
if exist(robust_path, 'file')
    plot_robustness(readtable(robust_path), fullfile(figure_dir, 'ols_solver_robustness.png'));
end
apply_path = fullfile(table_dir, 'ols_apply_solution_mode_summary.csv');
if exist(apply_path, 'file')
    plot_apply_solution_modes(readtable(apply_path), fullfile(figure_dir, 'ols_apply_solution_mode_success.png'));
end
modeling_path = fullfile(table_dir, 'ols_modeling_consistency_check.csv');
if exist(modeling_path, 'file')
    plot_modeling_issues(readtable(modeling_path, 'Delimiter', ','), fullfile(figure_dir, 'ols_modeling_issue_summary.png'));
end
dc_path = fullfile(table_dir, 'dc_ols_feasibility_preview.csv');
if exist(dc_path, 'file')
    plot_dc_preview(readtable(dc_path, 'Delimiter', ','), fullfile(figure_dir, 'dc_ols_feasibility_preview.png'));
end
fixed_summary_path = fullfile(table_dir, 'ols_fixed_q_shed_summary.csv');
fixed_delta_path = fullfile(table_dir, 'ols_fixed_q_vs_free_q_delta.csv');
if exist(fixed_summary_path, 'file')
    fixed_summary = readtable(fixed_summary_path);
    plot_fixed_q_success(fixed_summary, fullfile(figure_dir, 'ols_fixed_q_success_comparison.png'));
    plot_fixed_q_mismatch(fixed_summary, fullfile(figure_dir, 'ols_fixed_q_q_mismatch.png'));
end
if exist(fixed_delta_path, 'file')
    plot_fixed_q_cri_delta(readtable(fixed_delta_path), fullfile(figure_dir, 'ols_fixed_q_cri_delta.png'));
end
formulation_path = fullfile(table_dir, 'ols_formulation_comparison.csv');
if exist(formulation_path, 'file')
    formulation = readtable(formulation_path);
    plot_formulation_failure_rate(formulation, fullfile(figure_dir, 'ols_formulation_failure_rate.png'));
    plot_formulation_q_behavior(formulation, fullfile(figure_dir, 'ols_formulation_q_behavior.png'));
    plot_formulation_cri(formulation, fullfile(figure_dir, 'ols_formulation_cri_comparison.png'));
end
end

function plot_cri(summary, out_path)
scenarios = string(unique(summary.scenario_id, 'stable'));
weighted_simple = zeros(numel(scenarios), 1);
weighted_ols = zeros(numel(scenarios), 1);
paper_simple = zeros(numel(scenarios), 1);
paper_ols = zeros(numel(scenarios), 1);
for i = 1:numel(scenarios)
    s = summary(string(summary.scenario_id) == scenarios(i) & string(summary.mode) == "simple", :);
    o = summary(string(summary.scenario_id) == scenarios(i) & string(summary.mode) == "paper_ols_violation", :);
    weighted_simple(i) = s.weighted_CRI_095(1);
    weighted_ols(i) = o.weighted_CRI_095(1);
    paper_simple(i) = s.paper_CRI_095(1);
    paper_ols(i) = o.paper_CRI_095(1);
end
figure('Visible', 'off', 'Color', 'w');
bar([weighted_simple, weighted_ols, paper_simple, paper_ols]);
set(gca, 'XTickLabel', cellstr(scenarios), 'XTickLabelRotation', 25);
ylabel('CRI');
title('OLS benchmark smoke: simple vs paper\_ols\_violation CRI');
legend({'weighted simple','weighted OLS','paper simple','paper OLS'}, 'Location', 'best');
grid on;
saveas(gcf, out_path);
close(gcf);
end

function plot_trigger_counts(summary, out_path)
ols = summary(string(summary.mode) == "paper_ols_violation", :);
figure('Visible', 'off', 'Color', 'w');
bar([ols.nonconverged_trigger_count, ols.line_overload_trigger_count, ols.voltage_violation_trigger_count], 'stacked');
set(gca, 'XTickLabel', cellstr(string(ols.scenario_id)), 'XTickLabelRotation', 25);
ylabel('Triggered stage count');
title('OLS trigger count diagnostics');
legend({'nonconverged','line overload','voltage violation'}, 'Location', 'best');
grid on;
saveas(gcf, out_path);
close(gcf);
end

function plot_paper_compare(bench, out_path)
figure('Visible', 'off', 'Color', 'w');
bar([bench.paper_CRI, bench.simple_paper_formula_CRI, bench.paper_ols_violation_paper_formula_CRI]);
set(gca, 'XTickLabel', cellstr(string(bench.reproduction_scenario_id)), 'XTickLabelRotation', 25);
ylabel('CRI raw value');
title('OLS smoke vs paper benchmark CRI (raw comparison; unit alignment pending)');
legend({'paper benchmark','simple paper\_formula','OLS paper\_formula'}, 'Location', 'best');
grid on;
saveas(gcf, out_path);
close(gcf);
end

function plot_failure_types(failure_summary, out_path)
count_fields = {'opf_nonconverged_count','opf_infeasible_count', ...
    'pf_after_apply_nonconverged_count','rateA_zero_or_too_tight_count', ...
    'voltage_constraint_too_tight_count','generator_limit_binding_count', ...
    'island_or_slack_issue_count','unknown_count'};
labels = {'OPF nonconv','OPF infeasible','PF after apply','RATE_A','Voltage','Gen limits','Island/slack','Unknown'};
counts = zeros(height(failure_summary), numel(count_fields));
for i = 1:numel(count_fields)
    counts(:, i) = failure_summary.(count_fields{i});
end
figure('Visible', 'off', 'Color', 'w');
bar(counts, 'stacked');
set(gca, 'XTickLabel', cellstr(string(failure_summary.scenario_id)), 'XTickLabelRotation', 25);
ylabel('Failed OLS count');
title('OLS failure type summary');
legend(labels, 'Location', 'bestoutside');
grid on;
saveas(gcf, out_path);
close(gcf);
end

function plot_robustness(robustness, out_path)
settings = string(unique(robustness.setting_name, 'stable'));
success_rate = zeros(numel(settings), 1);
for i = 1:numel(settings)
    rows = robustness(string(robustness.setting_name) == settings(i), :);
    success_rate(i) = mean(rows.pf_success_after_apply);
end
figure('Visible', 'off', 'Color', 'w');
bar(success_rate);
set(gca, 'XTickLabel', cellstr(settings), 'XTickLabelRotation', 20);
ylim([0, 1]);
ylabel('Post-apply PF success rate');
title('OLS solver robustness diagnostic');
grid on;
saveas(gcf, out_path);
close(gcf);
end

function plot_apply_solution_modes(summary, out_path)
figure('Visible', 'off', 'Color', 'w');
bar(summary.success_rate);
set(gca, 'XTickLabel', cellstr(string(summary.apply_solution_mode)), 'XTickLabelRotation', 20);
ylim([0, 1]);
ylabel('PF success rate after applying OLS');
title('OLS OPF solution application mode diagnostic');
grid on;
saveas(gcf, out_path);
close(gcf);
end

function plot_modeling_issues(consistency, out_path)
statuses = ["pass", "warning", "fail", "not_applicable"];
counts = zeros(numel(statuses), 1);
status_col = string(get_table_column(consistency, "status"));
for i = 1:numel(statuses)
    counts(i) = sum(status_col == statuses(i));
end
figure('Visible', 'off', 'Color', 'w');
bar(counts);
set(gca, 'XTickLabel', cellstr(statuses), 'XTickLabelRotation', 20);
ylabel('Check count');
title('OLS modeling consistency issue summary');
grid on;
saveas(gcf, out_path);
close(gcf);
end

function col = get_table_column(tbl, name)
vars = string(tbl.Properties.VariableNames);
idx = find(vars == name, 1);
if isempty(idx)
    idx = find(vars == name + "_", 1);
end
if isempty(idx)
    error('Missing expected table column: %s', name);
end
col = tbl.(vars(idx));
end

function plot_dc_preview(preview, out_path)
figure('Visible', 'off', 'Color', 'w');
success = double(logical(preview.dc_lp_success));
bar(success);
set(gca, 'XTickLabel', cellstr(string(preview.case_export_id)), 'XTickLabelRotation', 25);
ylim([0, 1]);
ylabel('DC LP success');
title('DC-OLS feasibility preview for exported failures');
grid on;
saveas(gcf, out_path);
close(gcf);
end

function plot_fixed_q_success(summary, out_path)
figure('Visible', 'off', 'Color', 'w');
bar(summary.success_rate);
set(gca, 'XTickLabel', cellstr(string(summary.shed_gen_q_mode)), 'XTickLabelRotation', 20);
ylim([0, 1]);
ylabel('PF success rate after apply');
title('Fixed-zero-Q OLS diagnostic: success rate');
grid on;
saveas(gcf, out_path);
close(gcf);
end

function plot_fixed_q_mismatch(summary, out_path)
figure('Visible', 'off', 'Color', 'w');
bar([summary.mean_q_mismatch, summary.max_q_mismatch]);
set(gca, 'XTickLabel', cellstr(string(summary.shed_gen_q_mode)), 'XTickLabelRotation', 20);
ylabel('Q mismatch (MVar)');
title('Fixed-zero-Q OLS diagnostic: Q mismatch');
legend({'mean mismatch','max mismatch'}, 'Location', 'best');
grid on;
saveas(gcf, out_path);
close(gcf);
end

function plot_fixed_q_cri_delta(delta, out_path)
mask = ismember(string(delta.metric_name), ["basic_CRI_095", "weighted_CRI_095", "paper_CRI_095"]);
sub = delta(mask, :);
if isempty(sub)
    return;
end
scenarios = unique(string(sub.scenario_id), 'stable');
metrics = ["basic_CRI_095", "weighted_CRI_095", "paper_CRI_095"];
values = nan(numel(scenarios), numel(metrics));
for s = 1:numel(scenarios)
    for m = 1:numel(metrics)
        row = sub(string(sub.scenario_id) == scenarios(s) & string(sub.metric_name) == metrics(m), :);
        if ~isempty(row)
            values(s, m) = row.delta_value(1);
        end
    end
end
figure('Visible', 'off', 'Color', 'w');
bar(values);
set(gca, 'XTickLabel', cellstr(scenarios), 'XTickLabelRotation', 25);
ylabel('fixed\_zero\_q - free\_q CRI');
title('Fixed-zero-Q OLS diagnostic: CRI delta (5-trial)');
legend(cellstr(metrics), 'Location', 'best');
grid on;
saveas(gcf, out_path);
close(gcf);
end

function plot_formulation_failure_rate(tbl, out_path)
labels = strcat(string(tbl.formulation), "/", string(tbl.q_mode));
scenarios = unique(string(tbl.scenario_id), 'stable');
forms = unique(labels, 'stable');
values = nan(numel(scenarios), numel(forms));
for s = 1:numel(scenarios)
    for f = 1:numel(forms)
        row = tbl(string(tbl.scenario_id) == scenarios(s) & labels == forms(f), :);
        if ~isempty(row), values(s, f) = row.failure_rate(1); end
    end
end
figure('Visible', 'off', 'Color', 'w');
bar(values);
set(gca, 'XTickLabel', cellstr(scenarios), 'XTickLabelRotation', 25);
ylabel('OLS failure rate');
title('OLS formulation diagnostic: failure rate (5-trial)');
legend(cellstr(forms), 'Location', 'bestoutside');
grid on;
saveas(gcf, out_path);
close(gcf);
end

function plot_formulation_q_behavior(tbl, out_path)
labels = strcat(string(tbl.formulation), "/", string(tbl.q_mode));
figure('Visible', 'off', 'Color', 'w');
bar([tbl.mean_q_mismatch, tbl.max_positive_q_injection]);
set(gca, 'XTickLabel', cellstr(labels + newline + string(tbl.scenario_id)), 'XTickLabelRotation', 35);
ylabel('MVar');
title('OLS formulation diagnostic: reactive behavior');
legend({'mean Q mismatch','max positive Q injection'}, 'Location', 'best');
grid on;
saveas(gcf, out_path);
close(gcf);
end

function plot_formulation_cri(tbl, out_path)
labels = strcat(string(tbl.formulation), "/", string(tbl.q_mode));
figure('Visible', 'off', 'Color', 'w');
bar([tbl.weighted_CRI_095, tbl.paper_CRI_095]);
set(gca, 'XTickLabel', cellstr(labels + newline + string(tbl.scenario_id)), 'XTickLabelRotation', 35);
ylabel('CRI');
title('OLS formulation diagnostic: CRI comparison (5-trial)');
legend({'weighted CRI','paper formula CRI'}, 'Location', 'best');
grid on;
saveas(gcf, out_path);
close(gcf);
end
