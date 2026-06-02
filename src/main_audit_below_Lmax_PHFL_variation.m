function main_audit_below_Lmax_PHFL_variation()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'hidden_failure_formula');
ensure_dir(out_dir);
T = readtable(fullfile(out_dir, 'hidden_failure_component_recompute_audit.csv'), 'TextType','string');
T = T(logical(T.below_Lmax_flag), :);
if isempty(T)
    R = table(strings(0,1), strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        zeros(0,1), zeros(0,1), zeros(0,1), false(0,1), false(0,1), false(0,1), strings(0,1), strings(0,1), ...
        'VariableNames', {'parameter_set_id','scenario_id','candidate_branch','below_Lmax_sample_count', ...
        'recorded_P_HF_L_min','recorded_P_HF_L_max','recorded_P_HF_L_range','recomputed_P_HF_L_paper_min', ...
        'recomputed_P_HF_L_paper_max','recomputed_P_HF_L_paper_range','recorded_varies_below_Lmax', ...
        'paper_recompute_constant_below_Lmax','issue_confirmed','recommended_fix','note'});
    writetable(R, fullfile(out_dir, 'below_Lmax_PHFL_variation_audit.csv'));
    return;
end
G = findgroups(T.parameter_set_id, T.scenario_id, T.candidate_branch);
rows = {};
for g = 1:max(G)
    S = T(G == g, :);
    rec_min = min(S.recorded_P_HF_L, [], 'omitnan'); rec_max = max(S.recorded_P_HF_L, [], 'omitnan');
    rep_min = min(S.recomputed_P_HF_L_paper, [], 'omitnan'); rep_max = max(S.recomputed_P_HF_L_paper, [], 'omitnan');
    rec_range = rec_max - rec_min;
    rep_range = rep_max - rep_min;
    recorded_varies = rec_range > 1e-8;
    paper_constant = rep_range <= 1e-10;
    issue = recorded_varies && paper_constant;
    fix = "no_fix_required";
    note = "Recorded and paper recomputed P_HF_L are constant below L_max.";
    if issue
        fix = "set_P_HF_L_constant_below_Lmax_for_paper_mode";
        note = "Recorded P_HF_L varies below L_max while paper recompute is constant.";
    end
    rows{end+1,1} = table(S.parameter_set_id(1), S.scenario_id(1), S.candidate_branch(1), height(S), ...
        rec_min, rec_max, rec_range, rep_min, rep_max, rep_range, recorded_varies, paper_constant, issue, fix, note, ...
        'VariableNames', {'parameter_set_id','scenario_id','candidate_branch','below_Lmax_sample_count', ...
        'recorded_P_HF_L_min','recorded_P_HF_L_max','recorded_P_HF_L_range','recomputed_P_HF_L_paper_min', ...
        'recomputed_P_HF_L_paper_max','recomputed_P_HF_L_paper_range','recorded_varies_below_Lmax', ...
        'paper_recompute_constant_below_Lmax','issue_confirmed','recommended_fix','note'}); %#ok<AGROW>
end
writetable(vertcat(rows{:}), fullfile(out_dir, 'below_Lmax_PHFL_variation_audit.csv'));
end

function ensure_dir(path)
if exist(path,'dir')~=7, mkdir(path); end
end
