function ols_stage_details = flatten_ols_records(chain_records)
%FLATTEN_OLS_RECORDS 展开 Markov 事故链中的 OLS/切负荷诊断记录。
% 输入：
%   chain_records - search_cascade_markov_line 输出的事故链结构体数组。
% 输出：
%   ols_stage_details - 每条事故链每一级一行的切负荷诊断表。
% 物理含义：
%   记录切负荷触发原因、切负荷前越限状态和 OLS 求解结果，用于区分非收敛
%   触发与线路/电压越限触发。

rows = {};
for i = 1:numel(chain_records)
    c = chain_records(i);
    for s = 1:numel(c.stage_records)
        st = c.stage_records(s);
        detail = extract_detail(st);
        trigger_detail = extract_trigger_detail(st);
        rows{end + 1, 1} = table( ... %#ok<AGROW>
            c.initial_branch, c.trial_id, st.stage_id, ...
            logical_value(get_struct_field(st, 'load_shedding_trigger', false)), ...
            string(get_struct_field(st, 'load_shedding_trigger_reason', "none")), ...
            trigger_detail.max_line_loading_pu, trigger_detail.min_voltage_pu, ...
            trigger_detail.max_voltage_pu, string(trigger_detail.trigger_mode), ...
            string(detail.mode), string(detail.status), ...
            detail.objective_load_shed_mw, detail.total_load_shed_mw, ...
            detail.corrective_load_shed_mw, detail.island_load_shed_mw, ...
            logical_value(detail.converged_after_shed), logical_value(detail.opf_success), ...
            logical_value(detail.pf_success_after_apply), detail.num_shed_buses, ...
            detail.max_bus_shed_mw, string(detail.paper_ols_formulation), ...
            string(detail.shed_gen_q_mode), detail.shed_gen_qg_sum, ...
            detail.max_abs_shed_gen_qg, detail.shed_q_applied_sum, ...
            detail.q_mismatch_between_opf_and_applied, string(detail.q_mismatch_warning), ...
            detail.served_load_mw, detail.shed_load_mw, detail.max_positive_q_injection, ...
            logical_value(detail.two_stage_enable), string(detail.two_stage_mode), ...
            string(detail.two_stage_status), logical_value(detail.dc_lp_success), ...
            detail.dc_preshed_load_mw, detail.ac_polish_load_shed_mw, ...
            detail.total_two_stage_load_shed_mw, ...
            detail.max_line_loading_after_apply, detail.min_voltage_after_apply, ...
            detail.max_voltage_after_apply, string(detail.message), ...
            'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
            'load_shedding_trigger', 'load_shedding_trigger_reason', ...
            'max_line_loading_pu_before_shed', 'min_voltage_pu_before_shed', ...
            'max_voltage_pu_before_shed', 'trigger_mode', ...
            'load_shedding_mode', 'ols_status', ...
            'objective_load_shed_mw', 'total_load_shed_mw', ...
            'corrective_load_shed_mw', 'island_load_shed_mw', ...
            'converged_after_shed', 'opf_success', 'pf_success_after_apply', ...
            'num_shed_buses', 'max_bus_shed_mw', 'paper_ols_formulation', ...
            'shed_gen_q_mode', 'shed_gen_qg_sum', 'max_abs_shed_gen_qg', ...
            'shed_q_applied_sum', 'q_mismatch_between_opf_and_applied', ...
            'q_mismatch_warning', 'served_load_mw', 'shed_load_mw', ...
            'max_positive_q_injection', 'two_stage_enable', 'two_stage_mode', ...
            'two_stage_status', 'dc_lp_success', 'dc_preshed_load_mw', ...
            'ac_polish_load_shed_mw', 'total_two_stage_load_shed_mw', ...
            'max_line_loading_after', 'min_voltage_after', ...
            'max_voltage_after', 'message'});
    end
end

if isempty(rows)
    ols_stage_details = table();
else
    ols_stage_details = vertcat(rows{:});
end
end

function trigger_detail = extract_trigger_detail(stage_record)
raw = get_struct_field(stage_record, 'load_shedding_trigger_detail', struct());
trigger_detail = struct();
trigger_detail.max_line_loading_pu = get_struct_field(raw, 'max_line_loading_pu', NaN);
trigger_detail.min_voltage_pu = get_struct_field(raw, 'min_voltage_pu', NaN);
trigger_detail.max_voltage_pu = get_struct_field(raw, 'max_voltage_pu', NaN);
trigger_detail.trigger_mode = get_struct_field(raw, 'trigger_mode', "unknown");
end

function detail = extract_detail(stage_record)
if ~isfield(stage_record, 'shed_detail') || isempty(stage_record.shed_detail)
    detail = empty_detail("missing", "missing_shed_detail", "stage中没有shed_detail。");
    return;
end

raw = stage_record.shed_detail;
if isfield(raw, 'paper_ols_detail')
    detail = raw.paper_ols_detail;
    detail.mode = string(raw.mode);
else
    detail = raw;
end

detail = ensure_field(detail, 'mode', "unknown");
detail = ensure_field(detail, 'status', "unknown");
detail = ensure_field(detail, 'objective_load_shed_mw', NaN);
detail = ensure_field(detail, 'total_load_shed_mw', NaN);
detail = ensure_field(detail, 'corrective_load_shed_mw', NaN);
detail = ensure_field(detail, 'island_load_shed_mw', NaN);
detail = ensure_field(detail, 'converged_after_shed', false);
detail = ensure_field(detail, 'opf_success', NaN);
detail = ensure_field(detail, 'pf_success_after_apply', NaN);
detail = ensure_field(detail, 'num_shed_buses', NaN);
detail = ensure_field(detail, 'max_bus_shed_mw', NaN);
detail = ensure_field(detail, 'paper_ols_formulation', "unknown");
detail = ensure_field(detail, 'shed_gen_q_mode', "unknown");
detail = ensure_field(detail, 'shed_gen_qg_sum', NaN);
detail = ensure_field(detail, 'max_abs_shed_gen_qg', NaN);
detail = ensure_field(detail, 'shed_q_applied_sum', NaN);
detail = ensure_field(detail, 'q_mismatch_between_opf_and_applied', NaN);
detail = ensure_field(detail, 'q_mismatch_warning', "");
detail = ensure_field(detail, 'served_load_mw', NaN);
detail = ensure_field(detail, 'shed_load_mw', NaN);
detail = ensure_field(detail, 'max_positive_q_injection', NaN);
detail = ensure_field(detail, 'two_stage_enable', false);
detail = ensure_field(detail, 'two_stage_mode', "none");
detail = ensure_field(detail, 'two_stage_status', "not_applicable");
detail = ensure_field(detail, 'dc_lp_success', false);
detail = ensure_field(detail, 'dc_preshed_load_mw', NaN);
detail = ensure_field(detail, 'ac_polish_load_shed_mw', NaN);
detail = ensure_field(detail, 'total_two_stage_load_shed_mw', NaN);
detail = ensure_field(detail, 'max_line_loading_after_apply', NaN);
detail = ensure_field(detail, 'min_voltage_after_apply', NaN);
detail = ensure_field(detail, 'max_voltage_after_apply', NaN);
detail = ensure_field(detail, 'message', "");
end

function detail = empty_detail(mode, status, message)
detail = struct('mode', string(mode), 'status', string(status), ...
    'objective_load_shed_mw', NaN, 'total_load_shed_mw', NaN, ...
    'corrective_load_shed_mw', NaN, 'island_load_shed_mw', NaN, ...
    'converged_after_shed', false, 'opf_success', NaN, ...
    'pf_success_after_apply', NaN, 'num_shed_buses', NaN, ...
    'max_bus_shed_mw', NaN, 'message', string(message));
end

function s = ensure_field(s, name, default_value)
if ~isfield(s, name)
    s.(name) = default_value;
end
end

function value = get_struct_field(s, name, default_value)
if isstruct(s) && isfield(s, name)
    value = s.(name);
else
    value = default_value;
end
end

function value = logical_value(x)
if islogical(x)
    value = x;
elseif isnumeric(x) && isscalar(x) && ~isnan(x)
    value = logical(x);
else
    value = false;
end
end
