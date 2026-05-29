function [p_line, detail] = compute_paper_line_outage_probability(line_loading_pu, branch_row, cfg, varargin)
%COMPUTE_PAPER_LINE_OUTAGE_PROBABILITY Thesis-style subsequent line outage probability.
% This implements the formula structure recorded from thesis Section 3.1.1.
% Parameters that are not yet confirmed from the paper remain NaN and are
% reported explicitly; they are never silently treated as calibrated values.

args = parse_args(varargin{:});
loading = max(line_loading_pu, 0);
fallback_probability = args.fallback_probability;
Z_m = args.Z_m;
Z_III = args.Z_III;
protection_mode = args.protection_mode;

missing = strings(0, 1);
used_fallback = false;
note = "paper_formula diagnostic; parameters require calibration";

L_rated = get_cfg(cfg, 'paper_line_L_rated_factor', 1.0);
L_max = get_cfg(cfg, 'paper_line_L_max_factor', 1.2);
P_L0 = get_cfg(cfg, 'paper_line_P_L0', NaN);
P_overload_max = get_cfg(cfg, 'paper_line_P_overload_max', 1.0);
P_W_D = get_cfg(cfg, 'paper_line_P_W_D', NaN);
P_L_D = get_cfg(cfg, 'paper_line_P_L_D', NaN);
P_L_r = get_cfg(cfg, 'paper_line_P_L_r', NaN);
P3 = get_cfg(cfg, 'paper_line_P3', 0);

if isnan(P_L0), missing(end + 1, 1) = "paper_line_P_L0"; end
if isnan(L_rated), missing(end + 1, 1) = "paper_line_L_rated_factor"; end
if isnan(L_max), missing(end + 1, 1) = "paper_line_L_max_factor"; end
if isnan(P_overload_max), missing(end + 1, 1) = "paper_line_P_overload_max"; end
if isnan(P3), missing(end + 1, 1) = "paper_line_P3"; end

P_flow = NaN;
if isempty(missing)
    if loading <= L_rated
        P_flow = P_L0;
    elseif loading <= L_max
        ratio = (loading - L_rated) / max(L_max - L_rated, eps);
        P_flow = P_L0 + ratio * (P_overload_max - P_L0);
    else
        P_flow = P_overload_max;
    end
end

P_hidden_distance = NaN;
distance_status = "not_evaluated";
if ~isnan(Z_m) || ~isnan(Z_III) || ~isnan(P_W_D)
    if isnan(P_W_D), missing(end + 1, 1) = "paper_line_P_W_D"; end
    if isnan(Z_III), missing(end + 1, 1) = "Z_III"; end
    if isnan(Z_m), missing(end + 1, 1) = "Z_m"; end
    if ~isnan(P_W_D) && ~isnan(Z_m) && ~isnan(Z_III)
        if Z_m <= 3 * Z_III
            P_hidden_distance = P_W_D;
        else
            P_hidden_distance = P_W_D * exp(-Z_m / Z_III);
        end
        distance_status = "computed_from_equation_3_4";
    else
        distance_status = "missing_parameter";
    end
else
    distance_status = "missing_parameter_not_supplied";
    missing(end + 1, 1) = "distance_hidden_failure_parameters";
end

P_hidden_loading = NaN;
loading_hidden_status = "not_evaluated";
if isnan(P_L_D), missing(end + 1, 1) = "paper_line_P_L_D"; end
if isnan(P_L_r), missing(end + 1, 1) = "paper_line_P_L_r"; end
if ~isnan(P_L_D) && ~isnan(P_L_r) && ~isnan(L_max)
    if loading < L_max
        P_hidden_loading = P_L_D;
    elseif loading <= 1.4 * L_max
        ratio = (loading - L_max) / max(0.4 * L_max, eps);
        P_hidden_loading = P_L_D + ratio * (P_L_r - P_L_D);
    else
        P_hidden_loading = P_L_r;
    end
    loading_hidden_status = "computed_from_equation_3_5";
else
    loading_hidden_status = "missing_parameter";
end

missing = unique(missing, 'stable');
has_missing = ~isempty(missing);
policy = lower(string(get_cfg(cfg, 'paper_line_missing_param_policy', 'fallback_to_engineering_with_warning')));
status = "ok_uncalibrated";

if has_missing
    status = "missing_parameter";
    switch policy
        case "fallback_to_engineering_with_warning"
            p_line = fallback_probability;
            used_fallback = true;
            status = "missing_parameter_fallback";
            note = "Paper formula has missing parameters; returned engineering fallback probability for main-chain safety.";
        case "return_nan"
            p_line = NaN;
            note = "Paper formula has missing parameters; returned NaN by policy.";
        case "error"
            error('Paper line outage probability missing parameters: %s', strjoin(cellstr(missing), ', '));
        otherwise
            error('Unknown paper_line_missing_param_policy: %s', policy);
    end
else
    hidden_terms = [P_hidden_distance, P_hidden_loading];
    hidden_terms = hidden_terms(~isnan(hidden_terms));
    P2 = sum(hidden_terms);
    p_line = P_flow + P2 + P3;
    p_line = min(max(p_line, 0), 1);
end

detail = struct();
detail.model_name = "paper_formula";
detail.protection_mode = protection_mode;
detail.line_loading_pu = loading;
detail.branch_rateA = get_branch_value(branch_row, 6, NaN);
detail.L_rated_pu = L_rated;
detail.L_max_pu = L_max;
detail.P_flow = P_flow;
detail.P_hidden_distance = P_hidden_distance;
detail.P_hidden_loading = P_hidden_loading;
detail.P3 = P3;
detail.distance_hidden_failure_status = distance_status;
detail.loading_hidden_failure_status = loading_hidden_status;
detail.missing_parameters = strjoin(cellstr(missing), ';');
detail.used_fallback = used_fallback;
detail.fallback_probability = fallback_probability;
detail.p_line = p_line;
detail.status = status;
detail.note = note;
end

function args = parse_args(varargin)
args = struct('fallback_probability', NaN, 'Z_m', NaN, 'Z_III', NaN, 'protection_mode', "unspecified");
if mod(numel(varargin), 2) ~= 0
    error('Optional inputs must be name-value pairs.');
end
for i = 1:2:numel(varargin)
    name = lower(string(varargin{i}));
    switch name
        case "fallback_probability"
            args.fallback_probability = varargin{i + 1};
        case "z_m"
            args.Z_m = varargin{i + 1};
        case "z_iii"
            args.Z_III = varargin{i + 1};
        case "protection_mode"
            args.protection_mode = varargin{i + 1};
        otherwise
            error('Unknown optional input: %s', name);
    end
end
end

function value = get_cfg(cfg, name, default_value)
if isfield(cfg, name)
    value = cfg.(name);
else
    value = default_value;
end
end

function value = get_branch_value(branch_row, col, default_value)
if isempty(branch_row) || numel(branch_row) < col
    value = default_value;
else
    value = branch_row(col);
end
end
