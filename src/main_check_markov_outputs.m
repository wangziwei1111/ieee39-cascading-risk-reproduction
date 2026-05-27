function main_check_markov_outputs()
%MAIN_CHECK_MARKOV_OUTPUTS Check Markov, candidate, VaR and severity outputs.
% 输入：
%   无。读取results目录下已经生成的CSV文件。
% 输出：
%   无。检查失败时报错；检查通过时打印中文自检报告。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

cfg = base_config();
cfg.results_table_dir = fullfile(project_root, cfg.results_table_dir);

summary_path = fullfile(cfg.results_table_dir, 'markov_chain_summary.csv');
stage_path = fullfile(cfg.results_table_dir, 'markov_chain_stages.csv');
candidate_path = fullfile(cfg.results_table_dir, 'markov_candidate_details.csv');
candidate_sample_path = fullfile(cfg.results_table_dir, 'markov_candidate_details_sample.csv');
candidate_summary_path = fullfile(cfg.results_table_dir, 'markov_candidate_summary.csv');
candidate_manifest_path = fullfile(cfg.results_table_dir, 'markov_candidate_details_manifest.csv');
candidate_chunk_dir = fullfile(cfg.results_table_dir, 'candidate_chunks');
risk_sample_path = fullfile(cfg.results_table_dir, 'markov_risk_samples.csv');
var_path = fullfile(cfg.results_table_dir, 'markov_var_metrics.csv');
by_initial_path = fullfile(cfg.results_table_dir, 'markov_var_by_initial_fault.csv');
severity_status_path = fullfile(cfg.results_table_dir, 'severity_formula_status.csv');

must_exist(summary_path);
must_exist(stage_path);
must_exist(candidate_path);
must_exist(candidate_sample_path);
must_exist(candidate_summary_path);
must_exist(candidate_manifest_path);
must_exist(risk_sample_path);
must_exist(var_path);
must_exist(by_initial_path);

summary_table = readtable(summary_path);
stage_table = readtable(stage_path);
candidate_sample_table = readtable(candidate_sample_path);
candidate_summary_table = readtable(candidate_summary_path);
candidate_manifest_table = readtable(candidate_manifest_path);
risk_samples = readtable(risk_sample_path);
var_table = readtable(var_path);
by_initial_table = readtable(by_initial_path);

expected_summary_rows = 46 * cfg.markov_num_trials_per_initial_fault;
if height(summary_table) ~= expected_summary_rows
    error('markov_chain_summary.csv行数应为%d，实际为%d。', expected_summary_rows, height(summary_table));
end
if isempty(stage_table)
    error('markov_chain_stages.csv为空。');
end
if isempty(candidate_sample_table)
    error('markov_candidate_details_sample.csv为空。');
end
if isempty(candidate_summary_table)
    error('markov_candidate_summary.csv为空。');
end
if isempty(candidate_manifest_table)
    error('markov_candidate_details_manifest.csv为空。');
end
if ~exist(candidate_chunk_dir, 'dir')
    error('candidate_chunks目录不存在：%s', candidate_chunk_dir);
end

required_candidate_columns = {'initial_branch', 'trial_id', 'stage_id', 'candidate_branch', ...
    'from_bus', 'to_bus', 'loading_pu', 'outage_probability', 'random_u', 'trip_selected'};
[full_candidate_ok, full_candidate_rows] = validate_full_candidate_csv( ...
    candidate_path, cfg, stage_table, required_candidate_columns);
[chunk_total_rows, chunk_selected_count, chunk_max_loading, chunk_max_probability] = ...
    validate_candidate_chunks_from_manifest(candidate_chunk_dir, candidate_manifest_table, ...
    candidate_summary_table, cfg, required_candidate_columns);

if height(risk_samples) ~= height(summary_table)
    error('markov_risk_samples.csv行数应与markov_chain_summary.csv一致。');
end
validate_basic_severity_fields(risk_samples, cfg, 'markov_risk_samples.csv');
severity_status_message = check_severity_status_table(severity_status_path, cfg);
if isfield(cfg, 'paper_severity_formula_confirmed') && cfg.paper_severity_formula_confirmed
    severity_status_message = "严重度公式状态表已检查：paper_formula已确认，允许输出有效paper结果。";
end

required_sigmas = cfg.var_confidence_levels(:);
for i = 1:numel(required_sigmas)
    if ~any(abs(var_table.sigma - required_sigmas(i)) < 1e-12)
        error('markov_var_metrics.csv缺少sigma=%.2f。', required_sigmas(i));
    end
end
if height(by_initial_table) ~= 46
    error('markov_var_by_initial_fault.csv应包含46条初始线路，实际为%d。', height(by_initial_table));
end

[paper_validated_status, weighted_status] = check_optional_weighted_outputs(cfg);
paper_severity_status = check_optional_paper_severity_outputs(cfg);

fprintf('Markov输出自检通过。\n');
fprintf('markov_chain_summary行数：%d\n', height(summary_table));
fprintf('markov_chain_stages行数：%d\n', height(stage_table));
if full_candidate_ok
    fprintf('full candidate CSV行数：%d\n', full_candidate_rows);
else
    fprintf('full candidate CSV读取异常，已使用chunks完成校验。\n');
end
fprintf('chunk文件数量：%d\n', height(candidate_manifest_table));
fprintf('chunk总行数：%d\n', chunk_total_rows);
fprintf('candidate_summary总行数：%d\n', candidate_summary_table.total_candidate_rows(1));
fprintf('candidate_details_sample行数：%d\n', height(candidate_sample_table));
fprintf('trip_selected=1数量：%d\n', chunk_selected_count);
fprintf('max loading_pu：%.6f\n', chunk_max_loading);
fprintf('max outage_probability：%.6f\n', chunk_max_probability);
fprintf('markov_risk_samples行数：%d\n', height(risk_samples));
fprintf('markov_var_metrics sigma列表：%s\n', mat2str(var_table.sigma'));
fprintf('markov_var_metrics行数：%d\n', height(var_table));
fprintf('markov_var_by_initial_fault行数：%d\n', height(by_initial_table));
fprintf('%s\n', severity_status_message);
fprintf('%s\n', paper_validated_status);
fprintf('%s\n', weighted_status);
fprintf('%s\n', paper_severity_status);
end

function must_exist(path_text)
if ~exist(path_text, 'file')
    error('缺少输出文件：%s', path_text);
end
end

function [full_ok, row_count] = validate_full_candidate_csv(candidate_path, cfg, stage_table, required_columns)
full_ok = true;
row_count = 0;
file_info = dir(candidate_path);
if isempty(file_info) || file_info.bytes < 100
    warning('markov_candidate_details.csv文件过小，将依赖chunks检查。');
    full_ok = false;
    return;
end
candidate_table = readtable(candidate_path);
row_count = height(candidate_table);
if isempty(candidate_table)
    warning('full markov_candidate_details.csv读回为空，将依赖chunks检查。');
    full_ok = false;
    return;
end
missing_columns = setdiff(required_columns, candidate_table.Properties.VariableNames);
if ~isempty(missing_columns)
    warning('full markov_candidate_details.csv缺少列：%s，将依赖chunks检查。', strjoin(missing_columns, ', '));
    full_ok = false;
    return;
end
validate_candidate_values(candidate_table, cfg, stage_table, 'full markov_candidate_details.csv');
end

function validate_candidate_values(candidate_table, cfg, stage_table, label)
if height(candidate_table) <= height(stage_table)
    error('%s行数%d应大于事故链逐级状态行数%d。', label, height(candidate_table), height(stage_table));
end
if max(candidate_table.outage_probability) <= cfg.line_outage_p0
    error('%s最大停运概率未高于基础概率line_outage_p0。', label);
end
if ~any(candidate_table.trip_selected == 1)
    error('%s中不存在trip_selected=1的记录。', label);
end
if any(candidate_table.random_u < 0 | candidate_table.random_u > 1)
    error('%s中random_u存在[0,1]以外的值。', label);
end
if any(candidate_table.outage_probability < 0 | candidate_table.outage_probability > 1)
    error('%s中outage_probability存在[0,1]以外的值。', label);
end
if any(candidate_table.loading_pu < 0)
    error('%s中loading_pu存在负值。', label);
end
end

function [total_rows, selected_count, max_loading, max_probability] = validate_candidate_chunks_from_manifest( ...
    chunk_dir, manifest_table, summary_table, cfg, required_columns)
total_rows = 0;
selected_count = 0;
max_loading = -Inf;
max_probability = -Inf;
for i = 1:height(manifest_table)
    chunk_path = fullfile(chunk_dir, char(manifest_table.file_name(i)));
    if ~exist(chunk_path, 'file')
        error('manifest记录的chunk文件不存在：%s', chunk_path);
    end
    bytes = get_file_bytes(chunk_path);
    if bytes < 100
        error('chunk文件过小：%s (%d bytes)', chunk_path, bytes);
    end
    chunk = readtable(chunk_path);
    missing_columns = setdiff(required_columns, chunk.Properties.VariableNames);
    if ~isempty(missing_columns)
        error('chunk文件缺少列：%s，文件：%s', strjoin(missing_columns, ', '), chunk_path);
    end
    if height(chunk) ~= manifest_table.row_count(i)
        error('chunk行数与manifest不一致：%s', chunk_path);
    end
    validate_candidate_values(chunk, cfg, table(), sprintf('chunk %s', chunk_path));
    total_rows = total_rows + height(chunk);
    selected_count = selected_count + sum(chunk.trip_selected == 1);
    max_loading = max(max_loading, max(chunk.loading_pu));
    max_probability = max(max_probability, max(chunk.outage_probability));
end
if total_rows ~= summary_table.total_candidate_rows(1)
    error('chunk总行数%d与candidate_summary总行数%d不一致。', total_rows, summary_table.total_candidate_rows(1));
end
if selected_count <= 0
    error('所有chunk中都没有trip_selected=1记录。');
end
if max_probability <= cfg.line_outage_p0
    error('所有chunk中的最大停运概率未高于基础概率line_outage_p0。');
end
end

function validate_basic_severity_fields(risk_samples, cfg, label)
required_basic = {'basic_LLR', 'basic_LFOR', 'basic_NVOR', 'basic_CRI'};
missing_basic = setdiff(required_basic, risk_samples.Properties.VariableNames);
if ~isempty(missing_basic)
    error('%s缺少basic严重度字段：%s', label, strjoin(missing_basic, ', '));
end
required_chain = {'chain_LLR', 'chain_LFOR', 'chain_NVOR', 'chain_CRI'};
if all(ismember(required_chain, risk_samples.Properties.VariableNames))
    pairs = {'LLR', 'LFOR', 'NVOR', 'CRI'};
    for i = 1:numel(pairs)
        basic_field = ['basic_', pairs{i}];
        chain_field = ['chain_', pairs{i}];
        if any(abs(risk_samples.(basic_field) - risk_samples.(chain_field)) > 1e-12)
            error('%s中%s必须与%s一致。', label, chain_field, basic_field);
        end
    end
end
if isfield(cfg, 'paper_severity_formula_confirmed') && ~cfg.paper_severity_formula_confirmed && ...
        ismember('paper_CRI', risk_samples.Properties.VariableNames) && any(~isnan(risk_samples.paper_CRI))
    error('论文严重度公式未确认时，不允许存在有效paper_CRI输出。');
end
end

function [paper_status, weighted_status] = check_optional_weighted_outputs(cfg)
validated_path = fullfile(cfg.results_table_dir, 'paper_table_4_1_probability_validated.csv');
weighted_samples_path = fullfile(cfg.results_table_dir, 'markov_risk_samples_weighted.csv');
weighted_var_path = fullfile(cfg.results_table_dir, 'markov_var_metrics_weighted.csv');
weighted_by_initial_path = fullfile(cfg.results_table_dir, 'markov_var_by_initial_fault_weighted.csv');
comparison_path = fullfile(cfg.results_table_dir, 'var_uniform_vs_weighted_comparison.csv');

if exist(validated_path, 'file')
    validated = readtable(validated_path);
    if height(validated) ~= 46
        error('paper_table_4_1_probability_validated.csv应包含46行。');
    end
    paper_status = "表4-1校验文件存在：46行。";
else
    paper_status = "表4-1未填写或未通过校验，加权VaR尚未运行。";
end

if exist(weighted_samples_path, 'file') || exist(weighted_var_path, 'file') || exist(weighted_by_initial_path, 'file')
    must_exist(weighted_samples_path);
    must_exist(weighted_var_path);
    must_exist(weighted_by_initial_path);
    evalc('main_check_paper_table_4_1_consistency');
    weighted_samples = readtable(weighted_samples_path);
    validate_basic_severity_fields(weighted_samples, cfg, 'markov_risk_samples_weighted.csv');
    weighted_var = readtable(weighted_var_path);
    weighted_by_initial = readtable(weighted_by_initial_path);
    if abs(sum(weighted_samples.sample_weight) - 1) > 1e-10
        error('markov_risk_samples_weighted.csv的sample_weight总和不为1。');
    end
    for i = 1:numel(cfg.var_confidence_levels)
        if ~any(abs(weighted_var.sigma - cfg.var_confidence_levels(i)) < 1e-12)
            error('markov_var_metrics_weighted.csv缺少sigma=%.2f。', cfg.var_confidence_levels(i));
        end
    end
    if height(weighted_by_initial) ~= 46
        error('markov_var_by_initial_fault_weighted.csv应包含46行。');
    end
    weighted_status = "表4-1源数据已填写；表4-1源数据与validated结果一致；weighted risk sample 权重一致；sample_weight总和=1。";
else
    weighted_status = "表4-1未填写，加权VaR尚未运行。";
end

if exist(comparison_path, 'file')
    comparison = readtable(comparison_path);
    if height(comparison) ~= numel(cfg.var_confidence_levels)
        error('var_uniform_vs_weighted_comparison.csv行数应等于置信水平数量。');
    end
end
end

function status_message = check_severity_status_table(severity_status_path, cfg)
if ~exist(severity_status_path, 'file')
    status_message = "severity_formula_status.csv尚未生成。";
    return;
end
status_table = readtable(severity_status_path);
required = {'severity_type', 'status', 'note'};
missing = setdiff(required, status_table.Properties.VariableNames);
if ~isempty(missing)
    error('severity_formula_status.csv缺少字段：%s', strjoin(missing, ', '));
end
severity_type = string(status_table.severity_type);
status = string(status_table.status);
if ~any(severity_type == "basic" & status == "available")
    error('severity_formula_status.csv必须说明basic严重度可用。');
end
if isfield(cfg, 'paper_severity_formula_confirmed') && ~cfg.paper_severity_formula_confirmed && ...
        any(severity_type == "paper_formula" & status == "available")
    error('论文严重度公式未确认时，severity_formula_status.csv不能标记paper_formula可用。');
end
status_message = "严重度公式状态表已检查：paper_formula尚未确认时不会输出有效paper结果。";
end
function paper_status = check_optional_paper_severity_outputs(cfg)
%CHECK_OPTIONAL_PAPER_SEVERITY_OUTPUTS 检查paper_formula严重度输出与分块归档。
sample_path = fullfile(cfg.results_table_dir, 'markov_risk_samples_paper_severity.csv');
var_path = fullfile(cfg.results_table_dir, 'markov_var_metrics_paper_severity.csv');
by_initial_path = fullfile(cfg.results_table_dir, 'markov_var_by_initial_fault_paper_severity.csv');
line_detail_path = fullfile(cfg.results_table_dir, 'markov_line_flow_details.csv');
bus_detail_path = fullfile(cfg.results_table_dir, 'markov_bus_voltage_details.csv');
stage_prob_path = fullfile(cfg.results_table_dir, 'markov_stage_probability_details.csv');
stage_summary_path = fullfile(cfg.results_table_dir, 'markov_stage_probability_summary.csv');
invalid_stage_path = fullfile(cfg.results_table_dir, 'markov_paper_invalid_stage_details.csv');
invalid_stage_summary_path = fullfile(cfg.results_table_dir, 'markov_paper_invalid_stage_summary.csv');
comparison_path = fullfile(cfg.results_table_dir, 'basic_vs_paper_severity_comparison.csv');
chunk_dir = fullfile(cfg.results_table_dir, 'paper_detail_chunks');

any_paper_file = exist(sample_path, 'file') || exist(var_path, 'file') || ...
    exist(by_initial_path, 'file') || exist(line_detail_path, 'file') || ...
    exist(bus_detail_path, 'file') || exist(stage_prob_path, 'file');
if ~any_paper_file
    paper_status = "paper_formula严重度结果尚未生成。";
    return;
end

project_root = fileparts(fileparts(mfilename('fullpath')));
must_exist(fullfile(project_root, 'src', 'paper', 'build_markov_paper_detail_tables.m'));
must_exist(fullfile(project_root, 'src', 'paper', 'summarize_paper_detail_tables.m'));
must_exist(fullfile(project_root, 'src', 'paper', 'build_paper_detail_samples.m'));

line_rows = validate_paper_detail_chunks(cfg, chunk_dir, 'markov_line_flow_details', ...
    {'P_li_pu', 'line_overlimit_component', 'line_severity_component'}, 'line');
bus_rows = validate_paper_detail_chunks(cfg, chunk_dir, 'markov_bus_voltage_details', ...
    {'voltage_pu', 'voltage_deviation_component', 'voltage_severity_component'}, 'bus');
validate_paper_detail_summaries(cfg);

must_exist(sample_path);
must_exist(var_path);
must_exist(by_initial_path);
must_exist(stage_prob_path);
must_exist(stage_summary_path);
must_exist(invalid_stage_path);
must_exist(invalid_stage_summary_path);
paper_samples = readtable(sample_path);
paper_var = readtable(var_path);
paper_by_initial = readtable(by_initial_path);
stage_prob = readtable(stage_prob_path);
stage_summary = readtable(stage_summary_path);
invalid_stage_summary = readtable(invalid_stage_summary_path);

if isempty(stage_prob)
    error('markov_stage_probability_details.csv不能为空。');
end
if any(isnan(stage_prob.stage_cumulative_probability)) || any(stage_prob.stage_cumulative_probability < 0)
    error('stage_cumulative_probability不能为NaN或负数。');
end
if ~all(contains(string(stage_prob.probability_source), "paper_table_4_1_initial_probability") | ...
        contains(string(stage_prob.probability_source), "uniform_initial_probability"))
    error('stage_probability_details中的probability_source缺少初始概率来源说明。');
end
if isempty(stage_summary) || stage_summary.total_rows(1) ~= height(stage_prob)
    error('markov_stage_probability_summary.csv与stage_probability_details行数不一致。');
end
if isempty(invalid_stage_summary)
    error('markov_paper_invalid_stage_summary.csv不能为空。');
end
if invalid_stage_summary.invalid_stage_ratio(1) > cfg.paper_max_invalid_chain_ratio_for_var && ...
        ismember('result_status', paper_var.Properties.VariableNames) && any(string(paper_var.result_status) == "valid")
    error('无效stage比例超过阈值时，paper VaR不能标记为valid。');
end
validate_stage_initial_probabilities(cfg, stage_prob);

required_paper = {'paper_LLR', 'paper_LFOR', 'paper_NVOR', 'paper_CRI'};
missing = setdiff(required_paper, paper_samples.Properties.VariableNames);
if ~isempty(missing)
    error('markov_risk_samples_paper_severity.csv缺少字段：%s', strjoin(missing, ', '));
end
for i = 1:numel(required_paper)
    field = required_paper{i};
    if all(isnan(paper_samples.(field)))
        error('%s不能全为NaN。', field);
    end
end
if any(isinf(paper_samples.paper_CRI))
    error('markov_risk_samples_paper_severity.csv中paper_CRI存在Inf。');
end
for i = 1:numel(cfg.var_confidence_levels)
    if ~any(abs(paper_var.sigma - cfg.var_confidence_levels(i)) < 1e-12)
        error('markov_var_metrics_paper_severity.csv缺少sigma=%.2f。', cfg.var_confidence_levels(i));
    end
end
if any(isinf(paper_var.SLLR) | isinf(paper_var.SLFOR) | isinf(paper_var.SNVOR) | isinf(paper_var.CRI))
    error('markov_var_metrics_paper_severity.csv中存在Inf。');
end
if all(isnan(paper_var.SLLR)) || all(isnan(paper_var.SLFOR)) || all(isnan(paper_var.SNVOR)) || all(isnan(paper_var.CRI))
    error('markov_var_metrics_paper_severity.csv中风险列不能全为NaN。');
end
if ~ismember('result_status', paper_var.Properties.VariableNames)
    error('markov_var_metrics_paper_severity.csv必须包含result_status字段。');
end
if height(paper_by_initial) ~= 46
    error('markov_var_by_initial_fault_paper_severity.csv应包含46行。');
end
if exist(comparison_path, 'file')
    comparison = readtable(comparison_path);
    if height(comparison) ~= numel(cfg.var_confidence_levels)
        error('basic_vs_paper_severity_comparison.csv应包含%d行。', numel(cfg.var_confidence_levels));
    end
end

paper_status = sprintf('paper_formula严重度输出已检查：line chunks=%d行，bus chunks=%d行，stage概率、paper VaR和源码均可追溯。', ...
    line_rows, bus_rows);
end

function total_rows = validate_paper_detail_chunks(cfg, chunk_dir, base_name, numeric_columns, detail_type)
%VALIDATE_PAPER_DETAIL_CHUNKS 校验paper full明细对应的manifest和chunks。
manifest_path = fullfile(cfg.results_table_dir, [base_name, '_manifest.csv']);
summary_path = fullfile(cfg.results_table_dir, [base_name, '_summary.csv']);
sample_path = fullfile(cfg.results_table_dir, [base_name, '_sample.csv']);
must_exist(manifest_path);
must_exist(summary_path);
must_exist(sample_path);
if ~exist(chunk_dir, 'dir')
    error('paper_detail_chunks目录不存在：%s', chunk_dir);
end
manifest = readtable(manifest_path);
summary = readtable(summary_path);
sample = readtable(sample_path);
if isempty(manifest) || isempty(summary) || isempty(sample)
    error('%s manifest/summary/sample不能为空。', base_name);
end

total_rows = 0;
max_seen = -Inf;
for i = 1:height(manifest)
    chunk_path = fullfile(chunk_dir, char(manifest.file_name(i)));
    must_exist(chunk_path);
    if get_file_bytes(chunk_path) < 100
        error('paper detail chunk文件过小：%s', chunk_path);
    end
    chunk = readtable(chunk_path);
    if height(chunk) ~= manifest.row_count(i)
        error('%s chunk行数与manifest不一致：%s', base_name, chunk_path);
    end
    if isempty(chunk)
        error('%s chunk为空：%s', base_name, chunk_path);
    end
    for c = 1:numel(numeric_columns)
        col = numeric_columns{c};
        if any(chunk.(col) < 0 | isnan(chunk.(col)))
            error('%s中的%s存在负数或NaN。', base_name, col);
        end
        max_seen = max(max_seen, max(chunk.(col)));
    end
    total_rows = total_rows + height(chunk);
end
if total_rows ~= summary.total_rows(1)
    error('%s chunks总行数%d与summary.total_rows=%d不一致。', base_name, total_rows, summary.total_rows(1));
end
if max_seen < 0
    error('%s没有读到有效非负明细值。', detail_type);
end
end

function validate_paper_detail_summaries(cfg)
%VALIDATE_PAPER_DETAIL_SUMMARIES 严格检查paper明细summary物理边界。
line_summary = readtable(fullfile(cfg.results_table_dir, 'markov_line_flow_details_summary.csv'));
bus_summary = readtable(fullfile(cfg.results_table_dir, 'markov_bus_voltage_details_summary.csv'));
if isinf(line_summary.max_line_severity_component(1)) || line_summary.has_inf_severity(1) ~= 0
    error('line_flow_summary中存在Inf严重度。');
end
if line_summary.has_nan_severity(1) ~= 0
    error('line_flow_summary中存在NaN严重度。');
end
if line_summary.max_P_li_pu(1) > cfg.paper_max_reasonable_line_loading_pu
    error('line_flow_summary中max_P_li_pu超过合理阈值。');
end
if bus_summary.max_voltage_pu(1) > cfg.paper_max_reasonable_voltage_pu || ...
        bus_summary.min_voltage_pu(1) < cfg.paper_min_reasonable_voltage_pu
    error('bus_voltage_summary中电压超出合理范围。');
end
if bus_summary.has_inf_severity(1) ~= 0 || bus_summary.has_nan_severity(1) ~= 0
    error('bus_voltage_summary中存在Inf或NaN严重度。');
end
end

function validate_stage_initial_probabilities(cfg, stage_prob)
%VALIDATE_STAGE_INITIAL_PROBABILITIES 校验阶段概率中的初始停运概率可映射回表4-1。
project_root = fileparts(fileparts(mfilename('fullpath')));
prob_file = fullfile(project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');
if ~exist(prob_file, 'file')
    return;
end
prob_table = readtable(prob_file);
branches = unique(stage_prob.initial_branch);
for i = 1:numel(branches)
    branch = branches(i);
    srow = stage_prob(stage_prob.initial_branch == branch, :);
    prow = prob_table(prob_table.branch_index == branch, :);
    if isempty(prow)
        error('表4-1源文件缺少branch %d。', branch);
    end
    if any(abs(srow.initial_outage_probability - prow.initial_outage_probability(1)) > 1e-12)
        error('stage_probability_details中branch %d的initial_outage_probability与表4-1不一致。', branch);
    end
end
end
