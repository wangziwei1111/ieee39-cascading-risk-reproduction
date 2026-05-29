function main_compare_stage_level_vs_chain_summary_risk_preview()
%MAIN_COMPARE_STAGE_LEVEL_VS_CHAIN_SUMMARY_RISK_PREVIEW Compare old repeated-chain preview with new stage-level preview.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'composite');
old_path = fullfile(out_dir, 'unified_state_probability_risk_preview.csv');
new_path = fullfile(out_dir, 'unified_stage_level_risk_preview.csv');
old_tbl = readtable(old_path, 'TextType', 'string');
new_tbl = readtable(new_path, 'TextType', 'string');
metrics = unique([old_tbl.metric_name; new_tbl.metric_name], 'stable');
rows = {};
for i = 1:numel(metrics)
    omask = old_tbl.metric_name == metrics(i);
    nmask = new_tbl.metric_name == metrics(i);
    old_risk = NaN;
    new_risk = NaN;
    if any(omask)
        if ismember('risk_unified_composite', old_tbl.Properties.VariableNames)
            old_risk = old_tbl.risk_unified_composite(find(omask, 1));
        end
    end
    if any(nmask)
        new_risk = new_tbl.risk_unified_stage_level(find(nmask, 1));
    end
    delta = new_risk - old_risk;
    rel = NaN;
    if old_risk ~= 0
        rel = delta / abs(old_risk);
    end
    if ~isnan(delta) && abs(delta) > 1e-12
        interp = "Old preview used chain summary severity repeated by stage; use stage-level risk preview going forward.";
    else
        interp = "Difference is small, but stage-level risk preview is the stricter diagnostic source.";
    end
    rows{end+1,1} = table(metrics(i), old_risk, new_risk, delta, rel, interp, ...
        'VariableNames', {'metric_name', 'old_chain_summary_repeated_risk', ...
        'new_stage_level_risk', 'delta', 'relative_delta', 'interpretation'}); %#ok<AGROW>
end
comparison = vertcat(rows{:});
writetable(comparison, fullfile(out_dir, 'stage_level_vs_chain_summary_risk_preview_comparison.csv'));
fprintf('stage-level vs chain-summary risk preview comparison written.\n');
end
