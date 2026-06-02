function main_rebuild_stage_probability_aggregation_audit_if_empty()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root,'results','calibration','stage_probability_aggregation');
integrity_path = fullfile(out_dir,'stage_probability_audit_artifact_integrity.csv');
need_rebuild = true;
if exist(integrity_path,'file')==2
    T = readtable(integrity_path,'TextType','string','Delimiter',',');
    need_rebuild = any(logical(T.blocking_for_severity_audit));
end
if need_rebuild
    main_audit_stage_probability_aggregation_response();
    main_diagnose_wind_speed_stage_probability_delta();
end
main_check_stage_probability_audit_artifact_integrity();
end
