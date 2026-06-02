function main_run_severity_component_trace_smoke_if_needed()
root=fileparts(fileparts(mfilename('fullpath')));
out_dir=fullfile(root,'results','calibration','severity_formula'); ensure_dir(out_dir);
smoke_dir=fullfile(out_dir,'severity_component_trace_smoke'); ensure_dir(smoke_dir);
F=readtable(fullfile(out_dir,'severity_component_field_availability.csv'),'TextType','string','Delimiter',',');
need=any(logical(F.blocking_if_missing));
if ~need
    writelines(["skipped_fields_available";"Existing severity_component_trace fields are sufficient; no smoke Markov run executed."],fullfile(smoke_dir,'smoke_log.txt'));
    return;
end
error('Required severity fields are missing; explicit review is required before any smoke run.');
end
function ensure_dir(path), if exist(path,'dir')~=7, mkdir(path); end, end
