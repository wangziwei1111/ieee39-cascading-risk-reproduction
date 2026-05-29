function chain_record = search_cascade_markov_line(base_mpc, initial_branch, cfg, scenario, renewable_info, trial_id)
%SEARCH_CASCADE_MARKOV_LINE 搜索一条线路驱动的马尔可夫连锁故障事故链。
% 输入：
%   base_mpc - 新能源基础场景下的MATPOWER算例。
%   initial_branch - 初始N-1线路故障编号。
%   cfg - 全局配置，包含马尔可夫搜索和线路概率参数。
%   scenario - 场景配置，包含原始平衡节点等信息。
%   renewable_info - 新能源接入信息，用于识别风电机组。
%   trial_id - 当前初始故障下的蒙特卡洛样本编号。
% 输出：
%   chain_record - 单条事故链记录结构体，含逐级状态和汇总后果。
% 物理含义：
%   该函数实现“线路停运概率 -> 随机抽样 -> 后续线路停运”的最小闭环。
%   当前只触发线路后续停运，不触发风机实际脱网或传统机组保护停运。

mpc_current = base_mpc;
[mpc_current, initial_applied] = apply_line_outages(mpc_current, initial_branch);
outaged_branches = initial_applied(:)';

base_load_mw = sum(base_mpc.bus(:, 3));
cumulative_load_shed_mw = 0;
stage_records = struct([]);
terminated_reason = "max_depth_reached";
final_converged = false;
unified_line_cumulative_probability = NaN;
if isfield(cfg, 'unified_state_probability_diagnostic_enable') && cfg.unified_state_probability_diagnostic_enable
    unified_line_cumulative_probability = resolve_initial_unified_line_probability(initial_branch, cfg);
end

for stage_id = 1:cfg.markov_max_depth
    [mpc_current, island_info] = normalize_case_after_contingency( ...
        mpc_current, cfg, scenario, renewable_info);
    cumulative_load_shed_mw = cumulative_load_shed_mw + island_info.disconnected_load_mw;

    [pf_result, converged_before_shedding] = run_ac_powerflow(mpc_current);
    preliminary_violations = check_violations(pf_result, cfg);
    [load_shedding_trigger, load_shedding_trigger_reason, load_shedding_trigger_detail] = ...
        should_trigger_load_shedding(pf_result, converged_before_shedding, preliminary_violations, cfg);
    shed = struct('island_load_shed_mw', cumulative_load_shed_mw, ...
        'corrective_load_shed_mw', 0, ...
        'load_shed_mw', cumulative_load_shed_mw, ...
        'total_load_shed_mw', cumulative_load_shed_mw, ...
        'load_shed_frac', cumulative_load_shed_mw / base_load_mw, ...
        'iterations', 0, ...
        'converged_after_shed', converged_before_shedding);

    if load_shedding_trigger && string(load_shedding_trigger_reason) == "diagnostic_violation_only"
        shed_detail = build_diagnostic_shed_detail(mpc_current, cfg, cumulative_load_shed_mw, shed, load_shedding_trigger_reason);
    elseif load_shedding_trigger
        [mpc_current, pf_result, shed, shed_detail] = apply_load_shedding_strategy( ...
            mpc_current, cfg, cumulative_load_shed_mw);
    else
        shed_detail = struct('mode', "none", 'status', "not_needed", ...
            'solver', "none", 'objective_load_shed_mw', 0, ...
            'total_load_shed_mw', shed.total_load_shed_mw, ...
            'corrective_load_shed_mw', 0, ...
            'island_load_shed_mw', shed.island_load_shed_mw, ...
            'converged_after_shed', shed.converged_after_shed, ...
            'opf_success', NaN, ...
            'pf_success_after_apply', shed.converged_after_shed, ...
            'num_shed_buses', 0, 'max_bus_shed_mw', 0, ...
            'message', "潮流已收敛，无需切负荷。", ...
            'bus_shed_table', table());
    end
    converged = shed.converged_after_shed;
    cumulative_load_shed_mw = shed.total_load_shed_mw;
    final_converged = converged;

    violations = check_violations(pf_result, cfg);
    if isstruct(pf_result)
        pf_result.success = logical(converged);
    end

    if isfield(cfg, 'enable_wind_voltage_trip_sampling') && cfg.enable_wind_voltage_trip_sampling && ...
            isfield(renewable_info, 'wind_buses') && ~isempty(renewable_info.wind_buses) && converged
        wind_trip_table = record_wind_trip_probability(pf_result, stage_id, initial_branch, trial_id, renewable_info, cfg);
    else
        wind_trip_table = table();
    end
    [~, wind_state_probability_detail] = compute_wind_state_probability(wind_trip_table, cfg);

    if isfield(cfg, 'generator_state_probability_enable') && cfg.generator_state_probability_enable && converged
        generator_trip_table = record_generator_outage_probability(mpc_current, pf_result, stage_id, ...
            initial_branch, trial_id, scenario, renewable_info, cfg);
    else
        generator_trip_table = table();
    end
    [~, generator_state_probability_detail] = compute_generator_state_probability(generator_trip_table, cfg);

    if converged
        candidate_table = update_line_outage_probabilities( ...
            mpc_current, pf_result, cfg, outaged_branches);
    else
        candidate_table = empty_candidate_table();
    end

    unified_state_probability_detail = [];
    unified_component_tables = struct('line_probability_table', table(), ...
        'wind_trip_table', wind_trip_table, 'generator_trip_table', generator_trip_table);
    if isfield(cfg, 'unified_state_probability_diagnostic_enable') && cfg.unified_state_probability_diagnostic_enable
        stage_context = struct();
        stage_context.mpc_current = mpc_current;
        stage_context.pf_result = pf_result;
        stage_context.scenario = scenario;
        stage_context.candidate_table = candidate_table;
        stage_context.wind_trip_table = wind_trip_table;
        stage_context.generator_trip_table = generator_trip_table;
        stage_context.stage_id = stage_id;
        stage_context.initial_branch = initial_branch;
        stage_context.trial_id = trial_id;
        stage_context.line_cumulative_probability_before_stage = unified_line_cumulative_probability;
        [unified_state_probability_detail, unified_component_tables] = ...
            record_unified_state_probability(stage_context, cfg);
        unified_line_cumulative_probability = unified_state_probability_detail.P_line_Ek;
    end

    selected = candidate_table.branch_index(candidate_table.trip_selected);
    selected = selected(:)';

    if stage_id >= cfg.markov_max_depth
        terminated_reason = "max_depth_reached";
        selected = [];
        if ~isempty(candidate_table)
            candidate_table.trip_selected(:) = false;
        end
    elseif cfg.markov_stop_if_load_loss_frac_gt > 0 && ...
            cumulative_load_shed_mw / base_load_mw > cfg.markov_stop_if_load_loss_frac_gt
        terminated_reason = "load_loss_threshold";
        selected = [];
        if ~isempty(candidate_table)
            candidate_table.trip_selected(:) = false;
        end
    elseif ~converged
        terminated_reason = "powerflow_not_converged";
        selected = [];
    elseif isempty(selected) && cfg.markov_stop_if_no_new_outage
        terminated_reason = "no_new_outage";
    end

    stage_records(stage_id).stage_id = stage_id; %#ok<AGROW>
    stage_records(stage_id).new_outaged_branches = selected;
    stage_records(stage_id).all_outaged_branches = outaged_branches;
    stage_records(stage_id).island_info = island_info;
    stage_records(stage_id).converged_before_shedding = converged_before_shedding;
    stage_records(stage_id).converged = converged;
    stage_records(stage_id).load_shedding_trigger = load_shedding_trigger;
    stage_records(stage_id).load_shedding_trigger_reason = load_shedding_trigger_reason;
    stage_records(stage_id).load_shedding_trigger_detail = load_shedding_trigger_detail;
    stage_records(stage_id).shed = shed;
    stage_records(stage_id).shed_detail = shed_detail;
    stage_records(stage_id).violations = violations;
    stage_records(stage_id).candidate_table = candidate_table;
    stage_records(stage_id).wind_trip_table = wind_trip_table;
    stage_records(stage_id).wind_state_probability_detail = wind_state_probability_detail;
    stage_records(stage_id).generator_trip_table = generator_trip_table;
    stage_records(stage_id).generator_state_probability_detail = generator_state_probability_detail;
    stage_records(stage_id).unified_state_probability_detail = unified_state_probability_detail;
    stage_records(stage_id).unified_component_tables = unified_component_tables;

    if isempty(selected)
        break;
    end

    [mpc_current, applied] = apply_line_outages(mpc_current, selected);
    outaged_branches = unique([outaged_branches, applied(:)']); %#ok<AGROW>
end

chain_depth = numel(stage_records);
max_line_loading_pu = max(arrayfun(@(s) s.violations.max_line_loading_pu, stage_records), [], 'omitnan');
max_voltage_deviation_pu = max(arrayfun(@(s) s.violations.max_voltage_deviation_pu, stage_records), [], 'omitnan');
final_shed = stage_records(end).shed;
final_result = struct('success', final_converged);
final_violations = stage_records(end).violations;
metrics = calc_basic_risk_metrics(final_result, final_violations, final_shed, base_load_mw);
basic_cri = calc_cri(metrics.SLLR, metrics.SLFOR, metrics.SNVOR, cfg.risk_weights);

chain_record = struct();
chain_record.initial_branch = initial_branch;
chain_record.trial_id = trial_id;
chain_record.stage_records = stage_records;
chain_record.outaged_branches = outaged_branches;
chain_record.total_load_shed_mw = cumulative_load_shed_mw;
chain_record.total_load_shed_frac = cumulative_load_shed_mw / base_load_mw;
chain_record.max_line_loading_pu = max_line_loading_pu;
chain_record.max_voltage_deviation_pu = max_voltage_deviation_pu;
chain_record.terminated_reason = terminated_reason;
chain_record.chain_depth = chain_depth;
chain_record.final_converged = final_converged;
chain_record.basic_LLR = metrics.SLLR;
chain_record.basic_LFOR = metrics.SLFOR;
chain_record.basic_NVOR = metrics.SNVOR;
chain_record.basic_CRI = basic_cri;
end

function p0 = resolve_initial_unified_line_probability(initial_branch, cfg)
p0 = NaN;
if isfield(cfg, 'initial_fault_probability_file') && exist(cfg.initial_fault_probability_file, 'file') == 2
    tbl = readtable(cfg.initial_fault_probability_file);
    if ismember('branch_index', tbl.Properties.VariableNames) && ...
            ismember('initial_outage_probability', tbl.Properties.VariableNames)
        row = tbl(tbl.branch_index == initial_branch, :);
        if ~isempty(row)
            p0 = row.initial_outage_probability(1);
        end
    end
end
if isnan(p0)
    p0 = 1;
end
end

function candidate_table = empty_candidate_table()
%EMPTY_CANDIDATE_TABLE 生成空的候选线路表。
% 输入：
%   无。
% 输出：
%   candidate_table - 与update_line_outage_probabilities一致的空表。
% 物理含义：
%   当潮流不收敛时，没有可信线路负载率，因此不产生下一阶段候选线路。

candidate_table = table([], [], [], [], [], strings(0,1), [], [], strings(0,1), strings(0,1), false(0,1), [], [], ...
    'VariableNames', {'branch_index', 'from_bus', 'to_bus', 'loading_pu', ...
    'outage_probability', 'prob_model', 'engineering_probability', ...
    'paper_formula_probability', 'paper_formula_status', ...
    'paper_formula_missing_parameters', 'paper_formula_used_fallback', ...
    'random_u', 'trip_selected'});
end

function shed_detail = build_diagnostic_shed_detail(mpc_current, cfg, cumulative_load_shed_mw, shed, trigger_reason)
%BUILD_DIAGNOSTIC_SHED_DETAIL 在越限诊断模式下旁路运行OLS，不改变主链路。
if isfield(cfg, 'paper_ols_enable') && cfg.paper_ols_enable
    [~, ~, ~, ols_detail] = solve_paper_ols_load_shedding(mpc_current, cfg, cumulative_load_shed_mw);
else
    ols_detail = struct('mode', "paper_ols", 'status', "diagnostic_skipped", ...
        'solver', "none", 'objective_load_shed_mw', NaN, ...
        'total_load_shed_mw', shed.total_load_shed_mw, ...
        'corrective_load_shed_mw', NaN, ...
        'island_load_shed_mw', shed.island_load_shed_mw, ...
        'converged_after_shed', shed.converged_after_shed, ...
        'opf_success', NaN, 'pf_success_after_apply', NaN, ...
        'num_shed_buses', NaN, 'max_bus_shed_mw', NaN, ...
        'message', "paper_ols_enable=false，越限诊断未运行OLS。", ...
        'bus_shed_table', table());
end

shed_detail = struct();
shed_detail.mode = "violation_only_diagnostic";
shed_detail.status = "main_chain_unchanged";
shed_detail.trigger_reason = trigger_reason;
shed_detail.paper_ols_detail = ols_detail;
shed_detail.objective_load_shed_mw = ols_detail.objective_load_shed_mw;
shed_detail.total_load_shed_mw = shed.total_load_shed_mw;
shed_detail.corrective_load_shed_mw = 0;
shed_detail.island_load_shed_mw = shed.island_load_shed_mw;
shed_detail.converged_after_shed = shed.converged_after_shed;
shed_detail.opf_success = ols_detail.opf_success;
shed_detail.pf_success_after_apply = shed.converged_after_shed;
shed_detail.num_shed_buses = ols_detail.num_shed_buses;
shed_detail.max_bus_shed_mw = ols_detail.max_bus_shed_mw;
shed_detail.message = "越限诊断模式：主链路不切负荷，仅记录OLS旁路结果。";
shed_detail.bus_shed_table = table();
end
