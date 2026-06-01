function main_reconstruct_formal_chain_risk_var_metrics()
%MAIN_RECONSTRUCT_FORMAL_CHAIN_RISK_VAR_METRICS Reconstruct VaR from chain-risk samples.

project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'formal_var_pilot');
S = readtable(fullfile(out_root, 'formal_chain_risk_samples.csv'), 'TextType', 'string', 'Delimiter', ',');
sigmas = [0.90, 0.95, 0.98];
metric_fields = {'SLLR','R1_LLR'; 'SLFOR','R2_LFOR'; 'SNVOR','R3_NVOR'; ...
    'CRI_basic','R_CRI_basic'; 'CRI_recomputed','R_CRI_recomputed'};
groups = unique(S(:, {'parameter_set_id','scenario_id','sample_variant'}), 'rows', 'stable');
rows = {};
for g = 1:height(groups)
    mask = S.parameter_set_id == groups.parameter_set_id(g) & ...
        S.scenario_id == groups.scenario_id(g) & S.sample_variant == groups.sample_variant(g);
    D = S(mask, :);
    status_summary = strjoin(unique(D.probability_status, 'stable'), ';');
    for sg = 1:numel(sigmas)
        for m = 1:size(metric_fields, 1)
            metric_name = string(metric_fields{m, 1});
            field = metric_fields{m, 2};
            values = D.(field);
            valid = ~isnan(values);
            var_value = q(values(valid), sigmas(sg));
            rows(end + 1, :) = {groups.parameter_set_id(g), groups.scenario_id(g), ...
                groups.sample_variant(g), sigmas(sg), metric_name, var_value, height(D), ...
                sum(valid), "matlab_quantile_default", string(status_summary), ...
                "Offline reconstruction from existing formal pilot chain summaries only."}; %#ok<AGROW>
        end
    end
end
T = cell2table(rows, 'VariableNames', {'parameter_set_id','scenario_id','sample_variant', ...
    'sigma','metric_name','var_value','sample_count','valid_sample_count','quantile_rule', ...
    'probability_status_summary','note'});
writetable(T, fullfile(out_root, 'formal_chain_risk_var_metrics.csv'));
fprintf('Wrote %s\n', fullfile(out_root, 'formal_chain_risk_var_metrics.csv'));
end

function value = q(x, sigma)
if isempty(x)
    value = NaN;
else
    value = quantile(x, sigma);
end
end
