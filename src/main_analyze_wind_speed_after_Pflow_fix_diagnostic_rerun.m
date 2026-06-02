function main_analyze_wind_speed_after_Pflow_fix_diagnostic_rerun()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'line_probability_formula');
rerun_root = fullfile(out_dir, 'wind_speed_after_Pflow_fix_diagnostic_rerun');
before_root = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun');
var_path = fullfile(out_dir, 'wind_speed_after_Pflow_fix_var_metrics.csv');
cmp_path = fullfile(out_dir, 'wind_speed_before_after_Pflow_fix_comparison.csv');
if exist(fullfile(rerun_root, 'high_hidden_failure'), 'dir') ~= 7
    V = table(strings(0,1), strings(0,1), zeros(0,1), strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), strings(0,1), strings(0,1), ...
        'VariableNames', {'parameter_set_id','scenario_id','sigma','metric_name','var_value','sample_count','valid_sample_count', ...
        'line_outage_flow_probability_mode','note'});
    writetable(V, var_path);
    B = readtable(fullfile(before_root, 'wind_speed_component_diagnostic_var_metrics.csv'), 'TextType','string');
    C = build_skipped_comparison(B);
    writetable(C, cmp_path);
    return;
end
error('Actual after-Pflow-fix rerun analysis is not implemented because rerun was not expected unless issue confirmed.');
end

function C = build_skipped_comparison(B)
psets = unique(B.parameter_set_id); metrics = unique(B.metric_name); sigmas = unique(B.sigma);
rows = {};
for p = 1:numel(psets)
    for m = 1:numel(metrics)
        for s = 1:numel(sigmas)
            a = B(B.parameter_set_id==psets(p)&B.metric_name==metrics(m)&B.sigma==sigmas(s)&B.scenario_id=="wind_speed_11_28",:);
            b = B(B.parameter_set_id==psets(p)&B.metric_name==metrics(m)&B.sigma==sigmas(s)&B.scenario_id=="wind_speed_12_00",:);
            if isempty(a)||isempty(b), continue; end
            before_dir = dir_text(b.var_value(1)-a.var_value(1));
            rows{end+1,1}=table(psets(p),metrics(m),sigmas(s),a.var_value(1),b.var_value(1),before_dir,NaN,NaN,"skipped_no_issue_confirmed",false, ...
                "12mps_expected_lower_or_not_higher", before_dir=="matches_paper_direction", false, "insufficient_data", ...
                "After-fix rerun skipped because below-rated P_flow issue was not confirmed.", ...
                'VariableNames', {'parameter_set_id','metric_name','sigma','before_11_28_var','before_12_00_var','before_direction', ...
                'after_11_28_var','after_12_00_var','after_direction','direction_changed','paper_expected_direction','before_match', ...
                'after_match','interpretation','note'}); %#ok<AGROW>
        end
    end
end
C = vertcat(rows{:});
end

function s = dir_text(delta)
if delta < 0, s="matches_paper_direction"; elseif delta > 0, s="12mps_higher_than_11p28"; else, s="flat"; end
end
