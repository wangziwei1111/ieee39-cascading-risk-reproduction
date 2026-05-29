function main_scan_markov_wind_voltage_ranges()
%MAIN_SCAN_MARKOV_WIND_VOLTAGE_RANGES Scan existing smoke wind-voltage range.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(project_root, 'src')));
out_dir = fullfile(project_root, 'results', 'renewable');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
detail_path = fullfile(out_dir, 'wind_state_probability_diagnostic_smoke', ...
    'diagnostic_linear_voltage_probability', 'wind_trip_probability_details.csv');
if ~exist(detail_path, 'file')
    error('Missing wind trip details: %s', detail_path);
end
tbl = readtable(detail_path, 'TextType', 'string');
v = tbl.voltage_pu;
hit_mask = v < 0.90 | v > 1.10;
note = "threshold hits found";
if ~any(hit_mask)
    note = "no threshold hits; P_wt(E_k)=1 is due to sample voltages staying inside the normal range";
end
summary = table(height(tbl), min(v, [], 'omitnan'), percentile_local(v, 1), ...
    percentile_local(v, 5), mean(v, 'omitnan'), percentile_local(v, 95), ...
    max(v, [], 'omitnan'), sum(v < 0.90), sum(v < 0.20), ...
    sum(v > 1.10), sum(v > 1.30), note, ...
    'VariableNames', {'row_count', 'min_wind_voltage_pu', 'p01_wind_voltage_pu', ...
    'p05_wind_voltage_pu', 'mean_wind_voltage_pu', 'p95_wind_voltage_pu', ...
    'max_wind_voltage_pu', 'count_below_0p9', 'count_below_0p2', ...
    'count_above_1p1', 'count_above_1p3', 'note'});
writetable(summary, fullfile(out_dir, 'markov_wind_voltage_range_summary.csv'));
hits = tbl(hit_mask, :);
if isempty(hits)
    hits = tbl([], :);
end
writetable(hits, fullfile(out_dir, 'markov_wind_voltage_threshold_hits.csv'));
fprintf('markov wind voltage range scan written.\n');
end

function value = percentile_local(x, p)
x = sort(x(~isnan(x)));
if isempty(x)
    value = NaN;
else
    idx = max(1, min(numel(x), ceil(p / 100 * numel(x))));
    value = x(idx);
end
end
