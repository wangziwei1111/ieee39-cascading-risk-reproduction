function main_scan_markov_generator_voltage_ranges()
%MAIN_SCAN_MARKOV_GENERATOR_VOLTAGE_RANGES Summarize diagnostic Markov generator voltage/frequency ranges.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(project_root, 'src')));
in_path = fullfile(project_root, 'results', 'generator', 'generator_state_probability_diagnostic_smoke', ...
    'diagnostic_voltage_frequency_probability', 'generator_trip_probability_details.csv');
if exist(in_path, 'file') ~= 2
    error('Missing generator trip probability details: %s', in_path);
end
tbl = readtable(in_path, 'TextType', 'string');
out_dir = fullfile(project_root, 'results', 'generator');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

v = tbl.gen_voltage_pu;
f = tbl.gen_frequency_hz;
summary = table(height(tbl), min(v, [], 'omitnan'), pct(v, 1), pct(v, 5), ...
    mean(v, 'omitnan'), pct(v, 95), max(v, [], 'omitnan'), ...
    min(f, [], 'omitnan'), max(f, [], 'omitnan'), ...
    sum(v < 0.9), sum(v < 0.7), sum(v > 1.1), sum(v > 1.3), ...
    sum(f < 49.5), sum(f < 48.5), sum(f > 50.5), sum(f > 51.5), ...
    "Static power-flow diagnostic uses nominal frequency; threshold hits are voltage/frequency record-only observations.", ...
    'VariableNames', {'row_count', 'min_gen_voltage_pu', 'p01_gen_voltage_pu', ...
    'p05_gen_voltage_pu', 'mean_gen_voltage_pu', 'p95_gen_voltage_pu', ...
    'max_gen_voltage_pu', 'min_frequency_hz', 'max_frequency_hz', ...
    'count_voltage_below_0p9', 'count_voltage_below_0p7', ...
    'count_voltage_above_1p1', 'count_voltage_above_1p3', ...
    'count_frequency_below_49p5', 'count_frequency_below_48p5', ...
    'count_frequency_above_50p5', 'count_frequency_above_51p5', 'note'});
writetable(summary, fullfile(out_dir, 'markov_generator_voltage_frequency_range_summary.csv'));

hit_mask = v < 0.9 | v > 1.1 | f < 49.5 | f > 50.5;
hits = tbl(hit_mask, :);
if height(hits) == 0
    hits = tbl([], :);
end
writetable(hits, fullfile(out_dir, 'markov_generator_threshold_hits.csv'));
fprintf('generator voltage/frequency range scan written.\n');
end

function y = pct(x, p)
if isempty(x) || all(isnan(x))
    y = NaN;
else
    y = prctile(x, p);
end
end
