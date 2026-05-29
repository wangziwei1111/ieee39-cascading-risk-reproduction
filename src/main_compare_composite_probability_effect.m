function main_compare_composite_probability_effect()
%MAIN_COMPARE_COMPOSITE_PROBABILITY_EFFECT Summarize offline composite probability impact.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(project_root, 'src')));
in_path = fullfile(project_root, 'results', 'composite', 'composite_state_probability_diagnostic.csv');
if exist(in_path, 'file') ~= 2
    error('Missing composite diagnostic table: %s', in_path);
end
tbl = readtable(in_path, 'TextType', 'string');
sets = unique(tbl.line_parameter_set_id, 'stable');
rows = {};
for i = 1:numel(sets)
    mask = tbl.line_parameter_set_id == sets(i);
    sub = tbl(mask, :);
    valid = ~isnan(sub.P_total_Ek);
    wind_reduction = sub.P_line_Ek - sub.P_line_Ek .* sub.P_wt_Ek;
    gen_reduction = sub.P_line_Ek .* sub.P_wt_Ek - sub.P_total_Ek;
    total_reduction = sub.P_line_Ek - sub.P_total_Ek;
    if all(abs(sub.P_wt_Ek - 1) < 1e-12 | isnan(sub.P_wt_Ek)) && ...
            all(abs(sub.P_ge_Ek - 1) < 1e-12 | isnan(sub.P_ge_Ek))
        interpretation = "current Markov smoke did not trigger wind or traditional generator state probability; composite probability equals line probability";
    else
        interpretation = "state probabilities have diagnostic impact on chain probability";
    end
    rows{end+1,1} = table(sets(i), height(sub), sum(valid), ...
        mean(sub.P_line_Ek, 'omitnan'), mean(sub.P_wt_Ek, 'omitnan'), mean(sub.P_ge_Ek, 'omitnan'), ...
        mean(sub.P_total_Ek, 'omitnan'), min(sub.P_wt_Ek, [], 'omitnan'), min(sub.P_ge_Ek, [], 'omitnan'), ...
        sum(sub.P_wt_Ek < 1), sum(sub.P_ge_Ek < 1), mean(wind_reduction, 'omitnan'), ...
        mean(gen_reduction, 'omitnan'), mean(total_reduction, 'omitnan'), interpretation, ...
        'VariableNames', {'line_parameter_set_id', 'stage_count', 'valid_composite_stage_count', ...
        'mean_P_line_Ek', 'mean_P_wt_Ek', 'mean_P_ge_Ek', 'mean_P_total_Ek', ...
        'min_P_wt_Ek', 'min_P_ge_Ek', 'num_wind_affected_stages', ...
        'num_generator_affected_stages', 'mean_reduction_from_wind', ...
        'mean_reduction_from_generator', 'mean_reduction_total', 'interpretation'}); %#ok<AGROW>
end
summary = vertcat(rows{:});
writetable(summary, fullfile(project_root, 'results', 'composite', 'composite_probability_effect_summary.csv'));
fprintf('composite probability effect summary written.\n');
end
