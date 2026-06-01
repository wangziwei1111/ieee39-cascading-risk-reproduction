function main_compare_scenario_aligned_var_to_paper_targets()
%MAIN_COMPARE_SCENARIO_ALIGNED_VAR_TO_PAPER_TARGETS Compare scenario-aligned reconstructed VaR with calibration targets.
project_root = fileparts(fileparts(mfilename('fullpath')));
diag_dir = fullfile(project_root, 'results', 'calibration', 'diagnostics');
var_path = fullfile(diag_dir, 'scenario_aligned_chain_var_metrics.csv');
target_path = fullfile(project_root, 'paper_inputs', 'filled', 'calibration_target_benchmark.csv');
out_path = fullfile(diag_dir, 'scenario_aligned_var_to_paper_gap.csv');
if exist(var_path,'file')~=2 || exist(target_path,'file')~=2
    writetable(table(), out_path); return;
end
V = read_csv(var_path); T = read_csv(target_path);
V = V(abs(V.sigma - 0.95) < 1e-12 | abs(V.sigma - 0.90) < 1e-12 | abs(V.sigma - 0.98) < 1e-12, :);

parameter_set_id=strings(0,1); target_group=strings(0,1); scenario_id=strings(0,1); sigma=[];
metric_name=strings(0,1); metric_source=strings(0,1); scale_variant=strings(0,1);
paper_table_value=[]; paper_actual_value_if_table_unit_1e4=[]; sim_var_value=[]; comparison_mode=strings(0,1);
absolute_gap=[]; relative_gap=[]; ratio_paper_to_sim=[]; match_status=strings(0,1); note=strings(0,1);

for i=1:height(T)
    scen = string(T.scenario_id(i)); target_metric = string(T.metric_name(i));
    group = string(T.target_group(i)); pval = T.paper_value(i);
    metric_candidates = target_to_metric_candidates(target_metric);
    mask = string(V.scenario_id)==scen & ismember(string(V.metric_name), metric_candidates);
    rows = V(mask,:);
    for r=1:height(rows)
        for mode = ["compare_to_paper_table_value","compare_to_paper_actual_1e_minus_4"]
            if mode == "compare_to_paper_table_value"
                ref = pval;
            else
                ref = pval * 1e-4;
            end
            sim = rows.var_value(r);
            [gap, rel, ratio, status, row_note] = compare_values(ref, sim);
            parameter_set_id(end+1,1)=rows.parameter_set_id(r); target_group(end+1,1)=group; scenario_id(end+1,1)=scen; sigma(end+1,1)=rows.sigma(r); %#ok<AGROW>
            metric_name(end+1,1)=target_metric; metric_source(end+1,1)=rows.metric_source(r) + ":" + rows.metric_name(r); scale_variant(end+1,1)=rows.scale_variant(r); %#ok<AGROW>
            paper_table_value(end+1,1)=pval; paper_actual_value_if_table_unit_1e4(end+1,1)=pval*1e-4; sim_var_value(end+1,1)=sim; comparison_mode(end+1,1)=mode; %#ok<AGROW>
            absolute_gap(end+1,1)=gap; relative_gap(end+1,1)=rel; ratio_paper_to_sim(end+1,1)=ratio; match_status(end+1,1)=status; note(end+1,1)=row_note; %#ok<AGROW>
        end
    end
end
out=table(parameter_set_id,target_group,scenario_id,sigma,metric_name,metric_source,scale_variant,paper_table_value,paper_actual_value_if_table_unit_1e4,sim_var_value,comparison_mode,absolute_gap,relative_gap,ratio_paper_to_sim,match_status,note);
writetable(out,out_path);
fprintf('scenario-aligned VaR to paper gap written: %d rows\n', height(out));
end
function candidates=target_to_metric_candidates(metric)
switch string(metric)
    case "SLLR"; candidates="SLLR";
    case "SLFOR"; candidates="SLFOR";
    case "SNVOR"; candidates="SNVOR";
    case "CRI"; candidates=["CRI_recomputed","CRI_basic"];
    otherwise; candidates=metric;
end
end
function [gap,rel,ratio,status,row_note]=compare_values(ref,sim)
gap=NaN; rel=NaN; ratio=NaN; status="valid"; row_note="scenario-aligned comparison; diagnostic only";
if isnan(sim)
    status="missing_sim_value"; row_note="sim_var_value is NaN; not filled with zero"; return;
end
if sim == 0
    status="zero_sim_value"; row_note="sim_var_value is zero; ratio is undefined"; gap=sim-ref; return;
end
gap=sim-ref; ratio=ref/sim;
if abs(ref)>1e-12; rel=gap/abs(ref); end
end
function tbl=read_csv(path_value); opts=detectImportOptions(path_value,'Delimiter',',','TextType','string'); opts.VariableNamingRule='preserve'; tbl=readtable(path_value,opts); end
