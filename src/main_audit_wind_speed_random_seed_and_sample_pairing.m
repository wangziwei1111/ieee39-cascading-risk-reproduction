function main_audit_wind_speed_random_seed_and_sample_pairing()
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
parameter_sets = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
rows = cell(numel(parameter_sets), 1);
for p = 1:numel(parameter_sets)
    ps = parameter_sets(p);
    a_dir = fullfile(out_root, ps, 'wind_speed_11_28');
    b_dir = fullfile(out_root, ps, 'wind_speed_12_00');
    A = readtable(fullfile(a_dir, 'tables', 'markov_chain_summary.csv'), 'TextType', 'string');
    B = readtable(fullfile(b_dir, 'tables', 'markov_chain_summary.csv'), 'TextType', 'string');
    SA = readtable(fullfile(a_dir, 'scenario_config_snapshot.csv'), 'TextType', 'string');
    SB = readtable(fullfile(b_dir, 'scenario_config_snapshot.csv'), 'TextType', 'string');
    CA = readtable(fullfile(a_dir, 'tables', 'candidate_probability_trace.csv'), 'TextType', 'string');
    CB = readtable(fullfile(b_dir, 'tables', 'candidate_probability_trace.csv'), 'TextType', 'string');
    seed_a = SA.random_seed(1); seed_b = SB.random_seed(1);
    seed_status = ternary(seed_a == seed_b, "matched", "not_matched");
    keyA = unique(A(:, {'initial_branch','trial_id'}), 'rows');
    keyB = unique(B(:, {'initial_branch','trial_id'}), 'rows');
    [common, ia, ib] = intersect(keyA, keyB, 'rows'); %#ok<ASGLU>
    unpaired_a = height(keyA) - height(common);
    unpaired_b = height(keyB) - height(common);
    branch_match = isequal(sort(unique(A.initial_branch)), sort(unique(B.initial_branch)));
    trial_match = isequal(sort(unique(A.trial_id)), sort(unique(B.trial_id)));
    stageA = unique(CA(:, {'initial_branch','trial_id','stage_id'}), 'rows');
    stageB = unique(CB(:, {'initial_branch','trial_id','stage_id'}), 'rows');
    common_stage = intersect(stageA, stageB, 'rows');
    candidate_pairable = height(common_stage) > 0;
    if seed_status ~= "matched"
        pairing = "not_confirmed";
        fix = "rerun_wind_speed_scan_with_common_random_numbers";
    elseif height(common) == height(keyA) && height(common) == height(keyB) && candidate_pairable
        pairing = "fully_pairable";
        fix = "no_rerun_needed_for_pairing; inspect paired risk deltas";
    elseif height(common) > 0
        pairing = "paired_by_initial_branch_trial";
        fix = "use chain-level paired deltas; candidate stage pairing incomplete";
    else
        pairing = "not_confirmed";
        fix = "rerun_wind_speed_scan_with_common_random_numbers";
    end
    rows{p} = table(ps, "wind_speed_11_28", "wind_speed_12_00", seed_a, seed_b, seed_status, ...
        branch_match, trial_match, height(A), height(B), height(common), unpaired_a, unpaired_b, ...
        height(CA), height(CB), candidate_pairable, pairing, fix, ...
        "Audit reads existing after-curve-fix pilot only; no Markov rerun.", ...
        'VariableNames', {'parameter_set_id','scenario_a','scenario_b','random_seed_a','random_seed_b', ...
        'seed_match_status','initial_branch_set_match','trial_id_set_match','chain_sample_count_a','chain_sample_count_b', ...
        'paired_sample_count','unpaired_sample_count_a','unpaired_sample_count_b','candidate_trace_count_a','candidate_trace_count_b', ...
        'candidate_trace_pairable','pairing_status','recommended_fix','note'});
end
writetable(vertcat(rows{:}), fullfile(out_root, 'wind_speed_random_seed_pairing_audit.csv'));
end

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
