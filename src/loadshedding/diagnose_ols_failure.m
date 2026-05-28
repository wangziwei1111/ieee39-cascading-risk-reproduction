function failure_info = diagnose_ols_failure(mpc_before_ols, pf_before_ols, ols_detail, trigger_detail, cfg)
%DIAGNOSE_OLS_FAILURE Classify OLS failure causes without changing results.
% Inputs may be partial. Missing physical data are reported as NaN/unknown.
arguments
    mpc_before_ols = []
    pf_before_ols = []
    ols_detail struct = struct()
    trigger_detail struct = struct()
    cfg struct = struct()
end

failure_info = struct();
failure_info.failure_type = "none";
failure_info.likely_cause = "OLS solved successfully.";
failure_info.recommended_fix = "No OLS fix needed for this stage.";
failure_info.min_voltage_before = get_field(trigger_detail, 'min_voltage_pu', NaN);
failure_info.max_voltage_before = get_field(trigger_detail, 'max_voltage_pu', NaN);
failure_info.max_line_loading_before = get_field(trigger_detail, 'max_line_loading_pu', NaN);
failure_info.num_zero_rateA_lines = NaN;
failure_info.num_binding_generators = get_field(ols_detail, 'num_binding_generators', NaN);
failure_info.has_slack_online = get_field(ols_detail, 'has_slack_online', NaN);
failure_info.message = string(get_field(ols_detail, 'message', ""));

if isstruct(mpc_before_ols) && isfield(mpc_before_ols, 'branch')
    failure_info.num_zero_rateA_lines = sum(mpc_before_ols.branch(:, 6) <= 0);
end
if isstruct(mpc_before_ols) && isfield(mpc_before_ols, 'bus') && isfield(mpc_before_ols, 'gen')
    failure_info.has_slack_online = has_online_slack(mpc_before_ols);
end
if isstruct(pf_before_ols) && isfield(pf_before_ols, 'bus') && ~isempty(pf_before_ols.bus)
    vm = pf_before_ols.bus(:, 8);
    failure_info.min_voltage_before = min(vm);
    failure_info.max_voltage_before = max(vm);
end

status = lower(string(get_field(ols_detail, 'status', "")));
opf_success = logical_value(get_field(ols_detail, 'opf_success', NaN));
pf_success_after = logical_value(get_field(ols_detail, 'pf_success_after_apply', NaN));
message = lower(failure_info.message);

if status == "success"
    return;
end

if ~isnan(failure_info.has_slack_online) && ~failure_info.has_slack_online
    set_result("island_or_slack_issue", ...
        "No online slack generator is available in the retained island.", ...
        "Check island selection and slack reassignment before OLS.");
elseif contains(message, "infeasible")
    set_result("opf_infeasible", ...
        "MATPOWER OPF reports infeasibility or an infeasibility-like failure.", ...
        "Inspect voltage, branch, generator, and load-shed bounds for feasibility.");
elseif ~opf_success || contains(message, "opf") && (contains(message, "not converge") || contains(message, "未收敛"))
    set_result("opf_nonconverged", ...
        "The OLS OPF did not converge.", ...
        "Inspect OPF algorithm, scaling, binding constraints, and island/slack status.");
elseif opf_success && ~pf_success_after
    set_result("pf_after_apply_nonconverged", ...
        "OPF solved, but the post-OLS AC power flow did not converge.", ...
        "Check whether OPF dispatchable-shed result is compatible with the follow-up AC PF validation.");
elseif failure_info.num_zero_rateA_lines > 0
    set_result("rateA_zero_or_too_tight", ...
        "One or more branch RATE_A values are zero or unavailable.", ...
        "Confirm thesis line limits and default RATE_A replacement before formal OLS runs.");
elseif is_voltage_extreme(failure_info, cfg)
    set_result("voltage_constraint_too_tight", ...
        "Pre-OLS voltage is far outside the configured voltage limits.", ...
        "Run a diagnostic-only sensitivity with relaxed voltage limits.");
elseif ~isnan(failure_info.num_binding_generators) && failure_info.num_binding_generators > 0
    set_result("generator_limit_binding", ...
        "One or more generators are at P/Q limits in the OPF result.", ...
        "Inspect generator P/Q limits and thesis generator parameter alignment.");
else
    set_result("unknown", ...
        "The available diagnostics do not uniquely identify the OLS failure.", ...
        "Review OPF raw output and reconstruct the stage for detailed debugging.");
end

    function set_result(failure_type, likely_cause, recommended_fix)
        failure_info.failure_type = string(failure_type);
        failure_info.likely_cause = string(likely_cause);
        failure_info.recommended_fix = string(recommended_fix);
    end
end

function tf = is_voltage_extreme(info, cfg)
lo = get_cfg(cfg, 'paper_ols_relaxed_voltage_min_pu', 0.85);
hi = get_cfg(cfg, 'paper_ols_relaxed_voltage_max_pu', 1.15);
tf = (~isnan(info.min_voltage_before) && info.min_voltage_before < lo) || ...
    (~isnan(info.max_voltage_before) && info.max_voltage_before > hi);
end

function value = get_cfg(cfg, field_name, default_value)
if isstruct(cfg) && isfield(cfg, field_name)
    value = cfg.(field_name);
else
    value = default_value;
end
end

function value = get_field(s, field_name, default_value)
if isstruct(s) && isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end

function value = logical_value(x)
if islogical(x)
    value = x;
elseif isnumeric(x) && isscalar(x) && ~isnan(x)
    value = logical(x);
elseif isstring(x) || ischar(x)
    value = any(strcmpi(string(x), ["true", "1", "success"]));
else
    value = false;
end
end

function tf = has_online_slack(mpc)
slack_buses = mpc.bus(mpc.bus(:, 2) == 3, 1);
if isempty(slack_buses)
    tf = false;
    return;
end
online_gen_buses = mpc.gen(mpc.gen(:, 8) > 0, 1);
tf = any(ismember(slack_buses, online_gen_buses));
end
