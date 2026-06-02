function main_run_wind_speed_probability_component_trace_smoke()
root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
audit_path = fullfile(out_root, 'wind_speed_probability_severity_field_availability.csv');
smoke_root = fullfile(out_root, 'wind_speed_probability_component_trace_smoke');
if exist(smoke_root, 'dir') ~= 7, mkdir(smoke_root); end
Audit = readtable(audit_path, 'TextType', 'string');
needs = any(Audit.blocking_if_missing & Audit.recommended_fix == "need_probability_component_trace_smoke");
if ~needs
    writelines("skipped_because_fields_available", fullfile(out_root, 'wind_speed_probability_component_trace_smoke_check_log.txt'));
    return;
end
psets = ["high_hidden_failure","benchmark_calibrated_seed"];
scens = ["wind_speed_11_28","wind_speed_12_00"];
for p = 1:numel(psets)
    for s = 1:numel(scens)
        in_dir = fullfile(out_root, psets(p), scens(s), 'tables');
        out_dir = fullfile(smoke_root, psets(p), scens(s));
        if exist(out_dir, 'dir') ~= 7, mkdir(out_dir); end
        C = readtable(fullfile(in_dir, 'candidate_probability_trace.csv'), 'TextType', 'string');
        S = readtable(fullfile(in_dir, 'stage_transition_probability_details.csv'), 'TextType', 'string');
        M = readtable(fullfile(in_dir, 'markov_chain_summary.csv'), 'TextType', 'string');
        C = C(C.initial_branch <= 3 & C.trial_id <= 2, :);
        S = S(S.initial_branch <= 3 & S.trial_id <= 2, :);
        M = M(M.initial_branch <= 3 & M.trial_id <= 2, :);
        writetable(M, fullfile(out_dir, 'markov_chain_summary.csv'));
        writetable(S, fullfile(out_dir, 'stage_transition_probability_details.csv'));
        writetable(C, fullfile(out_dir, 'candidate_probability_trace.csv'));
        writetable(line_trace(C, psets(p), scens(s)), fullfile(out_dir, 'line_probability_component_trace.csv'));
        writetable(severity_trace(M, psets(p), scens(s)), fullfile(out_dir, 'severity_component_trace.csv'));
        writelines(["component trace smoke exported from existing after-curve-fix trace"; ...
            "No new formal pilot, local search, or final_summary write was executed."], fullfile(out_dir, 'trace_log.txt'));
    end
end
end

function T = line_trace(C, ps, scen)
if ~ismember("line_loading_pu", string(C.Properties.VariableNames)) && ismember("loading_pu", string(C.Properties.VariableNames))
    C.line_loading_pu = C.loading_pu;
end
n = height(C);
T = table(repmat(ps,n,1), repmat(scen,n,1), C.initial_branch, C.trial_id, C.stage_id, C.candidate_branch, ...
    C.line_loading_pu, nan(n,1), nan(n,1), nan(n,1), nan(n,1), nan(n,1), nan(n,1), nan(n,1), ...
    C.candidate_probability, C.candidate_probability, logical(C.selected), C.random_u, ...
    repmat("component_fields_missing_in_existing_trace", n,1), repmat("diagnostic_not_recomputed", n,1), ...
    repmat("benchmark_calibrated_not_original_paper_or_diagnostic", n,1), ...
    repmat("Existing trace exposes candidate_probability but not P_flow/P_HF_L/P1/P2 components.", n,1), ...
    'VariableNames', {'parameter_set_id','scenario_id','initial_branch','trial_id','stage_id','candidate_branch', ...
    'line_loading_pu','P_flow','P_HF_D','P_HF_L','P_mis_r','P1','P2','P3','P_L','candidate_probability', ...
    'selected','random_u','formula_status','parameter_status','calibration_status','note'});
end

function T = severity_trace(M, ps, scen)
n = height(M);
T = table(repmat(ps,n,1), repmat(scen,n,1), M.initial_branch, M.trial_id, nan(n,1), M.basic_LLR, M.basic_LFOR, ...
    M.basic_NVOR, M.basic_CRI, M.total_load_shed_frac, M.max_line_loading_pu, M.max_voltage_deviation_pu, ...
    repmat("chain_summary_basic_severity", n,1), repmat("Severity trace exported from existing chain summary; stage_id unavailable at chain level.", n,1), ...
    'VariableNames', {'parameter_set_id','scenario_id','initial_branch','trial_id','stage_id','basic_LLR','basic_LFOR', ...
    'basic_NVOR','basic_CRI','total_load_shed_frac','max_line_loading_pu','max_voltage_deviation_pu', ...
    'severity_formula_status','note'});
end
