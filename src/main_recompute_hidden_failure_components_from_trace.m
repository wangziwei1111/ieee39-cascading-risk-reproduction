function main_recompute_hidden_failure_components_from_trace()
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'config')); addpath(genpath(fullfile(root, 'src')));
out_dir = fullfile(root, 'results', 'calibration', 'hidden_failure_formula');
ensure_dir(out_dir);
src_root = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun');
psets = ["high_hidden_failure","benchmark_calibrated_seed"];
scens = ["wind_speed_11_28","wind_speed_12_00"];
rows = {};
for p = 1:numel(psets)
    cfg = load_benchmark_calibration_parameter_set(base_config(), psets(p));
    require_matpower(cfg);
    cfg.line_outage_flow_probability_mode = 'paper_piecewise_constant_below_rated';
    cfg.hidden_failure_loading_probability_mode = 'paper_piecewise_constant_below_Lmax';
    base_mpc = build_case39_base(cfg);
    for s = 1:numel(scens)
        trace_path = fullfile(src_root, psets(p), scens(s), 'tables', 'line_probability_component_trace.csv');
        if exist(trace_path, 'file') ~= 2
            rows{end+1,1} = missing_row(psets(p), scens(s), trace_path); %#ok<AGROW>
            continue;
        end
        T = readtable(trace_path, 'TextType','string');
        kept_per_branch = containers.Map('KeyType','double','ValueType','double');
        for i = 1:height(T)
            br = T.candidate_branch(i);
            [~, d] = compute_paper_line_outage_probability(T.line_loading_pu(i), base_mpc.branch(br,:), cfg, ...
                'branch_index', br, 'fallback_probability', T.candidate_probability(i));
            diffs = [T.P_HF_D(i)-d.P_HF_D, T.P_HF_L(i)-d.P_HF_L, T.P_mis_r(i)-d.P_mis_r, ...
                T.P2(i)-d.P2, T.P_L(i)-d.P_L];
            keep_count = 0;
            if isKey(kept_per_branch, br), keep_count = kept_per_branch(br); end
            keep_row = logical(T.selected(i)) || any(abs(diffs) > 1e-10) || keep_count < 10;
            if ~keep_row, continue; end
            kept_per_branch(br) = keep_count + 1;
            rows{end+1,1} = table(psets(p), scens(s), T.initial_branch(i), T.trial_id(i), T.stage_id(i), br, ...
                T.line_loading_pu(i), T.L(i), T.L_max(i), cfg.paper_line_P_L_D, cfg.paper_line_P_L_r, ...
                T.P_HF_D(i), d.P_HF_D, diffs(1), T.P_HF_L(i), d.P_HF_L, diffs(2), ...
                T.P_mis_r(i), d.P_mis_r, diffs(3), T.P2(i), d.P2, diffs(4), ...
                T.P_L(i), d.P_L, diffs(5), logical(d.below_Lmax_flag), ...
                T.line_loading_pu(i) >= d.L_max_pu && T.line_loading_pu(i) <= 1.4*d.L_max_pu, ...
                T.line_loading_pu(i) > 1.4*d.L_max_pu, match_status(diffs), issue_type(d, diffs), ...
                "Offline recompute using paper_piecewise_constant_below_Lmax; all mismatches/selected rows plus representative rows kept.", ...
                'VariableNames', {'parameter_set_id','scenario_id','initial_branch','trial_id','stage_id','candidate_branch', ...
                'line_loading_pu','L','L_max','P_L_D','P_L_r','recorded_P_HF_D','recomputed_P_HF_D_paper','diff_P_HF_D', ...
                'recorded_P_HF_L','recomputed_P_HF_L_paper','diff_P_HF_L','recorded_P_mis_r','recomputed_P_mis_r_paper', ...
                'diff_P_mis_r','recorded_P2','recomputed_P2_paper','diff_P2','recorded_P_L','recomputed_P_L_paper','diff_P_L', ...
                'below_Lmax_flag','between_Lmax_1p4Lmax_flag','above_1p4Lmax_flag','formula_match_status','issue_type','note'}); %#ok<AGROW>
        end
    end
end
writetable(vertcat(rows{:}), fullfile(out_dir, 'hidden_failure_component_recompute_audit.csv'));
end

function T = missing_row(pset, scen, path)
T = table(pset, scen, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    false, false, false, "missing_required_field", "missing_required_field", "Missing trace file: "+string(path), ...
    'VariableNames', {'parameter_set_id','scenario_id','initial_branch','trial_id','stage_id','candidate_branch', ...
    'line_loading_pu','L','L_max','P_L_D','P_L_r','recorded_P_HF_D','recomputed_P_HF_D_paper','diff_P_HF_D', ...
    'recorded_P_HF_L','recomputed_P_HF_L_paper','diff_P_HF_L','recorded_P_mis_r','recomputed_P_mis_r_paper', ...
    'diff_P_mis_r','recorded_P2','recomputed_P2_paper','diff_P2','recorded_P_L','recomputed_P_L_paper','diff_P_L', ...
    'below_Lmax_flag','between_Lmax_1p4Lmax_flag','above_1p4Lmax_flag','formula_match_status','issue_type','note'});
end

function s = match_status(diffs)
if any(isnan(diffs))
    s = "missing_required_field";
elseif max(abs(diffs)) <= 1e-10
    s = "match";
else
    s = "mismatch";
end
end

function s = issue_type(d, diffs)
if any(isnan(diffs)), s = "missing_required_field"; return; end
if logical(d.below_Lmax_flag) && abs(diffs(2)) > 1e-10
    s = "P_HF_L_varies_below_Lmax";
elseif abs(diffs(2)) > 1e-10
    s = "P_HF_L_linear_region_mismatch";
elseif abs(diffs(3)) > 1e-10
    s = "P_mis_r_mismatch";
elseif abs(diffs(4)) > 1e-10
    s = "P2_mismatch";
elseif abs(diffs(5)) > 1e-10
    s = "P_L_mismatch";
else
    s = "no_issue";
end
end

function ensure_dir(path)
if exist(path,'dir')~=7, mkdir(path); end
end
