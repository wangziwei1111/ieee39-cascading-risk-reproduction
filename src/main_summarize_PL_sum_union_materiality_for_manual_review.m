function main_summarize_PL_sum_union_materiality_for_manual_review()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'event_probability_formula');
U = readtable(fullfile(out_dir, 'PL_sum_vs_union_difference_audit.csv'), 'TextType','string');
S = readtable(fullfile(out_dir, 'wind_speed_PL_aggregation_sensitivity.csv'), 'TextType','string');
E = readtable(fullfile(out_dir, 'wind_speed_P1_P2_P3_increase_explanation.csv'), 'TextType','string');
rows = {};
rows{end+1,1} = item("material_difference_candidate_count", sum(logical(U.difference_material)), "simple sum and union differ materially for this many grouped candidate rows", "shows formula choice matters", "");
rows{end+1,1} = item("candidate_probability_equals_simple_sum_count", sum(logical(U.candidate_probability_equals_simple_sum)), "recorded candidate probability follows clipped simple sum groups", "confirms current code basis", "");
rows{end+1,1} = item("candidate_probability_equals_union_count", sum(logical(U.candidate_probability_equals_union)), "recorded candidate probability follows independent union groups", "would support union only if paper confirms it", "");
rows{end+1,1} = item("max_abs_difference", max(U.max_abs_difference, [], 'omitnan'), "maximum absolute difference between clipped sum and union", "quantifies materiality", "");
rows{end+1,1} = item("mean_abs_difference", mean(U.mean_abs_difference, 'omitnan'), "mean grouped absolute difference", "quantifies average materiality", "");
changes = any(S.aggregation_variant=="union_PL_offline_proxy" & S.direction_match);
rows{end+1,1} = item("whether_union_changes_wind_speed_direction", changes, "union proxy has at least one direction-match row", "proxy only; not a formula decision", "Uses same selected flags; no Markov rerun.");
rows{end+1,1} = item("whether_simple_sum_currently_used", true, "current candidate probability equals clipped simple sum", "documents implementation state", "");
rows{end+1,1} = item("whether_paper_union_confirmed", false, "current repository does not contain explicit union confirmation", "blocks formula change", "");
rows{end+1,1} = item("recommended_manual_check", "confirm P_L formula and event relationships from paper screenshot", "manual confirmation required before code change", "highest priority", "Dominant terms include "+strjoin(unique(E.dominant_probability_term)', ','));
writetable(vertcat(rows{:}), fullfile(out_dir, 'PL_sum_union_materiality_summary.csv'));
end

function T = item(name, value, interp, relevance, note)
T = table(string(name), string(value), string(interp), string(relevance), string(note), ...
    'VariableNames', {'summary_item','value','interpretation','manual_confirmation_relevance','note'});
end
