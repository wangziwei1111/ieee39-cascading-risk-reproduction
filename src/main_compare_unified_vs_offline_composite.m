function main_compare_unified_vs_offline_composite()
%MAIN_COMPARE_UNIFIED_VS_OFFLINE_COMPOSITE Compare same-run and offline composite diagnostics with explicit basis notes.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'composite');
offline_all = readtable(fullfile(out_dir, 'composite_state_probability_diagnostic.csv'), 'TextType', 'string');
unified = readtable(fullfile(out_dir, 'unified_state_probability_diagnostic_smoke', ...
    'unified_state_probability_stage_details.csv'), 'TextType', 'string');
offline = offline_all(offline_all.line_parameter_set_id == "table41_P_L0_only", :);

offline_basis = "offline_replayed_stage_cumulative_probability";
unified_basis = "same_run_candidate_selected_probability";
keys = unique([key_table(offline); key_table(unified)], 'rows', 'stable');
rows = {};
for i = 1:height(keys)
    oidx = find_match(offline, keys(i, :));
    uidx = find_match(unified, keys(i, :));
    offline_exists = ~isempty(oidx);
    unified_exists = ~isempty(uidx);
    [opline, opwt, opge, optotal] = get_probs(offline, oidx);
    [upline, upwt, upge, uptotal] = get_probs(unified, uidx);
    diff_total = uptotal - optotal;

    offline_ps = get_string_value(offline, oidx, 'line_parameter_set_id');
    unified_ps = get_string_value(unified, uidx, 'line_parameter_set_id');
    [match_status, basis_status, diagnosis_note] = classify_row(offline_exists, unified_exists, ...
        optotal, uptotal, diff_total, offline_basis, unified_basis);

    rows{end+1,1} = table(keys.initial_branch(i), keys.trial_id(i), keys.stage_id(i), ...
        opline, upline, opwt, upwt, opge, upge, optotal, uptotal, diff_total, ...
        match_status, offline_exists, unified_exists, offline_ps, unified_ps, ...
        offline_basis, unified_basis, basis_status, diagnosis_note, ...
        'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
        'offline_P_line', 'unified_P_line', 'offline_P_wt', 'unified_P_wt', ...
        'offline_P_ge', 'unified_P_ge', 'offline_P_total', 'unified_P_total', ...
        'diff_P_total', 'match_status', 'offline_stage_exists', 'unified_stage_exists', ...
        'offline_line_parameter_set_id', 'unified_line_parameter_set_id', ...
        'offline_probability_basis', 'unified_probability_basis', ...
        'comparison_basis_status', 'diagnosis_note'}); %#ok<AGROW>
end
comparison = vertcat(rows{:});
writetable(comparison, fullfile(out_dir, 'unified_vs_offline_composite_comparison.csv'));
fprintf('unified vs offline composite comparison written.\n');
end

function [match_status, basis_status, note] = classify_row(offline_exists, unified_exists, optotal, uptotal, diff_total, offline_basis, unified_basis)
if ~offline_exists
    match_status = "missing_offline_stage";
    basis_status = "stage_set_mismatch";
    note = "stage exists in unified smoke but not in offline composite input; likely stage-set mismatch, not probability error.";
elseif ~unified_exists
    match_status = "missing_unified_stage";
    basis_status = "stage_set_mismatch";
    note = "stage exists in offline composite but not in unified smoke; likely stage-set mismatch.";
elseif isnan(optotal) || isnan(uptotal)
    match_status = "missing_probability";
    basis_status = "missing_probability";
    note = "one side has NaN P_total; no zero-fill was applied.";
elseif abs(diff_total) < 1e-12
    match_status = "matched";
    basis_status = "same_numeric_result";
    note = "P_total matches within tolerance.";
elseif offline_basis ~= unified_basis
    match_status = "expected_different_due_to_probability_basis";
    basis_status = "probability_basis_mismatch";
    note = "offline composite uses replayed stage probability while unified smoke uses same-run candidate selected probability; difference is explainable.";
else
    match_status = "unexpected_difference";
    basis_status = "same_basis_unexpected_difference";
    note = "same probability basis but P_total differs beyond tolerance.";
end
end

function keys = key_table(tbl)
keys = tbl(:, {'initial_branch', 'trial_id', 'stage_id'});
end

function idx = find_match(tbl, key)
idx = find(tbl.initial_branch == key.initial_branch & tbl.trial_id == key.trial_id & ...
    tbl.stage_id == key.stage_id, 1);
end

function [pline, pwt, pge, ptotal] = get_probs(tbl, idx)
if isempty(idx)
    pline = NaN; pwt = NaN; pge = NaN; ptotal = NaN;
else
    pline = tbl.P_line_Ek(idx);
    pwt = tbl.P_wt_Ek(idx);
    pge = tbl.P_ge_Ek(idx);
    ptotal = tbl.P_total_Ek(idx);
end
end

function value = get_string_value(tbl, idx, field_name)
if isempty(idx) || ~ismember(field_name, tbl.Properties.VariableNames)
    value = "";
else
    value = string(tbl.(field_name)(idx));
end
end
