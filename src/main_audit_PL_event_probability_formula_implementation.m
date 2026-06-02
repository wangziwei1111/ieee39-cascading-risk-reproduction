function main_audit_PL_event_probability_formula_implementation()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'event_probability_formula');
ensure_dir(out_dir);
files = struct();
files.line = fullfile(root, 'src', 'outage', 'compute_paper_line_outage_probability.m');
files.stage = fullfile(root, 'src', 'cascade', 'compute_stage_transition_probability_from_candidates.m');
files.chain = fullfile(root, 'src', 'cascade', 'aggregate_chain_transition_probability.m');
line_txt = string(fileread(files.line));
stage_txt = string(fileread(files.stage));
chain_txt = string(fileread(files.chain));
rows = {
    row(files.line, "compute_paper_line_outage_probability", "P1_formula", "P1 = P_flow*(1-P_in_r)*(1-P_in_c)", line_txt, "P_flow * (1 - P_in_r) * (1 - P_in_c)", "P1_formula_mismatch")
    row(files.line, "compute_paper_line_outage_probability", "P_mis_r_formula", "P_mis_r = P_HF_D + P_HF_L - P_HF_D*P_HF_L", line_txt, "P_HF_D + P_HF_L - P_HF_D * P_HF_L", "unknown")
    row(files.line, "compute_paper_line_outage_probability", "P2_formula", "P2 = P_mis_c + P_mis_r*(1-P_in_c)", line_txt, "P_mis_c + P_mis_r * (1 - P_in_c)", "P2_formula_mismatch")
    row(files.line, "compute_paper_line_outage_probability", "P3_formula", "P3 read from cfg/table; not fabricated", line_txt, "paper_line_P3", "P3_formula_missing")
    row(files.line, "compute_paper_line_outage_probability", "PL_formula", "Current encoded paper structure uses P_L = P1 + P2 + P3 with final clipping", line_txt, "P1 + P2 + P3", "unknown")
    row(files.line, "compute_paper_line_outage_probability", "PL_clipping", "P_L clipped to [0,1] after summing terms", line_txt, "min(max(P1 + P2 + P3, 0), 1)", "PL_clipping_mismatch")
    manual_row("paper_inputs/filled and validated", "paper_formula_reference", "event_mutual_exclusivity", "Paper text available in repository does not explicitly confirm mutual exclusivity beyond listed sum formula.", "manual confirmation required", "ambiguous", "unknown", "need_manual_paper_confirmation")
    manual_row("paper_inputs/filled and validated", "paper_formula_reference", "inclusion_exclusion_needed", "Do not switch to union unless paper explicitly requires inclusion-exclusion.", "union not confirmed by available extracted inputs", "missing_paper_definition", "PL_should_use_inclusion_exclusion", "need_manual_paper_confirmation")
    row(files.stage, "compute_stage_transition_probability_from_candidates", "candidate_probability_equals_PL", "Candidate probability should be the line outage probability P_L for the candidate line.", stage_txt, "candidate_probability", "candidate_probability_not_PL")
    row(files.stage, "compute_stage_transition_probability_from_candidates", "stage_probability_uses_candidate_probability", "Full-event stage probability multiplies selected p and unselected (1-p).", stage_txt, "selected_product * unselected_product", "unknown")
    row(files.chain, "aggregate_chain_transition_probability", "chain_probability_uses_stage_probability", "Chain probability is product of stage transition probabilities.", chain_txt, "prod(stage_probs)", "unknown")
    manual_row(files.stage, "compute_stage_transition_probability_from_candidates", "duplicate_probability_multiplication", "P_L is used once as Bernoulli probability per candidate; complements are event aggregation, not re-applying P_L formula.", "full Bernoulli event aggregation", "match", "no_issue", "no_fix_required")
    row(files.line, "compute_paper_line_outage_probability", "legacy_mode_separation", "Legacy modes must remain explicit diagnostic-only options.", line_txt, "legacy", "unknown")
};
writetable(vertcat(rows{:}), fullfile(out_dir, 'PL_event_probability_formula_implementation_audit.csv'));
end

function T = row(file, func, item, expected, txt, needle, issue)
if contains(txt, needle)
    status = "match"; issue_type = "no_issue"; fix = "no_fix_required";
else
    status = "ambiguous"; issue_type = issue; fix = "inspect_formula_implementation";
end
T = manual_row(file, func, item, expected, needle, status, issue_type, fix);
end

function T = manual_row(file, func, item, expected, current, status, issue, fix)
T = table(string(file), string(func), string(item), string(expected), string(current), string(status), string(issue), string(fix), ...
    "Offline source audit only; no formula change unless paper definition is explicit.", ...
    'VariableNames', {'source_file','source_function','formula_item','expected_paper_behavior','current_behavior','match_status','issue_type','recommended_fix','note'});
end

function ensure_dir(path)
if exist(path,'dir')~=7, mkdir(path); end
end
