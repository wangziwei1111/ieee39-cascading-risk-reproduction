function [score, detail_table] = compute_benchmark_calibration_error(sim_table, target_table, cfg)
%COMPUTE_BENCHMARK_CALIBRATION_ERROR Weighted relative-error objective.
if nargin < 3
    cfg = struct();
end
epsilon = get_cfg(cfg, 'calibration_error_epsilon', 1e-6);

rows = cell(height(target_table), 1);
valid_weighted_error = [];
for i = 1:height(target_table)
    target_group = string(target_table.target_group(i));
    scenario_id = string(target_table.scenario_id(i));
    metric_name = string(target_table.metric_name(i));
    paper_value = target_table.paper_value(i);
    weight = target_table.weight(i);

    match = sim_table(string(sim_table.target_group) == target_group & ...
        string(sim_table.scenario_id) == scenario_id & ...
        string(sim_table.metric_name) == metric_name, :);
    if isempty(match) || isnan(match.sim_value(1)) || isnan(paper_value)
        sim_value = NaN;
        relative_error = NaN;
        weighted_error = NaN;
        match_status = "missing";
        note = "missing sim or paper value; excluded from score";
    else
        sim_value = match.sim_value(1);
        relative_error = (sim_value - paper_value) / (abs(paper_value) + epsilon);
        weighted_error = weight * relative_error^2;
        valid_weighted_error(end + 1, 1) = weighted_error; %#ok<AGROW>
        match_status = "matched";
        note = "";
    end
    rows{i} = table(target_group, scenario_id, metric_name, paper_value, sim_value, ...
        relative_error, weight, weighted_error, match_status, note, ...
        'VariableNames', {'target_group','scenario_id','metric_name','paper_value','sim_value', ...
        'relative_error','weight','weighted_error','match_status','note'});
end
detail_table = vertcat(rows{:});
if isempty(valid_weighted_error)
    score = NaN;
else
    score = mean(valid_weighted_error);
end
end

function value = get_cfg(cfg, name, default_value)
if isfield(cfg, name)
    value = cfg.(name);
else
    value = default_value;
end
end
