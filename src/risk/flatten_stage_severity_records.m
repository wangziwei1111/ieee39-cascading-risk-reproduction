function stage_severity_table = flatten_stage_severity_records(chain_records)
%FLATTEN_STAGE_SEVERITY_RECORDS Extract stage-level diagnostic severity records.
tables = {};
for c = 1:numel(chain_records)
    stages = chain_records(c).stage_records;
    for s = 1:numel(stages)
        if isfield(stages(s), 'stage_severity_detail') && ...
                istable(stages(s).stage_severity_detail) && height(stages(s).stage_severity_detail) > 0
            tables{end+1, 1} = stages(s).stage_severity_detail; %#ok<AGROW>
        end
    end
end
if isempty(tables)
    stage_severity_table = empty_table();
else
    stage_severity_table = vertcat(tables{:});
end
end

function tbl = empty_table()
tbl = table([], [], [], [], [], [], [], [], [], [], [], [], strings(0, 1), strings(0, 1), ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', 'severity_LLR', ...
    'severity_LFOR', 'severity_NVOR', 'severity_CRI', 'load_shed_mw', ...
    'base_load_mw', 'max_line_loading_pu', 'min_voltage_pu', 'max_voltage_pu', ...
    'severity_status', 'calculation_note'});
end
