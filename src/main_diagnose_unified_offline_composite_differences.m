function main_diagnose_unified_offline_composite_differences()
%MAIN_DIAGNOSE_UNIFIED_OFFLINE_COMPOSITE_DIFFERENCES Explain unified/offline composite differences.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'composite');
ensure_dir(out_dir);

offline_all = read_optional_table(fullfile(out_dir, 'composite_state_probability_diagnostic.csv'));
unified = read_optional_table(fullfile(out_dir, 'unified_state_probability_diagnostic_smoke', ...
    'unified_state_probability_stage_details.csv'));
comparison = read_optional_table(fullfile(out_dir, 'unified_vs_offline_composite_comparison.csv'));
unified_candidates = read_optional_table(fullfile(out_dir, 'unified_state_probability_diagnostic_smoke', ...
    'line_probability_candidate_details.csv'));
offline_candidates = read_optional_table(fullfile(project_root, 'results', 'outage', ...
    'line_probability_parameter_smoke', 'table41_P_L0_only', 'tables', 'candidate_probability_details.csv'));

offline = offline_all;
if ~isempty(offline) && ismember('line_parameter_set_id', offline.Properties.VariableNames)
    offline = offline(offline.line_parameter_set_id == "table41_P_L0_only", :);
end

stage_audit = build_stage_audit(offline, unified, offline_candidates, unified_candidates);
stage_diff = build_stage_key_diff(offline, unified, offline_candidates, unified_candidates);
basis_audit = build_basis_audit(offline, unified, offline_candidates, unified_candidates);
diagnosis = build_diagnosis(offline, unified, comparison);

writetable(diagnosis, fullfile(out_dir, 'unified_offline_difference_diagnosis.csv'));
writetable(stage_audit, fullfile(out_dir, 'unified_offline_stage_set_audit.csv'));
writetable(stage_diff, fullfile(out_dir, 'unified_offline_stage_key_diff.csv'));
writetable(basis_audit, fullfile(out_dir, 'line_probability_basis_audit.csv'));
fprintf('unified/offline composite difference diagnosis written.\n');
end

function diagnosis = build_diagnosis(offline, unified, comparison)
if isempty(comparison) || ~ismember('match_status', comparison.Properties.VariableNames) || ...
        any(comparison.match_status == "different")
    main_compare_unified_vs_offline_composite();
    project_root = fileparts(fileparts(mfilename('fullpath')));
    comparison = readtable(fullfile(project_root, 'results', 'composite', ...
        'unified_vs_offline_composite_comparison.csv'), 'TextType', 'string');
end
rows = {};
for i = 1:height(comparison)
    original_status = comparison.match_status(i);
    [dtype, cause, fix, note] = diagnose_status(comparison(i, :));
    rows{end+1,1} = table(comparison.initial_branch(i), comparison.trial_id(i), comparison.stage_id(i), ...
        comparison.offline_P_line(i), comparison.unified_P_line(i), ...
        comparison.offline_P_wt(i), comparison.unified_P_wt(i), ...
        comparison.offline_P_ge(i), comparison.unified_P_ge(i), ...
        comparison.offline_P_total(i), comparison.unified_P_total(i), ...
        comparison.unified_P_line(i) - comparison.offline_P_line(i), ...
        comparison.unified_P_total(i) - comparison.offline_P_total(i), ...
        original_status, dtype, cause, fix, note, ...
        'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
        'offline_P_line', 'unified_P_line', 'offline_P_wt', 'unified_P_wt', ...
        'offline_P_ge', 'unified_P_ge', 'offline_P_total', 'unified_P_total', ...
        'diff_P_line', 'diff_P_total', 'original_match_status', ...
        'diagnosed_difference_type', 'likely_cause', 'recommended_fix', 'note'}); %#ok<AGROW>
end
diagnosis = vertcat(rows{:});
end

function [dtype, cause, fix, note] = diagnose_status(row)
status = string(row.match_status);
switch status
    case "matched"
        dtype = "exact_matched";
        cause = "same stage key and numerically identical P_total";
        fix = "none";
        note = "comparison is consistent";
    case "missing_offline_stage"
        dtype = "missing_offline_stage";
        cause = "stage exists in unified smoke but not in offline composite input";
        fix = "keep row and document stage-set mismatch; prefer unified smoke for same-run diagnostics";
        note = "not a probability calculation error";
    case "missing_unified_stage"
        dtype = "missing_unified_stage";
        cause = "stage exists in offline composite but not in unified smoke";
        fix = "keep row and document stage-set mismatch";
        note = "not zero-filled";
    case "expected_different_due_to_probability_basis"
        dtype = "probability_basis_mismatch";
        cause = "offline replayed stage probability and unified same-run selected candidate probability are not the same basis";
        fix = "do not require exact match; report basis explicitly";
        note = "expected diagnostic difference";
    case "missing_probability"
        dtype = "stage_set_mismatch";
        cause = "one side has missing component probability";
        fix = "preserve NaN and note missing component";
        note = "no zero-fill applied";
    otherwise
        dtype = "unknown";
        cause = "unclassified comparison status";
        fix = "inspect candidate details and stage key membership";
        note = "manual review needed";
end
end

function audit = build_stage_audit(offline, unified, offline_candidates, unified_candidates)
names = ["offline_composite"; "unified_smoke"; "offline_line_probability_smoke"; "unified_line_probability_candidates"];
tables = {offline; unified; offline_candidates; unified_candidates};
rows = {};
for i = 1:numel(names)
    keys = extract_stage_keys(tables{i});
    if isempty(keys)
        rows{end+1,1} = table(names(i), 0, 0, NaN, NaN, "empty", "source missing or empty", ...
            'VariableNames', {'source_name', 'stage_count', 'unique_chain_count', ...
            'min_stage_id', 'max_stage_id', 'stage_key_list_hash', 'note'}); %#ok<AGROW>
    else
        chain_key = string(keys.initial_branch) + "_" + string(keys.trial_id);
        rows{end+1,1} = table(names(i), height(keys), numel(unique(chain_key)), ...
            min(keys.stage_id), max(keys.stage_id), key_hash(keys), "stage keys audited without changing data", ...
            'VariableNames', {'source_name', 'stage_count', 'unique_chain_count', ...
            'min_stage_id', 'max_stage_id', 'stage_key_list_hash', 'note'}); %#ok<AGROW>
    end
end
audit = vertcat(rows{:});
end

function diff = build_stage_key_diff(offline, unified, offline_candidates, unified_candidates)
all_keys = unique([extract_stage_keys(offline); extract_stage_keys(unified); ...
    extract_stage_keys(offline_candidates); extract_stage_keys(unified_candidates)], 'rows', 'stable');
rows = {};
for i = 1:height(all_keys)
    eo = key_exists(offline, all_keys(i, :));
    eu = key_exists(unified, all_keys(i, :));
    eoc = key_exists(offline_candidates, all_keys(i, :));
    euc = key_exists(unified_candidates, all_keys(i, :));
    note = "stage key membership audited";
    if ~eo && eu
        note = "stage exists in unified smoke but not offline composite";
    elseif eo && ~eu
        note = "stage exists in offline composite but not unified smoke";
    end
    rows{end+1,1} = table(all_keys.initial_branch(i), all_keys.trial_id(i), all_keys.stage_id(i), ...
        eo, eu, eoc, euc, note, ...
        'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
        'exists_in_offline_composite', 'exists_in_unified_smoke', ...
        'exists_in_offline_line_probability_smoke', 'exists_in_unified_candidate_details', 'note'}); %#ok<AGROW>
end
diff = vertcat(rows{:});
end

function audit = build_basis_audit(offline, unified, offline_candidates, unified_candidates)
rows = {
    basis_row("offline_composite", "P_line_Ek", "table41_P_L0_only", offline.P_line_Ek, ...
    "stage", "offline composite rebuilt from line_probability_parameter_smoke stage cumulative probability")
    basis_row("unified_smoke", "P_line_Ek", "table41_P_L0_only", unified.P_line_Ek, ...
    "stage", "same-run cumulative P_line from selected/unselected candidate probabilities")
    basis_row("offline_line_probability_smoke", "paper_formula_probability", "table41_P_L0_only", ...
    get_numeric_column(offline_candidates, 'paper_formula_probability'), "candidate", ...
    "candidate-level paper_formula probability from previous P_L smoke")
    basis_row("unified_line_probability_candidates", "diagnostic_line_probability", "table41_P_L0_only", ...
    get_numeric_column(unified_candidates, 'diagnostic_line_probability'), "candidate", ...
    "candidate-level same-run diagnostic line probability")
    };
audit = vertcat(rows{:});
end

function row = basis_row(source, field, ps, values, unit_name, desc)
row = table(source, field, ps, mean(values, 'omitnan'), min(values, [], 'omitnan'), ...
    max(values, [], 'omitnan'), numel(values), desc, ...
    "These diagnostic bases are documented explicitly; stage-level equality is not assumed across bases.", ...
    'VariableNames', {'source_name', 'probability_field_used', 'parameter_set_id', ...
    'probability_mean', 'probability_min', 'probability_max', 'candidate_count_or_stage_count', ...
    'basis_description', 'note'});
end

function values = get_numeric_column(tbl, col)
if isempty(tbl) || ~ismember(col, tbl.Properties.VariableNames)
    values = NaN;
else
    values = tbl.(col);
end
end

function keys = extract_stage_keys(tbl)
if isempty(tbl) || ~all(ismember({'initial_branch', 'trial_id', 'stage_id'}, tbl.Properties.VariableNames))
    keys = table([], [], [], 'VariableNames', {'initial_branch', 'trial_id', 'stage_id'});
else
    keys = unique(tbl(:, {'initial_branch', 'trial_id', 'stage_id'}), 'rows', 'stable');
end
end

function tf = key_exists(tbl, key)
if isempty(tbl) || ~all(ismember({'initial_branch', 'trial_id', 'stage_id'}, tbl.Properties.VariableNames))
    tf = false;
else
    tf = any(tbl.initial_branch == key.initial_branch & tbl.trial_id == key.trial_id & tbl.stage_id == key.stage_id);
end
end

function h = key_hash(keys)
parts = string(keys.initial_branch) + "_" + string(keys.trial_id) + "_" + string(keys.stage_id);
joined = char(strjoin(parts, "|"));
checksum = sum(double(joined) .* (1:numel(joined)));
h = "stage_key_checksum_" + string(checksum);
end

function tbl = read_optional_table(path)
if exist(path, 'file') == 2
    tbl = readtable(path, 'TextType', 'string');
else
    tbl = table();
end
end

function ensure_dir(path)
if ~exist(path, 'dir'), mkdir(path); end
end
