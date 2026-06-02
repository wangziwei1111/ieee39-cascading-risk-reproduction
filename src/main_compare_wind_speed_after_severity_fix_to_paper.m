function main_compare_wind_speed_after_severity_fix_to_paper()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'severity_formula');
M = readtable(fullfile(out_dir,'wind_speed_after_severity_fix_var_metrics.csv'), 'TextType','string', 'Delimiter', ',');
target_file = fullfile(root,'results','calibration','diagnostics','calibration_target_benchmark_candidate_v2.csv');
if exist(target_file,'file') ~= 2
    target_file = fullfile(root,'paper_inputs','filled','calibration_target_benchmark.csv');
end
T = readtable(target_file, 'TextType','string', 'Delimiter', ',');
if ismember('recommended_use', T.Properties.VariableNames)
    T = T(T.recommended_use == 1, :);
end
if ismember('confidence_sigma', T.Properties.VariableNames)
    T = T(abs(T.confidence_sigma-0.95)<1e-9, :);
end
T = T(T.target_group=="wind_speed_scan" & ismember(T.scenario_id, ["wind_speed_11_28","wind_speed_12_00"]), :);
rows = {};
for i=1:height(M)
    if abs(M.sigma(i)-0.95)>1e-9, continue; end
    t = T(T.scenario_id==M.scenario_id(i) & T.metric_name==M.metric_name(i), :);
    if isempty(t), continue; end
    paper = t.paper_value(1);
    sim = M.var_value(i);
    gap = sim-paper;
    rel = gap/(abs(paper)+1e-6);
    ratio = paper/(sim+1e-6);
    direction_status = "single_point";
    rows{end+1,1}=table(M.parameter_set_id(i),M.scenario_id(i),M.metric_name(i),paper,sim,gap,rel,ratio,direction_status, ...
        "Diagnostic display comparison only; no scaling or tuning.", ...
        'VariableNames', {'parameter_set_id','scenario_id','metric_name','paper_value','sim_var_value','absolute_gap','relative_gap','ratio_paper_to_sim','direction_status','note'}); %#ok<AGROW>
end
writetable(vertcat_or_empty(rows), fullfile(out_dir,'wind_speed_after_severity_fix_to_paper_gap.csv'));
end

function T=vertcat_or_empty(rows)
if isempty(rows), T=table(); else, T=vertcat(rows{:}); end
end
