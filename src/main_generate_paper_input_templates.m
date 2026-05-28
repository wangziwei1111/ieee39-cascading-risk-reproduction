function main_generate_paper_input_templates(run_options)
%MAIN_GENERATE_PAPER_INPUT_TEMPLATES 生成原文参数录入模板。
% 输入：
%   run_options.force_overwrite_templates - 可选，true时覆盖已有模板。
% 输出：
%   paper_inputs/templates/*.csv
%   paper_inputs/logs/generate_paper_input_templates_log.txt
% 物理含义：
%   为后续人工录入论文原文公式、参数、场景和结果建立统一数据入口。
%   bus/gen/branch 模板含 MATPOWER case39 当前值，仅作参考，不代表原文已确认。
if nargin < 1
    run_options = struct();
end
if ~isfield(run_options, 'force_overwrite_templates')
    run_options.force_overwrite_templates = false;
end

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();
require_matpower(cfg);
mpc = build_case39_base(cfg);

root = fullfile(project_root, 'paper_inputs');
template_dir = fullfile(root, 'templates');
ensure_dir(template_dir);
ensure_dir(fullfile(root, 'filled'));
ensure_dir(fullfile(root, 'validated'));
ensure_dir(fullfile(root, 'logs'));

write_if_needed(fullfile(template_dir, 'paper_case39_bus_template.csv'), build_bus_template(mpc), run_options.force_overwrite_templates);
write_if_needed(fullfile(template_dir, 'paper_case39_gen_template.csv'), build_gen_template(mpc), run_options.force_overwrite_templates);
write_if_needed(fullfile(template_dir, 'paper_case39_branch_template.csv'), build_branch_template(mpc), run_options.force_overwrite_templates);
write_if_needed(fullfile(template_dir, 'paper_line_initial_outage_probability_template.csv'), build_line_initial_template(mpc), run_options.force_overwrite_templates);
write_if_needed(fullfile(template_dir, 'paper_line_subsequent_outage_model_template.csv'), build_line_subsequent_template(), run_options.force_overwrite_templates);
write_if_needed(fullfile(template_dir, 'paper_wind_trip_probability_model_template.csv'), build_wind_trip_template(), run_options.force_overwrite_templates);
write_if_needed(fullfile(template_dir, 'paper_generator_outage_model_template.csv'), build_generator_outage_template(), run_options.force_overwrite_templates);
write_if_needed(fullfile(template_dir, 'paper_state_probability_formula_template.csv'), build_state_probability_template(), run_options.force_overwrite_templates);
write_if_needed(fullfile(template_dir, 'paper_risk_severity_formula_template.csv'), build_risk_severity_template(), run_options.force_overwrite_templates);
write_if_needed(fullfile(template_dir, 'paper_scenario_definition_template.csv'), build_scenario_template(), run_options.force_overwrite_templates);
write_if_needed(fullfile(template_dir, 'paper_result_benchmark_template.csv'), build_result_benchmark_template(), run_options.force_overwrite_templates);
write_if_needed(fullfile(template_dir, 'paper_load_shedding_model_template.csv'), build_load_shedding_template(), run_options.force_overwrite_templates);

log_file = fullfile(root, 'logs', 'generate_paper_input_templates_log.txt');
fid = fopen(log_file, 'w', 'n', 'UTF-8');
cleaner = onCleanup(@() fclose(fid));
fprintf(fid, 'Paper input templates generated.\n');
fprintf(fid, 'force_overwrite_templates=%d\n', logical(run_options.force_overwrite_templates));
fprintf(fid, 'template_dir=%s\n', template_dir);
fprintf(fid, 'bus_rows=%d\n', size(mpc.bus, 1));
fprintf(fid, 'gen_rows=%d\n', size(mpc.gen, 1));
fprintf(fid, 'branch_rows=%d\n', size(mpc.branch, 1));
fprintf('Paper input templates generated: %s\n', log_file);
end

function tbl = build_bus_template(mpc)
note = repmat("MATPOWER case39 reference; replace if thesis differs", size(mpc.bus, 1), 1);
tbl = array2table(mpc.bus(:, 1:13), 'VariableNames', ...
    {'bus_i','type','Pd','Qd','Gs','Bs','area','Vm','Va','baseKV','zone','Vmax','Vmin'});
tbl.source_note = note;
end

function tbl = build_gen_template(mpc)
cols = {'bus','Pg','Qg','Qmax','Qmin','Vg','mBase','status','Pmax','Pmin'};
tbl = array2table(mpc.gen(:, 1:10), 'VariableNames', cols);
tbl = addvars(tbl, (1:height(tbl)).', 'Before', 1, 'NewVariableNames', 'gen_id');
tbl.source_note = repmat("MATPOWER case39 reference; replace if thesis differs", height(tbl), 1);
end

function tbl = build_branch_template(mpc)
vars = {'from_bus','to_bus','r','x','b','rateA','rateB','rateC','ratio','angle','status','angmin','angmax'};
tbl = array2table(mpc.branch(:, 1:13), 'VariableNames', vars);
tbl = addvars(tbl, (1:height(tbl)).', 'Before', 1, 'NewVariableNames', 'branch_index');
tbl.source_note = repmat("MATPOWER case39 reference; replace if thesis differs", height(tbl), 1);
end

function tbl = build_line_initial_template(mpc)
tbl = table((1:size(mpc.branch, 1)).', mpc.branch(:, 1), mpc.branch(:, 2), ...
    nan(size(mpc.branch, 1), 1), nan(size(mpc.branch, 1), 1), ...
    repmat("fill from thesis Table 4-1; do not guess", size(mpc.branch, 1), 1), ...
    'VariableNames', {'branch_index','from_bus','to_bus','paper_prob_times_1e_minus_4','initial_outage_probability','source_note'});
end

function tbl = build_line_subsequent_template()
tbl = table("", "", "", "", NaN, "", "", "fill from thesis line subsequent outage probability model; do not use engineering approximation", ...
    'VariableNames', {'model_name','loading_variable','formula_text','parameter_name','parameter_value','unit','source_equation','source_note'});
end

function tbl = build_wind_trip_template()
tbl = table("", "", "", "", NaN, "", "", "fill from thesis P_WT(h) or protection model; do not use diagnostic thresholds", ...
    'VariableNames', {'model_name','input_variable','formula_text','parameter_name','parameter_value','unit','source_equation','source_note'});
end

function tbl = build_generator_outage_template()
tbl = table("", "", "", "", "", NaN, "", "", "fill from thesis P_G(q) or generator protection model; do not guess", ...
    'VariableNames', {'model_name','generator_type','input_variable','formula_text','parameter_name','parameter_value','unit','source_equation','source_note'});
end

function tbl = build_state_probability_template()
terms = ["P_wt_Ek"; "P_ge_Ek"; "P_line_Ek"; "P_stage_Ek"; "P_chain"];
tbl = table(terms, repmat("", 5, 1), repmat("", 5, 1), repmat("missing", 5, 1), ...
    repmat("", 5, 1), repmat("fill exact thesis formula; current engineering implementation is not validated", 5, 1), ...
    'VariableNames', {'probability_term','formula_text','required_variables','current_status','source_equation','source_note'});
end

function tbl = build_risk_severity_template()
terms = ["LLR"; "LFOR"; "NVOR"; "CRI"; "VaR"];
tbl = table(terms, repmat("", 5, 1), repmat("", 5, 1), repmat("missing", 5, 1), ...
    repmat("", 5, 1), repmat("current project has line-only implementation; fill and verify exact thesis formula", 5, 1), ...
    'VariableNames', {'risk_term','formula_text','required_variables','current_status','source_equation','source_note'});
end

function tbl = build_scenario_template()
tbl = table("", "", "", "", "", "", "", NaN, NaN, "", NaN, NaN, "", ...
    "fill from thesis Chapter 4 scenario definition; do not infer missing values", ...
    'VariableNames', {'scenario_id','paper_section','scenario_type','renewable_dispatch_mode','wind_buses','centralized_bus','distributed_buses','total_wind_capacity_mw','penetration_ratio','penetration_definition','wind_speed_mps','sample_count','confidence_levels','source_note'});
end

function tbl = build_result_benchmark_template()
tbl = table("", "", "", NaN, NaN, "", "fill from thesis Chapter 4 figure/table values; leave blank if unreadable", ...
    'VariableNames', {'paper_figure_or_table','scenario_id','metric_name','confidence_level','paper_value','unit','source_note'});
end

function tbl = build_load_shedding_template()
tbl = table("", "", "", "", "", NaN, "", "", "fill from thesis load shedding or loss-of-load model; do not use simple_load_shedding as paper model", ...
    'VariableNames', {'model_name','objective_function','constraint_name','constraint_formula','parameter_name','parameter_value','unit','source_equation','source_note'});
end

function write_if_needed(path, tbl, force_overwrite)
if exist(path, 'file') && ~force_overwrite
    return;
end
writetable(tbl, path);
end

function ensure_dir(path)
if ~exist(path, 'dir')
    mkdir(path);
end
end
