function main_compare_before_after_wind_curve_fix_formal_pilot()
project_root = fileparts(fileparts(mfilename('fullpath')));
before_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
after_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
B = readtable(fullfile(before_root, 'full_event_formal_var_score_summary.csv'), 'TextType','string', 'Delimiter', ',');
A = readtable(fullfile(after_root, 'full_event_var_score_summary_after_curve_fix.csv'), 'TextType','string', 'Delimiter', ',');
Bgap = readtable(fullfile(before_root, 'full_event_formal_var_to_paper_gap.csv'), 'TextType','string', 'Delimiter', ',');
Agap = readtable(fullfile(after_root, 'full_event_var_to_paper_gap_after_curve_fix.csv'), 'TextType','string', 'Delimiter', ',');
params = unique(A.parameter_set_id, 'stable');
items = ["wind_speed_direction_match","overall_trend_match_rate","median_abs_relative_gap", ...
    "mean_abs_relative_gap","penetration_direction_match","topology_direction_match"];
rows = {};
for p = 1:numel(params)
    b = B(B.parameter_set_id==params(p),:); a = A(A.parameter_set_id==params(p),:);
    for it = items
        bv = val(b,it); av = val(a,it);
        rows{end+1,1} = table(params(p), it, bv, av, av-bv, improvement(it,bv,av), "Score summary before/after curve fix.", ...
            'VariableNames', {'parameter_set_id','metric_or_summary_item','before_value','after_value','delta','improved','note'}); %#ok<AGROW>
    end
    for sc = ["wind_speed_11_28","wind_speed_12_00"]
        bv = gap_val(Bgap, params(p), sc); av = gap_val(Agap, params(p), sc);
        rows{end+1,1} = table(params(p), "CRI_"+sc, bv, av, av-bv, av<=bv, "CRI_recomputed sigma=0.95 sim value before/after curve fix.", ...
            'VariableNames', {'parameter_set_id','metric_or_summary_item','before_value','after_value','delta','improved','note'}); %#ok<AGROW>
    end
end
T = vertcat(rows{:});
writetable(T, fullfile(after_root, 'before_after_curve_fix_comparison.csv'));
end

function x = val(T, name)
if isempty(T) || ~ismember(name, T.Properties.VariableNames), x=NaN; else, x=T.(name)(1); end
end
function x = gap_val(T, p, sc)
row = T(T.parameter_set_id==p & T.scenario_id==sc & T.metric_name=="CRI_recomputed",:);
if isempty(row), x=NaN; else, x=row.sim_var_value(1); end
end
function tf = improvement(item,bv,av)
if contains(item,"gap"), tf = av < bv; else, tf = av > bv; end
end
