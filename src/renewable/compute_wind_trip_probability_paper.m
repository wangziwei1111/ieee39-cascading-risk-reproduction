function [P_wt, detail] = compute_wind_trip_probability_paper(U_pu, f_hz, cfg)
%COMPUTE_WIND_TRIP_PROBABILITY_PAPER Record-only P_WT diagnostic formula.
% The voltage/frequency thresholds follow the paper structure. The interval
% probability function is diagnostic unless the paper gives an explicit curve.

if nargin < 2 || isempty(f_hz)
    f_hz = NaN(size(U_pu));
end
if isscalar(f_hz) && ~isscalar(U_pu)
    f_hz = repmat(f_hz, size(U_pu));
end

P_wt = nan(size(U_pu));
detail = repmat(empty_detail(), size(U_pu));
mode = string(get_cfg(cfg, 'wind_trip_interval_probability_mode', 'linear'));
cap = get_cfg(cfg, 'wind_trip_probability_cap', 1.0);

for k = 1:numel(U_pu)
    U = U_pu(k);
    f = f_hz(k);
    [P_U_low, vlow_region, vlow_status] = low_voltage_probability(U, cfg, mode);
    [P_U_high, vhigh_region, vhigh_status] = high_voltage_probability(U, cfg, mode);
    [P_f_low, flow_region, flow_status] = low_frequency_probability(f, cfg, mode);
    [P_f_high, fhigh_region, fhigh_status] = high_frequency_probability(f, cfg, mode);

    parts = [P_U_low, P_U_high, P_f_low, P_f_high];
    if any(isnan(parts))
        p = NaN;
        source_status = "unavailable";
        note = "Missing voltage/frequency input or threshold; P_WT was not fabricated.";
    else
        p = 1 - prod(1 - parts);
        p = min(max(p, 0), cap);
        if mode == "linear"
            source_status = "original_paper_thresholds_with_diagnostic_interval_function";
            note = "Paper thresholds with diagnostic linear interval probability; not an original paper interval function.";
        else
            source_status = "unavailable";
            note = "Unsupported interval probability mode.";
        end
    end

    detail(k).U_pu = U;
    detail(k).f_hz = f;
    detail(k).P_U_low = P_U_low;
    detail(k).P_U_high = P_U_high;
    detail(k).P_f_low = P_f_low;
    detail(k).P_f_high = P_f_high;
    detail(k).P_wt = p;
    detail(k).voltage_trip_region = join_non_normal([vlow_region, vhigh_region], "normal_voltage");
    detail(k).frequency_trip_region = join_non_normal([flow_region, fhigh_region], "normal_frequency");
    detail(k).interval_probability_mode = mode;
    detail(k).source_status = source_status;
    detail(k).note = note + " component_status=" + strjoin([vlow_status, vhigh_status, flow_status, fhigh_status], ';');
    P_wt(k) = p;
end
end

function [p, region, status] = low_voltage_probability(U, cfg, mode)
forced = get_cfg(cfg, 'wind_trip_low_voltage_forced_pu', 0.20);
start = get_cfg(cfg, 'wind_trip_low_voltage_start_pu', 0.90);
if isnan(U)
    p = NaN; region = "missing_voltage"; status = "missing_voltage";
elseif any(isnan([forced, start]))
    p = NaN; region = "missing_low_voltage_threshold"; status = "missing_threshold";
elseif U < forced || abs(U-forced) < eps
    p = 1; region = "forced_low_voltage"; status = "valid";
elseif U < start
    p = interval_linear((start - U) / max(start - forced, eps), mode);
    region = "low_voltage_interval"; status = "diagnostic_interval";
else
    p = 0; region = "normal_low_voltage"; status = "valid";
end
end

function [p, region, status] = high_voltage_probability(U, cfg, mode)
start = get_cfg(cfg, 'wind_trip_high_voltage_start_pu', 1.10);
forced = get_cfg(cfg, 'wind_trip_high_voltage_forced_pu', 1.30);
if isnan(U)
    p = NaN; region = "missing_voltage"; status = "missing_voltage";
elseif any(isnan([start, forced]))
    p = NaN; region = "missing_high_voltage_threshold"; status = "missing_threshold";
elseif U > forced || abs(U-forced) < eps
    p = 1; region = "forced_high_voltage"; status = "valid";
elseif U > start
    p = interval_linear((U - start) / max(forced - start, eps), mode);
    region = "high_voltage_interval"; status = "diagnostic_interval";
else
    p = 0; region = "normal_high_voltage"; status = "valid";
end
end

function [p, region, status] = low_frequency_probability(f, cfg, mode)
forced = get_cfg(cfg, 'wind_trip_low_frequency_forced_hz', 46.5);
start = get_cfg(cfg, 'wind_trip_low_frequency_start_hz', 48.5);
if isnan(f)
    p = NaN; region = "missing_frequency"; status = "missing_frequency";
elseif any(isnan([forced, start]))
    p = NaN; region = "missing_low_frequency_threshold"; status = "missing_threshold";
elseif f < forced || abs(f-forced) < eps
    p = 1; region = "forced_low_frequency"; status = "valid";
elseif f < start
    p = interval_linear((start - f) / max(start - forced, eps), mode);
    region = "low_frequency_interval"; status = "diagnostic_interval";
else
    p = 0; region = "normal_low_frequency"; status = "valid";
end
end

function [p, region, status] = high_frequency_probability(f, cfg, mode)
start = get_cfg(cfg, 'wind_trip_high_frequency_start_hz', 50.5);
forced = get_cfg(cfg, 'wind_trip_high_frequency_forced_hz', 51.5);
if isnan(f)
    p = NaN; region = "missing_frequency"; status = "missing_frequency";
elseif any(isnan([start, forced]))
    p = NaN; region = "missing_high_frequency_threshold"; status = "missing_threshold";
elseif f > forced || abs(f-forced) < eps
    p = 1; region = "forced_high_frequency"; status = "valid";
elseif f > start
    p = interval_linear((f - start) / max(forced - start, eps), mode);
    region = "high_frequency_interval"; status = "diagnostic_interval";
else
    p = 0; region = "normal_high_frequency"; status = "valid";
end
end

function p = interval_linear(x, mode)
if mode ~= "linear"
    p = NaN;
else
    p = min(max(x, 0), 1);
end
end

function region = join_non_normal(parts, normal_name)
parts = string(parts);
mask = ~(startsWith(parts, "normal_"));
if any(mask)
    region = strjoin(parts(mask), '+');
else
    region = normal_name;
end
end

function detail = empty_detail()
detail = struct('U_pu', NaN, 'f_hz', NaN, 'P_U_low', NaN, ...
    'P_U_high', NaN, 'P_f_low', NaN, 'P_f_high', NaN, 'P_wt', NaN, ...
    'voltage_trip_region', "unknown", 'frequency_trip_region', "unknown", ...
    'interval_probability_mode', "unknown", 'source_status', "unknown", 'note', "");
end

function value = get_cfg(cfg, field_name, default_value)
if isfield(cfg, field_name)
    value = cfg.(field_name);
else
    value = default_value;
end
end
