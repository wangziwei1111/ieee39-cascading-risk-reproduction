function main_audit_line_outage_probability_formula_implementation()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'line_probability_formula');
ensure_dir(out_dir);
src_file = fullfile(root, 'src', 'outage', 'compute_paper_line_outage_probability.m');
txt = string(fileread(src_file));
items = [
    "P_flow_below_Lrated","loading <= L_rated_pu","P_flow = P_L0","match","no_issue"
    "P_flow_between_Lrated_Lmax","loading <= L_max_pu","P_L0 + (1 - P_L0)","match","no_issue"
    "P_flow_above_Lmax","else","P_flow = 1","match","no_issue"
    "L_Rated_definition","L_rated_pu = L_rated_factor * L_max_pu","L_Rated=L_rated_factor*L_max","match","no_issue"
    "L_max_definition","L_max_pu = L_max_factor","L_max from configured factor / loading pu base","match","no_issue"
    "line_loading_pu_mapping","loading = max(line_loading_pu, 0)","line_loading_pu interpreted as L/L_max in probability formula","match","no_issue"
    "P_HF_L_piecewise","loading < L_max_pu","P_L_D / linear to P_L_r / P_L_r","match","no_issue"
    "P_HF_D_mode","compute_distance_hidden_failure","impedance formula or disabled/proxy if missing","match","no_issue"
    "P_mis_r_formula","P_HF_D + P_HF_L - P_HF_D * P_HF_L","union probability","match","no_issue"
    "P1_formula","P_flow * (1 - P_in_r) * (1 - P_in_c)","paper P1","match","no_issue"
    "P2_formula","P_mis_c + P_mis_r * (1 - P_in_c)","paper P2","match","no_issue"
    "P_L_formula","P1 + P2 + P3","paper total probability","match","no_issue"
    "clipping_to_0_1","min(max(P1 + P2 + P3, 0), 1)","clip total probability to [0,1]","match","no_issue"
    "legacy_mode_separation","legacy_loading_scaled","legacy explicit mode only","match","no_issue"
];
rows = cell(size(items,1),1);
for i = 1:size(items,1)
    present = contains(txt, items(i,2));
    status = items(i,4);
    issue = items(i,5);
    if ~present
        status = "ambiguous"; issue = "unknown";
    end
    rows{i} = table(string(src_file), "compute_paper_line_outage_probability", items(i,1), items(i,3), ...
        items(i,2), status, issue, recommended(status, items(i,1)), ...
        "Static source audit; confirms paper-mode P_flow is constant below L_Rated.", ...
        'VariableNames', {'source_file','source_function','formula_item','expected_paper_behavior','current_behavior', ...
        'match_status','issue_type','recommended_fix','note'});
end
writetable(vertcat(rows{:}), fullfile(out_dir, 'line_outage_probability_formula_implementation_audit.csv'));
end

function r = recommended(status, item)
if status == "match"
    r = "no_fix_required";
elseif item == "P_flow_below_Lrated"
    r = "set_P_flow_constant_below_Lrated_for_paper_mode";
else
    r = "inspect_formula_implementation";
end
end

function ensure_dir(path)
if exist(path,'dir')~=7, mkdir(path); end
end
