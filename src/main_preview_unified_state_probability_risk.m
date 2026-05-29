function main_preview_unified_state_probability_risk()
%MAIN_PREVIEW_UNIFIED_STATE_PROBABILITY_RISK Offline risk preview for same-run unified probability.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(project_root, 'src')));
case_dir = fullfile(project_root, 'results', 'composite', 'unified_state_probability_diagnostic_smoke');
unified = readtable(fullfile(case_dir, 'unified_state_probability_stage_details.csv'), 'TextType', 'string');
chain_summary = readtable(fullfile(case_dir, 'markov_chain_summary.csv'), 'TextType', 'string');

joined = outerjoin(unified, chain_summary, 'Keys', {'initial_branch', 'trial_id'}, ...
    'MergeKeys', true, 'Type', 'left');
metrics = ["LLR", "LFOR", "NVOR", "CRI"];
columns = ["basic_LLR", "basic_LFOR", "basic_NVOR", "basic_CRI"];
rows = {};
for i = 1:numel(metrics)
    if ~ismember(columns(i), joined.Properties.VariableNames)
        rows{end+1,1} = table(metrics(i), NaN, NaN, NaN, NaN, height(unified), 0, ...
            "missing stage severity detail; chain summary metric unavailable", ...
            'VariableNames', {'metric_name', 'risk_line_only', 'risk_unified_composite', ...
            'delta_risk', 'relative_delta', 'stage_count', 'valid_stage_count', 'note'}); %#ok<AGROW>
        continue;
    end
    sev = joined.(columns(i));
    valid = ~isnan(sev) & ~isnan(joined.P_total_Ek);
    risk_line = sum(joined.P_line_Ek(valid) .* sev(valid), 'omitnan');
    risk_unified = sum(joined.P_total_Ek(valid) .* sev(valid), 'omitnan');
    rel = NaN;
    if risk_line ~= 0
        rel = (risk_unified - risk_line) / abs(risk_line);
    end
    rows{end+1,1} = table(metrics(i), risk_line, risk_unified, risk_unified - risk_line, ...
        rel, height(joined), sum(valid), ...
        "Diagnostic preview using chain summary severity repeated by stage; not formal VaR or paper_formula.", ...
        'VariableNames', {'metric_name', 'risk_line_only', 'risk_unified_composite', ...
        'delta_risk', 'relative_delta', 'stage_count', 'valid_stage_count', 'note'}); %#ok<AGROW>
end
preview = vertcat(rows{:});
writetable(preview, fullfile(project_root, 'results', 'composite', 'unified_state_probability_risk_preview.csv'));
fprintf('unified state probability risk preview written.\n');
end
