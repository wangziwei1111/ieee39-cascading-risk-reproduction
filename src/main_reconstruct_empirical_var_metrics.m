function main_reconstruct_empirical_var_metrics()
%MAIN_RECONSTRUCT_EMPIRICAL_VAR_METRICS Compute empirical VaR from reconstructed chain samples.
project_root = fileparts(fileparts(mfilename('fullpath')));
diag_dir = fullfile(project_root, 'results', 'calibration', 'diagnostics');
in_path = fullfile(diag_dir, 'chain_level_risk_samples.csv');
out_path = fullfile(diag_dir, 'reconstructed_empirical_var_metrics.csv');
if exist(in_path, 'file') ~= 2
    writetable(empty_var(), out_path); return;
end
S = read_csv(in_path);
sigmas = [0.90 0.95 0.98];
metrics = ["SLLR","SLFOR","SNVOR","CRI"];
cols = ["R1_LLR","R2_LFOR","R3_NVOR","R_CRI"];
[G, variants, scales] = findgroups(S.sample_variant, S.scale_variant);
sample_variant=strings(0,1); scale_variant=strings(0,1); sigma=[]; metric_name=strings(0,1); var_value=[]; sample_count=[]; valid_sample_count=[]; quantile_rule=strings(0,1); note=strings(0,1);
for g=1:max(G)
    idx = G==g; group=S(idx,:);
    for s=sigmas
        for m=1:numel(metrics)
            values = group.(cols(m));
            valid = values(~isnan(values));
            sample_variant(end+1,1)=variants(g); scale_variant(end+1,1)=scales(g); sigma(end+1,1)=s; metric_name(end+1,1)=metrics(m); %#ok<AGROW>
            if isempty(valid)
                var_value(end+1,1)=NaN; note(end+1,1)="no valid samples"; %#ok<AGROW>
            else
                var_value(end+1,1)=quantile(valid, s); note(end+1,1)="right-tail empirical VaR: quantile(sample_values, sigma); diagnostic preview"; %#ok<AGROW>
            end
            sample_count(end+1,1)=numel(values); valid_sample_count(end+1,1)=numel(valid); quantile_rule(end+1,1)="R_var = quantile(sample_values, sigma)"; %#ok<AGROW>
        end
    end
end
out=table(sample_variant,scale_variant,sigma,metric_name,var_value,sample_count,valid_sample_count,quantile_rule,note);
writetable(out,out_path);
fprintf('reconstructed empirical VaR metrics written: %d rows\n', height(out));
end
function out=empty_var()
out=table(strings(0,1),strings(0,1),[],strings(0,1),[],[],[],strings(0,1),strings(0,1),'VariableNames',{'sample_variant','scale_variant','sigma','metric_name','var_value','sample_count','valid_sample_count','quantile_rule','note'});
end
function tbl=read_csv(path_value); opts=detectImportOptions(path_value,'Delimiter',',','TextType','string'); opts.VariableNamingRule='preserve'; tbl=readtable(path_value,opts); end
