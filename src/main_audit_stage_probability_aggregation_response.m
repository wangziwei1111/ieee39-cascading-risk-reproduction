function main_audit_stage_probability_aggregation_response()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'stage_probability_aggregation');
ensure_dir(out_dir);
src_root = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun');
psets = ["high_hidden_failure","benchmark_calibrated_seed"];
scens = ["wind_speed_11_28","wind_speed_12_00"];
rows = {};
for p = 1:numel(psets)
    for s = 1:numel(scens)
        base = fullfile(src_root, psets(p), scens(s), 'tables');
        C = readtable(fullfile(base, 'candidate_probability_trace.csv'), 'TextType','string', 'Delimiter', ',');
        S = readtable(fullfile(base, 'stage_transition_probability_details.csv'), 'TextType','string', 'Delimiter', ',');
        M = readtable(fullfile(base, 'markov_chain_summary.csv'), 'TextType','string', 'Delimiter', ',');
        [G, ib, tr] = findgroups(S.initial_branch, S.trial_id);
        recomputed_chain = table(ib, tr, splitapply(@prod, S.stage_transition_probability, G), ...
            'VariableNames', {'initial_branch','trial_id','recomputed_chain_transition_probability'});
        for i = 1:height(S)
            Cstage = C(C.initial_branch==S.initial_branch(i) & C.trial_id==S.trial_id(i) & C.stage_id==S.stage_id(i), :);
            pvec = min(max(Cstage.candidate_probability,0),1);
            selected = logical(Cstage.selected);
            if isempty(Cstage)
                selected_product = 1; unselected_product = 1; recomputed_stage = 1;
            else
                selected_product = prod(pvec(selected)); if isempty(selected_product), selected_product = 1; end
                unselected_product = prod(1-pvec(~selected)); if isempty(unselected_product), unselected_product = 1; end
                if logical(S.terminal_stage_flag(i)) && ~logical(S.should_multiply_candidate_complements(i))
                    recomputed_stage = 1;
                else
                    recomputed_stage = selected_product * unselected_product;
                end
            end
            Mrow = M(M.initial_branch==S.initial_branch(i) & M.trial_id==S.trial_id(i), :);
            Crow = recomputed_chain(recomputed_chain.initial_branch==S.initial_branch(i)&recomputed_chain.trial_id==S.trial_id(i), :);
            chain_prob = first_or_nan(Mrow, 'chain_transition_probability');
            recomputed_chain_prob = first_or_nan(Crow, 'recomputed_chain_transition_probability');
            d_stage = S.stage_transition_probability(i) - recomputed_stage;
            d_chain = chain_prob - recomputed_chain_prob;
            rows{end+1,1} = table(psets(p), scens(s), S.initial_branch(i), S.trial_id(i), S.stage_id(i), ...
                S.candidate_count(i), S.selected_candidate_count(i), selected_product, unselected_product, ...
                S.stage_transition_probability(i), recomputed_stage, d_stage, logical(S.terminal_stage_flag(i)), ...
                string(S.probability_status(i)), chain_prob, recomputed_chain_prob, d_chain, match_status(d_stage,d_chain), issue_type(d_stage,d_chain,S), ...
                "Offline recompute from recorded candidate selected flags; no Markov rerun.", ...
                'VariableNames', {'parameter_set_id','scenario_id','initial_branch','trial_id','stage_id','candidate_count','selected_candidate_count', ...
                'selected_probability_product','unselected_probability_product','stage_transition_probability','recomputed_stage_transition_probability', ...
                'diff_stage_probability','terminal_stage_flag','stage_probability_status','chain_transition_probability','recomputed_chain_transition_probability', ...
                'diff_chain_probability','aggregation_match_status','issue_type','note'}); %#ok<AGROW>
        end
    end
end
writetable(vertcat(rows{:}), fullfile(out_dir, 'stage_probability_aggregation_audit.csv'));
end

function v = first_or_nan(T, name)
if isempty(T) || ~ismember(name, T.Properties.VariableNames), v = NaN; else, v = T.(name)(1); end
end

function s = match_status(ds, dc)
if isnan(ds) || isnan(dc), s = "missing";
elseif abs(ds) <= 1e-10 && abs(dc) <= 1e-10, s = "match";
else, s = "mismatch";
end
end

function s = issue_type(ds, dc, S)
if abs(ds) > 1e-10, s = "stage_probability_mismatch";
elseif abs(dc) > 1e-10, s = "chain_probability_mismatch";
elseif string(S.probability_status(1)) == "missing_candidate_probability", s = "missing_candidate_probability";
else, s = "no_issue";
end
end

function ensure_dir(path)
if exist(path,'dir')~=7, mkdir(path); end
end
