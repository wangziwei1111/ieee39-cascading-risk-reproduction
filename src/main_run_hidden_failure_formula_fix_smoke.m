function main_run_hidden_failure_formula_fix_smoke()
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'config')); addpath(genpath(fullfile(root, 'src')));
out_dir = fullfile(root, 'results', 'calibration', 'hidden_failure_formula');
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
cfg.hidden_failure_loading_probability_mode = 'paper_piecewise_constant_below_Lmax';
cfg.paper_line_parameter_calibration_status = 'diagnostic_assumption_not_paper';
loads = [0.50 0.80 0.99 1.00 1.20 1.40 1.50];
branch = zeros(1,13); branch(6) = 1;
rows = cell(numel(loads),1);
for i = 1:numel(loads)
    [~, d] = compute_paper_line_outage_probability(loads(i), branch, cfg, 'branch_index', 1);
    rows{i} = table("loading_"+string(loads(i)), loads(i), loads(i), d.L_max_pu, cfg.paper_line_P_L_D, cfg.paper_line_P_L_r, ...
        d.P_HF_D, d.P_HF_L, d.P_mis_r, d.P2, d.P_L, string(d.P_HF_L_formula_branch), expected_behavior(loads(i)), pass_fail(loads(i), d), ...
        "Formula smoke only; no Markov run.", ...
        'VariableNames', {'test_case','line_loading_pu','L','L_max','P_L_D','P_L_r','P_HF_D','P_HF_L','P_mis_r','P2','P_L', ...
        'P_HF_L_formula_branch','expected_behavior','pass_fail','note'});
end
writetable(vertcat(rows{:}), fullfile(out_dir, 'hidden_failure_formula_fix_smoke.csv'));
end

function s = expected_behavior(x)
if x < 1.0
    s = "P_HF_L equals P_L_D below L_max";
elseif x <= 1.4
    s = "P_HF_L in linear interval from L_max to 1.4 L_max";
else
    s = "P_HF_L equals P_L_r above 1.4 L_max";
end
end

function s = pass_fail(x, d)
if x < 1.0
    ok = abs(d.P_HF_L - 1e-3) < 1e-12;
elseif x <= 1.4
    expected = 1e-3 + (x - 1.0) * (5e-2 - 1e-3) / 0.4;
    ok = abs(d.P_HF_L - expected) < 1e-10;
else
    ok = abs(d.P_HF_L - 5e-2) < 1e-12;
end
if ok, s = "pass"; else, s = "fail"; end
end

function ensure_dir(path)
if exist(path,'dir')~=7, mkdir(path); end
end
