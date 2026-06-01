function main_diagnose_calibration_metric_scale()
%MAIN_DIAGNOSE_CALIBRATION_METRIC_SCALE Audit calibration metric sources and scales.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'calibration', 'diagnostics');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

sim_metrics = read_csv(fullfile(project_root, 'results', 'calibration', 'pilot', 'calibration_pilot_sim_metrics.csv'));
target_table = read_csv(fullfile(project_root, 'paper_inputs', 'filled', 'calibration_target_benchmark.csv'));

rows = cell(height(sim_metrics), 1);
for i = 1:height(sim_metrics)
    parameter_set_id = string(sim_metrics.parameter_set_id(i));
    target_group = string(sim_metrics.target_group(i));
    scenario_id = string(sim_metrics.scenario_id(i));
    metric_name = string(sim_metrics.metric_name(i));
    target_row = target_table(target_table.target_group == target_group & ...
        target_table.scenario_id == scenario_id & target_table.metric_name == metric_name, :);
    if isempty(target_row)
        paper_value = NaN;
    else
        paper_value = target_row.paper_value(1);
    end

    table_dir = fullfile(project_root, 'results', 'calibration', 'pilot', char(parameter_set_id), char(scenario_id), 'tables');
    raw_value = read_var_metric(fullfile(table_dir, 'markov_var_metrics.csv'), metric_name);
    weighted_value = read_var_metric(fullfile(table_dir, 'markov_var_metrics_weighted.csv'), metric_name);
    paper_severity_value = read_var_metric(fullfile(table_dir, 'markov_var_metrics_paper_severity.csv'), metric_name);
    chain_value = read_chain_summary_value(fullfile(table_dir, 'markov_chain_summary.csv'), metric_name);

    sim_value = sim_metrics.sim_value(i);
    ratio_used = safe_ratio(paper_value, sim_value);
    ratio_raw = safe_ratio(paper_value, raw_value);
    ratio_weighted = safe_ratio(paper_value, weighted_value);
    ratio_paper = safe_ratio(paper_value, paper_severity_value);
    possible_scale_issue = classify_scale_issue([ratio_used, ratio_raw, ratio_weighted, ratio_paper]);
    note = build_note(sim_metrics, i, paper_severity_value, sim_value, raw_value, weighted_value);

    rows{i} = table(parameter_set_id, target_group, scenario_id, metric_name, paper_value, sim_value, ...
        sim_metrics.source_file(i), raw_value, weighted_value, paper_severity_value, chain_value, ...
        ratio_used, ratio_raw, ratio_weighted, ratio_paper, possible_scale_issue, note, ...
        'VariableNames', {'parameter_set_id','target_group','scenario_id','metric_name','paper_value', ...
        'sim_value_used_in_pilot','sim_source_file_used_in_pilot','raw_markov_var_value', ...
        'weighted_markov_var_value','paper_severity_markov_var_value','chain_summary_value_if_available', ...
        'ratio_paper_to_sim_used','ratio_paper_to_raw','ratio_paper_to_weighted','ratio_paper_to_paper_severity', ...
        'possible_scale_issue','note'});
end
audit = vertcat(rows{:});
save_result_table(audit, fullfile(out_dir, 'calibration_metric_source_audit.csv'), true);

summary = build_scale_summary(audit);
save_result_table(summary, fullfile(out_dir, 'calibration_metric_scale_summary.csv'), true);
end

function value = read_var_metric(path, metric_name)
value = NaN;
if exist(path, 'file') ~= 2
    return;
end
    tbl = read_csv(path);
idx = find(abs(tbl.sigma - 0.95) < 1e-9, 1);
if isempty(idx) || ~ismember(metric_name, tbl.Properties.VariableNames)
    return;
end
value = tbl.(metric_name)(idx);
end

function value = read_chain_summary_value(path, metric_name)
value = NaN;
if exist(path, 'file') ~= 2
    return;
end
tbl = read_csv(path);
field = metric_to_chain_field(metric_name);
if ~ismember(field, tbl.Properties.VariableNames)
    return;
end
value = empirical_quantile(tbl.(field), 0.95);
end

function field = metric_to_chain_field(metric_name)
switch string(metric_name)
    case "SLLR"
        field = 'basic_LLR';
    case "SLFOR"
        field = 'basic_LFOR';
    case "SNVOR"
        field = 'basic_NVOR';
    case "CRI"
        field = 'basic_CRI';
    otherwise
        field = '';
end
end

function q = empirical_quantile(x, sigma)
x = x(~isnan(x) & ~isinf(x));
if isempty(x)
    q = NaN;
    return;
end
x = sort(x(:));
idx = max(1, min(numel(x), ceil(sigma * numel(x))));
q = x(idx);
end

function r = safe_ratio(a, b)
if isnan(a) || isnan(b)
    r = NaN;
elseif abs(b) < 1e-12
    if abs(a) < 1e-12
        r = NaN;
    else
        r = Inf;
    end
else
    r = a / b;
end
end

function issue = classify_scale_issue(ratios)
finite_ratios = ratios(isfinite(ratios) & ~isnan(ratios) & ratios > 0);
if isempty(finite_ratios)
    issue = "missing_or_zero_sim";
    return;
end
med = median(finite_ratios);
if med > 50 && med < 150
    issue = "near_100_scale_gap";
elseif med > 5 && med < 20
    issue = "near_10_scale_gap";
elseif med > 1.5 && med < 3
    issue = "near_2_scale_gap";
elseif med > 150
    issue = "large_nonconstant_scale_gap";
else
    issue = "no_simple_scale_hint";
end
end

function note = build_note(sim_metrics, i, paper_severity_value, sim_value, raw_value, weighted_value)
parts = strings(0, 1);
parts(end + 1, 1) = "pilot_source_note=" + string(sim_metrics.note(i));
if ~isnan(paper_severity_value) && abs(paper_severity_value - sim_value) > 1e-9
    parts(end + 1, 1) = "pilot_used_value differs from paper_severity";
end
if ~isnan(raw_value) && ~isnan(weighted_value) && abs(raw_value - weighted_value) > 1e-9
    parts(end + 1, 1) = "raw and weighted differ";
end
note = strjoin(parts, "; ");
end

function summary = build_scale_summary(audit)
groups = unique(audit(:, {'metric_name','target_group'}), 'rows');
rows = cell(height(groups), 1);
for i = 1:height(groups)
    metric_name = string(groups.metric_name(i));
    target_group = string(groups.target_group(i));
    mask = audit.metric_name == metric_name & audit.target_group == target_group;
    sub = audit(mask, :);
    ratios = sub.ratio_paper_to_sim_used(isfinite(sub.ratio_paper_to_sim_used) & ~isnan(sub.ratio_paper_to_sim_used) & sub.ratio_paper_to_sim_used > 0);
    if isempty(ratios)
        med_ratio = NaN; p10 = NaN; p90 = NaN; stability = "insufficient";
    else
        ratios = sort(ratios);
        med_ratio = median(ratios);
        p10 = percentile_from_sorted(ratios, 0.10);
        p90 = percentile_from_sorted(ratios, 0.90);
        if p10 > 0 && p90 / p10 < 2
            stability = "stable";
        elseif p10 > 0 && p90 / p10 < 5
            stability = "moderate";
        else
            stability = "unstable";
        end
    end
    suggested_scale_factor = med_ratio;
    diagnosis = diagnose_group(sub, med_ratio, stability);
    recommended_metric_source = recommend_source(sub);
    rows{i} = table(metric_name, target_group, height(sub), mean(sub.paper_value, 'omitnan'), ...
        mean(sub.sim_value_used_in_pilot, 'omitnan'), med_ratio, p10, p90, suggested_scale_factor, ...
        stability, diagnosis, recommended_metric_source, ...
        'VariableNames', {'metric_name','target_group','row_count','mean_paper_value','mean_sim_value', ...
        'median_ratio_paper_to_sim','p10_ratio_paper_to_sim','p90_ratio_paper_to_sim','suggested_scale_factor', ...
        'scale_factor_stability','diagnosis','recommended_metric_source'});
end
summary = vertcat(rows{:});
end

function p = percentile_from_sorted(x, prob)
idx = max(1, min(numel(x), ceil(prob * numel(x))));
p = x(idx);
end

function diagnosis = diagnose_group(sub, med_ratio, stability)
if ~isnan(med_ratio) && med_ratio > 50 && med_ratio < 150 && stability ~= "unstable"
    diagnosis = "likely_percent_vs_pu_scale";
elseif stability == "unstable"
    diagnosis = "likely_metric_definition_mismatch";
elseif source_closer(sub, 'paper_severity_markov_var_value') || source_closer(sub, 'weighted_markov_var_value')
    diagnosis = "likely_wrong_source_file";
elseif ~isnan(med_ratio) && med_ratio > 10
    diagnosis = "likely_metric_definition_mismatch";
elseif height(sub) < 4
    diagnosis = "likely_sample_size_noise";
else
    diagnosis = "likely_valid_but_under_calibrated";
end
end

function tf = source_closer(sub, field_name)
used_err = abs(sub.paper_value - sub.sim_value_used_in_pilot);
src_err = abs(sub.paper_value - sub.(field_name));
tf = mean(src_err, 'omitnan') + 1e-9 < mean(used_err, 'omitnan');
end

function src = recommend_source(sub)
variants = ["sim_value_used_in_pilot","raw_markov_var_value","weighted_markov_var_value","paper_severity_markov_var_value"];
names = ["pilot_used","raw_markov_var","weighted_markov_var","paper_severity_markov_var"];
errs = NaN(numel(variants), 1);
for k = 1:numel(variants)
    errs(k) = mean(abs(sub.paper_value - sub.(variants(k))), 'omitnan');
end
[~, idx] = min(errs);
if isempty(idx) || isnan(errs(idx))
    src = "rebuild_paper_consistent_metric";
else
    src = names(idx);
end
end

function tbl = read_csv(path)
opts = detectImportOptions(path, 'Delimiter', ',', 'TextType', 'string');
tbl = readtable(path, opts);
end
