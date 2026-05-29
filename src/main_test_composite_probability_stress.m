function main_test_composite_probability_stress()
%MAIN_TEST_COMPOSITE_PROBABILITY_STRESS Validate P_line * P_wt * P_ge multiplication.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
out_dir = fullfile(project_root, 'results', 'composite');
ensure_dir(out_dir);

cfg = base_config();
cfg.composite_probability_missing_policy = 'component_nan';
cases = {
    "all_one", 1, 1, 1, 1
    "line_only_half", 0.5, 1, 1, 0.5
    "wind_half", 0.5, 0.5, 1, 0.25
    "generator_half", 0.5, 1, 0.5, 0.25
    "all_half", 0.5, 0.5, 0.5, 0.125
    "wind_forced_zero", 0.5, 0, 1, 0
    "missing_wind", 0.5, NaN, 1, NaN
    };
rows = {};
for i = 1:size(cases, 1)
    line = struct('P_line_Ek', cases{i, 2}, 'status', "synthetic");
    wind = struct('P_wt_Ek', cases{i, 3}, 'status', "synthetic");
    gen = struct('P_ge_Ek', cases{i, 4}, 'status', "synthetic");
    [actual, d] = compute_composite_state_probability(line, wind, gen, cfg);
    expected = cases{i, 5};
    pass = (isnan(expected) && isnan(actual)) || abs(expected - actual) < 1e-12;
    status = "pass";
    if ~pass
        status = "fail";
    end
    rows{end+1,1} = table(string(cases{i,1}), cases{i,2}, cases{i,3}, cases{i,4}, ...
        string(cfg.composite_probability_missing_policy), expected, actual, status, string(d.note), ...
        'VariableNames', {'test_case', 'P_line_Ek', 'P_wt_Ek', 'P_ge_Ek', ...
        'missing_policy', 'expected_P_total', 'actual_P_total', 'test_status', 'note'}); %#ok<AGROW>
end
writetable(vertcat(rows{:}), fullfile(out_dir, 'composite_probability_stress_test.csv'));
fprintf('composite probability stress test written.\n');
end

function ensure_dir(path)
if ~exist(path, 'dir')
    mkdir(path);
end
end
