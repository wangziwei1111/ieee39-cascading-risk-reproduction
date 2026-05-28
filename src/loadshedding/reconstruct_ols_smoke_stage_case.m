function [mpc_before, cumulative_load_shed_mw, stage_record, context] = reconstruct_ols_smoke_stage_case(project_root, root_dir, cfg, scenario_id, initial_branch, trial_id, stage_id)
%RECONSTRUCT_OLS_SMOKE_STAGE_CASE Rebuild a recorded OLS smoke stage input.
% This helper replays only recorded outages from existing chain_records. It
% does not resample Markov candidates or modify the original smoke results.
arguments
    project_root char
    root_dir char
    cfg struct
    scenario_id {mustBeTextScalar}
    initial_branch double
    trial_id double
    stage_id double
end

scenario_id = string(scenario_id);
base_mpc0 = build_case39_base(cfg);
scenario = get_scenario_by_id(char(scenario_id), cfg, sum(base_mpc0.bus(:, 3)));
[base_mpc, renewable_info] = apply_renewable_scenario(base_mpc0, scenario);

mat_path = fullfile(root_dir, 'paper_ols_violation', char(scenario_id), ...
    'chains', 'markov_chain_records.mat');
if ~exist(mat_path, 'file')
    error('Missing chain_records file for OLS smoke scenario: %s', mat_path);
end
loaded = load(mat_path, 'chain_records');
chain_records = loaded.chain_records;
match_idx = find([chain_records.initial_branch]' == initial_branch & ...
    [chain_records.trial_id]' == trial_id, 1);
if isempty(match_idx)
    error('Could not find chain record for %s initial=%g trial=%g.', ...
        scenario_id, initial_branch, trial_id);
end
if stage_id < 1 || stage_id > numel(chain_records(match_idx).stage_records)
    error('Stage %g is out of range for %s initial=%g trial=%g.', ...
        stage_id, scenario_id, initial_branch, trial_id);
end
stage_record = chain_records(match_idx).stage_records(stage_id);
if ~isfield(stage_record, 'all_outaged_branches')
    error('Stage record does not contain all_outaged_branches; cannot rebuild without fabricating state.');
end

[mpc_fault, ~] = apply_line_outages(base_mpc, stage_record.all_outaged_branches);
[mpc_before, island_info] = normalize_case_after_contingency(mpc_fault, cfg, scenario, renewable_info);
if isfield(stage_record, 'shed') && isfield(stage_record.shed, 'island_load_shed_mw')
    cumulative_load_shed_mw = stage_record.shed.island_load_shed_mw;
else
    cumulative_load_shed_mw = island_info.disconnected_load_mw;
end

context = struct();
context.scenario = scenario;
context.renewable_info = renewable_info;
context.base_mpc = base_mpc;
context.chain_record = chain_records(match_idx);
context.chain_records_path = mat_path;
context.island_info = island_info;
end
