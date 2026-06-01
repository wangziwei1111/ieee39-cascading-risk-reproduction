function main_score_scenario_aligned_var_metric_sources()
%MAIN_SCORE_SCENARIO_ALIGNED_VAR_METRIC_SOURCES Score scenario-aligned metric sources.
project_root = fileparts(fileparts(mfilename('fullpath')));
diag_dir = fullfile(project_root, 'results', 'calibration', 'diagnostics');
gap_path = fullfile(diag_dir, 'scenario_aligned_var_to_paper_gap.csv');
out_path = fullfile(diag_dir, 'scenario_aligned_var_score_summary.csv');
if exist(gap_path,'file')~=2; writetable(table(),out_path); return; end
GAP=read_csv(gap_path);
[G, psets, sigmas, sources, scales, modes] = findgroups(GAP.parameter_set_id, GAP.sigma, GAP.metric_source, GAP.scale_variant, GAP.comparison_mode);
parameter_set_id=strings(0,1); sigma=[]; metric_source=strings(0,1); scale_variant=strings(0,1); comparison_mode=strings(0,1); valid_target_count=[]; mean_abs_relative_gap=[]; median_abs_relative_gap=[]; trend_match_rate=[]; topology_direction_match=[]; wind_speed_direction_match=[]; penetration_direction_match=[]; score_rank=[]; recommendation=strings(0,1);
for g=1:max(G)
    rows=GAP(G==g,:);
    valid=~isnan(rows.relative_gap) & isfinite(rows.relative_gap);
    [topo,wind,pen,rate]=trend_scores(rows);
    parameter_set_id(end+1,1)=psets(g); sigma(end+1,1)=sigmas(g); metric_source(end+1,1)=sources(g); scale_variant(end+1,1)=scales(g); comparison_mode(end+1,1)=modes(g); %#ok<AGROW>
    valid_target_count(end+1,1)=sum(valid); mean_abs_relative_gap(end+1,1)=mean(abs(rows.relative_gap(valid)),'omitnan'); median_abs_relative_gap(end+1,1)=median(abs(rows.relative_gap(valid)),'omitnan'); %#ok<AGROW>
    topology_direction_match(end+1,1)=topo; wind_speed_direction_match(end+1,1)=wind; penetration_direction_match(end+1,1)=pen; trend_match_rate(end+1,1)=rate; %#ok<AGROW>
    recommendation(end+1,1)=recommend(sum(valid), median_abs_relative_gap(end), rate); score_rank(end+1,1)=NaN; %#ok<AGROW>
end
out=table(parameter_set_id,sigma,metric_source,scale_variant,comparison_mode,valid_target_count,mean_abs_relative_gap,median_abs_relative_gap,trend_match_rate,topology_direction_match,wind_speed_direction_match,penetration_direction_match,score_rank,recommendation);
score = out.median_abs_relative_gap - out.trend_match_rate;
[~,ord]=sort(score,'ascend','MissingPlacement','last');
rank=zeros(height(out),1); rank(ord)=1:height(out); out.score_rank=rank;
writetable(out,out_path);
fprintf('scenario-aligned VaR score summary written: %d rows\n', height(out));
end
function rec=recommend(n,med_gap,trend)
if n < 4; rec="insufficient_targets";
elseif trend >= 0.75 && med_gap < 1; rec="candidate_for_scale_aware_calibration";
elseif trend >= 0.75; rec="candidate_but_needs_formal_rerun";
elseif med_gap > 5; rec="wrong_scale";
elseif trend < 0.5; rec="wrong_trend";
else; rec="not_recommended";
end
end
function [topo,wind,pen,rate]=trend_scores(rows)
metrics=unique(string(rows.metric_name)); tests=[];
for m=metrics'
    R=rows(string(rows.metric_name)==m,:);
    tests(end+1)=direction_pair(R,"concentrated_bus34","distributed_30_39",true); %#ok<AGROW>
    tests(end+1)=direction_pair(R,"wind_speed_11_28","wind_speed_12_00",false); %#ok<AGROW>
    tests(end+1)=direction_triple(R,"penetration_40pct","penetration_60pct","penetration_80pct"); %#ok<AGROW>
end
topo=mean(tests(1:3:end),'omitnan'); wind=mean(tests(2:3:end),'omitnan'); pen=mean(tests(3:3:end),'omitnan'); rate=mean(tests,'omitnan');
end
function ok=direction_pair(R,a,b,expect_second_lower)
ok=NaN; ia=find(string(R.scenario_id)==a,1); ib=find(string(R.scenario_id)==b,1); if isempty(ia)||isempty(ib); return; end
paper_dir=sign(R.paper_table_value(ib)-R.paper_table_value(ia)); sim_dir=sign(R.sim_var_value(ib)-R.sim_var_value(ia));
if expect_second_lower; paper_dir=sign(-abs(paper_dir)); end %#ok<NASGU>
ok=double(paper_dir==sim_dir);
end
function ok=direction_triple(R,a,b,c)
ok=NaN; ia=find(string(R.scenario_id)==a,1); ib=find(string(R.scenario_id)==b,1); ic=find(string(R.scenario_id)==c,1); if isempty(ia)||isempty(ib)||isempty(ic); return; end
paper=sign(R.paper_table_value(ic)-R.paper_table_value(ia)); sim=sign(R.sim_var_value(ic)-R.sim_var_value(ia)); ok=double(paper==sim);
end
function tbl=read_csv(path_value); opts=detectImportOptions(path_value,'Delimiter',',','TextType','string'); opts.VariableNamingRule='preserve'; tbl=readtable(path_value,opts); end
