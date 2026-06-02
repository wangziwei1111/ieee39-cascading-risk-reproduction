function main_check_stage_probability_audit_artifact_integrity()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root,'results','calibration','stage_probability_aggregation');
ensure_dir(out_dir);
files = [
    "stage_probability_aggregation_audit.csv"
    "wind_speed_stage_probability_delta.csv"
    "post_stage_probability_aggregation_action.csv"
    "PL_confirmation_and_stage_probability_audit_check_log.txt"
];
rows = {};
for i=1:numel(files)
    p = fullfile(out_dir, files(i));
    [rc, cc, header, fields] = inspect_file(p);
    nonempty = rc > 0;
    blocking = files(i) ~= "PL_confirmation_and_stage_probability_audit_check_log.txt" && ~nonempty;
    if ~exist(p,'file')
        st = "missing_artifact"; fix = "rebuild_stage_probability_aggregation_audit_if_empty";
    elseif blocking
        st = "empty_artifact"; fix = "rebuild_stage_probability_aggregation_audit_if_empty";
    elseif ~fields && endsWith(files(i), ".csv")
        st = "missing_expected_fields"; fix = "inspect_or_rebuild_artifact";
    else
        st = "pass"; fix = "no_fix_required";
    end
    rows{end+1,1} = table(string(p), exist(p,'file')==2, rc, cc, header, fields, nonempty, st, blocking, fix, ...
        "Artifact integrity gate before severity audit.", ...
        'VariableNames', {'artifact_path','exists','row_count','column_count','has_header','has_expected_fields','nonempty_required', ...
        'integrity_status','blocking_for_severity_audit','recommended_fix','note'}); %#ok<AGROW>
end
writetable(vertcat(rows{:}), fullfile(out_dir,'stage_probability_audit_artifact_integrity.csv'));
end

function [rc, cc, header, fields] = inspect_file(p)
rc = 0; cc = 0; header = false; fields = false;
if exist(p,'file') ~= 2, return; end
[~,~,ext] = fileparts(p);
if ext ~= ".csv"
    txt = string(fileread(p)); rc = numel(splitlines(txt)); cc = 1; header = rc > 0; fields = true; return;
end
T = readtable(p,'TextType','string','Delimiter',',');
rc = height(T); cc = width(T); header = cc > 0;
need = ["parameter_set_id","scenario_id","initial_branch","trial_id","stage_id"];
if contains(string(p), "stage_probability_aggregation_audit")
    need = [need, "stage_transition_probability","chain_transition_probability"];
elseif contains(string(p), "wind_speed_stage_probability_delta")
    need = ["parameter_set_id","initial_branch","trial_id","stage_id","stage_probability_11_28","chain_probability_11_28"];
end
fields = all(ismember(need, string(T.Properties.VariableNames)));
end

function ensure_dir(path)
if exist(path,'dir')~=7, mkdir(path); end
end
