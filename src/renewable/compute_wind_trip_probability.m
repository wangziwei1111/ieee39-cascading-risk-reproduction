function [p_wt_h, detail] = compute_wind_trip_probability(wind_voltage_pu, wind_frequency_hz, cfg, varargin)
%COMPUTE_WIND_TRIP_PROBABILITY Compute diagnostic wind-unit trip probability P_WT(h).
% This function is a record-only probability interface. It never samples,
% trips a wind unit, changes gen status, or modifies Markov line sampling.
if nargin < 2 || isempty(wind_frequency_hz)
    wind_frequency_hz = NaN(size(wind_voltage_pu));
end
if isscalar(wind_frequency_hz) && ~isscalar(wind_voltage_pu)
    wind_frequency_hz = repmat(wind_frequency_hz, size(wind_voltage_pu));
end

model = string(get_cfg(cfg, 'wind_trip_probability_model', 'diagnostic_voltage_piecewise'));
calibration_status = string(get_cfg(cfg, 'wind_trip_parameter_calibration_status', 'diagnostic_assumption_not_paper'));
p_wt_h = nan(size(wind_voltage_pu));
detail = repmat(empty_detail(model, calibration_status), size(wind_voltage_pu));

for k = 1:numel(wind_voltage_pu)
    v = wind_voltage_pu(k);
    f = wind_frequency_hz(k);
    [voltage_region, voltage_threshold_hit, voltage_missing] = classify_voltage(v, cfg);
    [frequency_region, frequency_threshold_hit, frequency_missing] = classify_frequency(f, cfg);

    missing = strings(0, 1);
    if voltage_missing
        missing(end + 1, 1) = "wind_voltage_pu"; %#ok<AGROW>
    end
    if frequency_missing
        missing(end + 1, 1) = "wind_frequency_hz"; %#ok<AGROW>
    end

    threshold_hit = voltage_threshold_hit || frequency_threshold_hit;
    note = "";
    status = "";
    p = NaN;
    switch model
        case "none"
            p = 0;
            status = "disabled";
            note = "Wind trip probability model disabled.";
        case {"diagnostic_voltage_piecewise", "voltage_piecewise_diagnostic"}
            if voltage_missing
                p = NaN;
                status = "missing_voltage";
                note = "Diagnostic voltage model needs wind voltage.";
            else
                p = diagnostic_piecewise_voltage_probability(v, cfg);
                status = "diagnostic_assumption_not_paper";
                note = "Diagnostic linear voltage probability; not a calibrated thesis P_WT(h).";
            end
        case "paper_threshold_record"
            if threshold_hit
                p = NaN;
                status = "threshold_hit_probability_missing";
                note = "Paper threshold hit, but full probability function is missing.";
                if ~any(missing == "paper_probability_function")
                    missing(end + 1, 1) = "paper_probability_function"; %#ok<AGROW>
                end
            else
                p = 0;
                status = "threshold_not_hit";
                note = "No LVRT/HVRT/FRT threshold hit; record-only probability is 0.";
            end
        case "paper_formula"
            p = NaN;
            status = "missing_paper_probability_function";
            note = "P_WT(h) paper formula or parameters are not yet available.";
            missing(end + 1, 1) = "paper_probability_function"; %#ok<AGROW>
        otherwise
            error('Unknown wind_trip_probability_model: %s', model);
    end
    if ~isnan(p)
        p = min(max(p, 0), get_cfg(cfg, 'wind_trip_probability_cap', 1.0));
    end

    detail(k).model_name = model;
    detail(k).wind_voltage_pu = v;
    detail(k).wind_frequency_hz = f;
    detail(k).voltage_region = voltage_region;
    detail(k).frequency_region = frequency_region;
    detail(k).p_wt_h = p;
    detail(k).threshold_hit = threshold_hit;
    detail(k).missing_parameters = strjoin(missing, ';');
    detail(k).calibration_status = calibration_status;
    detail(k).status = status;
    detail(k).note = note;
    p_wt_h(k) = p;
end
end

function detail = empty_detail(model, calibration_status)
detail = struct('model_name', model, 'wind_voltage_pu', NaN, ...
    'wind_frequency_hz', NaN, 'voltage_region', "unknown", ...
    'frequency_region', "unknown", 'p_wt_h', NaN, ...
    'threshold_hit', false, 'missing_parameters', "", ...
    'calibration_status', calibration_status, 'status', "unknown", 'note', "");
end

function p = diagnostic_piecewise_voltage_probability(v, cfg)
low_forced = get_cfg(cfg, 'wind_trip_low_voltage_forced_pu', get_cfg(cfg, 'wind_trip_low_voltage_trip_pu', 0.20));
low_start = get_cfg(cfg, 'wind_trip_low_voltage_start_pu', 0.90);
high_start = get_cfg(cfg, 'wind_trip_high_voltage_start_pu', 1.10);
high_forced = get_cfg(cfg, 'wind_trip_high_voltage_forced_pu', get_cfg(cfg, 'wind_trip_high_voltage_trip_pu', 1.30));
if v <= low_forced
    p = 1;
elseif v < low_start
    p = (low_start - v) / max(low_start - low_forced, eps);
elseif v <= high_start
    p = 0;
elseif v < high_forced
    p = (v - high_start) / max(high_forced - high_start, eps);
else
    p = 1;
end
end

function [region, threshold_hit, missing] = classify_voltage(v, cfg)
missing = isnan(v);
threshold_hit = false;
if missing
    region = "missing_voltage";
    return;
end
low_forced = get_cfg(cfg, 'wind_trip_low_voltage_forced_pu', get_cfg(cfg, 'wind_trip_low_voltage_trip_pu', 0.20));
low_start = get_cfg(cfg, 'wind_trip_low_voltage_start_pu', 0.90);
high_start = get_cfg(cfg, 'wind_trip_high_voltage_start_pu', 1.10);
high_forced = get_cfg(cfg, 'wind_trip_high_voltage_forced_pu', get_cfg(cfg, 'wind_trip_high_voltage_trip_pu', 1.30));
if any(isnan([low_forced, low_start, high_start, high_forced]))
    region = "missing_voltage_threshold";
    threshold_hit = true;
elseif v <= low_forced
    region = "low_voltage_forced_trip";
    threshold_hit = true;
elseif v < low_start
    region = "low_voltage_ride_through_risk";
    threshold_hit = true;
elseif v <= high_start
    region = "normal";
elseif v < high_forced
    region = "high_voltage_ride_through_risk";
    threshold_hit = true;
else
    region = "high_voltage_forced_trip";
    threshold_hit = true;
end
end

function [region, threshold_hit, missing] = classify_frequency(f, cfg)
missing = isnan(f);
threshold_hit = false;
if missing
    region = "missing_frequency";
    return;
end
rule_file = get_cfg(cfg, 'wind_frequency_rule_file', '');
if strlength(string(rule_file)) > 0 && exist(char(rule_file), 'file') ~= 2
    project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    candidate = fullfile(project_root, char(rule_file));
    if exist(candidate, 'file') == 2
        rule_file = candidate;
    end
end
if strlength(string(rule_file)) > 0 && exist(char(rule_file), 'file') == 2
    rules = readtable(rule_file, 'TextType', 'string');
    for r = 1:height(rules)
        fmin = rules.f_min_hz(r);
        fmax = rules.f_max_hz(r);
        lower_ok = isnan(fmin) || f >= fmin;
        upper_ok = isnan(fmax) || f < fmax;
        if lower_ok && upper_ok
            region = string(rules.frequency_region(r));
            threshold_hit = region ~= "continuous_operation";
            return;
        end
    end
end
if f < 48.5 || f >= 50.5
    threshold_hit = true;
    region = "frequency_ride_through_risk";
else
    region = "continuous_operation";
end
end

function value = get_cfg(cfg, field_name, default_value)
if isfield(cfg, field_name)
    value = cfg.(field_name);
else
    value = default_value;
end
end
