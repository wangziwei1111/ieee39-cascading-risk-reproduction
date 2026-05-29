function main_generate_calibration_local_search_plan()
%MAIN_GENERATE_CALIBRATION_LOCAL_SEARCH_PLAN Generate local search candidates only.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'calibration');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
summary_path = fullfile(out_dir, 'pilot', 'calibration_pilot_score_summary.csv');
if exist(summary_path, 'file') ~= 2
    error('Missing calibration pilot score summary: %s', summary_path);
end
score_summary = readtable(summary_path, 'TextType', 'string');
valid = score_summary(~isnan(score_summary.score_total), :);
if isempty(valid)
    base_id = "benchmark_calibrated_seed";
else
    valid = sortrows(valid, 'score_total');
    base_id = valid.parameter_set_id(1);
end

set_table = readtable(fullfile(project_root, 'paper_inputs', 'filled', 'benchmark_calibration_parameter_sets.csv'), 'TextType', 'string');
base_row = set_table(set_table.parameter_set_id == base_id, :);
if isempty(base_row)
    base_row = set_table(set_table.parameter_set_id == "benchmark_calibrated_seed", :);
    base_id = "benchmark_calibrated_seed";
end

factors = [0.5, 0.75, 1.25, 1.5];
rows = {};
idx = 0;
for f = factors
    idx = idx + 1;
    rows{end + 1, 1} = make_candidate(idx, base_id, base_row, f, 1, "uniform probability scale perturbation"); %#ok<AGROW>
end
for lf = [0.85, 0.95, 1.05, 1.15]
    idx = idx + 1;
    rows{end + 1, 1} = make_candidate(idx, base_id, base_row, 1, lf, "L_max local perturbation"); %#ok<AGROW>
end
for pf = [0.5, 2.0]
    idx = idx + 1;
    candidate = make_candidate(idx, base_id, base_row, 1, 1, "selective relay/breaker perturbation");
    candidate.P_in_r = candidate.P_in_r * pf;
    candidate.P_in_c = candidate.P_in_c * pf;
    candidate.P_mis_c = candidate.P_mis_c * pf;
    rows{end + 1, 1} = candidate; %#ok<AGROW>
end
plan = vertcat(rows{:});
save_result_table(plan, fullfile(out_dir, 'local_search_plan.csv'), true);
end

function candidate = make_candidate(idx, base_id, base_row, prob_factor, lmax_factor, reason)
candidate_id = "local_" + compose("%02d", idx);
base_parameter_set_id = string(base_id);
P_W_D = clamp(getv(base_row, 'P_W_D') * prob_factor, 1e-5, 5e-2);
P_L_D = clamp(getv(base_row, 'P_L_D') * prob_factor, 1e-5, 5e-2);
P_L_r = clamp(getv(base_row, 'P_L_r') * prob_factor, 1e-3, 0.5);
P_in_r = clamp(getv(base_row, 'P_in_r') * prob_factor, 1e-5, 5e-2);
P_in_c = clamp(getv(base_row, 'P_in_c') * prob_factor, 1e-5, 5e-2);
P_mis_c = clamp(getv(base_row, 'P_mis_c') * prob_factor, 1e-6, 1e-2);
P3 = clamp(getv(base_row, 'P3') * prob_factor, 0, 1e-3);
L_rated_factor = clamp(getv(base_row, 'L_rated_factor'), 0.80, 1.00);
L_max_factor = clamp(getv(base_row, 'L_max_factor') * lmax_factor, 1.00, 1.30);
ZIII_factor = getv(base_row, 'ZIII_factor');
calibration_status = "benchmark_calibration_candidate_not_original_paper";
candidate = table(candidate_id, base_parameter_set_id, P_W_D, P_L_D, P_L_r, P_in_r, P_in_c, ...
    P_mis_c, P3, L_rated_factor, L_max_factor, ZIII_factor, calibration_status, string(reason), ...
    'VariableNames', {'candidate_id','base_parameter_set_id','P_W_D','P_L_D','P_L_r','P_in_r','P_in_c', ...
    'P_mis_c','P3','L_rated_factor','L_max_factor','ZIII_factor','calibration_status','reason'});
end

function value = getv(row, name)
value = row.(name)(1);
if ismissing(value), value = NaN; end
end

function y = clamp(x, lo, hi)
if isnan(x), y = x; else, y = min(max(x, lo), hi); end
end
