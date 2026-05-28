function main_export_ols_failure_cases()
%MAIN_EXPORT_OLS_FAILURE_CASES Export representative OLS failures for replay.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
table_dir = fullfile(root_dir, 'tables');
case_root = fullfile(root_dir, 'failure_cases');
if ~exist(case_root, 'dir'), mkdir(case_root); end

cfg = base_config();
require_matpower(cfg);
failure_path = fullfile(table_dir, 'ols_failure_diagnosis.csv');
must_exist(failure_path);
failures = readtable(failure_path);
selected = select_failure_rows(failures);

index_rows = {};
for i = 1:height(selected)
    row = selected(i, :);
    case_export_id = sprintf('case_%03d', i);
    case_dir = fullfile(case_root, case_export_id);
    if ~exist(case_dir, 'dir'), mkdir(case_dir); end
    [mpc_before, cumulative_load_shed_mw, stage_record, context] = reconstruct_ols_smoke_stage_case( ...
        project_root, root_dir, cfg, string(row.scenario_id), row.initial_branch, row.trial_id, row.stage_id);

    cfg.paper_ols_apply_solution_mode = 'load_only';
    cfg.paper_ols_relax_voltage_limits = false;
    cfg.paper_ols_rate_limit_relax_factor = 1.0;
    [mpc_after_apply_load_only, runpf_after_apply_result, ~, ols_detail] = ...
        solve_paper_ols_load_shedding(mpc_before, cfg, cumulative_load_shed_mw);
    [mpc_opf_with_shed_generators, opf_result] = run_export_opf_case(mpc_before, cfg);

    case_info = table(string(case_export_id), string(row.scenario_id), row.initial_branch, ...
        row.trial_id, row.stage_id, string(row.failure_type), ...
        string(row.load_shedding_trigger_reason), string(row.message), ...
        string(selected.why_selected(i)), cumulative_load_shed_mw, ...
        'VariableNames', {'case_export_id', 'scenario_id', 'initial_branch', ...
        'trial_id', 'stage_id', 'failure_type', 'trigger_reason', 'message', ...
        'why_selected', 'cumulative_load_shed_mw'});
    writetable(case_info, fullfile(case_dir, 'case_info.csv'));
    save(fullfile(case_dir, 'mpc_before_ols.mat'), 'mpc_before', 'cumulative_load_shed_mw', 'stage_record', 'context', '-v7.3');
    save(fullfile(case_dir, 'mpc_opf_with_shed_generators.mat'), 'mpc_opf_with_shed_generators', '-v7.3');
    save(fullfile(case_dir, 'opf_result.mat'), 'opf_result', '-v7.3');
    save(fullfile(case_dir, 'mpc_after_apply_load_only.mat'), 'mpc_after_apply_load_only', '-v7.3');
    save(fullfile(case_dir, 'runpf_after_apply_result.mat'), 'runpf_after_apply_result', '-v7.3');
    save(fullfile(case_dir, 'ols_detail.mat'), 'ols_detail', '-v7.3');
    write_case_readme(fullfile(case_dir, 'README_case.md'), case_info, ols_detail);

    index_rows{end + 1, 1} = table(string(case_export_id), string(row.scenario_id), ...
        row.initial_branch, row.trial_id, row.stage_id, string(row.failure_type), ...
        string(row.load_shedding_trigger_reason), string(row.message), ...
        string(case_dir), string(selected.why_selected(i)), ...
        'VariableNames', {'case_export_id', 'scenario_id', 'initial_branch', ...
        'trial_id', 'stage_id', 'failure_type', 'trigger_reason', 'message', ...
        'case_dir', 'why_selected'}); %#ok<AGROW>
end

if isempty(index_rows)
    index = table(strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
        strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
        'VariableNames', {'case_export_id', 'scenario_id', 'initial_branch', ...
        'trial_id', 'stage_id', 'failure_type', 'trigger_reason', 'message', ...
        'case_dir', 'why_selected'});
else
    index = vertcat(index_rows{:});
end
writetable(index, fullfile(table_dir, 'ols_failure_case_index.csv'));
fprintf('OLS failure cases exported: %s\n', fullfile(table_dir, 'ols_failure_case_index.csv'));
end

function selected = select_failure_rows(failures)
selected = table();
selected = append_group(selected, failures, string(failures.failure_type) == "opf_nonconverged", 3, "representative OPF nonconverged failure");
selected = append_group(selected, failures, logical(failures.opf_success) & ~logical(failures.pf_success_after_apply), 3, "representative OPF success but PF after apply failed");
selected = append_group(selected, failures, contains(string(failures.load_shedding_trigger_reason), "line_overload"), 2, "representative line-overload trigger failure");
selected = append_group(selected, failures, contains(string(failures.load_shedding_trigger_reason), "nonconverged"), 2, "representative nonconverged trigger failure");
if isempty(selected)
    return;
end
[~, ia] = unique(strcat(string(selected.scenario_id), "_", string(selected.initial_branch), "_", ...
    string(selected.trial_id), "_", string(selected.stage_id)), 'stable');
selected = selected(ia, :);
end

function selected = append_group(selected, failures, mask, limit, note)
rows = failures(mask, :);
if isempty(rows)
    return;
end
rows = rows(1:min(limit, height(rows)), :);
rows.why_selected = repmat(string(note), height(rows), 1);
selected = [selected; rows]; %#ok<AGROW>
end

function [mpc_opf, opf_result] = run_export_opf_case(mpc_before, cfg)
[mpc_opf, ~] = build_export_opf_case(mpc_before, cfg);
try
    mpopt = mpoption('verbose', 0, 'out.all', 0);
    opf_result = runopf(mpc_opf, mpopt);
catch ME
    opf_result = struct('success', false, 'message', ME.message);
end
end

function [mpc_opf, shed_gen_rows] = build_export_opf_case(mpc_in, cfg)
load_rows = find(mpc_in.bus(:, 3) > 1e-9);
mpc_opf = mpc_in;
num_shed = numel(load_rows);
num_gen0 = size(mpc_in.gen, 1);
new_gen = zeros(num_shed, size(mpc_in.gen, 2));
for k = 1:num_shed
    bus_row = load_rows(k);
    pd = mpc_in.bus(bus_row, 3);
    qd = mpc_in.bus(bus_row, 4);
    new_gen(k, 1) = mpc_in.bus(bus_row, 1);
    new_gen(k, 4) = max(abs(qd), 0);
    new_gen(k, 5) = -max(abs(qd), 0);
    new_gen(k, 6) = max(mpc_in.bus(bus_row, 8), 1.0);
    new_gen(k, 7) = mpc_in.baseMVA;
    new_gen(k, 8) = 1;
    new_gen(k, 9) = pd;
    new_gen(k, 10) = 0;
end
mpc_opf.gen = [mpc_opf.gen; new_gen];
shed_gen_rows = (num_gen0 + 1):(num_gen0 + num_shed);
cost_col = 6;
if isfield(mpc_opf, 'gencost') && ~isempty(mpc_opf.gencost)
    cost_col = size(mpc_opf.gencost, 2);
end
gencost = zeros(num_gen0 + num_shed, cost_col);
gencost(:, 1) = 2;
gencost(:, 4) = 2;
if cost_col >= 6
    gencost(1:num_gen0, 5) = get_cfg(cfg, 'paper_ols_generation_cost', 0.0);
    gencost(num_gen0 + 1:end, 5) = get_cfg(cfg, 'paper_ols_shed_cost', 1.0);
end
mpc_opf.gencost = gencost;
end

function write_case_readme(path, case_info, ols_detail)
fid = fopen(path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# OLS Failure Case %s\n\n', case_info.case_export_id);
fprintf(fid, '- scenario_id: `%s`\n', case_info.scenario_id);
fprintf(fid, '- initial_branch: %g\n', case_info.initial_branch);
fprintf(fid, '- trial_id: %g\n', case_info.trial_id);
fprintf(fid, '- stage_id: %g\n', case_info.stage_id);
fprintf(fid, '- failure_type: `%s`\n', case_info.failure_type);
fprintf(fid, '- trigger_reason: `%s`\n', case_info.trigger_reason);
fprintf(fid, '- why_selected: %s\n\n', case_info.why_selected);
fprintf(fid, 'This case was reconstructed from existing OLS benchmark smoke `chain_records`. It does not rerun Markov sampling.\n\n');
fprintf(fid, 'Replay files include `mpc_before_ols.mat`, `mpc_opf_with_shed_generators.mat`, `opf_result.mat`, `mpc_after_apply_load_only.mat`, `runpf_after_apply_result.mat`, and `ols_detail.mat`.\n\n');
fprintf(fid, 'Recorded replay status: opf_success=%d, pf_success_after_apply=%d, message=%s\n', ...
    ols_detail.opf_success, ols_detail.pf_success_after_apply, ols_detail.message);
end

function value = get_cfg(cfg, field_name, default_value)
if isfield(cfg, field_name)
    value = cfg.(field_name);
else
    value = default_value;
end
end

function must_exist(path)
if ~exist(path, 'file')
    error('Required file is missing: %s', path);
end
end
