function main_recompute_line_probability_components_from_trace()
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'config')); addpath(genpath(fullfile(root, 'src')));
out_dir = fullfile(root, 'results', 'calibration', 'line_probability_formula');
ensure_dir(out_dir);
src_root = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun');
psets = ["high_hidden_failure","benchmark_calibrated_seed"];
scens = ["wind_speed_11_28","wind_speed_12_00"];
rows = {};
for p = 1:numel(psets)
    cfg = load_benchmark_calibration_parameter_set(base_config(), psets(p));
    require_matpower(cfg);
    cfg.line_outage_flow_probability_mode = 'paper_piecewise_constant_below_rated';
    base_mpc = build_case39_base(cfg);
    for s = 1:numel(scens)
        T = readtable(fullfile(src_root, psets(p), scens(s), 'tables', 'line_probability_component_trace.csv'), 'TextType','string');
        kept_per_branch = containers.Map('KeyType','double','ValueType','double');
        for i = 1:height(T)
            br = T.candidate_branch(i);
            [~, d] = compute_paper_line_outage_probability(T.line_loading_pu(i), base_mpc.branch(br,:), cfg, ...
                'branch_index', br, 'fallback_probability', T.candidate_probability(i));
            diffs = [T.P_flow(i)-d.P_flow, T.P_HF_L(i)-d.P_HF_L, T.P_mis_r(i)-d.P_mis_r, ...
                T.P1(i)-d.P1, T.P2(i)-d.P2, T.P_L(i)-d.P_L];
            keep_count = 0;
            if isKey(kept_per_branch, br)
                keep_count = kept_per_branch(br);
            end
            keep_row = logical(T.selected(i)) || any(abs(diffs) > 1e-10) || keep_count < 10;
            if ~keep_row
                continue;
            end
            kept_per_branch(br) = keep_count + 1;
            rows{end+1,1} = table(psets(p), scens(s), T.initial_branch(i), T.trial_id(i), T.stage_id(i), br, ...
                T.line_loading_pu(i), T.L(i), T.L_rated(i), T.L_max(i), T.L_rated_factor(i), ...
                T.P_flow(i), d.P_flow, diffs(1), T.P_HF_L(i), d.P_HF_L, diffs(2), ...
                T.P_mis_r(i), d.P_mis_r, diffs(3), T.P1(i), d.P1, diffs(4), T.P2(i), d.P2, diffs(5), ...
                T.P_L(i), d.P_L, diffs(6), logical(d.below_Lrated_flag), match_status(diffs), issue_type(T, d, diffs, i), ...
                "Offline recompute sample from trace using paper_piecewise_constant_below_rated; all mismatches/selected rows plus representative rows kept.", ...
                'VariableNames', {'parameter_set_id','scenario_id','initial_branch','trial_id','stage_id','candidate_branch', ...
                'line_loading_pu','L','L_rated','L_max','L_rated_factor','recorded_P_flow','recomputed_P_flow_paper','diff_P_flow', ...
                'recorded_P_HF_L','recomputed_P_HF_L_paper','diff_P_HF_L','recorded_P_mis_r','recomputed_P_mis_r_paper', ...
                'diff_P_mis_r','recorded_P1','recomputed_P1_paper','diff_P1','recorded_P2','recomputed_P2_paper', ...
                'diff_P2','recorded_P_L','recomputed_P_L_paper','diff_P_L','below_Lrated_flag','formula_match_status','issue_type','note'}); %#ok<AGROW>
        end
    end
end
writetable(vertcat(rows{:}), fullfile(out_dir, 'line_probability_component_recompute_audit.csv'));
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

function s = issue_type(T, d, diffs, i)
if any(isnan(diffs)), s = "no_issue"; return; end
if logical(d.below_Lrated_flag) && abs(diffs(1)) > 1e-10
    s = "P_flow_varies_below_Lrated";
elseif abs(diffs(6)) > 1e-10
    s = "P_L_mismatch";
elseif abs(diffs(2)) > 1e-10
    s = "P_HF_L_mismatch";
elseif abs(diffs(4)) > 1e-10
    s = "P1_mismatch";
elseif abs(diffs(5)) > 1e-10
    s = "P2_mismatch";
else
    s = "no_issue";
end
end

function ensure_dir(path)
if exist(path,'dir')~=7, mkdir(path); end
end
