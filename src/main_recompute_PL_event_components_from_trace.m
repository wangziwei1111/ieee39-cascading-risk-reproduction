function main_recompute_PL_event_components_from_trace()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'event_probability_formula');
ensure_dir(out_dir);
src_root = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun');
psets = ["high_hidden_failure","benchmark_calibrated_seed"];
scens = ["wind_speed_11_28","wind_speed_12_00"];
rows = {};
for p = 1:numel(psets)
    for s = 1:numel(scens)
        trace_path = fullfile(src_root, psets(p), scens(s), 'tables', 'line_probability_component_trace.csv');
        T = readtable(trace_path, 'TextType','string');
        kept = containers.Map('KeyType','char','ValueType','double');
        for i = 1:height(T)
            P1 = T.P_flow(i) * 0 + T.P1(i);
            P2 = T.P2(i);
            P3 = T.P3(i);
            simple = P1 + P2 + P3;
            clipped = min(max(simple, 0), 1);
            unionp = 1 - (1-P1)*(1-P2)*(1-P3);
            key = sprintf('%d_%d', T.candidate_branch(i), T.stage_id(i));
            n = 0; if isKey(kept,key), n = kept(key); end
            diffs = [T.P1(i)-P1, T.P2(i)-P2, T.P3(i)-P3, T.P_L(i)-clipped, T.candidate_probability(i)-T.P_L(i)];
            if ~(logical(T.selected(i)) || any(abs(diffs)>1e-10) || n < 5)
                continue;
            end
            kept(key) = n + 1;
            rows{end+1,1} = table(psets(p), scens(s), T.initial_branch(i), T.trial_id(i), T.stage_id(i), T.candidate_branch(i), ...
                T.line_loading_pu(i), T.P1(i), P1, T.P1(i)-P1, T.P2(i), P2, T.P2(i)-P2, T.P3(i), P3, T.P3(i)-P3, ...
                T.P_L(i), simple, clipped, unionp, T.candidate_probability(i), T.P_L(i)-T.candidate_probability(i), ...
                T.P_L(i)-simple, T.P_L(i)-unionp, match_status(diffs), candidate_match(T.P_L(i), T.candidate_probability(i)), issue_type(diffs, T.P_L(i), unionp), ...
                "Offline recompute from existing component trace; independent union is diagnostic proxy only, not a formula change.", ...
                'VariableNames', {'parameter_set_id','scenario_id','initial_branch','trial_id','stage_id','candidate_branch','line_loading_pu', ...
                'recorded_P1','recomputed_P1','diff_P1','recorded_P2','recomputed_P2','diff_P2','recorded_P3','recomputed_P3','diff_P3', ...
                'recorded_P_L','recomputed_PL_simple_sum','recomputed_PL_clipped','recomputed_PL_independent_union','recorded_candidate_probability', ...
                'diff_recorded_PL_vs_candidate_probability','diff_PL_simple_sum','diff_PL_independent_union','PL_formula_match_status', ...
                'candidate_probability_match_status','issue_type','note'}); %#ok<AGROW>
        end
    end
end
writetable(vertcat(rows{:}), fullfile(out_dir, 'PL_event_component_recompute_audit.csv'));
end

function s = match_status(diffs)
if any(isnan(diffs))
    s = "missing_required_field";
elseif max(abs(diffs(1:4))) <= 1e-10
    s = "match";
else
    s = "mismatch";
end
end

function s = candidate_match(pl, cp)
if isnan(pl) || isnan(cp), s = "missing_required_field";
elseif abs(pl-cp) <= 1e-10, s = "match";
else, s = "mismatch";
end
end

function s = issue_type(diffs, pl, unionp)
if any(isnan(diffs)), s = "missing_required_field";
elseif abs(diffs(1)) > 1e-10, s = "P1_mismatch";
elseif abs(diffs(2)) > 1e-10, s = "P2_mismatch";
elseif abs(diffs(3)) > 1e-10, s = "P3_mismatch";
elseif abs(diffs(5)) > 1e-10, s = "candidate_probability_not_equal_PL";
elseif abs(pl-unionp) > 1e-4, s = "PL_union_diff_large";
else, s = "no_issue";
end
end

function ensure_dir(path)
if exist(path,'dir')~=7, mkdir(path); end
end
