function main_validate_paper_inputs(strict)
%MAIN_VALIDATE_PAPER_INPUTS 校验 paper_inputs/filled 下的原文参数文件。
% 输入：
%   strict - 可选。true时缺少 filled 文件直接报错；默认 false，仅记录 missing。
% 输出：
%   paper_inputs/validated/paper_input_validation_summary.csv
%   paper_inputs/logs/validate_paper_inputs_log.txt
% 物理含义：
%   防止后续实现 P_wt/P_ge/线路停运概率等模型时误用空模板或工程默认值。
if nargin < 1
    strict = false;
end

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();
require_matpower(cfg);
mpc = build_case39_base(cfg);

root = fullfile(project_root, 'paper_inputs');
filled_dir = fullfile(root, 'filled');
validated_dir = fullfile(root, 'validated');
log_dir = fullfile(root, 'logs');
ensure_dir(filled_dir);
ensure_dir(validated_dir);
ensure_dir(log_dir);

specs = build_specs();
rows = cell(numel(specs), 1);
for i = 1:numel(specs)
    rows{i} = validate_one(specs(i), filled_dir, mpc, strict);
end
summary = vertcat(rows{:});
writetable(summary, fullfile(validated_dir, 'paper_input_validation_summary.csv'));

log_file = fullfile(log_dir, 'validate_paper_inputs_log.txt');
fid = fopen(log_file, 'w', 'n', 'UTF-8');
cleaner = onCleanup(@() fclose(fid));
fprintf(fid, 'Paper input validation completed.\n');
fprintf(fid, 'strict=%d\n', logical(strict));
fprintf(fid, 'input_count=%d\n', height(summary));
fprintf(fid, 'missing_count=%d\n', sum(string(summary.status) == "missing"));
fprintf(fid, 'complete_or_validated_count=%d\n', sum(ismember(string(summary.status), ["complete","validated"])));
fprintf('Paper input validation completed: %s\n', log_file);
end

function specs = build_specs()
names = {
    'paper_system_summary.csv', 'system_summary'
    'paper_case39_bus.csv', 'bus'
    'paper_case39_gen.csv', 'gen'
    'paper_case39_branch.csv', 'branch'
    'paper_line_initial_outage_probability.csv', 'line_initial'
    'paper_line_subsequent_outage_model.csv', 'line_subsequent'
    'paper_wind_power_curve.csv', 'wind_power_curve'
    'paper_wind_trip_probability_model.csv', 'wind_trip'
    'paper_generator_outage_model.csv', 'generator_outage'
    'paper_state_probability_formula.csv', 'state_probability'
    'paper_risk_severity_formula.csv', 'risk_severity'
    'paper_scenario_definition.csv', 'scenario'
    'paper_result_benchmark.csv', 'benchmark'
    'paper_load_shedding_model.csv', 'load_shedding'
    };
for i = 1:size(names, 1)
    specs(i).file = names{i, 1}; %#ok<AGROW>
    specs(i).kind = names{i, 2}; %#ok<AGROW>
end
end

function row = validate_one(spec, filled_dir, mpc, strict)
path = fullfile(filled_dir, spec.file);
if ~exist(path, 'file')
    if strict
        error('缺少 filled 文件：%s', path);
    end
    row = make_row(spec.file, "missing", "", 0, false, "filled file not found");
    return;
end

tbl = readtable(path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
if height(tbl) == 0
    row = make_row(spec.file, "template_only", "", 0, false, "file exists but has no data rows");
    return;
end

switch spec.kind
    case 'system_summary'
        [status, missing, can_use, note] = validate_system_summary(tbl);
    case 'bus'
        [status, missing, can_use, note] = validate_case_table(tbl, {'bus_i','Pd','Qd'}, size(mpc.bus, 1), "bus table");
    case 'gen'
        [status, missing, can_use, note] = validate_case_table(tbl, {'gen_id','bus','Pmax','Pmin'}, size(mpc.gen, 1), "gen table");
    case 'branch'
        [status, missing, can_use, note] = validate_branch_table(tbl, mpc);
    case 'line_initial'
        [status, missing, can_use, note] = validate_line_initial(tbl, mpc);
    case {'line_subsequent','wind_trip','generator_outage'}
        [status, missing, can_use, note] = validate_formula_parameter_table(tbl);
    case 'load_shedding'
        [status, missing, can_use, note] = validate_load_shedding(tbl);
    case 'wind_power_curve'
        [status, missing, can_use, note] = validate_wind_power_curve(tbl);
    case 'state_probability'
        [status, missing, can_use, note] = validate_required_terms(tbl, 'probability_term', ...
            ["P_wt_Ek","P_ge_Ek","P_line_Ek","P_stage_Ek","P_chain"]);
    case 'risk_severity'
        [status, missing, can_use, note] = validate_required_terms(tbl, 'risk_term', ["LLR","LFOR","NVOR","CRI","VaR"]);
    case 'scenario'
        [status, missing, can_use, note] = validate_scenario(tbl);
    case 'benchmark'
        [status, missing, can_use, note] = validate_benchmark(tbl);
    otherwise
        status = "incomplete"; missing = "unknown spec"; can_use = false; note = "unknown input kind";
end
row = make_row(spec.file, status, missing, height(tbl), can_use, note);
end

function [status, missing, can_use, note] = validate_system_summary(tbl)
required_items = ["system_name","bus_count","branch_count","generator_count","slack_bus","total_load_mw","total_installed_capacity_mw"];
missing_items = setdiff(required_items, string(tbl.item));
missing = missing_columns_or_values(tbl, {'item','source_section'});
numeric_items = ["bus_count","branch_count","generator_count","slack_bus","total_load_mw","total_installed_capacity_mw"];
for k = 1:numel(numeric_items)
    idx = string(tbl.item) == numeric_items(k);
    if ~any(idx) || isnan(tbl.value(find(idx, 1)))
        missing = strjoin([string(missing), numeric_items(k) + " value"], "; ");
    end
end
if ~isempty(missing_items)
    missing = strjoin([string(missing), "missing items: " + strjoin(missing_items, "|")], "; ");
end
if strlength(strtrim(missing)) > 0
    status = "incomplete"; can_use = false; note = "system summary missing required thesis facts";
else
    status = "validated"; can_use = true; note = "system summary facts validated from filled table";
end
end

function [status, missing, can_use, note] = validate_load_shedding(tbl)
has_objective = ismember('objective_function', tbl.Properties.VariableNames) && ...
    any(strlength(strtrim(string(tbl.objective_function))) > 0);
has_constraints = ismember('constraint_formula', tbl.Properties.VariableNames) && ...
    any(strlength(strtrim(string(tbl.constraint_formula))) > 0);
missing_parts = strings(0, 1);
if ~has_objective
    missing_parts(end+1) = "objective_function";
end
if ~has_constraints
    missing_parts(end+1) = "constraint_formula";
end
if ismember('parameter_value', tbl.Properties.VariableNames) && any(is_missing_value(tbl.parameter_value))
    missing_parts(end+1) = "parameter_value value";
end
missing = strjoin(missing_parts, "; ");
if strlength(missing) > 0
    status = "incomplete"; can_use = false; note = "load shedding model structure recorded but numeric parameters are incomplete";
else
    status = "complete"; can_use = true; note = "load shedding model complete but still needs manual source review";
end
end

function [status, missing, can_use, note] = validate_case_table(tbl, keys, expected_rows, label)
missing = missing_columns_or_values(tbl, keys);
if strlength(missing) > 0
    status = "incomplete"; can_use = false; note = label + " missing required fields";
elseif height(tbl) ~= expected_rows
    status = "incomplete"; can_use = false; note = label + " row count differs from current case39; mark thesis_modified_case before use";
else
    status = "validated"; can_use = true; note = label + " validates against current case39 row count";
end
end

function [status, missing, can_use, note] = validate_branch_table(tbl, mpc)
[status, missing, can_use, note] = validate_case_table(tbl, {'branch_index','from_bus','to_bus','rateA'}, size(mpc.branch, 1), "branch table");
if status == "validated"
    if any(tbl.from_bus ~= mpc.branch(:,1)) || any(tbl.to_bus ~= mpc.branch(:,2))
        status = "incomplete"; can_use = false; note = "branch from/to does not match current case39 order";
    end
end
end

function [status, missing, can_use, note] = validate_line_initial(tbl, mpc)
missing = missing_columns_or_values(tbl, {'branch_index','from_bus','to_bus','initial_outage_probability'});
if height(tbl) ~= size(mpc.branch, 1)
    status = "incomplete"; can_use = false; note = "line probability row count must be 46";
elseif strlength(missing) > 0
    status = "incomplete"; can_use = false; note = "line initial probability missing required values";
elseif any(tbl.initial_outage_probability < 0 | isnan(tbl.initial_outage_probability))
    status = "incomplete"; can_use = false; note = "probability must be nonnegative and non-NaN";
elseif ismember('paper_prob_times_1e_minus_4', tbl.Properties.VariableNames) && ...
        any(abs(tbl.initial_outage_probability - tbl.paper_prob_times_1e_minus_4 * 1e-4) > 1e-12)
    status = "incomplete"; can_use = false; note = "paper_prob_times_1e_minus_4 inconsistent with initial_outage_probability";
else
    status = "validated"; can_use = true; note = "line initial outage probability validated";
end
end

function [status, missing, can_use, note] = validate_formula_parameter_table(tbl)
missing = missing_columns_or_values(tbl, {'formula_text','parameter_name','parameter_value'});
if strlength(missing) > 0
    status = "incomplete"; can_use = false; note = "formula or parameter values missing; do not use engineering defaults";
else
    status = "complete"; can_use = true; note = "formula table complete but still needs manual source review";
end
end

function [status, missing, can_use, note] = validate_wind_power_curve(tbl)
required_params = ["v_in","v_r","v_out","P_wr"];
missing_params = setdiff(required_params, string(tbl.parameter_name));
missing = missing_columns_or_values(tbl, {'parameter_name','formula_text','source_section'});
idx_numeric = ismember(string(tbl.parameter_name), ["v_in","v_r","v_out"]);
if any(idx_numeric)
    values = tbl.parameter_value(idx_numeric);
    if any(isnan(values))
        missing = strjoin([string(missing), "v_in/v_r/v_out value"], "; ");
    end
end
if ~isempty(missing_params)
    missing = strjoin([string(missing), "missing params: " + strjoin(missing_params, "|")], "; ");
end
if strlength(strtrim(missing)) > 0
    status = "incomplete"; can_use = false; note = "wind power curve missing required fields";
else
    status = "validated"; can_use = true; note = "wind power curve parameters recorded; P_wr is scenario-dependent";
end
end

function [status, missing, can_use, note] = validate_required_terms(tbl, term_col, required_terms)
missing_terms = setdiff(required_terms, string(tbl.(term_col)));
missing_values = missing_columns_or_values(tbl, {term_col,'formula_text','required_variables'});
parts = strings(0, 1);
if ~isempty(missing_terms)
    parts(end+1) = "missing terms: " + strjoin(missing_terms, "|");
end
if strlength(missing_values) > 0
    parts(end+1) = missing_values;
end
if isempty(parts)
    status = "complete"; can_use = true; missing = ""; note = "required formula terms complete";
else
    status = "incomplete"; can_use = false; missing = strjoin(parts, "; "); note = "required formula terms incomplete";
end
end

function [status, missing, can_use, note] = validate_scenario(tbl)
missing = missing_columns_or_values(tbl, {'scenario_id','scenario_type','penetration_definition','sample_count','confidence_levels'});
if strlength(missing) > 0
    status = "incomplete"; can_use = false; note = "scenario definition incomplete";
else
    status = "complete"; can_use = true; note = "scenario definition complete but needs manual thesis source review";
end
end

function [status, missing, can_use, note] = validate_benchmark(tbl)
missing = missing_columns_or_values(tbl, {'paper_figure_or_table','scenario_id','metric_name','paper_value'});
if strlength(missing) > 0
    status = "incomplete"; can_use = false; note = "benchmark values incomplete";
elseif benchmark_tables_complete(tbl)
    status = "complete"; can_use = true; note = "Table 4-2/4-4/4-5/4-6 benchmark rows complete";
else
    status = "complete"; can_use = true; note = "declared benchmark rows complete";
end
end

function tf = benchmark_tables_complete(tbl)
%BENCHMARK_TABLES_COMPLETE 检查本轮已声明录入的论文 benchmark 表是否行数完整。
% 物理含义：这里只检查论文原文 benchmark 数据层是否完整，不代表复现结果已经对齐。
tf = true;
tf = tf && check_benchmark_group(tbl, "Table 4-2", 2, 1, 4);
tf = tf && check_benchmark_group(tbl, "Table 4-4", 2, 3, 4);
tf = tf && check_benchmark_group(tbl, "Table 4-5", 9, 1, 4);
tf = tf && check_benchmark_group(tbl, "Table 4-6", 4, 1, 4);
end

function tf = check_benchmark_group(tbl, table_name, scenario_count, confidence_count, metric_count)
rows = string(tbl.paper_figure_or_table) == table_name;
if ~any(rows)
    tf = false;
    return;
end
sub = tbl(rows, :);
tf = height(sub) == scenario_count * confidence_count * metric_count;
tf = tf && numel(unique(string(sub.scenario_id))) == scenario_count;
tf = tf && numel(unique(sub.confidence_level)) == confidence_count;
tf = tf && numel(unique(string(sub.metric_name))) == metric_count;
tf = tf && all(~ismissing(sub.paper_value));
tf = tf && all(sub.paper_value >= 0);
tf = tf && all(string(sub.unit) == "10^-4");
end

function missing = missing_columns_or_values(tbl, cols)
missing_parts = strings(0, 1);
for i = 1:numel(cols)
    col = cols{i};
    if ~ismember(col, tbl.Properties.VariableNames)
        missing_parts(end+1) = string(col) + " column"; %#ok<AGROW>
    elseif any(is_missing_value(tbl.(col)))
        missing_parts(end+1) = string(col) + " value"; %#ok<AGROW>
    end
end
missing = strjoin(missing_parts, "; ");
end

function tf = is_missing_value(x)
if isnumeric(x)
    tf = isnan(x);
elseif iscell(x)
    tf = cellfun(@(v) isempty(v) || (ischar(v) && strlength(string(v)) == 0), x);
else
    sx = string(x);
    tf = ismissing(sx) | strlength(strtrim(sx)) == 0 | lower(strtrim(sx)) == "nan";
end
end

function row = make_row(file, status, missing, num_rows, can_use, note)
row = table(string(file), string(status), string(missing), num_rows, logical(can_use), string(note), ...
    'VariableNames', {'input_file','status','missing_fields','num_rows','can_use_for_implementation','note'});
end

function ensure_dir(path)
if ~exist(path, 'dir')
    mkdir(path);
end
end
