function [line_flow_detail_table, bus_voltage_detail_table, stage_probability_table, ...
    invalid_stage_detail_table, invalid_stage_summary_table] = ...
    build_markov_paper_detail_tables(chain_records, base_mpc, cfg, scenario, renewable_info, initial_probability_table)
%BUILD_MARKOV_PAPER_DETAIL_TABLES 回放Markov事故链并导出论文严重度所需明细。
% 输入：
%   chain_records - 已生成的Markov事故链结构体数组。
%   base_mpc - 已应用新能源场景的MATPOWER基础算例。
%   cfg - 全局配置，包含paper严格收敛和合理数值阈值。
%   scenario - 新能源场景配置，用于孤岛标准化和平衡节点选择。
%   renewable_info - 新能源机组信息，用于识别风电机组。
%   initial_probability_table - 初始线路停运概率表。
% 输出：
%   line_flow_detail_table - 仅收敛且数值合理stage的全线路有功潮流明细。
%   bus_voltage_detail_table - 仅收敛且数值合理stage的全节点电压明细。
%   stage_probability_table - 每级初始概率、转移概率、累计概率、LLR输入和有效性标记。
%   invalid_stage_detail_table - 非收敛或数值异常stage诊断表。
%   invalid_stage_summary_table - 无效stage汇总统计。
% 物理含义：
%   本函数只回放chain_records中已经记录的停运线路和candidate_table，不重新随机抽样。
%   非收敛潮流结果不能作为LFOR/NVOR物理输入；这些stage只记录LLR和诊断，不输出line/bus明细。

if isempty(chain_records)
    error('chain_records为空，无法构造论文严重度明细表。');
end

line_rows = {};
bus_rows = {};
prob_rows = {};
invalid_rows = {};

base_load_mw = sum(base_mpc.bus(:, 3));

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
        [mpc_current, pf_result, converged, replay_source] = replay_stage_powerflow( ...
            mpc_current, cfg, scenario, renewable_info);

        [stage_transition_probability, num_selected_candidates, num_unselected_candidates, transition_note] = ...
            calc_stage_transition_probability(st);
        cumulative_probability = cumulative_probability * stage_transition_probability;

        stage_load_shed_mw = extract_stage_load_shed_mw(st);
        stage_load_shed_frac = stage_load_shed_mw / base_load_mw;

        [severity_valid, invalid_reason, line_table, bus_table, max_p, min_v, max_v] = ...
            build_valid_stage_details(pf_result, cfg, initial_branch, trial_id, stage_id, converged, replay_source);

        if severity_valid
            line_rows{end + 1, 1} = line_table; %#ok<AGROW>
            bus_rows{end + 1, 1} = bus_table; %#ok<AGROW>
        else
            invalid_rows{end + 1, 1} = build_invalid_stage_row(initial_branch, trial_id, stage_id, ...
                converged, severity_valid, invalid_reason, replay_source, stage_load_shed_mw, ...
                base_load_mw, cumulative_probability, max_p, min_v, max_v); %#ok<AGROW>
        end

        prob_rows{end + 1, 1} = table(initial_branch, trial_id, stage_id, ...
            initial_outage_probability, stage_transition_probability, cumulative_probability, ...
            string(probability_source + transition_note), num_selected_candidates, num_unselected_candidates, ...
            stage_load_shed_mw, base_load_mw, stage_load_shed_frac, double(converged), ...
            double(severity_valid), string(invalid_reason), string(replay_source), ...
            'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
            'initial_outage_probability', 'stage_transition_probability', 'stage_cumulative_probability', ...
            'probability_source', 'num_selected_candidates', 'num_unselected_candidates', ...
            'stage_load_shed_mw', 'base_load_mw', 'stage_load_shed_frac', 'pf_converged', ...
            'severity_valid', 'invalid_reason', 'replay_source'});

        selected = get_numeric_vector(st.new_outaged_branches);
        if ~isempty(selected)
            [mpc_current, ~] = apply_line_outages(mpc_current, selected);
        end
    end
end

line_flow_detail_table = vertcat_or_empty(line_rows, line_flow_empty_table());
bus_voltage_detail_table = vertcat_or_empty(bus_rows, bus_voltage_empty_table());
stage_probability_table = vertcat(prob_rows{:});
invalid_stage_detail_table = vertcat_or_empty(invalid_rows, invalid_stage_empty_table());
invalid_stage_summary_table = summarize_invalid_stage_details(stage_probability_table, invalid_stage_detail_table);
end

function [mpc_current, pf_result, converged, replay_source] = replay_stage_powerflow(mpc_current, cfg, scenario, renewable_info)
%REPLAY_STAGE_POWERFLOW 回放单级状态潮流。
[mpc_current, island_info] = normalize_case_after_contingency(mpc_current, cfg, scenario, renewable_info);
[pf_result, converged_before_shedding] = run_ac_powerflow(mpc_current);
replay_source = "replayed_pf_result";
converged = converged_before_shedding;
if ~converged_before_shedding
    existing_shed_mw = 0;
    if isfield(island_info, 'disconnected_load_mw')
        existing_shed_mw = island_info.disconnected_load_mw;
    end
    [mpc_current, pf_result, shed] = simple_load_shedding(mpc_current, cfg, existing_shed_mw);
    converged = isfield(shed, 'converged_after_shed') && shed.converged_after_shed;
    replay_source = "replayed_after_load_shedding";
end
if ~converged
    replay_source = "invalid_nonconverged";
end
end

function [severity_valid, invalid_reason, line_table, bus_table, max_p, min_v, max_v] = ...
    build_valid_stage_details(pf_result, cfg, initial_branch, trial_id, stage_id, converged, replay_source)
%BUILD_VALID_STAGE_DETAILS 只为收敛且合理的stage构造line/bus明细。
line_table = line_flow_empty_table();
bus_table = bus_voltage_empty_table();
max_p = NaN;
min_v = NaN;
max_v = NaN;

if ~isfield(pf_result, 'branch') || ~isfield(pf_result, 'bus')
    severity_valid = false;
    invalid_reason = "missing_pf_result";
    return;
end

if ~converged
    [max_p, min_v, max_v] = extract_raw_extremes(pf_result, cfg);
    severity_valid = false;
    invalid_reason = "nonconverged_power_flow";
    return;
end

[candidate_line_table, line_valid, line_reason, max_p] = build_line_flow_rows( ...
    pf_result, cfg, initial_branch, trial_id, stage_id, replay_source);
[candidate_bus_table, bus_valid, bus_reason, min_v, max_v] = build_bus_voltage_rows( ...
    pf_result, cfg, initial_branch, trial_id, stage_id, replay_source);

if ~line_valid
    severity_valid = false;
    invalid_reason = line_reason;
    return;
end
if ~bus_valid
    severity_valid = false;
    invalid_reason = bus_reason;
    return;
end

severity_valid = true;
invalid_reason = "none";
line_table = candidate_line_table;
bus_table = candidate_bus_table;
end

function [line_table, valid_flag, invalid_reason, max_p] = build_line_flow_rows(pf_result, cfg, initial_branch, trial_id, stage_id, replay_source)
%BUILD_LINE_FLOW_ROWS 构造收敛stage的全线路有功潮流严重度明细。
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
max_p = max(P_li_pu);

[line_severity_component, component_valid, component_reason] = safe_exponential_severity(line_overlimit_component, cfg);
valid_flag = true;
invalid_reason = "none";
if any(P_li_pu < 0 | isnan(P_li_pu))
    valid_flag = false;
    invalid_reason = "unreasonable_line_loading";
elseif max_p > cfg.paper_max_reasonable_line_loading_pu
    valid_flag = false;
    invalid_reason = "unreasonable_line_loading";
elseif any(~component_valid)
    valid_flag = false;
    invalid_reason = first_invalid_reason(component_reason);
elseif any(isinf(line_severity_component) | isnan(line_severity_component))
    valid_flag = false;
    invalid_reason = "inf_or_nan_severity";
end

n = numel(branch_index);
line_table = table(repmat(initial_branch, n, 1), repmat(trial_id, n, 1), repmat(stage_id, n, 1), ...
    branch_index, from_bus, to_bus, PF, PT, active_flow_mw, active_limit_mw, ...
    P_li_pu, P_li_max_pu, line_overlimit_component, line_severity_component, ...
    ones(n, 1), repmat(string(replay_source), n, 1), ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
    'branch_index', 'from_bus', 'to_bus', 'PF', 'PT', 'active_flow_mw', 'active_limit_mw', ...
    'P_li_pu', 'P_li_max_pu', 'line_overlimit_component', 'line_severity_component', ...
    'severity_valid', 'replay_source'});
end

function [bus_table, valid_flag, invalid_reason, min_v, max_v] = build_bus_voltage_rows(pf_result, cfg, initial_branch, trial_id, stage_id, replay_source)
%BUILD_BUS_VOLTAGE_ROWS 构造收敛stage的全节点电压严重度明细。
bus_id = pf_result.bus(:, 1);
voltage_pu = pf_result.bus(:, 8);
min_v = min(voltage_pu);
max_v = max(voltage_pu);
lower_limit = cfg.paper_voltage_lower_limit_pu;
upper_limit = cfg.paper_voltage_upper_limit_pu;
voltage_deviation_component = max(max(lower_limit - voltage_pu, voltage_pu - upper_limit), 0);
[voltage_severity_component, component_valid, component_reason] = safe_exponential_severity(voltage_deviation_component, cfg);

valid_flag = true;
invalid_reason = "none";
if any(voltage_pu < cfg.paper_min_reasonable_voltage_pu | voltage_pu > cfg.paper_max_reasonable_voltage_pu | isnan(voltage_pu))
    valid_flag = false;
    invalid_reason = "unreasonable_voltage";
elseif any(~component_valid)
    valid_flag = false;
    invalid_reason = first_invalid_reason(component_reason);
elseif any(isinf(voltage_severity_component) | isnan(voltage_severity_component))
    valid_flag = false;
    invalid_reason = "inf_or_nan_severity";
end

n = numel(bus_id);
bus_table = table(repmat(initial_branch, n, 1), repmat(trial_id, n, 1), repmat(stage_id, n, 1), ...
    bus_id, voltage_pu, voltage_deviation_component, voltage_severity_component, ...
    ones(n, 1), repmat(string(replay_source), n, 1), ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
    'bus_id', 'voltage_pu', 'voltage_deviation_component', 'voltage_severity_component', ...
    'severity_valid', 'replay_source'});
end

function reason = first_invalid_reason(reasons)
%FIRST_INVALID_REASON 返回第一个非none原因。
reasons = string(reasons(:));
bad = reasons(reasons ~= "none");
if isempty(bad)
    reason = "none";
else
    reason = bad(1);
end
end

function [max_p, min_v, max_v] = extract_raw_extremes(pf_result, cfg)
%EXTRACT_RAW_EXTREMES 仅用于诊断，不进入严重度计算。
max_p = NaN;
min_v = NaN;
max_v = NaN;
if isfield(pf_result, 'branch') && size(pf_result.branch, 2) >= 16
    active_limit_mw = pf_result.branch(:, 6);
    active_limit_mw(active_limit_mw <= 0 | isnan(active_limit_mw)) = cfg.default_branch_rate_mva;
    max_p = max(max(abs(pf_result.branch(:, 14)), abs(pf_result.branch(:, 16))) ./ active_limit_mw);
end
if isfield(pf_result, 'bus') && size(pf_result.bus, 2) >= 8
    min_v = min(pf_result.bus(:, 8));
    max_v = max(pf_result.bus(:, 8));
end
end

function row = build_invalid_stage_row(initial_branch, trial_id, stage_id, pf_converged, severity_valid, ...
    invalid_reason, replay_source, stage_load_shed_mw, base_load_mw, stage_cumulative_probability, max_p, min_v, max_v)
%BUILD_INVALID_STAGE_ROW 构造无效stage诊断行。
row = table(initial_branch, trial_id, stage_id, double(pf_converged), double(severity_valid), ...
    string(invalid_reason), string(replay_source), stage_load_shed_mw, base_load_mw, ...
    stage_cumulative_probability, max_p, min_v, max_v, ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', 'pf_converged', ...
    'severity_valid', 'invalid_reason', 'replay_source', 'stage_load_shed_mw', ...
    'base_load_mw', 'stage_cumulative_probability', 'max_P_li_pu_if_available', ...
    'min_voltage_pu_if_available', 'max_voltage_pu_if_available'});
end

function summary = summarize_invalid_stage_details(stage_probability_table, invalid_stage_detail_table)
%SUMMARIZE_INVALID_STAGE_DETAILS 汇总无效stage诊断。
total_stage_count = height(stage_probability_table);
invalid_stage_count = height(invalid_stage_detail_table);
valid_stage_count = total_stage_count - invalid_stage_count;
if invalid_stage_count > 0
    reasons = string(invalid_stage_detail_table.invalid_reason);
else
    reasons = strings(0, 1);
end
nonconverged_stage_count = sum(reasons == "nonconverged_power_flow");
unreasonable_line_loading_count = sum(reasons == "unreasonable_line_loading");
unreasonable_voltage_count = sum(reasons == "unreasonable_voltage");
inf_or_nan_severity_count = sum(reasons == "inf_or_nan_severity" | reasons == "exp_argument_too_large" | reasons == "nan_component");
invalid_stage_ratio = invalid_stage_count / max(total_stage_count, 1);
summary = table(total_stage_count, valid_stage_count, invalid_stage_count, ...
    nonconverged_stage_count, unreasonable_line_loading_count, unreasonable_voltage_count, ...
    inf_or_nan_severity_count, invalid_stage_ratio);
end

function source = resolve_probability_source(cfg)
mode = string(cfg.initial_fault_probability_mode);
if mode == "paper_table_4_1"
    source = "paper_table_4_1_initial_probability + candidate_transition_probability";
elseif mode == "uniform"
    source = "uniform_initial_probability + candidate_transition_probability";
else
    error('未知初始故障概率模式：%s', mode);
end
end

function value = get_numeric_vector(raw_value)
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
stage_load_shed_mw = 0;
if isfield(stage_record, 'shed') && isstruct(stage_record.shed)
    if isfield(stage_record.shed, 'load_shed_mw')
        stage_load_shed_mw = stage_record.shed.load_shed_mw;
    elseif isfield(stage_record.shed, 'total_load_shed_mw')
        stage_load_shed_mw = stage_record.shed.total_load_shed_mw;
    end
end
end

function tbl = line_flow_empty_table()
tbl = table([], [], [], [], [], [], [], [], [], [], [], [], [], [], [], [], ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', 'branch_index', ...
    'from_bus', 'to_bus', 'PF', 'PT', 'active_flow_mw', 'active_limit_mw', ...
    'P_li_pu', 'P_li_max_pu', 'line_overlimit_component', 'line_severity_component', ...
    'severity_valid', 'replay_source'});
end

function tbl = bus_voltage_empty_table()
tbl = table([], [], [], [], [], [], [], [], [], ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', 'bus_id', ...
    'voltage_pu', 'voltage_deviation_component', 'voltage_severity_component', ...
    'severity_valid', 'replay_source'});
end

function tbl = invalid_stage_empty_table()
tbl = table([], [], [], [], [], strings(0, 1), strings(0, 1), [], [], [], [], [], [], ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', 'pf_converged', ...
    'severity_valid', 'invalid_reason', 'replay_source', 'stage_load_shed_mw', ...
    'base_load_mw', 'stage_cumulative_probability', 'max_P_li_pu_if_available', ...
    'min_voltage_pu_if_available', 'max_voltage_pu_if_available'});
end

function tbl = vertcat_or_empty(rows, empty_table)
if isempty(rows)
    tbl = empty_table;
else
    tbl = vertcat(rows{:});
end
end
