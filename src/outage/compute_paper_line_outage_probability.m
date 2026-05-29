function [p_line, detail] = compute_paper_line_outage_probability(line_loading_pu, branch_row, cfg, varargin)
%COMPUTE_PAPER_LINE_OUTAGE_PROBABILITY Paper-structure line subsequent outage probability.
% Implements the target paper formula structure (3-1) to (3-6). Statistical
% parameters that are not public must be marked as diagnostic or
% benchmark_calibrated_not_original_paper by the caller.

args = parse_args(varargin{:});
loading = max(line_loading_pu, 0);
fallback_probability = args.fallback_probability;
branch_index = args.branch_index;
if isnan(branch_index)
    branch_index = get_branch_index(branch_row);
end

missing = strings(0, 1);
used_fallback = false;
note = "paper formula structure; parameter status must be read from calibration_status";

rateA = get_branch_value(branch_row, 6, NaN);
P_L0 = resolve_P_L0(cfg, branch_index);
P_W_D = get_cfg(cfg, 'paper_line_P_W_D', NaN);
P_L_D = get_cfg(cfg, 'paper_line_P_L_D', NaN);
P_L_r = get_cfg(cfg, 'paper_line_P_L_r', NaN);
P_in_r = get_cfg(cfg, 'paper_line_P_in_r', NaN);
P_in_c = get_cfg(cfg, 'paper_line_P_in_c', NaN);
P_mis_c = get_cfg(cfg, 'paper_line_P_mis_c', NaN);
P3 = get_cfg(cfg, 'paper_line_P3', NaN);
L_rated_factor = get_cfg(cfg, 'paper_line_L_rated_factor', NaN);
L_max_factor = get_cfg(cfg, 'paper_line_L_max_factor', NaN);
ZIII_factor = get_cfg(cfg, 'paper_line_ZIII_factor', NaN);
distance_mode = lower(string(get_cfg(cfg, 'calibration_distance_hidden_failure_mode', 'disable_if_missing')));

if isnan(P_L0), missing(end + 1, 1) = "paper_line_P_L0"; end
if isnan(P_L_D), missing(end + 1, 1) = "paper_line_P_L_D"; end
if isnan(P_L_r), missing(end + 1, 1) = "paper_line_P_L_r"; end
if isnan(P_in_r), missing(end + 1, 1) = "paper_line_P_in_r"; end
if isnan(P_in_c), missing(end + 1, 1) = "paper_line_P_in_c"; end
if isnan(P_mis_c), missing(end + 1, 1) = "paper_line_P_mis_c"; end
if isnan(P3), missing(end + 1, 1) = "paper_line_P3"; end
if isnan(L_rated_factor), missing(end + 1, 1) = "paper_line_L_rated_factor"; end
if isnan(L_max_factor), missing(end + 1, 1) = "paper_line_L_max_factor"; end

L_max_pu = L_max_factor;
L_rated_pu = L_rated_factor * L_max_pu;
P_flow = NaN;
if ~any(ismember(missing, ["paper_line_P_L0","paper_line_L_rated_factor","paper_line_L_max_factor"]))
    if loading <= L_rated_pu
        P_flow = P_L0;
    elseif loading <= L_max_pu
        P_flow = P_L0 + (1 - P_L0) * (loading - L_rated_pu) / max(L_max_pu - L_rated_pu, eps);
    else
        P_flow = 1;
    end
end

[P_HF_D, distance_status, distance_note] = compute_distance_hidden_failure(args.Z_m, args.Z_III, ...
    ZIII_factor, P_W_D, loading, distance_mode);
if isnan(P_HF_D)
    if distance_mode == "disable_if_missing"
        P_HF_D = 0;
        distance_status = "disabled_if_missing";
    else
        missing(end + 1, 1) = "distance_hidden_failure_inputs";
    end
end

P_HF_L = NaN;
if ~any(ismember(missing, ["paper_line_P_L_D","paper_line_P_L_r","paper_line_L_max_factor"]))
    if loading < L_max_pu
        P_HF_L = P_L_D;
    elseif loading <= 1.4 * L_max_pu
        P_HF_L = P_L_D + (loading - L_max_pu) * (P_L_r - P_L_D) / max(0.4 * L_max_pu, eps);
    else
        P_HF_L = P_L_r;
    end
end

P_mis_r = NaN;
P1 = NaN;
P2 = NaN;
if isempty(missing)
    P_mis_r = P_HF_D + P_HF_L - P_HF_D * P_HF_L;
    P1 = P_flow * (1 - P_in_r) * (1 - P_in_c);
    P2 = P_mis_c + P_mis_r * (1 - P_in_c);
    p_line = min(max(P1 + P2 + P3, 0), 1);
    formula_status = "computed_full_formula_3_1_to_3_6";
    parameter_status = "complete_for_selected_parameter_set";
else
    [p_line, used_fallback, formula_status, parameter_status, note] = handle_missing(missing, fallback_probability, cfg);
end

calibration_status = string(get_cfg(cfg, 'paper_line_parameter_calibration_status', 'unknown'));
detail = struct();
detail.model_name = "paper_formula";
detail.parameter_set_id = string(get_cfg(cfg, 'paper_line_parameter_set_id', 'cfg_direct'));
detail.parameter_calibration_status = calibration_status;
detail.calibration_status = calibration_status;
detail.line_loading_pu = loading;
detail.branch_rateA = rateA;
detail.L_rated_pu = L_rated_pu;
detail.L_max_pu = L_max_pu;
detail.P_flow = P_flow;
detail.P_HF_D = P_HF_D;
detail.P_HF_L = P_HF_L;
detail.P_hidden_distance = P_HF_D;
detail.P_hidden_loading = P_HF_L;
detail.P_mis_r = P_mis_r;
detail.P1 = P1;
detail.P2 = P2;
detail.P3 = P3;
detail.P_L = p_line;
detail.P_W_D = P_W_D;
detail.P_L_D = P_L_D;
detail.P_L_r = P_L_r;
detail.P_in_r = P_in_r;
detail.P_in_c = P_in_c;
detail.P_mis_c = P_mis_c;
detail.L_rated_factor = L_rated_factor;
detail.L_max_factor = L_max_factor;
detail.ZIII_factor = ZIII_factor;
detail.distance_hidden_failure_status = distance_status;
detail.loading_hidden_failure_status = "computed_from_formula_3_5";
if isnan(P_HF_L)
    detail.loading_hidden_failure_status = "missing_parameter";
end
detail.missing_parameters = strjoin(cellstr(unique(missing, 'stable')), ';');
detail.used_fallback = used_fallback;
detail.fallback_probability = fallback_probability;
detail.p_line = p_line;
detail.status = formula_status;
detail.formula_status = formula_status;
detail.parameter_status = parameter_status;
detail.note = note + " " + distance_note;
end

function [P_HF_D, status, note] = compute_distance_hidden_failure(Z_m, Z_III, ZIII_factor, P_W_D, loading, distance_mode)
P_HF_D = NaN;
status = "missing_impedance_data";
note = "";
if isnan(P_W_D)
    status = "missing_P_W_D";
    return;
end
if ~isnan(Z_m) && ~isnan(Z_III)
    if Z_m <= 3 * Z_III
        P_HF_D = P_W_D;
    else
        P_HF_D = P_W_D * exp(-Z_m / (3 * Z_III));
    end
    status = "computed_from_impedance";
elseif distance_mode == "proxy_by_line_loading"
    if isnan(ZIII_factor)
        status = "missing_ZIII_factor_for_proxy";
        return;
    end
    P_HF_D = P_W_D * min(max(loading / max(ZIII_factor, eps), 0), 1);
    status = "proxy_by_line_loading";
    note = "distance hidden failure uses diagnostic proxy, not original impedance calculation.";
else
    status = "missing_impedance_data";
end
end

function [p_line, used_fallback, formula_status, parameter_status, note] = handle_missing(missing, fallback_probability, cfg)
used_fallback = false;
policy = lower(string(get_cfg(cfg, 'paper_line_missing_param_policy', 'fallback_to_engineering_with_warning')));
formula_status = "missing_parameter";
parameter_status = "missing_parameter";
switch policy
    case "fallback_to_engineering_with_warning"
        p_line = fallback_probability;
        used_fallback = true;
        formula_status = "missing_parameter_fallback";
        note = "Paper formula has missing parameters; returned fallback probability.";
    case "return_nan"
        p_line = NaN;
        note = "Paper formula has missing parameters; returned NaN.";
    case "error"
        error('Paper line outage probability missing parameters: %s', strjoin(cellstr(missing), ', '));
    otherwise
        error('Unknown paper_line_missing_param_policy: %s', policy);
end
end

function args = parse_args(varargin)
args = struct('fallback_probability', NaN, 'Z_m', NaN, 'Z_III', NaN, ...
    'protection_mode', "unspecified", 'branch_index', NaN);
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
        case "branch_index"
            args.branch_index = varargin{i + 1};
        otherwise
            error('Unknown optional input: %s', name);
    end
end
end

function P_L0 = resolve_P_L0(cfg, branch_index)
source = string(get_cfg(cfg, 'paper_line_P_L0_source', 'scalar_cfg_value'));
switch source
    case "table4_1_initial_probability"
        values = get_cfg(cfg, 'paper_line_P_L0_by_branch', []);
        if isempty(values) || isnan(branch_index) || branch_index < 1 || branch_index > numel(values)
            P_L0 = NaN;
        else
            P_L0 = values(branch_index);
        end
    otherwise
        P_L0 = get_cfg(cfg, 'paper_line_P_L0', NaN);
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

function branch_index = get_branch_index(branch_row)
if numel(branch_row) >= 14
    branch_index = branch_row(14);
else
    branch_index = NaN;
end
end
