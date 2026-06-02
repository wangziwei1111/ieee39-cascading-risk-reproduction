function main_diagnose_wind_speed_line_probability_components()
root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
psets = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scens = ["wind_speed_11_28","wind_speed_12_00"];
rows = {};
for p = 1:numel(psets)
    for s = 1:numel(scens)
        path = fullfile(out_root, psets(p), scens(s), 'tables', 'candidate_probability_trace.csv');
        if exist(path, 'file') ~= 2, continue; end
        C = readtable(path, 'TextType', 'string');
        if ~ismember("line_loading_pu", string(C.Properties.VariableNames)) && ismember("loading_pu", string(C.Properties.VariableNames))
            C.line_loading_pu = C.loading_pu;
        end
        branches = unique(C.candidate_branch);
        for b = reshape(branches, 1, [])
            G = C(C.candidate_branch == b, :);
            status = component_status(G);
            rows{end+1,1} = table(psets(p), scens(s), b, height(G), sum(logical(G.selected)), ...
                mean(G.candidate_probability, 'omitnan'), quantile(G.candidate_probability, 0.95), max(G.candidate_probability, [], 'omitnan'), ...
                mean_optional(G, "P_flow"), mean_optional(G, "P_HF_D"), mean_optional(G, "P_HF_L"), mean_optional(G, "P_mis_r"), ...
                mean_optional(G, "P1"), mean_optional(G, "P2"), mean_optional(G, "P3"), mean_optional(G, "P_L"), ...
                mean(G.line_loading_pu, 'omitnan'), status, component_note(status), ...
                'VariableNames', {'parameter_set_id','scenario_id','candidate_branch','candidate_count','selected_count', ...
                'mean_candidate_probability','p95_candidate_probability','max_candidate_probability','mean_P_flow', ...
                'mean_P_HF_D','mean_P_HF_L','mean_P_mis_r','mean_P1','mean_P2','mean_P3','mean_P_L', ...
                'mean_line_loading_pu','component_status','note'}); %#ok<AGROW>
        end
    end
end
S = vertcat(rows{:});
writetable(S, fullfile(out_root, 'wind_speed_line_probability_component_summary.csv'));
writetable(build_delta(S), fullfile(out_root, 'wind_speed_line_probability_component_delta.csv'));
end

function v = mean_optional(T, name)
if ismember(name, string(T.Properties.VariableNames))
    v = mean(T.(char(name)), 'omitnan');
else
    v = NaN;
end
end

function s = component_status(T)
needed = ["P_flow","P_HF_L","P1","P2","P_L"];
vars = string(T.Properties.VariableNames);
if all(ismember(needed, vars))
    s = "component_fields_available";
else
    s = "need_probability_component_trace_smoke";
end
end

function s = component_note(status)
if status == "component_fields_available"
    s = "Formula component fields are present in candidate trace.";
else
    s = "Candidate probability and loading are available, but P_flow/P_HF_L/P1/P2/P_L fields are missing.";
end
end

function D = build_delta(S)
keys = unique(S(:, {'parameter_set_id','candidate_branch'}), 'rows');
rows = cell(height(keys), 1);
for i = 1:height(keys)
    A = S(S.parameter_set_id == keys.parameter_set_id(i) & S.candidate_branch == keys.candidate_branch(i) & S.scenario_id == "wind_speed_11_28", :);
    B = S(S.parameter_set_id == keys.parameter_set_id(i) & S.candidate_branch == keys.candidate_branch(i) & S.scenario_id == "wind_speed_12_00", :);
    rows{i} = table(keys.parameter_set_id(i), keys.candidate_branch(i), val(A,"mean_candidate_probability"), val(B,"mean_candidate_probability"), ...
        val(B,"mean_candidate_probability") - val(A,"mean_candidate_probability"), val(A,"mean_line_loading_pu"), val(B,"mean_line_loading_pu"), ...
        val(B,"mean_line_loading_pu") - val(A,"mean_line_loading_pu"), val(A,"mean_P_flow"), val(B,"mean_P_flow"), ...
        val(B,"mean_P_flow") - val(A,"mean_P_flow"), val(A,"mean_P_HF_L"), val(B,"mean_P_HF_L"), ...
        val(B,"mean_P_HF_L") - val(A,"mean_P_HF_L"), val(A,"selected_count"), val(B,"selected_count"), ...
        val(B,"selected_count") - val(A,"selected_count"), classify_driver(A, B), delta_note(A, B), ...
        'VariableNames', {'parameter_set_id','candidate_branch','mean_probability_11_28','mean_probability_12_00','delta_probability', ...
        'mean_line_loading_11_28','mean_line_loading_12_00','delta_line_loading','mean_P_flow_11_28','mean_P_flow_12_00', ...
        'delta_P_flow','mean_P_HF_L_11_28','mean_P_HF_L_12_00','delta_P_HF_L','selected_count_11_28', ...
        'selected_count_12_00','delta_selected_count','probability_driver','note'});
end
D = vertcat(rows{:});
end

function v = val(T, name)
if isempty(T), v = NaN; else, v = T.(char(name))(1); end
end

function s = classify_driver(A, B)
if isempty(A) || isempty(B) || A.component_status(1) == "need_probability_component_trace_smoke" || B.component_status(1) == "need_probability_component_trace_smoke"
    s = "component_fields_missing";
elseif abs(val(B,"mean_line_loading_pu") - val(A,"mean_line_loading_pu")) > 1e-6
    s = "loading_driven";
elseif abs(val(B,"mean_P_HF_L") - val(A,"mean_P_HF_L")) > 1e-9
    s = "hidden_failure_driven";
elseif abs(val(B,"mean_candidate_probability") - val(A,"mean_candidate_probability")) > 1e-9
    s = "base_probability_driven";
else
    s = "no_clear_driver";
end
end

function s = delta_note(A, B)
if isempty(A) || isempty(B)
    s = "Missing one wind-speed side.";
else
    s = "Paired candidate-branch delta from existing after-curve-fix trace; diagnostic only.";
end
end
