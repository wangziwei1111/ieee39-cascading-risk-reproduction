function main_diagnose_wind_speed_component_probability_delta()
root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun');
psets = ["high_hidden_failure","benchmark_calibrated_seed"];
rows = {};
for p = 1:numel(psets)
    A = summarize(readtable(fullfile(out_root, psets(p), 'wind_speed_11_28', 'tables', 'line_probability_component_trace.csv'), 'TextType', 'string'));
    B = summarize(readtable(fullfile(out_root, psets(p), 'wind_speed_12_00', 'tables', 'line_probability_component_trace.csv'), 'TextType', 'string'));
    branches = union(A.candidate_branch, B.candidate_branch);
    for b = reshape(branches, 1, [])
        a = A(A.candidate_branch == b, :); c = B(B.candidate_branch == b, :);
        rows{end+1,1} = table(psets(p), b, val(a,"P_L"), val(c,"P_L"), val(c,"P_L")-val(a,"P_L"), ...
            val(a,"P_flow"), val(c,"P_flow"), val(c,"P_flow")-val(a,"P_flow"), ...
            val(a,"P_HF_L"), val(c,"P_HF_L"), val(c,"P_HF_L")-val(a,"P_HF_L"), ...
            val(a,"P_mis_r"), val(c,"P_mis_r"), val(c,"P_mis_r")-val(a,"P_mis_r"), ...
            val(a,"P1"), val(c,"P1"), val(c,"P1")-val(a,"P1"), ...
            val(a,"P2"), val(c,"P2"), val(c,"P2")-val(a,"P2"), ...
            val(a,"line_loading_pu"), val(c,"line_loading_pu"), val(c,"line_loading_pu")-val(a,"line_loading_pu"), ...
            val(a,"selected_count"), val(c,"selected_count"), classify(a,c), "diagnostic component delta; not parameter tuning", ...
            'VariableNames', {'parameter_set_id','candidate_branch','mean_P_L_11_28','mean_P_L_12_00','delta_P_L', ...
            'mean_P_flow_11_28','mean_P_flow_12_00','delta_P_flow','mean_P_HF_L_11_28','mean_P_HF_L_12_00', ...
            'delta_P_HF_L','mean_P_mis_r_11_28','mean_P_mis_r_12_00','delta_P_mis_r','mean_P1_11_28','mean_P1_12_00', ...
            'delta_P1','mean_P2_11_28','mean_P2_12_00','delta_P2','mean_line_loading_11_28','mean_line_loading_12_00', ...
            'delta_line_loading','selected_count_11_28','selected_count_12_00','probability_driver','note'}); %#ok<AGROW>
    end
end
writetable(vertcat(rows{:}), fullfile(out_root, 'wind_speed_component_probability_delta.csv'));
end

function S = summarize(T)
branches = unique(T.candidate_branch);
rows = cell(numel(branches), 1);
for i = 1:numel(branches)
    G = T(T.candidate_branch == branches(i), :);
    rows{i} = table(branches(i), mean(G.P_L,'omitnan'), mean(G.P_flow,'omitnan'), mean(G.P_HF_L,'omitnan'), ...
        mean(G.P_mis_r,'omitnan'), mean(G.P1,'omitnan'), mean(G.P2,'omitnan'), mean(G.line_loading_pu,'omitnan'), sum(G.selected), ...
        'VariableNames', {'candidate_branch','P_L','P_flow','P_HF_L','P_mis_r','P1','P2','line_loading_pu','selected_count'});
end
S = vertcat(rows{:});
end

function v = val(T, name)
if isempty(T), v = NaN; else, v = T.(char(name))(1); end
end

function s = classify(A, B)
if isempty(A) || isempty(B)
    s = "insufficient_fields";
    return;
end
d = [val(B,"P_flow")-val(A,"P_flow"), val(B,"P_HF_L")-val(A,"P_HF_L"), val(B,"P_mis_r")-val(A,"P_mis_r"), ...
    val(B,"P1")-val(A,"P1"), val(B,"P2")-val(A,"P2"), val(B,"line_loading_pu")-val(A,"line_loading_pu")];
names = ["P_flow_increase","P_HF_L_increase","P_mis_r_increase","P1_increase","P2_increase","line_loading_increase"];
pos = d > 1e-9;
if sum(pos) > 1
    s = "mixed_probability_increase";
elseif any(pos)
    s = names(find(pos,1));
else
    s = "no_probability_increase";
end
end
