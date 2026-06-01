function main_run_transition_probability_trace_smoke()
%MAIN_RUN_TRANSITION_PROBABILITY_TRACE_SMOKE Small Markov smoke with transition-probability trace.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'calibration', 'transition_probability', 'trace_smoke');
ensure_dir(out_dir);

cfg = base_config();
require_matpower(cfg);
cfg = load_benchmark_calibration_parameter_set(cfg, 'low_hidden_failure');
cfg.markov_num_trials_per_initial_fault = 2;
cfg.markov_max_depth = min(cfg.markov_max_depth, 5);
cfg.markov_random_seed = cfg.seed;
cfg.chain_transition_probability_mode = 'selected_only_product';
cfg.initial_fault_probability_file = fullfile(project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');
rng(cfg.markov_random_seed);

base_mpc0 = build_case39_base(cfg);
scenario = get_scenario_by_id('distributed_30_39', cfg, sum(base_mpc0.bus(:, 3)));
[base_mpc, renewable_info] = apply_renewable_scenario(base_mpc0, scenario);

chain_cells = {};
idx = 0;
for initial_branch = 1:3
    for trial_id = 1:cfg.markov_num_trials_per_initial_fault
        idx = idx + 1;
        chain_cells{idx, 1} = search_cascade_markov_line(base_mpc, initial_branch, cfg, scenario, renewable_info, trial_id); %#ok<AGROW>
    end
end
chain_records = vertcat(chain_cells{:});

[chain_summary, ~] = flatten_chain_records(chain_records, cfg);
stage_transition_details = flatten_stage_transition_probability_records(chain_records);
candidate_trace = build_candidate_probability_trace(chain_records);

save(fullfile(out_dir, 'markov_chain_records.mat'), 'chain_records', 'cfg', 'scenario', 'renewable_info', 'base_mpc', '-v7.3');
writetable(chain_summary, fullfile(out_dir, 'markov_chain_summary.csv'));
writetable(stage_transition_details, fullfile(out_dir, 'stage_transition_probability_details.csv'));
writetable(candidate_trace, fullfile(out_dir, 'candidate_probability_trace.csv'));
write_log(fullfile(out_dir, 'diagnostic_log.txt'), cfg, scenario, chain_summary, stage_transition_details, candidate_trace);
fprintf('transition probability trace smoke written: %s\n', out_dir);
end

function tbl = flatten_stage_transition_probability_records(chain_records)
rows = {};
for i = 1:numel(chain_records)
    c = chain_records(i);
    for s = 1:numel(c.stage_records)
        st = c.stage_records(s);
        if ~isfield(st, 'transition_probability_detail')
            continue;
        end
        d = st.transition_probability_detail;
        rows{end + 1, 1} = table( ... %#ok<AGROW>
            c.initial_branch, c.trial_id, st.stage_id, ...
            string(d.stage_probability_mode), d.candidate_count, ...
            d.selected_candidate_count, d.unselected_candidate_count, ...
            d.selected_probability_product, d.unselected_probability_product, ...
            d.stage_transition_probability, string(d.probability_status), ...
            string(d.missing_reason), string(d.selected_branch_ids), ...
            string(d.random_u_selected), string(d.candidate_probability_basis), string(d.note), ...
            'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
            'stage_probability_mode', 'candidate_count', 'selected_candidate_count', ...
            'unselected_candidate_count', 'selected_probability_product', ...
            'unselected_probability_product', 'stage_transition_probability', ...
            'probability_status', 'missing_reason', 'selected_branch_ids', ...
            'random_u_selected', 'candidate_probability_basis', 'note'});
    end
end
if isempty(rows)
    tbl = table();
else
    tbl = vertcat(rows{:});
end
end

function candidate_trace = build_candidate_probability_trace(chain_records)
candidate_trace = flatten_candidate_tables(chain_records);
if isempty(candidate_trace)
    candidate_trace = table();
    return;
end
candidate_trace.Properties.VariableNames{'candidate_branch'} = 'candidate_branch';
candidate_trace.Properties.VariableNames{'outage_probability'} = 'candidate_probability';
candidate_trace.selected = candidate_trace.trip_selected;
candidate_trace = candidate_trace(:, {'initial_branch', 'trial_id', 'stage_id', ...
    'candidate_branch', 'loading_pu', 'candidate_probability', 'prob_model', ...
    'engineering_probability', 'paper_formula_probability', 'paper_formula_status', ...
    'paper_formula_missing_parameters', 'paper_formula_used_fallback', 'random_u', 'selected'});
end

function write_log(path, cfg, scenario, chain_summary, stage_details, candidate_trace)
fid = fopen(path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'transition_probability_trace_smoke\n');
fprintf(fid, 'scenario_id=%s\n', scenario.scenario_id);
fprintf(fid, 'parameter_set=low_hidden_failure\n');
fprintf(fid, 'initial_branches=1:3\n');
fprintf(fid, 'trials_per_initial_fault=%d\n', cfg.markov_num_trials_per_initial_fault);
fprintf(fid, 'chain_count=%d\n', height(chain_summary));
fprintf(fid, 'stage_count=%d\n', height(stage_details));
fprintf(fid, 'candidate_count=%d\n', height(candidate_trace));
fprintf(fid, 'chain_transition_probability_mode=%s\n', cfg.chain_transition_probability_mode);
fprintf(fid, 'note=Small diagnostic smoke only; selected-only product is not a formal paper probability.\n');
end

function ensure_dir(path)
if ~exist(path, 'dir'), mkdir(path); end
end
