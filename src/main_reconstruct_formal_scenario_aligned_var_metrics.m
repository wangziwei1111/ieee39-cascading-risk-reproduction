function main_reconstruct_formal_scenario_aligned_var_metrics()
%MAIN_RECONSTRUCT_FORMAL_SCENARIO_ALIGNED_VAR_METRICS Recompute VaR from chain summaries.

project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'formal_var_pilot');
parameter_sets = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scenario_ids = ["concentrated_bus34","distributed_30_39","wind_speed_11_28","wind_speed_12_00", ...
    "penetration_40pct","penetration_60pct","penetration_80pct"];
sigmas = [0.90, 0.95, 0.98];
metrics = ["SLLR","SLFOR","SNVOR","CRI_basic","CRI_recomputed_from_var"];
scale_variants = ["raw","percent","paper_table_display"];
rows = {};
for p = 1:numel(parameter_sets)
    for s = 1:numel(scenario_ids)
        source_file = fullfile(out_root, char(parameter_sets(p)), char(scenario_ids(s)), 'tables', 'markov_chain_summary.csv');
        if exist(source_file, 'file') ~= 2
            continue;
        end
        C = readtable(source_file, 'TextType', 'string', 'Delimiter', ',');
        sample_count = height(C);
        valid_mask = true(sample_count, 1);
        cols = struct('SLLR', "basic_LLR", 'SLFOR', "basic_LFOR", 'SNVOR', "basic_NVOR", 'CRI_basic', "basic_CRI");
        for sg = 1:numel(sigmas)
            sigma = sigmas(sg);
            var_sllr = q(C.(cols.SLLR), sigma);
            var_slfor = q(C.(cols.SLFOR), sigma);
            var_snvor = q(C.(cols.SNVOR), sigma);
            var_cri_basic = q(C.(cols.CRI_basic), sigma);
            var_cri_recomputed = 0.6 * var_sllr + 0.2 * var_slfor + 0.2 * var_snvor;
            values = containers.Map({'SLLR','SLFOR','SNVOR','CRI_basic','CRI_recomputed_from_var'}, ...
                [var_sllr, var_slfor, var_snvor, var_cri_basic, var_cri_recomputed]);
            for m = 1:numel(metrics)
                metric_name = metrics(m);
                raw_value = values(char(metric_name));
                for sv = 1:numel(scale_variants)
                    scale_variant = scale_variants(sv);
                    if scale_variant == "percent"
                        var_value = 100 * raw_value;
                        note = "percent = 100 * raw; not used for direct paper-table comparison";
                    elseif scale_variant == "paper_table_display"
                        var_value = raw_value;
                        note = "paper_table_display currently equals raw; no 1e4 or 1e-4 conversion applied";
                    else
                        var_value = raw_value;
                        note = "raw engineering risk value";
                    end
                    rows(end + 1, :) = {parameter_sets(p), scenario_ids(s), sigma, metric_name, ...
                        metric_name, scale_variant, var_value, sample_count, sum(valid_mask), ...
                        "matlab_quantile_default", string(source_file), note}; %#ok<AGROW>
                end
            end
        end
    end
end
T = cell2table(rows, 'VariableNames', {'parameter_set_id','scenario_id','sigma','metric_name', ...
    'metric_source','scale_variant','var_value','sample_count','valid_sample_count', ...
    'quantile_rule','source_file','note'});
writetable(T, fullfile(out_root, 'formal_scenario_aligned_var_metrics.csv'));
fprintf('Wrote %s\n', fullfile(out_root, 'formal_scenario_aligned_var_metrics.csv'));
end

function value = q(x, sigma)
x = x(~isnan(x));
if isempty(x)
    value = NaN;
else
    value = quantile(x, sigma);
end
end
