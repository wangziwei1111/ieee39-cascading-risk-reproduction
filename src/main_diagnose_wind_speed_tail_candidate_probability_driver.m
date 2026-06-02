function main_diagnose_wind_speed_tail_candidate_probability_driver()
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
parameter_sets = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scenario_ids = ["wind_speed_11_28","wind_speed_12_00"];
metrics = ["SLLR","SLFOR","SNVOR","CRI"];
tail_path = fullfile(out_root, 'wind_speed_var_tail_attribution.csv');
if exist(tail_path, 'file') ~= 2
    error('Missing tail attribution table: %s', tail_path);
end
Tail = readtable(tail_path, 'TextType', 'string');
rows = {};
for p = 1:numel(parameter_sets)
    for s = 1:numel(scenario_ids)
        C = read_candidate_table(out_root, parameter_sets(p), scenario_ids(s));
        if isempty(C), continue; end
        for m = 1:numel(metrics)
            metric = metrics(m);
            Tm = Tail(Tail.parameter_set_id == parameter_sets(p) & Tail.scenario_id == scenario_ids(s) & Tail.metric_name == metric, :);
            if isempty(Tm), continue; end
            key = string(Tm.initial_branch) + "|" + string(Tm.trial_id);
            candidate_key = string(C.initial_branch) + "|" + string(C.trial_id);
            in_tail = ismember(candidate_key, key);
            G = C(in_tail, :);
            if isempty(G), continue; end
            ranks = candidate_probability_rank(G);
            for i = 1:height(G)
                rows{end+1,1} = table(parameter_sets(p), scenario_ids(s), metric, ...
                    G.initial_branch(i), G.trial_id(i), G.stage_id(i), G.candidate_branch(i), ...
                    G.loading_pu(i), G.candidate_probability(i), ranks(i), logical(G.selected(i)), ...
                    selected_contribution(G.candidate_probability(i), G.selected(i)), ...
                    string(G.prob_model(i)), get_optional(G, "engineering_probability", i), ...
                    get_optional(G, "paper_formula_probability", i), optional_string(G, "paper_formula_status", i), ...
                    optional_string(G, "paper_formula_missing_parameters", i), optional_logical(G, "paper_formula_used_fallback", i), ...
                    "candidate rows from chains in sigma=0.95 tail; diagnostic only", ...
                    'VariableNames', {'parameter_set_id','scenario_id','metric_name','initial_branch','trial_id','stage_id', ...
                    'candidate_branch','line_loading_pu','candidate_probability','candidate_probability_rank','selected', ...
                    'selected_probability_contribution','prob_model','engineering_probability','paper_formula_probability', ...
                    'paper_formula_status','paper_formula_missing_parameters','paper_formula_used_fallback','note'}); %#ok<AGROW>
            end
        end
    end
end
Driver = vertcat_or_empty(rows, driver_schema());
writetable(Driver, fullfile(out_root, 'wind_speed_tail_candidate_probability_driver.csv'));
Delta = build_delta(Driver);
writetable(Delta, fullfile(out_root, 'wind_speed_tail_candidate_probability_delta.csv'));
end

function C = read_candidate_table(out_root, ps, scenario)
path = fullfile(out_root, ps, scenario, 'tables', 'candidate_probability_trace.csv');
if exist(path, 'file') ~= 2
    path = fullfile(out_root, ps, scenario, 'tables', 'markov_candidate_details.csv');
end
if exist(path, 'file') ~= 2
    C = table();
else
    C = readtable(path, 'TextType', 'string');
end
end

function ranks = candidate_probability_rank(G)
ranks = nan(height(G), 1);
keys = unique(G(:, {'initial_branch','trial_id','stage_id'}), 'rows');
for k = 1:height(keys)
    mask = G.initial_branch == keys.initial_branch(k) & G.trial_id == keys.trial_id(k) & G.stage_id == keys.stage_id(k);
    idx = find(mask);
    [~, order] = sort(G.candidate_probability(idx), 'descend', 'MissingPlacement', 'last');
    ranks(idx(order)) = 1:numel(idx);
end
end

function v = selected_contribution(p, selected)
if logical(selected)
    v = p;
else
    v = 0;
end
end

function v = get_optional(T, name, i)
if ismember(name, string(T.Properties.VariableNames))
    v = T.(char(name))(i);
else
    v = NaN;
end
end

function v = optional_string(T, name, i)
if ismember(name, string(T.Properties.VariableNames))
    v = string(T.(char(name))(i));
else
    v = "";
end
end

function v = optional_logical(T, name, i)
if ismember(name, string(T.Properties.VariableNames))
    v = logical(T.(char(name))(i));
else
    v = false;
end
end

function T = vertcat_or_empty(rows, schema)
if isempty(rows)
    T = schema;
else
    T = vertcat(rows{:});
end
end

function T = driver_schema()
T = table(strings(0,1), strings(0,1), strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
    zeros(0,1), zeros(0,1), zeros(0,1), false(0,1), zeros(0,1), strings(0,1), zeros(0,1), zeros(0,1), ...
    strings(0,1), strings(0,1), false(0,1), strings(0,1), ...
    'VariableNames', {'parameter_set_id','scenario_id','metric_name','initial_branch','trial_id','stage_id', ...
    'candidate_branch','line_loading_pu','candidate_probability','candidate_probability_rank','selected', ...
    'selected_probability_contribution','prob_model','engineering_probability','paper_formula_probability', ...
    'paper_formula_status','paper_formula_missing_parameters','paper_formula_used_fallback','note'});
end

function Delta = build_delta(D)
if isempty(D)
    Delta = table();
    return;
end
keys = unique(D(:, {'parameter_set_id','metric_name','candidate_branch'}), 'rows');
rows = cell(height(keys), 1);
for i = 1:height(keys)
    mask = D.parameter_set_id == keys.parameter_set_id(i) & D.metric_name == keys.metric_name(i) & D.candidate_branch == keys.candidate_branch(i);
    A = D(mask & D.scenario_id == "wind_speed_11_28", :);
    B = D(mask & D.scenario_id == "wind_speed_12_00", :);
    p11 = mean(A.candidate_probability, 'omitnan');
    p12 = mean(B.candidate_probability, 'omitnan');
    s11 = sum(A.selected);
    s12 = sum(B.selected);
    delta_p = p12 - p11;
    delta_s = s12 - s11;
    rows{i} = table(keys.parameter_set_id(i), keys.metric_name(i), keys.candidate_branch(i), ...
        height(A), height(B), p11, p12, delta_p, s11, s12, delta_s, classify_effect(delta_p, delta_s), ...
        'VariableNames', {'parameter_set_id','metric_name','candidate_branch','tail_candidate_rows_11_28', ...
        'tail_candidate_rows_12_00','mean_tail_candidate_probability_11_28','mean_tail_candidate_probability_12_00', ...
        'delta_probability_12_minus_11','selected_tail_count_11_28','selected_tail_count_12_00', ...
        'delta_selected_count_12_minus_11','likely_effect'});
end
Delta = vertcat(rows{:});
end

function s = classify_effect(delta_p, delta_s)
if delta_p > 0 && delta_s > 0
    s = "higher_probability_and_selected_more_at_12mps";
elseif delta_p > 0
    s = "higher_candidate_probability_at_12mps";
elseif delta_s > 0
    s = "selected_more_at_12mps";
else
    s = "no_clear_tail_candidate_effect";
end
end
