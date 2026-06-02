function main_audit_below_rated_Pflow_variation()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'line_probability_formula');
T = readtable(fullfile(out_dir, 'line_probability_component_recompute_audit.csv'), 'TextType','string');
T = T(T.below_Lrated_flag == 1, :);
keys = unique(T(:, {'parameter_set_id','scenario_id','candidate_branch'}), 'rows');
rows = cell(height(keys),1);
for i = 1:height(keys)
    G = T(T.parameter_set_id==keys.parameter_set_id(i) & T.scenario_id==keys.scenario_id(i) & T.candidate_branch==keys.candidate_branch(i), :);
    rr = range_safe(G.recorded_P_flow);
    pr = range_safe(G.recomputed_P_flow_paper);
    recorded_varies = rr > 1e-8;
    paper_constant = pr <= 1e-8;
    issue = recorded_varies && paper_constant;
    rows{i} = table(keys.parameter_set_id(i), keys.scenario_id(i), keys.candidate_branch(i), height(G), ...
        min(G.recorded_P_flow), max(G.recorded_P_flow), rr, min(G.recomputed_P_flow_paper), max(G.recomputed_P_flow_paper), pr, ...
        recorded_varies, paper_constant, issue, fix_text(issue), ...
        "Grouped by candidate branch; branch-specific P_L0 may differ across branches but should be constant within a branch below L_Rated.", ...
        'VariableNames', {'parameter_set_id','scenario_id','candidate_branch','below_Lrated_sample_count', ...
        'recorded_P_flow_min','recorded_P_flow_max','recorded_P_flow_range','recomputed_P_flow_paper_min', ...
        'recomputed_P_flow_paper_max','recomputed_P_flow_paper_range','recorded_varies_below_Lrated', ...
        'paper_recompute_constant_below_Lrated','issue_confirmed','recommended_fix','note'});
end
writetable(vertcat(rows{:}), fullfile(out_dir, 'below_rated_Pflow_variation_audit.csv'));
end

function r = range_safe(x)
r = max(x, [], 'omitnan') - min(x, [], 'omitnan');
end

function s = fix_text(issue)
if issue
    s = "set_P_flow_constant_below_Lrated_for_paper_mode";
else
    s = "no_fix_required";
end
end
