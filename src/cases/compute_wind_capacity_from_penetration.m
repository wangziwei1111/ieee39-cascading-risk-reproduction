function [wind_capacity_total_mw, detail] = compute_wind_capacity_from_penetration(penetration, cfg)
%COMPUTE_WIND_CAPACITY_FROM_PENETRATION Convert wind penetration to MW.
% Paper-aligned benchmark and calibration scenarios use total generation
% capacity as the denominator. The legacy base-load convention is retained as
% an explicit engineering diagnostic option.

if nargin < 2 || isempty(cfg)
    cfg = base_config();
end
if ~isfield(cfg, 'wind_penetration_basis') || isempty(cfg.wind_penetration_basis)
    cfg.wind_penetration_basis = 'total_generation_capacity';
end

basis = char(string(cfg.wind_penetration_basis));
switch basis
    case 'total_generation_capacity'
        base_mw = get_cfg_value(cfg, 'paper_total_generation_capacity_mw', 7500);
        paper_aligned = true;
        note = 'Paper-aligned penetration basis: wind capacity divided by total generation capacity.';
    case 'base_load'
        base_mw = get_cfg_value(cfg, 'paper_total_load_mw', 6254.23);
        paper_aligned = false;
        note = 'Legacy engineering penetration basis: wind capacity divided by base load.';
    otherwise
        error('Unknown wind_penetration_basis: %s', basis);
end

wind_capacity_total_mw = penetration * base_mw;
detail = struct();
detail.penetration = penetration;
detail.basis = basis;
detail.base_mw = base_mw;
detail.wind_capacity_total_mw = wind_capacity_total_mw;
detail.paper_aligned = paper_aligned;
detail.note = note;
end

function value = get_cfg_value(cfg, field_name, fallback)
if isfield(cfg, field_name) && ~isempty(cfg.(field_name)) && ~isnan(cfg.(field_name))
    value = cfg.(field_name);
else
    value = fallback;
end
end
