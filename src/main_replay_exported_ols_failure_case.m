function main_replay_exported_ols_failure_case()
%MAIN_REPLAY_EXPORTED_OLS_FAILURE_CASE Replay exported OLS failure cases.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
table_dir = fullfile(root_dir, 'tables');
cfg = base_config();
require_matpower(cfg);

index_path = fullfile(table_dir, 'ols_failure_case_index.csv');
must_exist(index_path);
index = readtable(index_path);
rows = {};
for i = 1:height(index)
    case_export_id = string(index.case_export_id(i));
    case_dir = string(index.case_dir(i));
    try
        before = load(fullfile(case_dir, 'mpc_before_ols.mat'), 'mpc_before', 'cumulative_load_shed_mw');
        original = load(fullfile(case_dir, 'ols_detail.mat'), 'ols_detail');
        cfg.paper_ols_apply_solution_mode = 'load_only';
        cfg.paper_ols_relax_voltage_limits = false;
        cfg.paper_ols_rate_limit_relax_factor = 1.0;
        [~, ~, ~, replay_detail] = solve_paper_ols_load_shedding( ...
            before.mpc_before, cfg, before.cumulative_load_shed_mw);
        replay_failure_type = string(replay_detail.diagnosis_failure_type);
        original_failure_type = string(index.failure_type(i));
        replay_opf_success = logical(replay_detail.opf_success);
        replay_pf_success_after_apply = logical(replay_detail.pf_success_after_apply);
        original_opf_success = logical(original.ols_detail.opf_success);
        original_pf_success_after_apply = logical(original.ols_detail.pf_success_after_apply);
        match_original = replay_opf_success == original_opf_success && ...
            replay_pf_success_after_apply == original_pf_success_after_apply && ...
            replay_failure_type == original_failure_type;
        message = string(replay_detail.message);
    catch ME
        replay_opf_success = false;
        replay_pf_success_after_apply = false;
        original_failure_type = string(index.failure_type(i));
        replay_failure_type = "replay_failed";
        match_original = false;
        message = "Replay failed: " + string(ME.message);
    end
    rows{end + 1, 1} = table(case_export_id, replay_opf_success, ...
        replay_pf_success_after_apply, original_failure_type, replay_failure_type, ...
        match_original, message, ...
        'VariableNames', {'case_export_id', 'replay_opf_success', ...
        'replay_pf_success_after_apply', 'original_failure_type', ...
        'replay_failure_type', 'match_original', 'message'}); %#ok<AGROW>
end

if isempty(rows)
    replay = table(strings(0, 1), false(0, 1), false(0, 1), strings(0, 1), ...
        strings(0, 1), false(0, 1), strings(0, 1), ...
        'VariableNames', {'case_export_id', 'replay_opf_success', ...
        'replay_pf_success_after_apply', 'original_failure_type', ...
        'replay_failure_type', 'match_original', 'message'});
else
    replay = vertcat(rows{:});
end
writetable(replay, fullfile(table_dir, 'ols_failure_case_replay_check.csv'));
fprintf('OLS failure case replay check written: %s\n', fullfile(table_dir, 'ols_failure_case_replay_check.csv'));
end

function must_exist(path)
if ~exist(path, 'file')
    error('Required file is missing: %s', path);
end
end
