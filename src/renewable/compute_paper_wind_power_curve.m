function [P_w, detail] = compute_paper_wind_power_curve(v, P_wr, cfg)
%COMPUTE_PAPER_WIND_POWER_CURVE Unified wind-power curve for paper-aligned scenarios.
% The default paper profile uses the public 2/12/20 wind turbine curve:
% P_w = P_wr * (v^3 - 8) / 1720 for 2 <= v <= 12.
if nargin < 3 || isempty(cfg)
    cfg = struct();
end

profile = string(get_field(cfg, 'wind_power_curve_profile', 'paper_2_12_20'));
switch profile
    case "paper_2_12_20"
        v_in = get_field(cfg, 'paper_wind_cut_in_speed', 2);
        v_r = get_field(cfg, 'paper_wind_rated_speed', 12);
        v_out = get_field(cfg, 'paper_wind_cut_out_speed', 20);
        source_status = "original_paper_formula";
    case "engineering_3_12_25"
        v_in = get_field(cfg, 'engineering_wind_cut_in_speed', 3);
        v_r = get_field(cfg, 'engineering_wind_rated_speed', 12);
        v_out = get_field(cfg, 'engineering_wind_cut_out_speed', 25);
        source_status = "engineering_legacy_formula";
    case "custom"
        v_in = get_field(cfg, 'custom_wind_cut_in_speed', get_field(cfg, 'cut_in_speed_mps', 2));
        v_r = get_field(cfg, 'custom_wind_rated_speed', get_field(cfg, 'rated_speed_mps', 12));
        v_out = get_field(cfg, 'custom_wind_cut_out_speed', get_field(cfg, 'cut_out_speed_mps', 20));
        source_status = "custom_formula";
    otherwise
        error('Unknown wind_power_curve_profile: %s', profile);
end

if v < v_in || v > v_out
    P_w = 0;
elseif v <= v_r
    P_w = P_wr * (v^3 - v_in^3) / (v_r^3 - v_in^3);
else
    P_w = P_wr;
end

detail = struct();
detail.wind_speed = v;
detail.rated_capacity_mw = P_wr;
detail.curve_profile = char(profile);
detail.cut_in_speed = v_in;
detail.rated_speed = v_r;
detail.cut_out_speed = v_out;
detail.power_mw = P_w;
detail.power_ratio = P_w / max(P_wr, eps);
detail.source_status = char(source_status);
end

function value = get_field(s, name, default_value)
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    value = s.(name);
else
    value = default_value;
end
end
