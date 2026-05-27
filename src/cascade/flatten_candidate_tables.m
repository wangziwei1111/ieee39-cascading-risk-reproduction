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
total_candidate_count_from_stages = 0;
for i = 1:numel(chain_records)
    c = chain_records(i);
    for s = 1:numel(c.stage_records)
        st = c.stage_records(s);
        if ~isfield(st, 'candidate_table') || isempty(st.candidate_table)
            continue;
        end
        t = normalize_candidate_table(st.candidate_table);
        if isempty(t) || height(t) == 0
            continue;
        end
        total_candidate_count_from_stages = total_candidate_count_from_stages + height(t);
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
    warning('候选线路明细为空：chain_records中未发现非空candidate_table。');
else
    candidate_detail_table = vertcat(rows{:});
end

if total_candidate_count_from_stages > 0 && height(candidate_detail_table) == 0
    error('候选线路明细展开失败：stage中存在候选线路，但candidate_detail_table为空。');
end
end

function t = normalize_candidate_table(candidate_table)
%NORMALIZE_CANDIDATE_TABLE 将候选线路数据标准化为table。
% 输入：
%   candidate_table - table或结构体形式的候选线路数据。
% 输出：
%   t - 标准table。
% 物理含义：
%   MAT文件保存/读取或结构体传递可能改变候选表类型，本函数保证后续
%   导出逻辑可以稳定读取线路负载率、停运概率和抽样结果。

if istable(candidate_table)
    t = candidate_table;
elseif isstruct(candidate_table)
    try
        t = struct2table(candidate_table);
    catch
        t = table();
    end
else
    t = table();
end

required = {'branch_index', 'from_bus', 'to_bus', 'loading_pu', ...
    'outage_probability', 'random_u', 'trip_selected'};
if ~isempty(t)
    missing = setdiff(required, t.Properties.VariableNames);
    if ~isempty(missing)
        error('candidate_table缺少字段：%s', strjoin(missing, ', '));
    end
end
end
