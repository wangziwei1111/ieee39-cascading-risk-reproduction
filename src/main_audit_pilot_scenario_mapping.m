function main_audit_pilot_scenario_mapping()
%MAIN_AUDIT_PILOT_SCENARIO_MAPPING Audit intended pilot scenario mapping by directory/config convention.
project_root = fileparts(fileparts(mfilename('fullpath')));
diag_dir = fullfile(project_root,'results','calibration','diagnostics'); ensure_dir(diag_dir);
pilot_dir = fullfile(project_root,'results','calibration','pilot');
dirs = dir(pilot_dir);
scenario_set = strings(0,1);
for i=1:numel(dirs)
    if dirs(i).isdir && ~startsWith(dirs(i).name,'.')
        sub=dir(fullfile(dirs(i).folder,dirs(i).name));
        for j=1:numel(sub)
            if sub(j).isdir && ~startsWith(sub(j).name,'.')
                if exist(fullfile(sub(j).folder,sub(j).name,'tables','markov_chain_summary.csv'),'file')==2
                    scenario_set(end+1,1)=string(sub(j).name); %#ok<AGROW>
                end
            end
        end
    end
end
scenario_set=unique(scenario_set);
pilot_scenario_id=scenario_set; n=numel(scenario_set);
intended_target_group=strings(n,1); intended_paper_scenario=strings(n,1); actual_config_summary=strings(n,1);
wind_buses=strings(n,1); wind_capacity_mw=nan(n,1); wind_penetration=nan(n,1); wind_speed=nan(n,1);
concentrated_bus=strings(n,1); distributed_buses=strings(n,1); mapping_status=strings(n,1); issue_type=strings(n,1); recommended_fix=strings(n,1); note=strings(n,1);
for i=1:n
    s=scenario_set(i);
    [intended_target_group(i), intended_paper_scenario(i)] = classify_scenario(s);
    wind_capacity_mw(i)=3000; wind_buses(i)="30:39"; distributed_buses(i)="30:39"; concentrated_bus(i)="";
    if s=="concentrated_bus34"; concentrated_bus(i)="34"; wind_buses(i)="34"; distributed_buses(i)=""; actual_config_summary(i)="concentrated wind injection at bus 34, 3000 MW intended";
    elseif s=="distributed_30_39"; actual_config_summary(i)="distributed wind injection at buses 30:39, 3000 MW intended; equal allocation is engineering assumption unless paper specifies";
    elseif startsWith(s,"wind_speed_"); wind_speed(i)=str2double(replace(extractAfter(s,"wind_speed_"),"_",".")); actual_config_summary(i)="paper Table 4-6 wind speed point with distributed 3000 MW wind intended";
    elseif startsWith(s,"penetration_"); pct=str2double(extractBetween(s,"penetration_","pct")); wind_penetration(i)=pct/100; wind_capacity_mw(i)=7500*wind_penetration(i); actual_config_summary(i)="penetration scenario using total generation capacity 7500 MW convention";
    else; actual_config_summary(i)="unknown pilot scenario convention";
    end
    if intended_target_group(i)=="unknown"
        mapping_status(i)="issue"; issue_type(i)="unknown_scenario"; recommended_fix(i)="inspect scenario library before calibration";
    else
        mapping_status(i)="mapped_by_directory_convention"; issue_type(i)="needs_config_file_confirmation"; recommended_fix(i)="confirm against scenario library before formal calibration";
    end
    note(i)="Audit is based on pilot directory names and established scenario conventions; no new simulation run.";
end
out=table(pilot_scenario_id,intended_target_group,intended_paper_scenario,actual_config_summary,wind_buses,wind_capacity_mw,wind_penetration,wind_speed,concentrated_bus,distributed_buses,mapping_status,issue_type,recommended_fix,note);
writetable(out,fullfile(diag_dir,'pilot_scenario_mapping_audit.csv'));
end
function [group,paper]=classify_scenario(s)
if s=="concentrated_bus34"; group="topology_compare"; paper="Table 4-4 centralized_3000mw";
elseif s=="distributed_30_39"; group="topology_compare"; paper="Table 4-4 distributed_3000mw";
elseif startsWith(s,"wind_speed_"); group="wind_speed_scan"; paper="Table 4-6 "+s;
elseif startsWith(s,"penetration_"); group="penetration_scan"; paper="Table 4-5 "+s;
else; group="unknown"; paper="unknown"; end
end
function ensure_dir(path_value); if exist(path_value,'dir')~=7; mkdir(path_value); end; end
