function main_run_line_probability_diagnostic_smoke()
%MAIN_RUN_LINE_PROBABILITY_DIAGNOSTIC_SMOKE Small Markov run comparing engineering and paper P_L.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'outage', 'line_probability_diagnostic_smoke');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

cfg = base_config();
require_matpower(cfg);
cfg.line_outage_probability_model = 'paper_formula_diagnostic';
cfg.markov_num_trials_per_initial_fault = 3;
cfg.markov_random_seed = cfg.seed;
rng(cfg.markov_random_seed);

base_mpc0 = build_case39_base(cfg);
base_load_mw = sum(base_mpc0.bus(:, 3));
scenario = get_scenario_by_id('distributed_wind_3000mw_base', cfg, base_load_mw);
[base_mpc, renewable_info] = apply_renewable_scenario(base_mpc0, scenario);

initial_branches = 1:5;
chain_cells = {};
idx = 0;
for b = initial_branches
    for trial_id = 1:cfg.markov_num_trials_per_initial_fault
        idx = idx + 1;
        chain_cells{idx, 1} = search_cascade_markov_line(base_mpc, b, cfg, scenario, renewable_info, trial_id); %#ok<AGROW>
    end
end

candidate_detail = flatten_candidate_tables_from_cells(chain_cells);
comparison = build_candidate_comparison(candidate_detail);
summary = build_probability_summary(comparison);
chain_summary = build_chain_summary(chain_cells);

writetable(comparison, fullfile(out_dir, 'candidate_probability_comparison.csv'));
writetable(summary, fullfile(out_dir, 'line_probability_summary.csv'));
writetable(chain_summary, fullfile(out_dir, 'markov_chain_summary.csv'));
write_log(out_dir, cfg, height(comparison));
fprintf('line probability diagnostic smoke written: %s\n', out_dir);
end

function comparison = build_candidate_comparison(candidate_detail)
if isempty(candidate_detail)
    comparison = empty_comparison();
    return;
end
comparison = candidate_detail(:, {'initial_branch', 'trial_id', 'stage_id', ...
    'candidate_branch', 'loading_pu', 'outage_probability', 'engineering_probability', ...
    'paper_formula_probability', 'paper_formula_status', ...
    'paper_formula_missing_parameters', 'paper_formula_used_fallback'});
comparison.Properties.VariableNames{'candidate_branch'} = 'candidate_branch';
comparison.Properties.VariableNames{'loading_pu'} = 'line_loading_pu';
end

function summary = build_probability_summary(comparison)
if isempty(comparison)
    summary = table(0, 0, 0, 0, NaN, NaN, NaN, NaN, "no candidate rows", ...
        'VariableNames', {'row_count', 'paper_formula_valid_count', ...
        'paper_formula_missing_param_count', 'paper_formula_fallback_count', ...
        'mean_engineering_probability', 'mean_paper_formula_probability', ...
        'max_engineering_probability', 'max_paper_formula_probability', 'note'});
    return;
end
status = string(comparison.paper_formula_status);
summary = table(height(comparison), ...
    sum(status == "ok_uncalibrated"), ...
    sum(contains(status, "missing_parameter")), ...
    sum(logical(comparison.paper_formula_used_fallback)), ...
    mean(comparison.engineering_probability, 'omitnan'), ...
    mean(comparison.paper_formula_probability, 'omitnan'), ...
    max(comparison.engineering_probability, [], 'omitnan'), ...
    max(comparison.paper_formula_probability, [], 'omitnan'), ...
    "paper_formula_diagnostic returns engineering probability to main chain; paper parameters uncalibrated.", ...
    'VariableNames', {'row_count', 'paper_formula_valid_count', ...
    'paper_formula_missing_param_count', 'paper_formula_fallback_count', ...
    'mean_engineering_probability', 'mean_paper_formula_probability', ...
    'max_engineering_probability', 'max_paper_formula_probability', 'note'});
end

function candidate_detail = flatten_candidate_tables_from_cells(chain_cells)
rows = {};
for i = 1:numel(chain_cells)
    t = flatten_candidate_tables(chain_cells{i});
    if ~isempty(t)
        rows{end+1,1} = t; %#ok<AGROW>
    end
end
if isempty(rows)
    candidate_detail = table();
else
    candidate_detail = vertcat(rows{:});
end
end

function chain_summary = build_chain_summary(chain_cells)
n = numel(chain_cells);
chain_index = (1:n)';
initial_branch = zeros(n,1);
trial_id = zeros(n,1);
chain_depth = zeros(n,1);
final_converged = false(n,1);
total_load_shed_mw = zeros(n,1);
basic_CRI = zeros(n,1);
terminated_reason = strings(n,1);
for i = 1:n
    c = chain_cells{i};
    initial_branch(i) = c.initial_branch;
    trial_id(i) = c.trial_id;
    chain_depth(i) = c.chain_depth;
    final_converged(i) = c.final_converged;
    total_load_shed_mw(i) = c.total_load_shed_mw;
    basic_CRI(i) = c.basic_CRI;
    terminated_reason(i) = string(c.terminated_reason);
end
chain_summary = table(chain_index, initial_branch, trial_id, ...
    chain_depth, final_converged, total_load_shed_mw, basic_CRI, ...
    terminated_reason, ...
    'VariableNames', {'chain_index', 'initial_branch', 'trial_id', ...
    'chain_depth', 'final_converged', 'total_load_shed_mw', ...
    'basic_CRI', 'terminated_reason'});
end

function write_log(out_dir, cfg, row_count)
fid = fopen(fullfile(out_dir, 'diagnostic_log.txt'), 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'line_probability_diagnostic_smoke\n');
fprintf(fid, 'model=%s\n', cfg.line_outage_probability_model);
fprintf(fid, 'scenario=distributed_wind_3000mw_base\n');
fprintf(fid, 'initial_branches=1:5\n');
fprintf(fid, 'trials_per_initial_fault=%d\n', cfg.markov_num_trials_per_initial_fault);
fprintf(fid, 'candidate_rows=%d\n', row_count);
fprintf(fid, 'note=Main chain uses engineering probabilities; paper_formula is diagnostic only and uncalibrated.\n');
end

function comparison = empty_comparison()
comparison = table([], [], [], [], [], [], [], strings(0,1), strings(0,1), false(0,1), ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
    'candidate_branch', 'line_loading_pu', 'outage_probability', ...
    'engineering_probability', 'paper_formula_probability', 'paper_formula_status', ...
    'paper_formula_missing_parameters', 'paper_formula_used_fallback'});
end
