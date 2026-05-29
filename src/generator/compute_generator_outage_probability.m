function [p_g_q, detail] = compute_generator_outage_probability(gen_voltage_pu, gen_frequency_hz, cfg, varargin)
%COMPUTE_GENERATOR_OUTAGE_PROBABILITY Compute diagnostic traditional generator outage probability P_G(q).
% This is a record-only diagnostic implementation of the paper formula
% structure. It does not trip generators or alter Markov sampling.
if nargin < 2 || isempty(gen_frequency_hz)
    gen_frequency_hz = get_cfg(cfg, 'system_frequency_hz', 50.0);
end

gen_voltage_pu = gen_voltage_pu(:);
if isscalar(gen_frequency_hz)
    gen_frequency_hz = repmat(gen_frequency_hz, numel(gen_voltage_pu), 1);
else
    gen_frequency_hz = gen_frequency_hz(:);
end
if numel(gen_frequency_hz) ~= numel(gen_voltage_pu)
    error('gen_voltage_pu and gen_frequency_hz must have compatible sizes.');
end

model = string(get_cfg(cfg, 'generator_outage_probability_model', 'diagnostic_voltage_frequency_piecewise'));
calibration_status = string(get_cfg(cfg, 'gen_trip_parameter_calibration_status', 'diagnostic_assumption_not_paper'));
p_g_q = nan(numel(gen_voltage_pu), 1);
detail = repmat(empty_detail(), numel(gen_voltage_pu), 1);

for k = 1:numel(gen_voltage_pu)
    v = gen_voltage_pu(k);
    f = gen_frequency_hz(k);
    thresholds_missing = has_missing_thresholds(cfg);
    if thresholds_missing
        voltage_region = "missing_voltage_threshold";
        frequency_region = "missing_frequency_threshold";
        voltage_hit = true;
        frequency_hit = true;
    else
        [voltage_region, voltage_hit] = classify_voltage_region(v, cfg);
        [frequency_region, frequency_hit] = classify_frequency_region(f, cfg);
    end
    p_v = NaN;
    p_f = NaN;
    missing_parameters = "";
    note = "";

    switch model
        case "none"
            p = 0;
            p_v = 0;
            p_f = 0;
            status = "disabled";
            threshold_hit = false;
            note = "Generator outage probability model disabled.";
        case "paper_threshold_record"
            threshold_hit = voltage_hit || frequency_hit;
            if thresholds_missing
                p = NaN;
                status = "threshold_parameters_missing";
                missing_parameters = "generator voltage/frequency thresholds";
                note = "Threshold cannot be evaluated because parameters are missing; paper formula structure is recorded but not parameterized.";
            elseif threshold_hit
                p = NaN;
                status = "threshold_hit_probability_missing";
                missing_parameters = "paper generator outage probability function";
                note = "Threshold risk region hit, but paper probability function parameters are missing.";
            else
                p = 0;
                status = "threshold_record_no_hit";
                note = "No threshold risk region hit; record-only probability is zero.";
            end
        case "diagnostic_voltage_frequency_piecewise"
            [p_v, voltage_region] = diagnostic_voltage_probability(v, cfg);
            [p_f, frequency_region] = diagnostic_frequency_probability(f, cfg);
            p = 1 - (1 - p_v) * (1 - p_f);
            p = min(max(p, 0), get_cfg(cfg, 'gen_trip_probability_cap', 1.0));
            threshold_hit = (p_v > 0) || (p_f > 0);
            status = "diagnostic_assumption_not_paper";
            note = "Piecewise voltage/frequency probability is diagnostic only; it is not confirmed paper data.";
        case "paper_formula"
            p = NaN;
            status = "missing_paper_probability_function";
            threshold_hit = voltage_hit || frequency_hit;
            missing_parameters = "P_G(q) paper probability function and thresholds";
            if thresholds_missing
                voltage_region = "missing_voltage_threshold";
                frequency_region = "missing_frequency_threshold";
                note = "Threshold cannot be evaluated because parameters are missing; no default probability is injected.";
            else
                note = "Paper formula parameters are missing; no default probability is injected.";
            end
        otherwise
            error('Unknown generator_outage_probability_model: %s', model);
    end

    p_g_q(k) = p;
    detail(k) = struct('model_name', model, ...
        'gen_voltage_pu', v, ...
        'gen_frequency_hz', f, ...
        'voltage_region', string(voltage_region), ...
        'frequency_region', string(frequency_region), ...
        'p_voltage', p_v, ...
        'p_frequency', p_f, ...
        'p_g_q', p, ...
        'threshold_hit', logical(threshold_hit), ...
        'missing_parameters', string(missing_parameters), ...
        'calibration_status', calibration_status, ...
        'status', string(status), ...
        'note', string(note));
end
end

function d = empty_detail()
d = struct('model_name', "", 'gen_voltage_pu', NaN, 'gen_frequency_hz', NaN, ...
    'voltage_region', "", 'frequency_region', "", 'p_voltage', NaN, ...
    'p_frequency', NaN, 'p_g_q', NaN, 'threshold_hit', false, ...
    'missing_parameters', "", 'calibration_status', "", 'status', "", 'note', "");
end

function [p, region] = diagnostic_voltage_probability(v, cfg)
low_forced = get_cfg(cfg, 'gen_trip_low_voltage_forced_pu', 0.70);
low_start = get_cfg(cfg, 'gen_trip_low_voltage_start_pu', 0.90);
high_start = get_cfg(cfg, 'gen_trip_high_voltage_start_pu', 1.10);
high_forced = get_cfg(cfg, 'gen_trip_high_voltage_forced_pu', 1.30);
if isnan(v)
    p = NaN; region = "missing_voltage";
elseif v <= low_forced
    p = 1; region = "forced_low_voltage";
elseif v < low_start
    p = (low_start - v) / (low_start - low_forced); region = "low_voltage_transition";
elseif v <= high_start
    p = 0; region = "normal_voltage";
elseif v < high_forced
    p = (v - high_start) / (high_forced - high_start); region = "high_voltage_transition";
else
    p = 1; region = "forced_high_voltage";
end
end

function [p, region] = diagnostic_frequency_probability(f, cfg)
low_forced = get_cfg(cfg, 'gen_trip_low_frequency_forced_hz', 48.50);
low_start = get_cfg(cfg, 'gen_trip_low_frequency_start_hz', 49.50);
high_start = get_cfg(cfg, 'gen_trip_high_frequency_start_hz', 50.50);
high_forced = get_cfg(cfg, 'gen_trip_high_frequency_forced_hz', 51.50);
if isnan(f)
    p = NaN; region = "missing_frequency";
elseif f <= low_forced
    p = 1; region = "forced_low_frequency";
elseif f < low_start
    p = (low_start - f) / (low_start - low_forced); region = "low_frequency_transition";
elseif f <= high_start
    p = 0; region = "normal_frequency";
elseif f < high_forced
    p = (f - high_start) / (high_forced - high_start); region = "high_frequency_transition";
else
    p = 1; region = "forced_high_frequency";
end
end

function [region, hit] = classify_voltage_region(v, cfg)
[~, region] = diagnostic_voltage_probability(v, cfg);
hit = ~ismember(string(region), ["normal_voltage", "missing_voltage"]);
end

function [region, hit] = classify_frequency_region(f, cfg)
[~, region] = diagnostic_frequency_probability(f, cfg);
hit = ~ismember(string(region), ["normal_frequency", "missing_frequency"]);
end

function tf = has_missing_thresholds(cfg)
names = ["gen_trip_low_voltage_forced_pu", "gen_trip_low_voltage_start_pu", ...
    "gen_trip_high_voltage_start_pu", "gen_trip_high_voltage_forced_pu", ...
    "gen_trip_low_frequency_forced_hz", "gen_trip_low_frequency_start_hz", ...
    "gen_trip_high_frequency_start_hz", "gen_trip_high_frequency_forced_hz"];
tf = false;
for i = 1:numel(names)
    if ~isfield(cfg, names(i)) || isnan(cfg.(names(i)))
        tf = true;
        return;
    end
end
end

function value = get_cfg(cfg, field_name, default_value)
if isfield(cfg, field_name)
    value = cfg.(field_name);
else
    value = default_value;
end
end
