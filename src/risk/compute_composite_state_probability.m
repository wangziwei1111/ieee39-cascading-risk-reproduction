function [p_total, detail] = compute_composite_state_probability(line_prob_detail, wind_state_detail, generator_state_detail, cfg)
%COMPUTE_COMPOSITE_STATE_PROBABILITY Offline diagnostic P_line * P_wt * P_ge.
% This function does not modify formal paper_formula outputs.
missing_policy = string(get_cfg(cfg, 'composite_probability_missing_policy', 'component_nan'));

[p_line, line_status] = extract_component(line_prob_detail, ["P_line_Ek", "stage_cumulative_probability", "p_line_Ek"], "line");
[p_wt, wind_status] = extract_component(wind_state_detail, ["P_wt_Ek", "p_wt_Ek"], "wind");
[p_ge, generator_status] = extract_component(generator_state_detail, ["P_ge_Ek", "p_ge_Ek"], "generator");

values = [p_line, p_wt, p_ge];
names = ["line", "wind", "generator"];
missing = isnan(values);
missing_components = strjoin(names(missing), ",");

switch missing_policy
    case "component_nan"
        if any(missing)
            p_total = NaN;
            composite_status = "missing_component";
        else
            p_total = prod(values);
            composite_status = "computed";
        end
    case "ignore_missing_component_with_warning"
        values(missing) = 1;
        p_total = prod(values);
        if any(missing)
            composite_status = "computed_with_missing_component_as_one_warning";
        else
            composite_status = "computed";
        end
    case "line_only_baseline"
        p_total = p_line;
        composite_status = "line_only_baseline";
    otherwise
        error('Unknown composite_probability_missing_policy: %s', missing_policy);
end

if ~isnan(p_total)
    p_total = min(max(p_total, 0), 1);
end
calibration_status = resolve_calibration_status(wind_state_detail, generator_state_detail);
detail = struct();
detail.P_line_Ek = p_line;
detail.P_wt_Ek = p_wt;
detail.P_ge_Ek = p_ge;
detail.P_total_Ek = p_total;
detail.line_status = line_status;
detail.wind_status = wind_status;
detail.generator_status = generator_status;
detail.missing_components = string(missing_components);
detail.missing_policy = missing_policy;
detail.composite_status = string(composite_status);
detail.calibration_status = calibration_status;
detail.note = "Offline diagnostic only; P_wt/P_ge are not formal paper results and no formal paper_formula output is replaced.";
end

function [value, status] = extract_component(detail, names, default_status)
value = NaN;
status = "missing_" + default_status;
if istable(detail) && height(detail) >= 1
    for i = 1:numel(names)
        if ismember(names(i), detail.Properties.VariableNames)
            value = detail.(names(i))(1);
            status = "ok";
            return;
        end
    end
elseif isstruct(detail)
    for i = 1:numel(names)
        if isfield(detail, names(i))
            value = detail.(names(i));
            status = "ok";
            return;
        end
    end
    if isfield(detail, 'status')
        status = string(detail.status);
    end
end
end

function calibration_status = resolve_calibration_status(wind_state_detail, generator_state_detail)
calibration_status = "diagnostic_assumption_not_paper";
if has_status(wind_state_detail, "missing") || has_status(generator_state_detail, "missing")
    calibration_status = "diagnostic_or_missing_not_paper";
end
end

function tf = has_status(detail, pattern)
tf = false;
if isstruct(detail) && isfield(detail, 'status')
    tf = contains(string(detail.status), pattern);
elseif istable(detail) && ismember('status', detail.Properties.VariableNames) && height(detail) >= 1
    tf = contains(string(detail.status(1)), pattern);
end
end

function value = get_cfg(cfg, field_name, default_value)
if isfield(cfg, field_name)
    value = cfg.(field_name);
else
    value = default_value;
end
end
