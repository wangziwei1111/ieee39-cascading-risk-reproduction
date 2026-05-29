function [p_wt_Ek, detail] = compute_wind_state_probability(wind_trip_table, cfg)
%COMPUTE_WIND_STATE_PROBABILITY Aggregate per-unit P_WT(h) into P_wt(E_k).
% In record-only mode no wind unit is actually tripped. Therefore all wind
% units are treated as currently online and the diagnostic probability is
% prod_h(1 - P_WT(h)).
mode = string(get_cfg(cfg, 'wind_trip_state_probability_mode', 'record_only'));
calibration_status = string(get_cfg(cfg, 'wind_trip_parameter_calibration_status', 'diagnostic_assumption_not_paper'));

if isempty(wind_trip_table) || ~istable(wind_trip_table) || height(wind_trip_table) == 0
    p_wt_Ek = 1;
    detail = build_detail(0, 0, NaN, NaN, p_wt_Ek, mode, "no_wind_units", ...
        "No wind-unit probability rows were available.", calibration_status);
    return;
end

if ismember('p_wt_h', wind_trip_table.Properties.VariableNames)
    p = wind_trip_table.p_wt_h;
else
    p = wind_trip_table.trip_probability;
end
p = double(p(:));

num_positive = sum(p > 0, 'omitnan');
max_p = max(p, [], 'omitnan');
mean_p = mean(p, 'omitnan');
if any(isnan(p))
    p_wt_Ek = NaN;
    status = "missing_probability";
    note = "At least one P_WT(h) is NaN; paper probability function or parameters are missing.";
else
    p = min(max(p, 0), 1);
    p_wt_Ek = prod(1 - p);
    status = "diagnostic_probability_only";
    note = "Record-only mode assumes all wind units remain online; P_wt(E_k)=prod(1-P_WT(h)) is a diagnostic online-state probability.";
end

detail = build_detail(height(wind_trip_table), num_positive, max_p, mean_p, ...
    p_wt_Ek, mode, status, note, calibration_status);
end

function detail = build_detail(num_units, num_positive, max_p, mean_p, p_stage, mode, status, note, calibration_status)
detail = struct();
detail.num_wind_units = num_units;
detail.num_probability_positive = num_positive;
detail.max_p_wt_h = max_p;
detail.mean_p_wt_h = mean_p;
detail.p_wt_Ek = p_stage;
detail.mode = mode;
detail.status = status;
detail.note = note;
detail.calibration_status = calibration_status;
end

function value = get_cfg(cfg, field_name, default_value)
if isfield(cfg, field_name)
    value = cfg.(field_name);
else
    value = default_value;
end
end
