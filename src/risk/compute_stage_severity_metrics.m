function [stage_severity, detail] = compute_stage_severity_metrics(stage_context, cfg)
%COMPUTE_STAGE_SEVERITY_METRICS Compute diagnostic stage-level severity metrics.
initial_branch = get_field(stage_context, 'initial_branch', NaN);
trial_id = get_field(stage_context, 'trial_id', NaN);
stage_id = get_field(stage_context, 'stage_id', NaN);
pf_result = get_field(stage_context, 'pf_result', struct());
violations = get_field(stage_context, 'violations', struct());
cumulative_load_shed_mw = get_field(stage_context, 'cumulative_load_shed_mw', NaN);
base_load_mw = get_field(stage_context, 'base_load_mw', NaN);

severity_LLR = NaN;
severity_LFOR = NaN;
severity_NVOR = NaN;
severity_CRI = NaN;
max_line_loading_pu = NaN;
min_voltage_pu = NaN;
max_voltage_pu = NaN;
status = "missing_pf_result";
note = "missing power-flow result; severity terms are NaN";

if ~isnan(base_load_mw) && base_load_mw > 0
    severity_LLR = cumulative_load_shed_mw / base_load_mw;
end

if isstruct(pf_result) && isfield(pf_result, 'success') && logical(pf_result.success) && ...
        isfield(pf_result, 'branch') && isfield(pf_result, 'bus')
    [severity_LFOR, max_line_loading_pu] = line_overload_severity(pf_result, cfg);
    [severity_NVOR, min_voltage_pu, max_voltage_pu] = voltage_overlimit_severity(pf_result);
    severity_CRI = calc_cri(severity_LLR, severity_LFOR, severity_NVOR, cfg.risk_weights);
    status = "diagnostic_stage_severity_computed";
    note = "Stage-level diagnostic severity; not VaR and not formal paper_formula.";
elseif isstruct(violations) && isfield(violations, 'max_line_loading_pu')
    max_line_loading_pu = violations.max_line_loading_pu;
    status = "nonconverged_or_missing_pf";
    note = "Power-flow did not converge or branch/bus data are unavailable; LFOR/NVOR are NaN.";
end

stage_severity = table(initial_branch, trial_id, stage_id, severity_LLR, severity_LFOR, ...
    severity_NVOR, severity_CRI, cumulative_load_shed_mw, base_load_mw, ...
    max_line_loading_pu, min_voltage_pu, max_voltage_pu, status, note, ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', 'severity_LLR', ...
    'severity_LFOR', 'severity_NVOR', 'severity_CRI', 'load_shed_mw', ...
    'base_load_mw', 'max_line_loading_pu', 'min_voltage_pu', 'max_voltage_pu', ...
    'severity_status', 'calculation_note'});
detail = table2struct(stage_severity);
end

function [severity, max_loading] = line_overload_severity(pf_result, cfg)
rate_a = pf_result.branch(:, 6);
rate_a(rate_a <= 0) = get_cfg(cfg, 'default_branch_rate_mva', 1000.0);
pf = pf_result.branch(:, 14);
qf = pf_result.branch(:, 15);
pt = pf_result.branch(:, 16);
qt = pf_result.branch(:, 17);
sf = sqrt(pf.^2 + qf.^2);
st = sqrt(pt.^2 + qt.^2);
loading = max(sf, st) ./ rate_a;
if size(pf_result.branch, 2) >= 11
    active_branch = pf_result.branch(:, 11) > 0;
    loading(~active_branch) = 0;
end
max_loading = max(loading, [], 'omitnan');
over = max(loading - 1, 0);
severity = sum(exp(over) - 1, 'omitnan') / (exp(1) - 1);
end

function [severity, min_v, max_v] = voltage_overlimit_severity(pf_result)
vm = pf_result.bus(:, 8);
min_v = min(vm, [], 'omitnan');
max_v = max(vm, [], 'omitnan');
dev = max([0.9 - vm, vm - 1.1, zeros(size(vm))], [], 2);
severity = sum(exp(dev) - 1, 'omitnan') / (exp(1) - 1);
end

function value = get_field(s, name, default_value)
if isstruct(s) && isfield(s, name)
    value = s.(name);
else
    value = default_value;
end
end

function value = get_cfg(cfg, name, default_value)
if isfield(cfg, name)
    value = cfg.(name);
else
    value = default_value;
end
end
