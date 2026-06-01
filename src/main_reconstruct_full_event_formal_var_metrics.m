function main_reconstruct_full_event_formal_var_metrics()
%MAIN_RECONSTRUCT_FULL_EVENT_FORMAL_VAR_METRICS Build full-event chain-risk VaR metrics.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
parameter_sets = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scenario_ids = ["concentrated_bus34","distributed_30_39","wind_speed_11_28","wind_speed_12_00", ...
    "penetration_40pct","penetration_60pct","penetration_80pct"];
sigmas = [0.90, 0.95, 0.98];
rows = {};
for p = 1:numel(parameter_sets)
    for s = 1:numel(scenario_ids)
        source_file = fullfile(out_root, char(parameter_sets(p)), char(scenario_ids(s)), 'tables', 'markov_chain_summary.csv');
        if exist(source_file, 'file') ~= 2
            continue;
        end
        T = readtable(source_file, 'TextType', 'string');
        risk = build_risk_samples(T);
        variants = ["full_event_chain_risk_display","severity_only_reference"];
        metrics = ["SLLR","SLFOR","SNVOR","CRI_recomputed","CRI_basic_reference"];
        for v = 1:numel(variants)
            for sg = 1:numel(sigmas)
                for m = 1:numel(metrics)
                    values = risk.(variants(v)).(metrics(m));
                    valid = ~isnan(values);
                    rows{end+1,1} = table(parameter_sets(p), scenario_ids(s), variants(v), sigmas(sg), metrics(m), ...
                        q(values(valid), sigmas(sg)), height(T), sum(valid), summarize_status(T), ...
                        summarize_stage_mode(T), "empirical_quantile", string(source_file), ...
                        "Full-event pilot metric reconstruction; not final benchmark.", ...
                        'VariableNames', {'parameter_set_id','scenario_id','sample_variant','sigma','metric_name', ...
                        'var_value','sample_count','valid_sample_count','chain_probability_status_summary', ...
                        'stage_probability_mode','quantile_rule','source_file','note'}); %#ok<AGROW>
                end
            end
        end
    end
end
metrics_tbl = vertcat(rows{:});
writetable(metrics_tbl, fullfile(out_root, 'full_event_formal_var_metrics.csv'));
fprintf('full-event formal VaR metrics written: %s\n', out_root);
end

function risk = build_risk_samples(T)
p = T.initial_line_probability .* T.chain_transition_probability ./ 1e-4;
risk.full_event_chain_risk_display.SLLR = p .* T.basic_LLR;
risk.full_event_chain_risk_display.SLFOR = p .* T.basic_LFOR;
risk.full_event_chain_risk_display.SNVOR = p .* T.basic_NVOR;
risk.full_event_chain_risk_display.CRI_recomputed = 0.6*risk.full_event_chain_risk_display.SLLR + ...
    0.2*risk.full_event_chain_risk_display.SLFOR + 0.2*risk.full_event_chain_risk_display.SNVOR;
risk.full_event_chain_risk_display.CRI_basic_reference = p .* T.basic_CRI;
risk.severity_only_reference.SLLR = T.basic_LLR;
risk.severity_only_reference.SLFOR = T.basic_LFOR;
risk.severity_only_reference.SNVOR = T.basic_NVOR;
risk.severity_only_reference.CRI_recomputed = 0.6*T.basic_LLR + 0.2*T.basic_LFOR + 0.2*T.basic_NVOR;
risk.severity_only_reference.CRI_basic_reference = T.basic_CRI;
end

function value = q(x, sigma)
if isempty(x), value = NaN; else, value = quantile(x, sigma); end
end

function s = summarize_status(T)
if ismember('chain_probability_status', T.Properties.VariableNames)
    s = strjoin(unique(string(T.chain_probability_status), 'stable'), ';');
else
    s = "missing";
end
end

function s = summarize_stage_mode(T)
if ismember('stage_probability_mode', T.Properties.VariableNames)
    s = strjoin(unique(string(T.stage_probability_mode), 'stable'), ';');
else
    s = "missing";
end
end
