function main_summarize_severity_formula_uncertainty_for_manual_review()
% Summarize current severity formula uncertainty for manual review.

root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'severity_formula');
ensure_dir(out_dir);

source_file = fullfile(out_dir, 'severity_formula_source_audit.csv');
action_file = fullfile(out_dir, 'post_severity_formula_audit_action.csv');
recompute_file = fullfile(out_dir, 'severity_metric_recompute_audit.csv');
var_file = fullfile(out_dir, 'wind_speed_var_sensitivity_to_severity_formula.csv');

S = read_if_exists(source_file);
A = read_if_exists(action_file);
R = read_if_exists(recompute_file);
V = read_if_exists(var_file);

rows = {};
rows{end+1,1}=summary_row("current_LLR_formula", lookup_formula(S,"LLR"), ...
    "Current code implementation only.", "User must confirm exact LLR/SLLR paper formula.", "");
rows{end+1,1}=summary_row("current_LFOR_formula", lookup_formula(S,"LFOR"), ...
    "Current code implementation only.", "User must confirm line overload severity formula.", "");
rows{end+1,1}=summary_row("current_NVOR_formula", lookup_formula(S,"NVOR"), ...
    "Current code implementation only.", "User must confirm voltage-overrun severity formula.", "");
rows{end+1,1}=summary_row("current_CRI_formula", lookup_formula(S,"CRI"), ...
    "CRI has extracted-note support for weights but still needs screenshot confirmation.", "Confirm weights and normalization.", "");

rows{end+1,1}=summary_row("LLR_paper_confirmed", "false", "No original-paper formula evidence found.", "Blocking formula changes.", "");
rows{end+1,1}=summary_row("LFOR_paper_confirmed", "false", "No original-paper formula evidence found.", "Blocking formula changes.", "");
rows{end+1,1}=summary_row("NVOR_paper_confirmed", "false", "No original-paper formula evidence found.", "Blocking formula changes.", "");
rows{end+1,1}=summary_row("CRI_paper_confirmed", "partial_weight_note_only", "Weights appear in notes/code but require paper screenshot.", "Confirm before treating as formal.", "");
rows{end+1,1}=summary_row("severity_stage_or_chain_level_confirmed", "false", "Audit found mismatch between trace and recomputed stage formula.", "Need stage-vs-chain semantic confirmation.", "");

issue_summary = summarize_issues(R);
rows{end+1,1}=summary_row("severity_recompute_issue_summary", issue_summary, ...
    "Trace values do not fully match simple recomputation from available trace fields.", "Supports pausing before formula changes.", "");

trend_summary = summarize_trend(V);
rows{end+1,1}=summary_row("severity_formula_material_to_wind_speed_direction", trend_summary, ...
    "Recorded and recomputed severity variants both affect wind-speed direction diagnostics.", "Do not tune parameters until formula is confirmed.", "");

if ~isempty(A) && ismember('go_no_go', A.Properties.VariableNames)
    rows{end+1,1}=summary_row("recommended_manual_check", A.go_no_go(1), ...
        A.recommended_next_action(1), "Manual formula confirmation is the next allowed action.", A.note(1));
else
    rows{end+1,1}=summary_row("recommended_manual_check", "need_manual_paper_confirmation_for_severity_formula", ...
        "Confirm LLR/LFOR/NVOR/CRI formulas before any fix.", "Manual confirmation required.", "");
end

writetable(vertcat(rows{:}), fullfile(out_dir, 'severity_formula_uncertainty_summary.csv'));
end

function T = read_if_exists(path)
if exist(path,'file') == 2
    T = readtable(path, 'TextType', 'string');
else
    T = table();
end
end

function value = lookup_formula(S, item)
value = "missing";
if isempty(S) || ~ismember('severity_item', S.Properties.VariableNames)
    return;
end
idx = find(S.severity_item == item, 1);
if ~isempty(idx)
    if ismember('formula_text_or_code', S.Properties.VariableNames)
        value = S.formula_text_or_code(idx);
    elseif ismember('current_code_formula', S.Properties.VariableNames)
        value = S.current_code_formula(idx);
    end
end
end

function text = summarize_issues(R)
if isempty(R) || ~ismember('issue_type', R.Properties.VariableNames)
    text = "missing_recompute_audit";
    return;
end
[G, issue] = findgroups(R.issue_type);
counts = splitapply(@numel, R.issue_type, G);
parts = strings(numel(issue),1);
for i = 1:numel(issue)
    parts(i) = issue(i) + "=" + string(counts(i));
end
text = strjoin(parts, "; ");
end

function text = summarize_trend(V)
if isempty(V)
    text = "missing_wind_speed_var_sensitivity";
    return;
end
if all(ismember(["severity_variant","trend_status"], V.Properties.VariableNames))
    [G, variant, trend] = findgroups(V.severity_variant, V.trend_status);
    counts = splitapply(@numel, V.trend_status, G);
    parts = strings(numel(counts),1);
    for i = 1:numel(counts)
        parts(i) = variant(i) + ":" + trend(i) + "=" + string(counts(i));
    end
    text = strjoin(parts, "; ");
elseif all(ismember(["variant","direction"], V.Properties.VariableNames))
    [G, variant, direction] = findgroups(V.variant, V.direction);
    counts = splitapply(@numel, V.direction, G);
    parts = strings(numel(counts),1);
    for i = 1:numel(counts)
        parts(i) = variant(i) + ":" + direction(i) + "=" + string(counts(i));
    end
    text = strjoin(parts, "; ");
else
    text = "available_but_unrecognized_schema";
end
end

function T = summary_row(item, value, interpretation, relevance, note)
T = table(string(item), string(value), string(interpretation), string(relevance), string(note), ...
    'VariableNames', {'summary_item','value','interpretation','manual_confirmation_relevance','note'});
end

function ensure_dir(path)
if exist(path,'dir')~=7, mkdir(path); end
end
