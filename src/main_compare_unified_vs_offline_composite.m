function main_compare_unified_vs_offline_composite()
%MAIN_COMPARE_UNIFIED_VS_OFFLINE_COMPOSITE Compare same-run and previous offline composite diagnostics.
project_root = fileparts(fileparts(mfilename('fullpath')));
offline_path = fullfile(project_root, 'results', 'composite', 'composite_state_probability_diagnostic.csv');
unified_path = fullfile(project_root, 'results', 'composite', 'unified_state_probability_diagnostic_smoke', ...
    'unified_state_probability_stage_details.csv');
offline_all = readtable(offline_path, 'TextType', 'string');
unified = readtable(unified_path, 'TextType', 'string');
offline = offline_all(offline_all.line_parameter_set_id == "table41_P_L0_only", :);

keys = unique([key_table(offline); key_table(unified)], 'rows', 'stable');
rows = {};
for i = 1:height(keys)
    oidx = find_match(offline, keys(i, :));
    uidx = find_match(unified, keys(i, :));
    [opline, opwt, opge, optotal] = get_probs(offline, oidx);
    [upline, upwt, opge2, uptotal] = get_probs(unified, uidx);
    diff_total = uptotal - optotal;
    if isempty(oidx)
        match_status = "missing_offline_stage";
        note = "stage exists only in unified";
    elseif isempty(uidx)
        match_status = "missing_unified_stage";
        note = "stage exists only in offline";
    elseif isnan(optotal) || isnan(uptotal)
        match_status = "missing_probability";
        note = "one side has NaN P_total";
    elseif abs(diff_total) < 1e-12
        match_status = "matched";
        note = "P_total matches within tolerance";
    else
        match_status = "different";
        note = "Unified smoke and offline reconstruction differ; inspect line probability basis and stage set";
    end
    rows{end+1,1} = table(keys.initial_branch(i), keys.trial_id(i), keys.stage_id(i), ...
        opline, upline, opwt, upwt, opge, opge2, optotal, uptotal, diff_total, match_status, note, ...
        'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
        'offline_P_line', 'unified_P_line', 'offline_P_wt', 'unified_P_wt', ...
        'offline_P_ge', 'unified_P_ge', 'offline_P_total', 'unified_P_total', ...
        'diff_P_total', 'match_status', 'note'}); %#ok<AGROW>
end
comparison = vertcat(rows{:});
comparison = comparison(:, {'initial_branch', 'trial_id', 'stage_id', ...
    'offline_P_line', 'unified_P_line', 'offline_P_wt', 'unified_P_wt', ...
    'offline_P_ge', 'unified_P_ge', 'offline_P_total', 'unified_P_total', ...
    'diff_P_total', 'match_status', 'note'});
% Preserve requested column order.
comparison = table(comparison.initial_branch, comparison.trial_id, comparison.stage_id, ...
    comparison.offline_P_line, comparison.unified_P_line, comparison.offline_P_wt, comparison.unified_P_wt, ...
    comparison.offline_P_ge, comparison.unified_P_ge, comparison.offline_P_total, comparison.unified_P_total, ...
    comparison.diff_P_total, comparison.match_status, comparison.note, ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
    'offline_P_line', 'unified_P_line', 'offline_P_wt', 'unified_P_wt', ...
    'offline_P_ge', 'unified_P_ge', 'offline_P_total', 'unified_P_total', ...
    'diff_P_total', 'match_status', 'note'});
writetable(comparison, fullfile(project_root, 'results', 'composite', 'unified_vs_offline_composite_comparison.csv'));
fprintf('unified vs offline composite comparison written.\n');
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
