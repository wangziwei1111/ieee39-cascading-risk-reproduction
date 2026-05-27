function [chain_summary_table, chain_stage_table] = flatten_chain_records(chain_records, cfg)
%FLATTEN_CHAIN_RECORDS 将事故链结构体数组展开为结果表。
% 输入：
%   chain_records - search_cascade_markov_line输出的结构体数组。
%   cfg - 全局配置，预留用于后续扩展。
% 输出：
%   chain_summary_table - 每条事故链一行的汇总表。
%   chain_stage_table - 每条事故链每一级一行的逐级状态表。
% 物理含义：
%   结构体适合保存完整候选线路表，CSV表格适合论文调试、筛选和复核。

arguments
    chain_records struct
    cfg struct %#ok<INUSA>
end

num_chains = numel(chain_records);
summary_rows = cell(num_chains, 1);
stage_rows = {};

for i = 1:num_chains
    c = chain_records(i);
    summary_rows{i} = table( ...
        c.initial_branch, c.trial_id, c.chain_depth, string(c.terminated_reason), ...
        c.total_load_shed_mw, c.total_load_shed_frac, ...
        c.max_line_loading_pu, c.max_voltage_deviation_pu, ...
        numel(c.outaged_branches), c.final_converged, ...
        c.basic_LLR, c.basic_LFOR, c.basic_NVOR, c.basic_CRI, ...
        'VariableNames', {'initial_branch', 'trial_id', 'chain_depth', 'terminated_reason', ...
        'total_load_shed_mw', 'total_load_shed_frac', ...
        'max_line_loading_pu', 'max_voltage_deviation_pu', ...
        'num_total_outaged_branches', 'final_converged', ...
        'basic_LLR', 'basic_LFOR', 'basic_NVOR', 'basic_CRI'});

    for s = 1:numel(c.stage_records)
        st = c.stage_records(s);
        selected_count = 0;
        if ~isempty(st.candidate_table)
            selected_count = sum(st.candidate_table.trip_selected);
        end
        stage_rows{end + 1, 1} = table( ... %#ok<AGROW>
            c.initial_branch, c.trial_id, st.stage_id, ...
            join_branch_list(st.new_outaged_branches), join_branch_list(st.all_outaged_branches), ...
            st.island_info.island_count, st.island_info.disconnected_load_mw, ...
            st.island_info.new_slack_bus, st.converged, st.shed.total_load_shed_mw, ...
            st.violations.num_overloaded_lines, st.violations.max_line_loading_pu, ...
            st.violations.num_voltage_violations, st.violations.max_voltage_deviation_pu, ...
            height(st.candidate_table), selected_count, ...
            'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
            'new_outaged_branches', 'all_outaged_branches', ...
            'island_count', 'disconnected_load_mw', 'new_slack_bus', ...
            'converged', 'load_shed_mw', ...
            'num_overloaded_lines', 'max_line_loading_pu', ...
            'num_voltage_violations', 'max_voltage_deviation_pu', ...
            'num_candidate_lines', 'num_selected_trips'});
    end
end

chain_summary_table = vertcat(summary_rows{:});
if isempty(stage_rows)
    chain_stage_table = table();
else
    chain_stage_table = vertcat(stage_rows{:});
end
end

function s = join_branch_list(branches)
%JOIN_BRANCH_LIST 将线路编号数组转为可写入CSV的字符串。
% 输入：
%   branches - 线路编号数组。
% 输出：
%   s - 逗号分隔字符串。
% 物理含义：
%   事故链中一阶段可能同时停运多条线路，用字符串保留完整编号列表。

branches = branches(:)';
if isempty(branches)
    s = "";
else
    s = strjoin(string(branches), ',');
end
end
