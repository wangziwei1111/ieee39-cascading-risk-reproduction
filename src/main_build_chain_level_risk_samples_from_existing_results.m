function main_build_chain_level_risk_samples_from_existing_results()
%MAIN_BUILD_CHAIN_LEVEL_RISK_SAMPLES_FROM_EXISTING_RESULTS Reconstruct chain samples offline.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'diagnostics');
ensure_dir(out_dir);
prob_path = fullfile(project_root, 'results', 'composite', 'unified_state_probability_diagnostic_smoke', 'unified_state_probability_stage_details.csv');
sev_path = fullfile(project_root, 'results', 'composite', 'unified_state_probability_diagnostic_smoke', 'stage_severity_details.csv');
out_path = fullfile(out_dir, 'chain_level_risk_samples.csv');
if exist(prob_path, 'file') ~= 2 || exist(sev_path, 'file') ~= 2
    writetable(empty_samples(), out_path); return;
end
prob = read_csv(prob_path); sev = read_csv(sev_path);
T = innerjoin(prob, sev, 'Keys', {'initial_branch','trial_id','stage_id'});
keys = unique(T(:, {'initial_branch','trial_id'}), 'rows');
variants = ["chain_sum_probability_weighted","chain_sum_severity","chain_max_severity","chain_final_stage_severity","chain_mean_stage_severity"];

sample_variant = strings(0,1); scale_variant = strings(0,1); initial_branch=[]; trial_id=[]; chain_id=[];
stage_count=[]; R1_LLR=[]; R2_LFOR=[]; R3_NVOR=[]; R_CRI=[]; sample_status=strings(0,1); construction_note=strings(0,1);
cid = 0;
for k = 1:height(keys)
    cid = cid + 1;
    mask = T.initial_branch == keys.initial_branch(k) & T.trial_id == keys.trial_id(k);
    G = sortrows(T(mask,:), 'stage_id');
    for v = variants
        [r1,r2,r3,status,note] = aggregate_variant(G, v);
        for scale = ["per_unit","percent"]
            factor = 1;
            if scale == "percent"; factor = 100; end
            sample_variant(end+1,1)=v; scale_variant(end+1,1)=scale; %#ok<AGROW>
            initial_branch(end+1,1)=keys.initial_branch(k); trial_id(end+1,1)=keys.trial_id(k); chain_id(end+1,1)=cid; stage_count(end+1,1)=height(G); %#ok<AGROW>
            R1_LLR(end+1,1)=factor*r1; R2_LFOR(end+1,1)=factor*r2; R3_NVOR(end+1,1)=factor*r3; %#ok<AGROW>
            R_CRI(end+1,1)=0.6*factor*r1 + 0.2*factor*r2 + 0.2*factor*r3; %#ok<AGROW>
            sample_status(end+1,1)=status; construction_note(end+1,1)=note; %#ok<AGROW>
        end
    end
end
out = table(sample_variant, scale_variant, initial_branch, trial_id, chain_id, stage_count, ...
    R1_LLR, R2_LFOR, R3_NVOR, R_CRI, sample_status, construction_note);
writetable(out, out_path);
fprintf('chain-level risk samples written: %d rows\n', height(out));
end

function [r1,r2,r3,status,note] = aggregate_variant(G, variant)
llr = G.severity_LLR; lfor = G.severity_LFOR; nvor = G.severity_NVOR;
status = "valid"; note = "constructed from unified smoke stage severity; diagnostic only";
switch variant
    case "chain_sum_probability_weighted"
        if ~ismember('P_total_Ek', G.Properties.VariableNames) || any(isnan(G.P_total_Ek))
            r1=NaN; r2=NaN; r3=NaN; status="missing_probability"; note="P_total_Ek missing; not filled with zero"; return;
        end
        r1=sum(G.P_total_Ek.*llr,'omitnan'); r2=sum(G.P_total_Ek.*lfor,'omitnan'); r3=sum(G.P_total_Ek.*nvor,'omitnan');
        note="sum_over_stage(P_total_Ek * severity_metric_Ek)";
    case "chain_sum_severity"
        r1=sum(llr,'omitnan'); r2=sum(lfor,'omitnan'); r3=sum(nvor,'omitnan'); note="sum_over_stage(severity_metric_Ek)";
    case "chain_max_severity"
        r1=max(llr,[],'omitnan'); r2=max(lfor,[],'omitnan'); r3=max(nvor,[],'omitnan'); note="max_over_stage(severity_metric_Ek)";
    case "chain_final_stage_severity"
        r1=llr(end); r2=lfor(end); r3=nvor(end); note="final available stage severity_metric";
    case "chain_mean_stage_severity"
        r1=mean(llr,'omitnan'); r2=mean(lfor,'omitnan'); r3=mean(nvor,'omitnan'); note="mean_over_stage(severity_metric_Ek)";
    otherwise
        r1=NaN; r2=NaN; r3=NaN; status="unknown_variant"; note="unknown reconstruction variant";
end
end

function out = empty_samples()
out = table(strings(0,1),strings(0,1),[],[],[],[],[],[],[],[],strings(0,1),strings(0,1), ...
    'VariableNames', {'sample_variant','scale_variant','initial_branch','trial_id','chain_id','stage_count','R1_LLR','R2_LFOR','R3_NVOR','R_CRI','sample_status','construction_note'});
end

function tbl = read_csv(path_value)
opts = detectImportOptions(path_value, 'Delimiter', ',', 'TextType', 'string'); opts.VariableNamingRule='preserve'; tbl=readtable(path_value,opts);
end
function ensure_dir(path_value); if exist(path_value,'dir')~=7; mkdir(path_value); end; end
