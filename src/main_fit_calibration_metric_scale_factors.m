function main_fit_calibration_metric_scale_factors()
%MAIN_FIT_CALIBRATION_METRIC_SCALE_FACTORS Fit diagnostic scale factors only.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'calibration', 'diagnostics');
audit_path = fullfile(out_dir, 'calibration_metric_source_audit.csv');
if exist(audit_path, 'file') ~= 2
    error('Run main_diagnose_calibration_metric_scale first.');
end
audit = read_csv(audit_path);

variants = {
"pilot_used","sim_value_used_in_pilot";
"raw_markov_var","raw_markov_var_value";
"weighted_markov_var","weighted_markov_var_value";
"paper_severity_markov_var","paper_severity_markov_var_value"
};
group_table = unique(audit(:, {'metric_name','target_group'}), 'rows');
rows = {};
for g = 1:height(group_table)
    sub_group = audit(audit.metric_name == group_table.metric_name(g) & audit.target_group == group_table.target_group(g), :);
    for v = 1:size(variants, 1)
        source_variant = variants{v, 1};
        field_name = variants{v, 2};
        for fit_type = ["scale_only", "scale_offset"]
            rows{end + 1, 1} = fit_one(sub_group, string(group_table.metric_name(g)), ...
                string(group_table.target_group(g)), source_variant, field_name, fit_type); %#ok<AGROW>
        end
    end
end
fit_table = vertcat(rows{:});
save_result_table(fit_table, fullfile(out_dir, 'calibration_metric_scale_fit.csv'), true);
end

function row = fit_one(tbl, metric_name, target_group, source_variant, field_name, fit_type)
x = tbl.(field_name);
y = tbl.paper_value;
valid = ~isnan(x) & ~isinf(x) & ~isnan(y) & ~isinf(y);
x = x(valid);
y = y(valid);
row_count = numel(x);
if row_count < 2 || all(abs(x) < 1e-12)
    scale_a = NaN; offset_b = NaN; yhat = NaN(size(y)); interpretation = "insufficient_points";
else
    switch fit_type
        case "scale_only"
            scale_a = (x' * y) / max(x' * x, eps);
            offset_b = 0;
            yhat = scale_a * x;
        case "scale_offset"
            X = [x, ones(row_count, 1)];
            beta = X \ y;
            scale_a = beta(1);
            offset_b = beta(2);
            yhat = X * beta;
        otherwise
            error('Unknown fit_type: %s', fit_type);
    end
    interpretation = interpret_fit(x, y, yhat, scale_a);
end
rmse_before = rmse(y, x);
rmse_after = rmse(y, yhat);
relative_rmse_before = rmse_before / max(mean(abs(y), 'omitnan'), eps);
relative_rmse_after = rmse_after / max(mean(abs(y), 'omitnan'), eps);
r2_after = r_squared(y, yhat);
row = table(metric_name, target_group, string(source_variant), string(fit_type), scale_a, offset_b, ...
    rmse_before, rmse_after, relative_rmse_before, relative_rmse_after, r2_after, row_count, interpretation, ...
    'VariableNames', {'metric_name','target_group','source_variant','fit_type','scale_a','offset_b', ...
    'rmse_before','rmse_after','relative_rmse_before','relative_rmse_after','r2_after','row_count','interpretation'});
end

function value = rmse(y, yhat)
if isempty(y) || all(isnan(yhat))
    value = NaN;
else
    value = sqrt(mean((y - yhat).^2, 'omitnan'));
end
end

function r2 = r_squared(y, yhat)
if isempty(y) || all(isnan(yhat))
    r2 = NaN;
    return;
end
ss_res = sum((y - yhat).^2, 'omitnan');
ss_tot = sum((y - mean(y, 'omitnan')).^2, 'omitnan');
if ss_tot <= eps
    r2 = NaN;
else
    r2 = 1 - ss_res / ss_tot;
end
end

function interpretation = interpret_fit(x, y, yhat, scale_a)
r2 = r_squared(y, yhat);
if isnan(r2)
    interpretation = "insufficient_points";
elseif r2 < 0.25
    interpretation = "scale_fit_poor_not_simple_scale_issue";
elseif scale_a > 50 && scale_a < 150
    interpretation = "scale_fit_suggests_percent_vs_pu_gap";
elseif scale_a > 10
    interpretation = "scale_fit_large_factor_metric_definition_check_needed";
else
    if rmse(y, yhat) < rmse(y, x)
        interpretation = "scale_fit_improves_but_diagnostic_only";
    else
        interpretation = "scale_fit_not_helpful";
    end
end
end

function tbl = read_csv(path)
opts = detectImportOptions(path, 'Delimiter', ',', 'TextType', 'string');
tbl = readtable(path, opts);
end
