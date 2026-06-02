function main_run_line_probability_formula_fix_smoke()
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'config')); addpath(genpath(fullfile(root, 'src')));
out_dir = fullfile(root, 'results', 'calibration', 'line_probability_formula');
ensure_dir(out_dir);
cfg = base_config();
cfg.paper_line_P_L0 = 1e-3;
cfg.paper_line_P_L0_source = 'scalar_cfg_value';
cfg.paper_line_P_W_D = 1e-3;
cfg.paper_line_P_L_D = 1e-3;
cfg.paper_line_P_L_r = 5e-2;
cfg.paper_line_P_in_r = 1e-3;
cfg.paper_line_P_in_c = 1e-3;
cfg.paper_line_P_mis_c = 1e-4;
cfg.paper_line_P3 = 0;
cfg.paper_line_L_rated_factor = 0.90;
cfg.paper_line_L_max_factor = 1.0;
cfg.paper_line_ZIII_factor = 3.0;
cfg.paper_line_missing_param_policy = 'return_nan';
cfg.calibration_distance_hidden_failure_mode = 'disable_if_missing';
cfg.line_outage_flow_probability_mode = 'paper_piecewise_constant_below_rated';
cfg.paper_line_parameter_calibration_status = 'diagnostic_assumption_not_paper';
loads = [0.50 0.80 0.90 0.95 1.00 1.20];
rows = cell(numel(loads),1);
branch = zeros(1,13); branch(6) = 1;
for i = 1:numel(loads)
    [~, d] = compute_paper_line_outage_probability(loads(i), branch, cfg, 'branch_index', 1);
    expected = expected_behavior(loads(i));
    rows{i} = table("loading_"+string(loads(i)), loads(i), loads(i), d.L_rated_pu, d.L_max_pu, cfg.paper_line_P_L0, ...
        d.P_flow, d.P_HF_L, d.P_mis_r, d.P1, d.P2, d.P3, d.P_L, string(d.P_flow_formula_branch), expected, pass_fail(loads(i), d), ...
        "Formula smoke only; no Markov run.", ...
        'VariableNames', {'test_case','line_loading_pu','L','L_Rated','L_max','P_L0','P_flow','P_HF_L','P_mis_r', ...
        'P1','P2','P3','P_L','P_flow_formula_branch','expected_behavior','pass_fail','note'});
end
writetable(vertcat(rows{:}), fullfile(out_dir, 'line_probability_formula_fix_smoke.csv'));
end

function s = expected_behavior(x)
if x <= 0.90
    s = "P_flow equals P_L0 below or at L_Rated";
elseif x <= 1.0
    s = "P_flow in linear interval";
else
    s = "P_flow forced to 1 above L_max";
end
end

function s = pass_fail(x, d)
if x <= 0.90
    ok = abs(d.P_flow - 1e-3) < 1e-12;
elseif x <= 1.0
    ok = d.P_flow > 1e-3 && d.P_flow <= 1;
else
    ok = abs(d.P_flow - 1) < 1e-12;
end
if ok, s = "pass"; else, s = "fail"; end
end

function ensure_dir(path)
if exist(path,'dir')~=7, mkdir(path); end
end
