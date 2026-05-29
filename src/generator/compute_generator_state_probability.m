function [p_ge_Ek, detail] = compute_generator_state_probability(generator_trip_table, cfg)
%COMPUTE_GENERATOR_STATE_PROBABILITY Aggregate P_G(q) into diagnostic P_ge(E_k).
mode = string(get_cfg(cfg, 'generator_state_probability_mode', 'record_only'));
calibration_status = string(get_cfg(cfg, 'gen_trip_parameter_calibration_status', 'diagnostic_assumption_not_paper'));

if isempty(generator_trip_table) || ~istable(generator_trip_table) || height(generator_trip_table) == 0
    p_ge_Ek = 1;
    detail = build_detail(0, 0, NaN, NaN, p_ge_Ek, mode, "no_traditional_generators", calibration_status);
    return;
end

if ismember('p_g_q', generator_trip_table.Properties.VariableNames)
    p = generator_trip_table.p_g_q;
else
    p = generator_trip_table.trip_probability;
end

if any(isnan(p))
    p_ge_Ek = NaN;
    status = "missing_probability";
else
    p = min(max(p, 0), 1);
    p_ge_Ek = prod(1 - p);
    p_ge_Ek = min(max(p_ge_Ek, 0), 1);
    status = "diagnostic_probability_computed";
end

detail = build_detail(height(generator_trip_table), sum(p > 0, 'omitnan'), ...
    max(p, [], 'omitnan'), mean(p, 'omitnan'), p_ge_Ek, mode, status, calibration_status);
end

function detail = build_detail(n, num_positive, max_p, mean_p, p_ge, mode, status, calibration_status)
detail = struct();
detail.num_traditional_generators = n;
detail.num_probability_positive = num_positive;
detail.max_p_g_q = max_p;
detail.mean_p_g_q = mean_p;
detail.p_ge_Ek = p_ge;
detail.mode = mode;
detail.status = status;
detail.calibration_status = calibration_status;
detail.note = "record_only mode does not sample or change traditional generator states; this probability is only a diagnostic online-state retention probability.";
end

function value = get_cfg(cfg, field_name, default_value)
if isfield(cfg, field_name)
    value = cfg.(field_name);
else
    value = default_value;
end
end
