function wind_trip_detail_table = flatten_wind_trip_records(chain_records)
%FLATTEN_WIND_TRIP_RECORDS 展开事故链中的风机脱网概率记录。
% 输入：
%   chain_records - search_cascade_markov_line输出的事故链结构体数组。
% 输出：
%   wind_trip_detail_table - 每条事故链、每一级、每台风机一行的诊断明细。
% 物理含义：
%   将record-only的P_WT(h)诊断结果从结构体展开成可复核CSV，不改变事故链。

tables = {};
for c = 1:numel(chain_records)
    stages = chain_records(c).stage_records;
    for s = 1:numel(stages)
        if isfield(stages(s), 'wind_trip_table') && ~isempty(stages(s).wind_trip_table) && ...
                istable(stages(s).wind_trip_table) && height(stages(s).wind_trip_table) > 0
            tables{end + 1, 1} = stages(s).wind_trip_table; %#ok<AGROW>
        end
    end
end

if isempty(tables)
    wind_trip_detail_table = empty_wind_trip_table();
else
    wind_trip_detail_table = vertcat(tables{:});
end
end

function tbl = empty_wind_trip_table()
tbl = table([], [], [], [], [], [], [], [], [], [], strings(0, 1), false(0, 1), ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', 'wind_index', ...
    'wind_bus', 'wind_gen_row', 'voltage_pu', 'wind_output_mw', 'wind_capacity_mw', ...
    'trip_probability', 'trip_region', 'record_only'});
end
