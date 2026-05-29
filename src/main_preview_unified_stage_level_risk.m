function main_preview_unified_stage_level_risk()
%MAIN_PREVIEW_UNIFIED_STAGE_LEVEL_RISK Compute diagnostic risk from same-stage probability and severity.
project_root = fileparts(fileparts(mfilename('fullpath')));
case_dir = fullfile(project_root, 'results', 'composite', 'unified_state_probability_diagnostic_smoke');
prob_path = fullfile(case_dir, 'unified_state_probability_stage_details.csv');
sev_path = fullfile(case_dir, 'stage_severity_details.csv');
out_path = fullfile(project_root, 'results', 'composite', 'unified_stage_level_risk_preview.csv');
if exist(prob_path, 'file') ~= 2 || exist(sev_path, 'file') ~= 2
    preview = empty_preview("missing stage probability or severity detail");
    writetable(preview, out_path);
    return;
end
prob = readtable(prob_path, 'TextType', 'string');
sev = readtable(sev_path, 'TextType', 'string');
joined = innerjoin(prob, sev, 'Keys', {'initial_branch', 'trial_id', 'stage_id'});
metrics = ["LLR", "LFOR", "NVOR", "CRI"];
columns = ["severity_LLR", "severity_LFOR", "severity_NVOR", "severity_CRI"];
rows = {};
degenerate = all(abs(joined.P_wt_Ek - 1) < 1e-12 | isnan(joined.P_wt_Ek)) && ...
    all(abs(joined.P_ge_Ek - 1) < 1e-12 | isnan(joined.P_ge_Ek));
for i = 1:numel(metrics)
    sev_values = joined.(columns(i));
    valid = ~isnan(joined.P_line_Ek) & ~isnan(joined.P_total_Ek) & ~isnan(sev_values);
    risk_line = sum(joined.P_line_Ek(valid) .* sev_values(valid), 'omitnan');
    risk_unified = sum(joined.P_total_Ek(valid) .* sev_values(valid), 'omitnan');
    rel = NaN;
    if risk_line ~= 0
        rel = (risk_unified - risk_line) / abs(risk_line);
    end
    note = "Stage-level diagnostic risk preview; not VaR and not formal paper_formula.";
    if degenerate
        note = "P_wt=1 and P_ge=1 in current smoke; unified risk degenerates to line-only risk.";
    end
    rows{end+1, 1} = table(metrics(i), risk_line, risk_unified, risk_unified - risk_line, rel, ...
        height(joined), sum(valid), sum(isnan(joined.P_total_Ek)), sum(isnan(sev_values)), note, ...
        'VariableNames', {'metric_name', 'risk_line_only_stage_level', ...
        'risk_unified_stage_level', 'delta_risk', 'relative_delta', ...
        'stage_count', 'valid_stage_count', 'missing_probability_count', ...
        'missing_severity_count', 'note'}); %#ok<AGROW>
end
writetable(vertcat(rows{:}), out_path);
fprintf('unified stage-level risk preview written.\n');
end

function preview = empty_preview(note)
metrics = ["LLR"; "LFOR"; "NVOR"; "CRI"];
preview = table(metrics, nan(4,1), nan(4,1), nan(4,1), nan(4,1), zeros(4,1), zeros(4,1), ...
    zeros(4,1), ones(4,1), repmat(string(note), 4, 1), ...
    'VariableNames', {'metric_name', 'risk_line_only_stage_level', ...
    'risk_unified_stage_level', 'delta_risk', 'relative_delta', ...
    'stage_count', 'valid_stage_count', 'missing_probability_count', ...
    'missing_severity_count', 'note'});
end
