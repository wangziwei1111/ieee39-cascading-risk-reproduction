function main_plot_line_probability_curves()
%MAIN_PLOT_LINE_PROBABILITY_CURVES Plot diagnostic P_L curves by parameter set.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_root = fullfile(project_root, 'results', 'outage');
fig_dir = fullfile(out_root, 'figures');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

cfg0 = base_config();
parameter_sets = read_parameter_sets(project_root);
loading = (0:0.01:1.6)';
branch_row = zeros(1, 14);
branch_row(6) = 100;
branch_row(14) = 1;

rows = {};
figure('Visible', 'off', 'Color', 'w');
hold on;
for i = 1:numel(parameter_sets)
    ps = parameter_sets(i);
    cfg = load_paper_line_probability_parameter_set(cfg0, ps);
    cfg.paper_line_missing_param_policy = 'return_nan';
    p = NaN(size(loading));
    for k = 1:numel(loading)
        [p(k), detail] = compute_paper_line_outage_probability(loading(k), branch_row, cfg, ...
            'branch_index', 1, 'fallback_probability', NaN);
        rows{end+1,1} = table(ps, loading(k), detail.P_flow, ...
            detail.P_hidden_distance, detail.P_hidden_loading, detail.P3, p(k), ...
            string(detail.status), string(detail.parameter_calibration_status), ...
            'VariableNames', {'parameter_set_id', 'line_loading_pu', 'P_flow', ...
            'P_hidden_distance', 'P_hidden_loading', 'P3', 'P_line', ...
            'status', 'calibration_status'}); %#ok<AGROW>
    end
    plot(loading, p, 'LineWidth', 1.5, 'DisplayName', char(ps));
end
hold off;
grid on;
xlabel('line loading (p.u.)');
ylabel('P_L');
title('Line outage probability curves by diagnostic parameter set (not calibrated paper values)');
legend('Location', 'northwest', 'Interpreter', 'none');
saveas(gcf, fullfile(fig_dir, 'line_probability_curves_by_parameter_set.png'));
close(gcf);

curve_table = vertcat(rows{:});
writetable(curve_table, fullfile(out_root, 'line_probability_curve_samples.csv'));
fprintf('line probability curves written: %s\n', fullfile(fig_dir, 'line_probability_curves_by_parameter_set.png'));
end

function ids = read_parameter_sets(project_root)
tbl = readtable(fullfile(project_root, 'paper_inputs', 'filled', ...
    'paper_line_probability_parameter_sets.csv'), 'TextType', 'string');
ids = string(tbl.parameter_set_id);
end
