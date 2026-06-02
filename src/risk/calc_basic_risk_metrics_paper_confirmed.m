function [metrics, detail] = calc_basic_risk_metrics_paper_confirmed(stage_state, cfg)
%CALC_BASIC_RISK_METRICS_PAPER_CONFIRMED Paper-confirmed stage severity.
% User-confirmed formulas from paper Section 3.2.4:
%   LLR = C_c(E_k) / P_load * 100
%   LFOR = sum((exp(max(P_l-P_lmax,0))-1)/(e-1))*100
%   NVOR = sum((exp(max(0.9-U, U-1.1, 0))-1)/(e-1))*100

if nargin < 2
    cfg = struct();
end

total_load_shed_mw = get_field(stage_state, 'total_load_shed_mw', NaN);
base_load_mw = get_field(stage_state, 'base_load_mw', NaN);

LLR_stage = NaN;
LLR_status = "missing_base_load_or_load_shed";
if ~isnan(total_load_shed_mw) && ~isnan(base_load_mw) && base_load_mw > 0
    LLR_stage = total_load_shed_mw / base_load_mw * 100;
    LLR_status = "load_mw_divided_by_base_load_mw_times_100";
elseif ~isnan(total_load_shed_mw) && isfield(stage_state, 'load_shed_is_per_unit') && stage_state.load_shed_is_per_unit
    LLR_stage = total_load_shed_mw * 100;
    LLR_status = "input_already_per_unit_times_100";
end

[line_loading, line_limit, lfor_status] = resolve_line_vectors(stage_state, cfg);
if ~isempty(line_loading)
    over = max(line_loading(:) - line_limit(:), 0);
    LFOR_stage = sum((exp(over) - 1) ./ (exp(1) - 1), 'omitnan') * 100;
else
    LFOR_stage = NaN;
end

[bus_voltage, nvor_status] = resolve_voltage_vector(stage_state);
if ~isempty(bus_voltage)
    dev = max([0.9 - bus_voltage(:), bus_voltage(:) - 1.1, zeros(numel(bus_voltage),1)], [], 2);
    NVOR_stage = sum((exp(dev) - 1) ./ (exp(1) - 1), 'omitnan') * 100;
else
    NVOR_stage = NaN;
end

weights = get_cfg(cfg, 'risk_weights', [0.6, 0.2, 0.2]);
CRI_stage_reference = calc_cri(LLR_stage, LFOR_stage, NVOR_stage, weights);

metrics = struct();
metrics.LLR_stage = LLR_stage;
metrics.LFOR_stage = LFOR_stage;
metrics.NVOR_stage = NVOR_stage;
metrics.CRI_stage_reference = CRI_stage_reference;
metrics.SLLR = LLR_stage;
metrics.SLFOR = LFOR_stage;
metrics.SNVOR = NVOR_stage;
metrics.CRI = CRI_stage_reference;

detail = struct();
detail.severity_formula_mode = "paper_confirmed_exponential_sum";
detail.LLR_formula_status = "paper_confirmed_by_user";
detail.LFOR_formula_status = "paper_confirmed_by_user";
detail.NVOR_formula_status = "paper_confirmed_by_user";
detail.LLR_normalization_status = LLR_status;
detail.LFOR_normalization_status = lfor_status;
detail.NVOR_normalization_status = nvor_status;
detail.zero_violation_handling = "zero_severity_when_no_overload_or_voltage_violation";
detail.branch_count = numel(line_loading);
detail.bus_count = numel(bus_voltage);
detail.overloaded_branch_count = sum(max(line_loading(:) - line_limit(:), 0) > 0, 'omitnan');
if isempty(bus_voltage)
    detail.voltage_violation_bus_count = 0;
else
    detail.voltage_violation_bus_count = sum(max([0.9 - bus_voltage(:), bus_voltage(:) - 1.1, zeros(numel(bus_voltage),1)], [], 2) > 0, 'omitnan');
end
detail.note = "Stage severity is paper-confirmed; final CRI should be weighted after SLLR/SLFOR/SNVOR VaR.";
end

function [line_loading, line_limit, status] = resolve_line_vectors(stage_state, cfg)
line_loading = [];
line_limit = [];
status = "missing_line_vector";
if isfield(stage_state, 'branch_loading_pu_vector')
    line_loading = stage_state.branch_loading_pu_vector(:);
    if isfield(stage_state, 'branch_limit_pu_vector')
        line_limit = stage_state.branch_limit_pu_vector(:);
        status = "used_branch_loading_and_limit_vectors";
    else
        line_limit = ones(size(line_loading));
        status = "used_line_loading_pu_with_limit_1_proxy";
    end
elseif isfield(stage_state, 'line_active_power_pu_vector')
    line_loading = abs(stage_state.line_active_power_pu_vector(:));
    if isfield(stage_state, 'line_active_power_max_pu_vector')
        line_limit = stage_state.line_active_power_max_pu_vector(:);
        status = "used_active_power_pu_and_max_vectors";
    else
        line_limit = ones(size(line_loading));
        status = "used_active_power_pu_with_limit_1_proxy";
    end
elseif isfield(stage_state, 'pf_result') && isstruct(stage_state.pf_result) && isfield(stage_state.pf_result, 'branch')
    br = stage_state.pf_result.branch;
    rate_a = br(:,6);
    rate_a(rate_a <= 0 | isnan(rate_a)) = get_cfg(cfg, 'default_branch_rate_mva', 1000);
    line_loading = max(abs(br(:,14)), abs(br(:,16))) ./ rate_a;
    line_limit = ones(size(line_loading));
    status = "used_pf_result_active_line_loading_with_limit_1_proxy";
end
if ~isempty(line_loading) && isempty(line_limit)
    line_limit = ones(size(line_loading));
end
if ~isempty(line_loading) && numel(line_limit) == 1
    line_limit = repmat(line_limit, size(line_loading));
end
end

function [bus_voltage, status] = resolve_voltage_vector(stage_state)
bus_voltage = [];
status = "missing_bus_voltage_vector";
if isfield(stage_state, 'bus_voltage_pu_vector')
    bus_voltage = stage_state.bus_voltage_pu_vector(:);
    status = "used_bus_voltage_pu_vector";
elseif isfield(stage_state, 'pf_result') && isstruct(stage_state.pf_result) && isfield(stage_state.pf_result, 'bus')
    bus_voltage = stage_state.pf_result.bus(:,8);
    status = "used_pf_result_bus_voltage_vector";
end
end

function value = get_field(s, name, default_value)
if isstruct(s) && isfield(s, name)
    value = s.(name);
else
    value = default_value;
end
end

function value = get_cfg(cfg, name, default_value)
if isstruct(cfg) && isfield(cfg, name)
    value = cfg.(name);
else
    value = default_value;
end
end
