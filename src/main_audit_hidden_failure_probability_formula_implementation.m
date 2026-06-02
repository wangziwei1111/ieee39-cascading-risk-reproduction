function main_audit_hidden_failure_probability_formula_implementation()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'hidden_failure_formula');
ensure_dir(out_dir);
src_file = fullfile(root, 'src', 'outage', 'compute_paper_line_outage_probability.m');
txt = string(fileread(src_file));

items = [
    "P_HF_L_below_Lmax", "loading < L_max_pu", "P_HF_L = P_L_D when L < L_max", "P_HF_L_varies_below_Lmax"
    "P_HF_L_between_Lmax_1p4Lmax", "loading <= 1.4 * L_max_pu", "linear interpolation from P_L_D to P_L_r over [L_max,1.4L_max]", "P_HF_L_wrong_linear_interval"
    "P_HF_L_above_1p4Lmax", "P_HF_L = P_L_r", "P_HF_L = P_L_r when L > 1.4L_max", "P_HF_L_wrong_linear_interval"
    "P_HF_L_threshold_basis", "L_max_pu", "P_HF_L threshold basis is L_max, not L_Rated", "P_HF_L_uses_Lrated_threshold"
    "P_L_D_definition", "paper_line_P_L_D", "P_L_D read from cfg/preset and not fabricated", "unknown"
    "P_L_r_definition", "paper_line_P_L_r", "P_L_r read from cfg/preset and not fabricated", "unknown"
    "P_HF_D_mode", "compute_distance_hidden_failure", "distance hidden failure is impedance formula or explicit disabled/proxy mode", "unknown"
    "P_mis_r_formula", "P_HF_D + P_HF_L - P_HF_D * P_HF_L", "P_mis_r is union probability", "P_mis_r_formula_mismatch"
    "P2_formula", "P_mis_c + P_mis_r * (1 - P_in_c)", "P2 = P_mis_c + P_mis_r*(1-P_in_c)", "P2_formula_mismatch"
    "P_L_formula", "P1 + P2 + P3", "P_L = P1 + P2 + P3 clipped to [0,1]", "P_L_formula_mismatch"
    "line_loading_pu_mapping", "loading = max(line_loading_pu, 0)", "line_loading_pu is interpreted as L/L_max in probability formula", "unknown"
    "legacy_mode_separation", "legacy_loading_scaled", "legacy loading-scaled mode is explicit diagnostic only", "unknown"
];

rows = cell(size(items, 1), 1);
for i = 1:size(items, 1)
    present = contains(txt, items(i, 2));
    status = "match";
    issue = "no_issue";
    if ~present
        status = "ambiguous";
        issue = items(i, 4);
    elseif items(i, 1) == "legacy_mode_separation"
        status = "legacy_mode_only";
    end
    rows{i} = table(string(src_file), "compute_paper_line_outage_probability", items(i,1), ...
        items(i,3), items(i,2), status, issue, recommended_fix(status, issue), ...
        "Static source audit for paper-consistent hidden-failure probability terms; no simulation run.", ...
        'VariableNames', {'source_file','source_function','formula_item','expected_paper_behavior','current_behavior', ...
        'match_status','issue_type','recommended_fix','note'});
end
writetable(vertcat(rows{:}), fullfile(out_dir, 'hidden_failure_probability_formula_implementation_audit.csv'));
end

function r = recommended_fix(status, issue)
if status == "match" || status == "legacy_mode_only"
    r = "no_fix_required";
elseif issue == "P_HF_L_varies_below_Lmax"
    r = "set_P_HF_L_constant_below_Lmax_for_paper_mode";
else
    r = "inspect_formula_implementation";
end
end

function ensure_dir(path)
if exist(path, 'dir') ~= 7, mkdir(path); end
end
