function [line_flow_detail_table, bus_voltage_detail_table, stage_probability_table] = ...
    build_markov_paper_detail_tables(chain_records, base_mpc, cfg, scenario, renewable_info, initial_probability_table)
%BUILD_MARKOV_PAPER_DETAIL_TABLES 回放Markov事故链并导出论文严重度所需明细。
% 输入：
%   chain_records - main_run_markov_line生成的事故链结构体数组。
%   base_mpc - 已应用新能源场景的MATPOWER基础算例。
%   cfg - 全局配置，包含论文电压阈值、线路容量近似和输出参数。
%   scenario - 新能源场景配置，用于故障后孤岛标准化和平衡节点选择。
%   renewable_info - 新能源机组信息，用于识别风电机组。
%   initial_probability_table - 初始线路停运概率表。
% 输出：
%   line_flow_detail_table - 每条事故链每一级所有线路的有功潮流明细。
%   bus_voltage_detail_table - 每条事故链每一级所有节点电压明细。
%   stage_probability_table - 每条事故链每一级的初始概率、转移概率和累计概率。
% 物理含义：
%   本函数不改变已抽样事故链，只按已记录的逐级新增停运线路回放准静态潮流。
%   对原Markov记录中不收敛的终止状态，仍导出MATPOWER最后一次迭代结果，并用pf_converged标记。

if isempty(chain_records)
    error('chain_records为空，无法构造论文严重度明细表。');
end
if isempty(initial_probability_table)
    error('initial_probability_table为空，无法构造阶段累计概率。');
end

line_rows = {};
bus_rows = {};
prob_rows = {};

for c = 1:numel(chain_records)
    chain = chain_records(c);
    initial_branch = chain.initial_branch;
    trial_id = chain.trial_id;
    prob_row = initial_probability_table(initial_probability_table.branch_index == initial_branch, :);
    if isempty(prob_row)
        error('初始线路概率表中找不到branch %d。', initial_branch);
    end

    initial_outage_probability = prob_row.initial_outage_probability(1);
    probability_source = resolve_probability_source(cfg);
    cumulative_probability = initial_outage_probability;
    mpc_current = base_mpc;
    [mpc_current, ~] = apply_line_outages(mpc_current, initial_branch);

    for s = 1:numel(chain.stage_records)
        st = chain.stage_records(s);
        stage_id = st.stage_id;

        [mpc_current, island_info] = normalize_case_after_contingency(mpc_current, cfg, scenario, renewable_info);
        [pf_result, converged] = run_ac_powerflow(mpc_current);
        if ~converged
            existing_shed_mw = 0;
            if isfield(island_info, 'disconnected_load_mw')
                existing_shed_mw = island_info.disconnected_load_mw;
            end
            [mpc_current, pf_result, shed] = simple_load_shedding(mpc_current, cfg, existing_shed_mw);
            converged = isfield(shed, 'converged_after_shed') && shed.converged_after_shed;
        end
        if ~isfield(pf_result, 'branch') || ~isfield(pf_result, 'bus')
            error('事故链 initial_branch=%d trial_id=%d stage_id=%d 缺少MATPOWER线路或节点结果。', ...
                initial_branch, trial_id, stage_id);
        end

        [stage_transition_probability, num_selected_candidates, num_unselected_candidates, transition_note] = ...
            calc_stage_transition_probability(st);
        cumulative_probability = cumulative_probability * stage_transition_probability;

        stage_load_shed_mw = extract_stage_load_shed_mw(st);
        base_load_mw = sum(base_mpc.bus(:, 3));
        stage_load_shed_frac = stage_load_shed_mw / base_load_mw;
        stage_probability_source = probability_source + transition_note;
        prob_rows{end + 1, 1} = table(initial_branch, trial_id, stage_id, ...
            initial_outage_probability, stage_transition_probability, cumulative_probability, ...
            string(stage_probability_source), num_selected_candidates, num_unselected_candidates, ...
            stage_load_shed_mw, base_load_mw, stage_load_shed_frac, double(converged), ...
            'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
            'initial_outage_probability', 'stage_transition_probability', 'stage_cumulative_probability', ...
            'probability_source', 'num_selected_candidates', 'num_unselected_candidates', ...
            'stage_load_shed_mw', 'base_load_mw', 'stage_load_shed_frac', 'pf_converged'});

        line_rows{end + 1, 1} = build_line_flow_rows(pf_result, cfg, initial_branch, trial_id, stage_id, converged);
        bus_rows{end + 1, 1} = build_bus_voltage_rows(pf_result, cfg, initial_branch, trial_id, stage_id, converged);

        selected = get_numeric_vector(st.new_outaged_branches);
        if ~isempty(selected)
            [mpc_current, ~] = apply_line_outages(mpc_current, selected);
        end
    end
end

line_flow_detail_table = vertcat(line_rows{:});
bus_voltage_detail_table = vertcat(bus_rows{:});
stage_probability_table = vertcat(prob_rows{:});
end

function source = resolve_probability_source(cfg)
%RESOLVE_PROBABILITY_SOURCE 给出阶段概率来源说明。
mode = "uniform";
if isfield(cfg, 'initial_fault_probability_mode')
    mode = string(cfg.initial_fault_probability_mode);
end
if mode == "paper_table_4_1"
    source = "paper_table_4_1_initial_probability + candidate_transition_probability";
elseif mode == "uniform"
    source = "uniform_initial_probability + candidate_transition_probability";
else
    error('未知初始故障概率模式：%s', mode);
end
end

function value = get_numeric_vector(raw_value)
%GET_NUMERIC_VECTOR 将事故链记录中的线路集合转换为列向量。
if isempty(raw_value)
    value = [];
elseif isnumeric(raw_value)
    value = raw_value(:);
elseif isstring(raw_value) || ischar(raw_value)
    text = string(raw_value);
    if strlength(text) == 0
        value = [];
    else
        value = str2double(split(text, ','));
        value = value(~isnan(value));
    end
else
    error('无法解析线路集合类型：%s', class(raw_value));
end
end

function [stage_transition_probability, num_selected, num_unselected, transition_note] = calc_stage_transition_probability(stage_record)
%CALC_STAGE_TRANSITION_PROBABILITY 根据候选线路抽样明细计算逐级条件转移概率。
if ~isfield(stage_record, 'candidate_table') || isempty(stage_record.candidate_table)
    stage_transition_probability = 1.0;
    num_selected = 0;
    num_unselected = 0;
    transition_note = " (no_candidate_table_transition_probability_set_to_1)";
    return;
end

candidate_table = stage_record.candidate_table;
if ~istable(candidate_table)
    candidate_table = struct2table(candidate_table);
end
if isempty(candidate_table)
    stage_transition_probability = 1.0;
    num_selected = 0;
    num_unselected = 0;
    transition_note = " (empty_candidate_table_transition_probability_set_to_1)";
    return;
end

required = {'outage_probability', 'trip_selected'};
missing = setdiff(required, candidate_table.Properties.VariableNames);
if ~isempty(missing)
    error('candidate_table缺少字段：%s', strjoin(missing, ', '));
end

p = candidate_table.outage_probability;
selected = candidate_table.trip_selected == 1;
if any(p < 0 | p > 1 | isnan(p))
    error('candidate_table中的outage_probability必须位于[0,1]且不能为NaN。');
end

num_selected = sum(selected);
num_unselected = sum(~selected);
stage_transition_probability = prod(p(selected)) * prod(1 - p(~selected));
transition_note = "";
end

function stage_load_shed_mw = extract_stage_load_shed_mw(stage_record)
%EXTRACT_STAGE_LOAD_SHED_MW 提取状态E_k下负荷损失MW。
stage_load_shed_mw = 0;
if isfield(stage_record, 'shed') && isstruct(stage_record.shed)
    if isfield(stage_record.shed, 'load_shed_mw')
        stage_load_shed_mw = stage_record.shed.load_shed_mw;
    elseif isfield(stage_record.shed, 'total_load_shed_mw')
        stage_load_shed_mw = stage_record.shed.total_load_shed_mw;
    end
end
end

function line_table = build_line_flow_rows(pf_result, cfg, initial_branch, trial_id, stage_id, converged)
%BUILD_LINE_FLOW_ROWS 构造某一级全线路有功潮流严重度明细。
branch_index = (1:size(pf_result.branch, 1))';
from_bus = pf_result.branch(:, 1);
to_bus = pf_result.branch(:, 2);
PF = pf_result.branch(:, 14);
PT = pf_result.branch(:, 16);
active_flow_mw = max(abs(PF), abs(PT));
active_limit_mw = pf_result.branch(:, 6);
bad_limit = active_limit_mw <= 0 | isnan(active_limit_mw);
active_limit_mw(bad_limit) = cfg.default_branch_rate_mva;
P_li_pu = active_flow_mw ./ active_limit_mw;
P_li_max_pu = ones(size(P_li_pu));
line_overlimit_component = max(P_li_pu - P_li_max_pu, 0);
line_severity_component = (exp(line_overlimit_component) - 1) / (exp(1) - 1) * 100;
pf_converged = repmat(double(converged), size(branch_index));

n = numel(branch_index);
line_table = table(repmat(initial_branch, n, 1), repmat(trial_id, n, 1), repmat(stage_id, n, 1), ...
    branch_index, from_bus, to_bus, PF, PT, active_flow_mw, active_limit_mw, ...
    P_li_pu, P_li_max_pu, line_overlimit_component, line_severity_component, pf_converged, ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
    'branch_index', 'from_bus', 'to_bus', 'PF', 'PT', 'active_flow_mw', 'active_limit_mw', ...
    'P_li_pu', 'P_li_max_pu', 'line_overlimit_component', 'line_severity_component', 'pf_converged'});
end

function bus_table = build_bus_voltage_rows(pf_result, cfg, initial_branch, trial_id, stage_id, converged)
%BUILD_BUS_VOLTAGE_ROWS 构造某一级全节点电压严重度明细。
bus_id = pf_result.bus(:, 1);
voltage_pu = pf_result.bus(:, 8);
lower_limit = cfg.paper_voltage_lower_limit_pu;
upper_limit = cfg.paper_voltage_upper_limit_pu;
voltage_deviation_component = max(max(lower_limit - voltage_pu, voltage_pu - upper_limit), 0);
voltage_severity_component = (exp(voltage_deviation_component) - 1) / (exp(1) - 1) * 100;
pf_converged = repmat(double(converged), size(bus_id));

n = numel(bus_id);
bus_table = table(repmat(initial_branch, n, 1), repmat(trial_id, n, 1), repmat(stage_id, n, 1), ...
    bus_id, voltage_pu, voltage_deviation_component, voltage_severity_component, pf_converged, ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
    'bus_id', 'voltage_pu', 'voltage_deviation_component', 'voltage_severity_component', 'pf_converged'});
end
