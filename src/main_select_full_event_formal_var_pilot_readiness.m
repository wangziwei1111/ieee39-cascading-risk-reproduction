function main_select_full_event_formal_var_pilot_readiness()
%MAIN_SELECT_FULL_EVENT_FORMAL_VAR_PILOT_READINESS Build readiness gate for future full-event formal pilot.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'calibration', 'transition_probability');
ta_summary = readtable(fullfile(root_dir, 'candidate_selection_consistency_terminal_aware_summary.csv'), 'TextType', 'string');
recon = readtable(fullfile(root_dir, 'full_event_zero_selection_reconciliation.csv'), 'TextType', 'string');
chain_tbl = readtable(fullfile(root_dir, 'full_event_trace_smoke', 'markov_chain_summary.csv'), 'TextType', 'string');
stage_tbl = readtable(fullfile(root_dir, 'full_event_trace_smoke', 'stage_transition_probability_details.csv'), 'TextType', 'string');
scenario_readiness_path = fullfile(project_root, 'results', 'calibration', 'diagnostics', 'formal_scenario_aligned_var_pilot_readiness.csv');

scenario_ready = false;
scenario_status = "missing_scenario_readiness";
if exist(scenario_readiness_path, 'file') == 2
    scenario_tbl = readtable(scenario_readiness_path, 'TextType', 'string');
    if ismember('formal_var_pilot_ready', scenario_tbl.Properties.VariableNames)
        scenario_ready = logical(scenario_tbl.formal_var_pilot_ready(1));
        scenario_status = string(scenario_tbl.target_mapping_status(1));
    end
end

nonterminal_inconsistent = ta_summary.inconsistent_nonterminal_count(1);
missing_random = ta_summary.random_u_missing_nonterminal_count(1);
blocking_recon = sum(logical(recon.blocking_for_formal_rerun));
all_chain_full = all(string(chain_tbl.chain_probability_status) == "full_event_available");
ambiguous_count = sum(string(stage_tbl.probability_status) == "ambiguous_terminal_stage");
inconsistent_stage_count = sum(string(stage_tbl.probability_status) == "inconsistent_candidate_selection" | ...
    string(stage_tbl.probability_status) == "inconsistent_random_selection");

blocking_issue_count = 0;
recommended = "run_full_event_formal_scenario_aligned_var_pilot";
if ~scenario_ready
    blocking_issue_count = blocking_issue_count + 1;
    recommended = "fix_scenario_mapping_first";
end
if nonterminal_inconsistent > 0 || missing_random > 0
    blocking_issue_count = blocking_issue_count + 1;
    recommended = "fix_nonterminal_selection_trace_before_formal_rerun";
end
if ambiguous_count > 0
    blocking_issue_count = blocking_issue_count + 1;
    recommended = "fix_terminal_stage_classification";
end
if inconsistent_stage_count > 0 || ~all_chain_full || blocking_recon > 0
    blocking_issue_count = blocking_issue_count + 1;
    if recommended == "run_full_event_formal_scenario_aligned_var_pilot"
        recommended = "fix_full_event_probability_trace_before_formal_rerun";
    end
end

ready = blocking_issue_count == 0;
if ready
    recommended = "run_full_event_formal_scenario_aligned_var_pilot";
end
warning_issue_count = ta_summary.terminal_exclusion_count(1);
out = table(ready, string(ta_summary.recommendation(1)), ...
    resolve_zero_probability_status(chain_tbl), resolve_chain_status(chain_tbl), ...
    scenario_status, blocking_issue_count, warning_issue_count, string(recommended), ...
    "Readiness only; this script does not run formal pilot or local search.", ...
    'VariableNames', {'ready_for_full_event_formal_var_pilot', ...
    'terminal_aware_selection_status', 'zero_probability_status', ...
    'chain_probability_status', 'scenario_mapping_status', ...
    'blocking_issue_count', 'warning_issue_count', 'recommended_next_step', 'note'});
writetable(out, fullfile(root_dir, 'full_event_formal_var_pilot_readiness.csv'));
fprintf('full-event formal VaR pilot readiness written: %s\n', root_dir);
end

function status = resolve_chain_status(chain_tbl)
statuses = unique(string(chain_tbl.chain_probability_status));
status = strjoin(statuses(:)', ',');
end

function status = resolve_zero_probability_status(chain_tbl)
if any(isnan(chain_tbl.chain_transition_probability))
    status = "chain_probability_nan";
elseif any(chain_tbl.chain_transition_probability == 0)
    status = "chain_probability_zero_present";
else
    status = "no_unexplained_zero_probability";
end
end
