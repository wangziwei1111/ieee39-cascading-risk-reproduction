function main_audit_calibration_target_mapping()
%MAIN_AUDIT_CALIBRATION_TARGET_MAPPING Audit calibration target rows against benchmark index.
project_root = fileparts(fileparts(mfilename('fullpath')));
diag_dir = fullfile(project_root, 'results', 'calibration', 'diagnostics');
target_path = fullfile(project_root, 'paper_inputs', 'filled', 'calibration_target_benchmark.csv');
index_path = fullfile(diag_dir, 'paper_benchmark_calibration_index.csv');
out_path = fullfile(diag_dir, 'calibration_target_mapping_audit.csv');
if exist(target_path,'file')~=2 || exist(index_path,'file')~=2
    writetable(table(), out_path); return;
end
T=read_csv(target_path); I=read_csv(index_path);
target_group=string(T.target_group); scenario_id=string(T.scenario_id); metric_name=string(T.metric_name);
target_paper_value=T.paper_value; matched_paper_table_id=strings(height(T),1); matched_scenario_label=strings(height(T),1);
matched_confidence_sigma=nan(height(T),1); matched_paper_table_value=nan(height(T),1); value_difference=nan(height(T),1);
mapping_status=strings(height(T),1); issue_type=strings(height(T),1); recommended_fix=strings(height(T),1); note=strings(height(T),1);
for r=1:height(T)
    expected = expected_benchmark(target_group(r), scenario_id(r));
    mask = string(I.metric_name)==metric_name(r) & string(I.scenario_label)==expected.scenario_label;
    if ~isempty(expected.table_id); mask = mask & string(I.paper_table_id)==expected.table_id; end
    if ~isnan(expected.sigma); mask = mask & abs(I.confidence_sigma-expected.sigma)<1e-12; end
    rows=I(mask,:);
    if isempty(rows)
        loose = I(string(I.metric_name)==metric_name(r) & abs(I.paper_table_value-target_paper_value(r))<1e-9,:);
        if isempty(loose)
            mapping_status(r)="value_not_found_in_paper_index"; issue_type(r)="missing_exact_mapping";
            recommended_fix(r)="review target scenario/table mapping before calibration";
            note(r)="No exact scenario+metric+sigma row found in benchmark index.";
        else
            rows=loose(1,:);
            mapping_status(r)="possible_wrong_table"; issue_type(r)="value_match_only";
            recommended_fix(r)="replace with explicit table/scenario/sigma mapping";
            note(r)="Value appears in paper index but not under expected scenario mapping.";
        end
    else
        rows=rows(1,:);
        diff=target_paper_value(r)-rows.paper_table_value;
        if abs(diff)<1e-9
            mapping_status(r)="exact_match";
            issue_type(r)="none";
            recommended_fix(r)="keep target row";
            note(r)="Target value matches expected paper table/scenario/sigma.";
        else
            mapping_status(r)="possible_wrong_sigma";
            issue_type(r)="value_difference";
            recommended_fix(r)="replace target value from matched benchmark row";
            note(r)="Scenario mapping matched, but value differs from benchmark index.";
        end
        value_difference(r)=diff;
    end
    if ~isempty(rows)
        matched_paper_table_id(r)=rows.paper_table_id(1); matched_scenario_label(r)=rows.scenario_label(1);
        matched_confidence_sigma(r)=rows.confidence_sigma(1); matched_paper_table_value(r)=rows.paper_table_value(1);
        if isnan(value_difference(r)); value_difference(r)=target_paper_value(r)-matched_paper_table_value(r); end
    end
    if strcmp(issue_type(r),"none") && strcmp(expected.note,"ambiguous")
        mapping_status(r)="scenario_label_ambiguous"; issue_type(r)="scenario_ambiguous";
        recommended_fix(r)="manual confirmation required";
        note(r)=note(r)+"; expected scenario mapping is ambiguous.";
    end
end
out=table(target_group,scenario_id,metric_name,target_paper_value,matched_paper_table_id,matched_scenario_label,matched_confidence_sigma,matched_paper_table_value,value_difference,mapping_status,issue_type,recommended_fix,note);
writetable(out,out_path);
fprintf('calibration target mapping audit written: %d rows\n', height(out));
end

function e=expected_benchmark(group, scenario)
e=struct('table_id',"",'scenario_label',"",'sigma',0.95,'note',"");
switch string(group)
    case "topology_compare"
        e.table_id="Table 4-4";
        if scenario=="concentrated_bus34"; e.scenario_label="centralized_3000mw";
        elseif scenario=="distributed_30_39"; e.scenario_label="distributed_3000mw";
        else; e.note="ambiguous"; end
    case "wind_speed_scan"
        e.table_id="Table 4-6";
        e.scenario_label = replace(string(scenario), "wind_speed_", "wind_speed_") + "mps";
        if scenario=="wind_speed_11_28"; e.scenario_label="wind_speed_11_28mps"; end
        if scenario=="wind_speed_12_00"; e.scenario_label="wind_speed_12_00mps"; end
    case "penetration_scan"
        e.table_id="Table 4-5"; e.scenario_label=string(scenario);
    otherwise
        e.note="ambiguous";
end
end
function tbl=read_csv(path_value); opts=detectImportOptions(path_value,'Delimiter',',','TextType','string'); opts.VariableNamingRule='preserve'; tbl=readtable(path_value,opts); end
