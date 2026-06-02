function main_analyze_wind_speed_PL_aggregation_sensitivity()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'event_probability_formula');
src_root = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun');
R = readtable(fullfile(out_dir, 'PL_event_component_recompute_audit.csv'), 'TextType','string');
Vbefore = readtable(fullfile(src_root, 'wind_speed_component_diagnostic_var_metrics.csv'), 'TextType','string');
psets = unique(R.parameter_set_id);
sigmas = [0.90;0.95;0.98];
metrics = ["basic_LLR","basic_LFOR","basic_NVOR","basic_CRI"];
metric_names = ["SLLR","SLFOR","SNVOR","CRI"];
rows = {};
for p = 1:numel(psets)
    for variant = ["recorded_PL_chain","simple_sum_PL_offline_proxy","union_PL_offline_proxy"]
        C11 = chain_proxy(root, psets(p), "wind_speed_11_28", variant, R);
        C12 = chain_proxy(root, psets(p), "wind_speed_12_00", variant, R);
        for m = 1:numel(metrics)
            for sg = 1:numel(sigmas)
                if variant == "recorded_PL_chain"
                    a = Vbefore(Vbefore.parameter_set_id==psets(p)&Vbefore.scenario_id=="wind_speed_11_28"&Vbefore.metric_name==metric_names(m)&Vbefore.sigma==sigmas(sg),:);
                    b = Vbefore(Vbefore.parameter_set_id==psets(p)&Vbefore.scenario_id=="wind_speed_12_00"&Vbefore.metric_name==metric_names(m)&Vbefore.sigma==sigmas(sg),:);
                    if isempty(a) || isempty(b), v11 = NaN; v12 = NaN; else, v11 = a.var_value(1); v12 = b.var_value(1); end
                else
                    v11 = quantile(C11.(metrics(m)) .* C11.proxy_chain_probability, sigmas(sg));
                    v12 = quantile(C12.(metrics(m)) .* C12.proxy_chain_probability, sigmas(sg));
                end
                dirn = dir_text(v12-v11);
                rows{end+1,1}=table(psets(p), variant, metric_names(m), sigmas(sg), v11, v12, dirn, ...
                    "12mps_expected_lower_or_not_higher", dirn=="matches_paper_direction", proxy_status(variant), ...
                    "Offline probability aggregation sensitivity; proxy variants are not formal results.", ...
                    'VariableNames', {'parameter_set_id','aggregation_variant','metric_name','sigma','wind_speed_11_28_var_proxy', ...
                    'wind_speed_12_00_var_proxy','direction','paper_expected_direction','direction_match','proxy_status','note'}); %#ok<AGROW>
            end
        end
    end
end
writetable(vertcat(rows{:}), fullfile(out_dir, 'wind_speed_PL_aggregation_sensitivity.csv'));
end

function C = chain_proxy(root, pset, scen, variant, R)
chain_path = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun', pset, scen, 'tables', 'markov_chain_summary.csv');
C = readtable(chain_path, 'TextType','string');
C.proxy_chain_probability = C.chain_transition_probability;
if variant == "recorded_PL_chain", return; end
trace_path = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun', pset, scen, 'tables', 'line_probability_component_trace.csv');
T = readtable(trace_path, 'TextType','string');
[G, ib, tr, st] = findgroups(T.initial_branch, T.trial_id, T.stage_id);
stage_probs = table(ib, tr, st, zeros(max(G),1), 'VariableNames', {'initial_branch','trial_id','stage_id','proxy_stage_probability'});
for g = 1:max(G)
    S = T(G==g,:);
    if variant == "union_PL_offline_proxy"
        p = 1 - (1-S.P1).*(1-S.P2).*(1-S.P3);
    else
        p = min(max(S.P1 + S.P2 + S.P3, 0), 1);
    end
    selected = logical(S.selected);
    selected_product = prod(p(selected));
    if isempty(selected_product), selected_product = 1; end
    unselected_product = prod(1 - p(~selected));
    if isempty(unselected_product), unselected_product = 1; end
    stage_probs.proxy_stage_probability(g) = selected_product * unselected_product;
end
[CG, cib, ctr] = findgroups(stage_probs.initial_branch, stage_probs.trial_id);
chain_prob = table(cib, ctr, splitapply(@prod, stage_probs.proxy_stage_probability, CG), ...
    'VariableNames', {'initial_branch','trial_id','proxy_chain_probability_new'});
C = outerjoin(C, chain_prob, 'Keys', {'initial_branch','trial_id'}, 'MergeKeys', true, 'Type','left');
C.proxy_chain_probability = C.proxy_chain_probability_new;
missing = isnan(C.proxy_chain_probability);
C.proxy_chain_probability(missing) = C.chain_transition_probability(missing);
end

function s = proxy_status(variant)
if variant == "recorded_PL_chain", s = "recorded"; else, s = "proxy_only_offline_reweighted_same_selected_flags"; end
end

function s = dir_text(delta)
if delta < 0, s="matches_paper_direction"; elseif delta > 0, s="12mps_higher_than_11p28"; else, s="flat"; end
end
