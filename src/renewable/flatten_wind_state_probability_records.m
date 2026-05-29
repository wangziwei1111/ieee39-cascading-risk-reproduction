function wind_state_probability_table = flatten_wind_state_probability_records(chain_records)
%FLATTEN_WIND_STATE_PROBABILITY_RECORDS Expand stage-level P_wt(E_k) diagnostics.
rows = {};
for c = 1:numel(chain_records)
    chain = chain_records(c);
    stages = chain.stage_records;
    for s = 1:numel(stages)
        if isfield(stages(s), 'wind_state_probability_detail') && ...
                ~isempty(stages(s).wind_state_probability_detail)
            d = stages(s).wind_state_probability_detail;
            rows{end + 1, 1} = table(chain.initial_branch, chain.trial_id, stages(s).stage_id, ...
                d.num_wind_units, d.num_probability_positive, d.max_p_wt_h, ...
                d.mean_p_wt_h, d.p_wt_Ek, string(d.status), string(d.mode), string(d.note), ...
                'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
                'num_wind_units', 'num_probability_positive', 'max_p_wt_h', ...
                'mean_p_wt_h', 'p_wt_Ek', 'status', 'mode', 'note'});
        end
    end
end
if isempty(rows)
    wind_state_probability_table = empty_table();
else
    wind_state_probability_table = vertcat(rows{:});
end
end

function tbl = empty_table()
tbl = table([], [], [], [], [], [], [], [], strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
    'num_wind_units', 'num_probability_positive', 'max_p_wt_h', ...
    'mean_p_wt_h', 'p_wt_Ek', 'status', 'mode', 'note'});
end
