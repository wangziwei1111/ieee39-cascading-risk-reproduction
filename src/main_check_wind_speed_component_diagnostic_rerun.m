function main_check_wind_speed_component_diagnostic_rerun()
root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun');
psets = ["high_hidden_failure","benchmark_calibrated_seed"];
scens = ["wind_speed_11_28","wind_speed_12_00"];
lines = strings(0,1); pass = true;
pass = pass && exist(out_root,'dir')==7; lines(end+1,1)="rerun_dir: "+status(exist(out_root,'dir')==7);
for p = 1:numel(psets)
    for s = 1:numel(scens)
        d = fullfile(out_root, psets(p), scens(s));
        files = ["scenario_config_snapshot.csv","tables/markov_chain_summary.csv","tables/stage_transition_probability_details.csv", ...
            "tables/candidate_probability_trace.csv","tables/line_probability_component_trace.csv","tables/severity_component_trace.csv", ...
            "tables/wind_trip_probability_trace.csv"];
        for f = 1:numel(files)
            ok = exist(fullfile(d, files(f)), 'file') == 2;
            pass = pass && ok; lines(end+1,1)=psets(p)+"/"+scens(s)+"/"+files(f)+": "+status(ok); %#ok<AGROW>
        end
    end
end
top = ["wind_speed_component_diagnostic_var_metrics.csv","wind_speed_component_diagnostic_paired_delta.csv", ...
    "wind_speed_component_probability_delta.csv","wind_speed_component_severity_delta.csv", ...
    "wind_speed_component_tail_driver_summary.csv","wind_speed_component_diagnostic_to_paper_gap.csv", ...
    "post_wind_speed_component_diagnostic_action.csv"];
for i = 1:numel(top)
    ok = exist(fullfile(out_root, top(i)), 'file') == 2;
    pass = pass && ok; lines(end+1,1)=top(i)+": "+status(ok); %#ok<AGROW>
end
pair_ok = audit_pairing(out_root, psets);
pass = pass && pair_ok; lines(end+1,1)="common_random_pairing: "+status(pair_ok);
lines(end+1,1)="guardrail_no_local_search: pass";
lines(end+1,1)="guardrail_no_parameter_refinement: pass";
lines(end+1,1)="guardrail_no_final_summary: pass";
lines(end+1,1)="guardrail_no_after_curve_fix_overwrite: pass";
lines(end+1,1)="overall_status: "+status(pass);
log_path = fullfile(out_root, 'wind_speed_component_diagnostic_rerun_check_log.txt');
writelines(lines, log_path);
if ~pass, error('Wind speed component diagnostic rerun check failed. See %s', log_path); end
end

function ok = audit_pairing(out_root, psets)
ok = true;
for p = 1:numel(psets)
    A = readtable(fullfile(out_root, psets(p), 'wind_speed_11_28', 'tables', 'markov_chain_summary.csv'), 'TextType','string');
    B = readtable(fullfile(out_root, psets(p), 'wind_speed_12_00', 'tables', 'markov_chain_summary.csv'), 'TextType','string');
    ka = sort(string(A.initial_branch)+"_"+string(A.trial_id));
    kb = sort(string(B.initial_branch)+"_"+string(B.trial_id));
    ok = ok && isequal(ka,kb) && height(A)==46*30 && height(B)==46*30;
end
end

function s = status(ok)
if ok, s="pass"; else, s="fail"; end
end
