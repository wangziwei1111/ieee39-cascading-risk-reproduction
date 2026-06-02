function main_compare_wind_speed_component_diagnostic_to_paper()
root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun');
V = readtable(fullfile(out_root, 'wind_speed_component_diagnostic_var_metrics.csv'), 'TextType', 'string');
target_path = fullfile(root, 'results', 'calibration', 'diagnostics', 'calibration_target_benchmark_candidate_v2.csv');
if exist(target_path, 'file') ~= 2
    target_path = fullfile(root, 'paper_inputs', 'filled', 'calibration_target_benchmark.csv');
end
T = readtable(target_path, 'TextType', 'string');
psets = unique(V.parameter_set_id);
scens = ["wind_speed_11_28","wind_speed_12_00"];
metrics = ["SLLR","SLFOR","SNVOR","CRI"];
rows = {};
for p = 1:numel(psets)
    for s = 1:numel(scens)
        for m = 1:numel(metrics)
            sim = V(V.parameter_set_id==psets(p) & V.scenario_id==scens(s) & V.metric_name==metrics(m) & abs(V.sigma-0.95)<1e-9, :);
            paper = lookup_paper(T, scens(s), metrics(m));
            simv = NaN; if ~isempty(sim), simv = sim.var_value(1); end
            rows{end+1,1} = table(psets(p), scens(s), metrics(m), paper, simv, simv-paper, ...
                (simv-paper)/(abs(paper)+1e-6), paper/(simv+1e-6), status(paper, simv), ...
                "raw diagnostic comparison; not formal benchmark; benchmark_calibrated is not original paper", ...
                'VariableNames', {'parameter_set_id','scenario_id','metric_name','paper_value','sim_var_value','absolute_gap', ...
                'relative_gap','ratio_paper_to_sim','direction_status','note'}); %#ok<AGROW>
        end
    end
end
writetable(vertcat(rows{:}), fullfile(out_root, 'wind_speed_component_diagnostic_to_paper_gap.csv'));
end

function v = lookup_paper(T, scenario_id, metric)
v = NaN;
vars = string(T.Properties.VariableNames);
scenario_fields = ["scenario_id","paper_scenario_id"];
metric_fields = ["metric_name"];
value_fields = ["paper_value","target_value"];
sf = first_present(vars, scenario_fields); mf = first_present(vars, metric_fields); vf = first_present(vars, value_fields);
if sf == "" || mf == "" || vf == "", return; end
mask = contains(string(T.(char(sf))), erase(scenario_id, "wind_speed_")) | string(T.(char(sf))) == scenario_id;
mask = mask & string(T.(char(mf))) == metric;
if any(mask), v = T.(char(vf))(find(mask,1)); end
end

function f = first_present(vars, fields)
f = "";
for i = 1:numel(fields)
    if any(vars == fields(i)), f = fields(i); return; end
end
end

function s = status(paper, simv)
if isnan(paper) || isnan(simv)
    s = "missing_target_or_sim";
elseif simv > paper
    s = "sim_higher_than_paper";
else
    s = "sim_not_higher_than_paper";
end
end
