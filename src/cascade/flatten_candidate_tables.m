function candidate_detail_table = flatten_candidate_tables(chain_records)
%FLATTEN_CANDIDATE_TABLES 展开所有事故链逐级候选线路抽样细节。
% 输入：
%   chain_records - search_cascade_markov_line保存的结构体数组。
% 输出：
%   candidate_detail_table - 每条候选线路一行，含负载率、停运概率、随机数。
% 物理含义：
%   用于检查线路概率模型是否合理：高负载率线路应对应更高停运概率，
%   random_u用于追踪某条线路为什么被抽中或未被抽中。

rows = {};
for i = 1:numel(chain_records)
    c = chain_records(i);
    for s = 1:numel(c.stage_records)
        st = c.stage_records(s);
        t = st.candidate_table;
        for k = 1:height(t)
            rows{end + 1, 1} = table( ... %#ok<AGROW>
                c.initial_branch, c.trial_id, st.stage_id, ...
                t.branch_index(k), t.from_bus(k), t.to_bus(k), ...
                t.loading_pu(k), t.outage_probability(k), ...
                t.random_u(k), t.trip_selected(k), ...
                'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
                'candidate_branch', 'from_bus', 'to_bus', 'loading_pu', ...
                'outage_probability', 'random_u', 'trip_selected'});
        end
    end
end

if isempty(rows)
    candidate_detail_table = table();
else
    candidate_detail_table = vertcat(rows{:});
end
end
