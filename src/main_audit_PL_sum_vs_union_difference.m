function main_audit_PL_sum_vs_union_difference()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'event_probability_formula');
T = readtable(fullfile(out_dir, 'PL_event_component_recompute_audit.csv'), 'TextType','string');
G = findgroups(T.parameter_set_id, T.scenario_id, T.candidate_branch);
rows = {};
for g = 1:max(G)
    S = T(G==g,:);
    diff = abs(S.recomputed_PL_clipped - S.recomputed_PL_independent_union);
    rel = diff ./ max(abs(S.recomputed_PL_clipped), 1e-12);
    simple_match = all(abs(S.recorded_candidate_probability - S.recomputed_PL_clipped) <= 1e-10 | isnan(S.recorded_candidate_probability));
    union_match = all(abs(S.recorded_candidate_probability - S.recomputed_PL_independent_union) <= 1e-10 | isnan(S.recorded_candidate_probability));
    material = max(diff, [], 'omitnan') > 1e-3 || mean(rel, 'omitnan') > 0.01;
    fix = "no_fix_required";
    note = "Simple-sum and union difference is diagnostic only; available extracted paper formula does not confirm union.";
    if material
        fix = "need_manual_paper_confirmation";
        note = "Simple-sum and independent-union differ materially, but paper union requirement is not confirmed.";
    end
    rows{end+1,1} = table(S.parameter_set_id(1), S.scenario_id(1), S.candidate_branch(1), height(S), ...
        mean(S.recomputed_PL_clipped,'omitnan'), mean(S.recomputed_PL_independent_union,'omitnan'), mean(diff,'omitnan'), max(diff,[],'omitnan'), ...
        mean(rel,'omitnan'), sum(S.recomputed_PL_simple_sum > 1), simple_match, union_match, material, fix, note, ...
        'VariableNames', {'parameter_set_id','scenario_id','candidate_branch','sample_count','mean_PL_simple_sum','mean_PL_independent_union', ...
        'mean_abs_difference','max_abs_difference','relative_difference_mean','PL_sum_exceeds_one_count','candidate_probability_equals_simple_sum', ...
        'candidate_probability_equals_union','difference_material','recommended_fix','note'}); %#ok<AGROW>
end
writetable(vertcat(rows{:}), fullfile(out_dir, 'PL_sum_vs_union_difference_audit.csv'));
end
