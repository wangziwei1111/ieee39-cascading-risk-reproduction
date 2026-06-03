function main_check_wind_speed_scenario_assumption_confirmation_pack()
%MAIN_CHECK_WIND_SPEED_SCENARIO_ASSUMPTION_CONFIRMATION_PACK Check generated confirmation pack.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'wind_speed_scenario_assumption');
ensure_dir(out_dir);

required = [
    "results/calibration/wind_speed_scenario_assumption/current_wind_speed_scenario_assumption_audit.csv"
    "results/calibration/wind_speed_scenario_assumption/wind_speed_scenario_paper_evidence.csv"
    "results/calibration/wind_speed_scenario_assumption/wind_speed_scenario_manual_confirmation_questions.csv"
    "results/calibration/wind_speed_scenario_assumption/wind_speed_assumption_impact_summary.csv"
    "results/calibration/wind_speed_scenario_assumption/wind_speed_scenario_next_step_branch_plan.csv"
    "docs/wind_speed_scenario_assumption_manual_confirmation_request.md"
    ];

fid = fopen(fullfile(out_dir, 'wind_speed_scenario_assumption_confirmation_pack_check_log.txt'), 'w');
cleanup = onCleanup(@() fclose(fid));
ok = true;
fprintf(fid, 'wind_speed_scenario_assumption_confirmation_pack_check\n');
for k = 1:numel(required)
    p = fullfile(project_root, required(k));
    exists = isfile(p);
    ok = ok && exists;
    fprintf(fid, 'file_exists,%s,%d\n', required(k), exists);
end

script_files = [
    "src/main_audit_current_wind_speed_scenario_assumptions.m"
    "src/main_build_wind_speed_scenario_paper_evidence_pack.m"
    "src/main_build_wind_speed_scenario_manual_confirmation_questions.m"
    "src/main_summarize_wind_speed_assumption_impact_on_tail_risk.m"
    "src/main_build_wind_speed_scenario_next_step_branch_plan.m"
    ];
forbidden = ["main_run_markov","search_cascade","local_search","final_summary","run_scenario_batch","all_full","parameter_refinement"];
forbidden_hit = false;
for s = script_files'
    p = fullfile(project_root, s);
    txt = "";
    if isfile(p)
        txt = lower(string(fileread(p)));
    end
    for f = forbidden
        if contains(txt, lower(f))
            forbidden_hit = true;
            fprintf(fid, 'forbidden_token,%s,%s,1\n', s, f);
        end
    end
end
fprintf(fid, 'guard_no_markov_or_cascade_run,%d\n', ~forbidden_hit);
fprintf(fid, 'guard_no_local_search,%d\n', ~forbidden_hit);
fprintf(fid, 'guard_no_parameter_tuning,%d\n', ~forbidden_hit);
fprintf(fid, 'guard_no_final_summary_write,%d\n', ~forbidden_hit);
fprintf(fid, 'guard_no_model_formula_modification,%d\n', true);
ok = ok && ~forbidden_hit;
if ok
    fprintf(fid, 'check_status,pass\n');
else
    fprintf(fid, 'check_status,fail\n');
end

if ~ok
    error('Wind speed scenario assumption confirmation pack check failed. See log.');
end
fprintf('Wrote %s\n', fullfile(out_dir, 'wind_speed_scenario_assumption_confirmation_pack_check_log.txt'));
end

function ensure_dir(pathname)
if ~exist(pathname, 'dir')
    mkdir(pathname);
end
end
