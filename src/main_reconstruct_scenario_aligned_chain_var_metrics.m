function main_reconstruct_scenario_aligned_chain_var_metrics()
%MAIN_RECONSTRUCT_SCENARIO_ALIGNED_CHAIN_VAR_METRICS Reconstruct scenario-aligned empirical VaR from pilot chain summaries.
project_root = fileparts(fileparts(mfilename('fullpath')));
diag_dir = fullfile(project_root, 'results', 'calibration', 'diagnostics');
ensure_dir(diag_dir);
pilot_dir = fullfile(project_root, 'results', 'calibration', 'pilot');
out_path = fullfile(diag_dir, 'scenario_aligned_chain_var_metrics.csv');

parameter_sets = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scenarios = ["concentrated_bus34","distributed_30_39","wind_speed_11_28","wind_speed_12_00", ...
    "penetration_40pct","penetration_60pct","penetration_80pct"];
sigmas = [0.90 0.95 0.98];
scale_variants = ["raw","percent","paper_table_1e4","paper_actual_from_table"];
metrics = ["SLLR","SLFOR","SNVOR","CRI_basic","CRI_recomputed"];
fields = ["basic_LLR","basic_LFOR","basic_NVOR","basic_CRI","recomputed_CRI"];
sources = ["markov_chain_summary.basic","markov_chain_summary.basic","markov_chain_summary.basic", ...
    "markov_chain_summary.basic","markov_chain_summary.recomputed_weighted"];

parameter_set_id = strings(0,1); scenario_id = strings(0,1); sigma = [];
metric_name = strings(0,1); metric_source = strings(0,1); scale_variant = strings(0,1);
var_value = []; sample_count = []; valid_sample_count = []; quantile_rule = strings(0,1);
source_file = strings(0,1); note = strings(0,1);

for p = parameter_sets
    for s = scenarios
        f = fullfile(pilot_dir, p, s, 'tables', 'markov_chain_summary.csv');
        if exist(f, 'file') ~= 2
            for sg = sigmas
                for m = 1:numel(metrics)
                    for sv = scale_variants
                        [parameter_set_id,scenario_id,sigma,metric_name,metric_source,scale_variant,var_value,sample_count,valid_sample_count,quantile_rule,source_file,note] = ...
                            add_row(parameter_set_id,scenario_id,sigma,metric_name,metric_source,scale_variant,var_value,sample_count,valid_sample_count,quantile_rule,source_file,note, ...
                            p,s,sg,metrics(m),sources(m),sv,NaN,0,0,f,"missing source file; not filled with zero");
                    end
                end
            end
            continue;
        end
        T = read_csv(f);
        if ~all(ismember(["basic_LLR","basic_LFOR","basic_NVOR"], string(T.Properties.VariableNames)))
            warning_note = "missing basic risk fields; not filled with zero";
            T.recomputed_CRI = NaN(height(T),1);
        else
            T.recomputed_CRI = 0.6*T.basic_LLR + 0.2*T.basic_LFOR + 0.2*T.basic_NVOR;
            warning_note = "scenario-aligned chain empirical VaR from existing pilot markov_chain_summary";
        end
        n = height(T);
        if n < 30
            warning_note = warning_note + "; warning: small sample count";
        end
        for sg = sigmas
            for m = 1:numel(metrics)
                if ismember(fields(m), string(T.Properties.VariableNames))
                    values_raw = T.(fields(m));
                else
                    values_raw = NaN(n,1);
                end
                for sv = scale_variants
                    values = apply_scale(values_raw, sv);
                    valid = values(~isnan(values));
                    if isempty(valid)
                        v = NaN;
                    else
                        v = quantile(valid, sg);
                    end
                    [parameter_set_id,scenario_id,sigma,metric_name,metric_source,scale_variant,var_value,sample_count,valid_sample_count,quantile_rule,source_file,note] = ...
                        add_row(parameter_set_id,scenario_id,sigma,metric_name,metric_source,scale_variant,var_value,sample_count,valid_sample_count,quantile_rule,source_file,note, ...
                        p,s,sg,metrics(m),sources(m),sv,v,n,numel(valid),f,warning_note);
                end
            end
        end
    end
end

out = table(parameter_set_id, scenario_id, sigma, metric_name, metric_source, scale_variant, ...
    var_value, sample_count, valid_sample_count, quantile_rule, source_file, note);
writetable(out, out_path);
fprintf('scenario-aligned chain VaR metrics written: %d rows\n', height(out));
end

function values = apply_scale(values_raw, scale_variant)
switch string(scale_variant)
    case "raw"
        values = values_raw;
    case "percent"
        values = 100 * values_raw;
    case "paper_table_1e4"
        values = values_raw * 10000;
    case "paper_actual_from_table"
        values = values_raw;
    otherwise
        values = values_raw;
end
end

function varargout = add_row(parameter_set_id,scenario_id,sigma,metric_name,metric_source,scale_variant,var_value,sample_count,valid_sample_count,quantile_rule,source_file,note, ...
    p,s,sg,m,src,sv,v,n,nv,f,row_note)
parameter_set_id(end+1,1)=p; scenario_id(end+1,1)=s; sigma(end+1,1)=sg; %#ok<AGROW>
metric_name(end+1,1)=m; metric_source(end+1,1)=src; scale_variant(end+1,1)=sv; %#ok<AGROW>
var_value(end+1,1)=v; sample_count(end+1,1)=n; valid_sample_count(end+1,1)=nv; %#ok<AGROW>
quantile_rule(end+1,1)="R_var = quantile(chain_sample_values, sigma)";
source_file(end+1,1)=string(f); note(end+1,1)=string(row_note); %#ok<AGROW>
varargout = {parameter_set_id,scenario_id,sigma,metric_name,metric_source,scale_variant,var_value,sample_count,valid_sample_count,quantile_rule,source_file,note};
end

function tbl = read_csv(path_value)
opts = detectImportOptions(path_value, 'Delimiter', ',', 'TextType', 'string'); opts.VariableNamingRule='preserve'; tbl=readtable(path_value, opts);
end
function ensure_dir(path_value); if exist(path_value,'dir')~=7; mkdir(path_value); end; end
