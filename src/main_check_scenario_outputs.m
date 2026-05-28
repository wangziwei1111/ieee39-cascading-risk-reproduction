function main_check_scenario_outputs(batch_mode)
%MAIN_CHECK_SCENARIO_OUTPUTS 检查指定场景批处理输出与状态语义。
% 输入：
%   batch_mode - 可选，默认smoke；例如penetration_scan、wind_speed_scan。
% 输出：
%   无；检查失败直接error。
% 物理含义：
%   区分ran/skipped_existing/failed和paper valid/diagnostic_only，并检查各类
%   场景扫描的专用物理字段，避免断点续跑误复用或误解释结果。

if nargin < 1 || isempty(batch_mode)
    batch_mode = 'smoke';
end

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();
scenario_root = fullfile(project_root, cfg.scenario_results_root);
summary_path = fullfile(scenario_root, sprintf('scenario_batch_summary_%s.csv', batch_mode));

if ~exist(summary_path, 'file')
    error('缺少批量汇总表：%s', summary_path);
end
summary_table = readtable(summary_path);
if height(summary_table) == 0
    error('批量汇总表为空：%s', summary_path);
end

required_fields = {'execution_status', 'completion_status', 'run_status', ...
    'basic_result_status', 'weighted_result_status', 'paper_result_status', ...
    'overall_status', 'note', 'expected_markov_trials_per_initial_fault', ...
    'markov_trials_per_initial_fault', 'reuse_decision_reason'};
missing = setdiff(required_fields, summary_table.Properties.VariableNames);
if ~isempty(missing)
    error('批量汇总表缺少状态字段：%s', strjoin(missing, ', '));
end

if strcmp(batch_mode, 'penetration_scan')
    check_penetration_summary(summary_table, cfg);
elseif strcmp(batch_mode, 'wind_speed_scan')
    check_wind_speed_summary(summary_table);
elseif strcmp(batch_mode, 'paper_wind_speed_scan')
    check_paper_wind_speed_summary(summary_table, cfg);
elseif strcmp(batch_mode, 'renewable_trip_record')
    check_renewable_trip_record_summary(summary_table, scenario_root);
end

diagnostic_ids = strings(0, 1);
for i = 1:height(summary_table)
    scenario_id = string(summary_table.scenario_id(i));
    execution_status = string(summary_table.execution_status(i));
    run_status = string(summary_table.run_status(i));
    paper_status = string(summary_table.paper_result_status(i));
    overall_status = string(summary_table.overall_status(i));
    note_value = string(summary_table.note(i));
    expected_trials = summary_table.expected_markov_trials_per_initial_fault(i);
    actual_trials = summary_table.markov_trials_per_initial_fault(i);

    if ~any(execution_status == ["ran", "skipped_existing", "failed"])
        error('场景%s execution_status非法：%s', scenario_id, execution_status);
    end

    if execution_status == "failed" || run_status == "failed"
        if strlength(note_value) == 0
            error('场景%s失败但note为空。', scenario_id);
        end
        continue;
    end

    if execution_status == "skipped_existing"
        expected_options = struct('expected_markov_trials_per_initial_fault', expected_trials, ...
            'expected_batch_mode', batch_mode, ...
            'allow_smoke_reuse', strcmp(batch_mode, 'smoke') || strcmp(batch_mode, 'topology_compare'));
        [is_complete, completion_status, missing_files, complete_note] = ...
            check_single_scenario_complete(scenario_id, scenario_root, expected_options);
        if ~is_complete
            error('场景%s标记为skipped_existing但完整性检查失败：%s %s', ...
                scenario_id, missing_files, complete_note);
        end
        if string(completion_status) == "incomplete_trial_count_mismatch"
            error('场景%s skipped_existing但trial数不匹配。', scenario_id);
        end
        if string(summary_table.completion_status(i)) ~= completion_status
            error('场景%s completion_status与完整性检查不一致。', scenario_id);
        end
    end

    if any(strcmp(batch_mode, {'penetration_scan', 'wind_speed_scan', 'paper_wind_speed_scan', 'all_full', 'renewable_trip_record'})) && ...
            execution_status ~= "failed"
        if actual_trials ~= expected_trials
            error('场景%s属于%s，但actual_trials=%g expected_trials=%g，禁止混入smoke结果。', ...
                scenario_id, batch_mode, actual_trials, expected_trials);
        end
    end

    if isnan(summary_table.paper_CRI_095(i))
        if ~(paper_status == "diagnostic_only" || paper_status == "failed" || paper_status == "not_available")
            error('场景%s paper_CRI_095为NaN，但paper_result_status=%s。', scenario_id, paper_status);
        end
        if overall_status == "success_all_valid"
            error('场景%s paper_CRI_095为NaN，不能标记为success_all_valid。', scenario_id);
        end
    end

    paper_var_path = fullfile(scenario_root, scenario_id, 'tables', 'markov_var_metrics_paper_severity.csv');
    paper_var = readtable(paper_var_path);
    paper_rows_status = string(paper_var.result_status);
    idx095 = find(abs(paper_var.sigma - 0.95) < 1e-9, 1);
    if isempty(idx095)
        error('场景%s的paper VaR缺少sigma=0.95。', scenario_id);
    end

    if paper_status == "valid"
        if isnan(summary_table.paper_CRI_095(i)) || isinf(summary_table.paper_CRI_095(i))
            error('场景%s paper_result_status=valid但paper_CRI_095无效。', scenario_id);
        end
        if paper_rows_status(idx095) ~= "valid"
            error('场景%s汇总为valid，但paper VaR sigma=0.95不是valid。', scenario_id);
        end
    elseif paper_status == "diagnostic_only"
        diagnostic_ids(end + 1, 1) = scenario_id; %#ok<AGROW>
        if ~any(paper_rows_status == "diagnostic_only")
            error('场景%s汇总为diagnostic_only，但paper VaR无diagnostic_only行。', scenario_id);
        end
        if overall_status ~= "success_with_diagnostic_paper"
            error('场景%s diagnostic_only时overall_status必须是success_with_diagnostic_paper。', scenario_id);
        end
        if strlength(note_value) == 0
            error('场景%s diagnostic_only但note为空。', scenario_id);
        end
    end
end

execution = string(summary_table.execution_status);
overall = string(summary_table.overall_status);
fprintf('场景批处理自检通过。\n');
fprintf('batch_mode：%s\n', batch_mode);
fprintf('场景数：%d\n', height(summary_table));
fprintf('ran 数量：%d\n', sum(execution == "ran"));
fprintf('skipped_existing 数量：%d\n', sum(execution == "skipped_existing"));
fprintf('failed 数量：%d\n', sum(execution == "failed"));
fprintf('success_all_valid 数量：%d\n', sum(overall == "success_all_valid"));
fprintf('success_with_diagnostic_paper 数量：%d\n', sum(overall == "success_with_diagnostic_paper"));
fprintf('diagnostic_only 场景列表：%s\n', strjoin(diagnostic_ids, ', '));
end

function check_penetration_summary(summary_table, cfg)
%CHECK_PENETRATION_SUMMARY 校验渗透率扫描命名、容量和单调性。
ids = string(summary_table.scenario_id);
if any(ids == "distributed_wind_40pct")
    error('legacy distributed_wind_40pct must not be used in penetration_scan.');
end
ratios = nan(height(summary_table), 1);
for k = 1:height(summary_table)
    token = regexp(char(ids(k)), '^distributed_wind_penetration_(\d+)pct$', 'tokens', 'once');
    if isempty(token)
        error('penetration_scan场景命名非法：%s', ids(k));
    end
    ratios(k) = str2double(token{1}) / 100;
end
[sorted_ratios, order] = sort(ratios);
capacities = summary_table.total_wind_capacity_mw(order);
if any(diff(sorted_ratios) <= 0) || any(diff(capacities) <= 0)
    error('penetration_scan渗透率或风电容量不单调递增。');
end
base_load_mw = median(capacities ./ sorted_ratios);
expected_capacity = sorted_ratios .* base_load_mw;
if any(abs(capacities - expected_capacity) > max(1e-6, 1e-6 * base_load_mw))
    error('penetration_scan容量与scenario_id渗透率不一致。');
end
if isfield(cfg, 'scenario_penetration_definition') && ...
        ~strcmp(cfg.scenario_penetration_definition, 'wind_capacity_divided_by_base_load')
    error('未知渗透率定义：%s', cfg.scenario_penetration_definition);
end
end

function check_wind_speed_summary(summary_table)
%CHECK_WIND_SPEED_SUMMARY 校验风速扫描的命名、实际出力和样本数语义。
required = {'total_wind_output_mw', 'wind_capacity_factor', 'basecase_slack_pg_mw', ...
    'basecase_overloaded_line_count', 'basecase_voltage_violation_count'};
missing = setdiff(required, summary_table.Properties.VariableNames);
if ~isempty(missing)
    error('wind_speed_scan汇总表缺少字段：%s', strjoin(missing, ', '));
end

ids = string(summary_table.scenario_id);
speeds = nan(height(summary_table), 1);
for k = 1:height(summary_table)
    token = regexp(char(ids(k)), '^wind_speed_(\d+)mps$', 'tokens', 'once');
    if isempty(token)
        error('wind_speed_scan场景命名非法：%s', ids(k));
    end
    speeds(k) = str2double(token{1});
end
if any(abs(summary_table.wind_speed_mps - speeds) > 1e-9)
    error('wind_speed_scan的wind_speed_mps与scenario_id不一致。');
end
if any(abs(summary_table.total_wind_capacity_mw - 3000) > 1e-6)
    error('wind_speed_scan应保持3000 MW装机容量。');
end
if any(isnan(summary_table.total_wind_output_mw))
    error('wind_speed_scan存在NaN total_wind_output_mw。');
end
if any(summary_table.total_wind_output_mw < -1e-6) || any(summary_table.total_wind_output_mw > 3000 + 1e-6)
    error('wind_speed_scan实际风电出力超出[0, 3000] MW。');
end
cf = summary_table.wind_capacity_factor;
if any(isnan(cf)) || any(cf < -1e-9) || any(cf > 1 + 1e-9)
    error('wind_speed_scan容量因子必须位于[0,1]。');
end
[sorted_speeds, order] = sort(speeds);
outputs = summary_table.total_wind_output_mw(order);
idx_ramp = sorted_speeds <= 12;
if sum(idx_ramp) >= 2 && any(diff(outputs(idx_ramp)) < -1e-6)
    error('wind_speed_scan在cut-in到rated范围内实际出力应非递减。');
end
if any(outputs(sorted_speeds >= 12) > 3000 + 1e-6)
    error('wind_speed_scan额定平台出力不应超过装机容量。');
end
end

function check_paper_wind_speed_summary(summary_table, cfg)
%CHECK_PAPER_WIND_SPEED_SUMMARY 校验论文表4-6风速点批次。
required_ids = ["paper_wind_speed_11_28mps", "paper_wind_speed_11_52mps", ...
    "paper_wind_speed_11_76mps", "paper_wind_speed_12_00mps"];
ids = string(summary_table.scenario_id);
missing_ids = setdiff(required_ids, ids);
if ~isempty(missing_ids)
    error('paper_wind_speed_scan缺少场景：%s', strjoin(missing_ids, ', '));
end
if height(summary_table) ~= numel(required_ids)
    error('paper_wind_speed_scan应只包含4个论文表4-6风速场景。');
end
required = {'wind_speed_mps','total_wind_capacity_mw','total_wind_output_mw', ...
    'wind_capacity_factor','paper_result_status','paper_CRI_095','chain_count'};
missing = setdiff(required, summary_table.Properties.VariableNames);
if ~isempty(missing)
    error('paper_wind_speed_scan汇总表缺少字段：%s', strjoin(missing, ', '));
end
speeds = nan(height(summary_table), 1);
for k = 1:height(summary_table)
    token = regexp(char(ids(k)), '^paper_wind_speed_(\d+)_(\d+)mps$', 'tokens', 'once');
    if isempty(token)
        error('paper_wind_speed_scan场景命名非法：%s', ids(k));
    end
    speeds(k) = str2double(token{1}) + str2double(token{2}) / 100;
end
expected_speeds = [11.28; 11.52; 11.76; 12.00];
if any(abs(sort(speeds) - expected_speeds) > 1e-9)
    error('paper_wind_speed_scan风速点必须为11.28、11.52、11.76、12.00。');
end
if any(abs(summary_table.wind_speed_mps - speeds) > 1e-9)
    error('paper_wind_speed_scan的wind_speed_mps与scenario_id不一致。');
end
if any(abs(summary_table.total_wind_capacity_mw - 3000) > 1e-6)
    error('paper_wind_speed_scan应保持3000 MW装机容量。');
end
if any(isnan(summary_table.total_wind_output_mw))
    error('paper_wind_speed_scan存在NaN total_wind_output_mw。');
end
cf = summary_table.wind_capacity_factor;
if any(isnan(cf)) || any(cf < -1e-9) || any(cf > 1 + 1e-9)
    error('paper_wind_speed_scan容量因子必须位于[0,1]。');
end
if any(summary_table.chain_count ~= 46 * cfg.markov_num_trials_per_initial_fault)
    error('paper_wind_speed_scan链数必须等于46*trial数。');
end
[sorted_speeds, order] = sort(speeds); %#ok<ASGLU>
outputs = summary_table.total_wind_output_mw(order);
if any(diff(outputs) < -1e-3)
    error('paper_wind_speed_scan实际出力应随风速非递减。');
end
idx12 = abs(sorted_speeds - 12.00) < 1e-9;
if any(idx12) && abs(outputs(idx12) - 3000) > 1e-3
    error('paper_wind_speed_scan 12.00m/s应接近额定3000 MW。');
end
valid_status = string(summary_table.paper_result_status);
if any(~ismember(valid_status, ["valid", "diagnostic_only", "failed", "not_available"]))
    error('paper_wind_speed_scan paper_result_status存在未知状态。');
end
if any(isnan(summary_table.paper_CRI_095) & valid_status == "valid")
    error('paper_result_status=valid时paper_CRI_095不得为NaN。');
end
if any(summary_table.paper_CRI_095 == 0 & valid_status == "diagnostic_only")
    error('diagnostic_only的paper_CRI_095不得填0。');
end
end

function check_renewable_trip_record_summary(summary_table, scenario_root)
%CHECK_RENEWABLE_TRIP_RECORD_SUMMARY 校验新能源脱网概率record-only场景。
required_ids = ["distributed_wind_3000mw_base", "distributed_wind_40pct_trip_record_only"];
ids = string(summary_table.scenario_id);
missing_ids = setdiff(required_ids, ids);
if ~isempty(missing_ids)
    error('renewable_trip_record缺少场景：%s', strjoin(missing_ids, ', '));
end
required_fields = {'wind_trip_record_enabled', 'wind_trip_detail_rows', ...
    'max_wind_trip_probability', 'p95_wind_trip_probability', ...
    'num_wind_trip_probability_positive'};
missing = setdiff(required_fields, summary_table.Properties.VariableNames);
if ~isempty(missing)
    error('renewable_trip_record汇总表缺少字段：%s', strjoin(missing, ', '));
end

base_row = summary_table(ids == "distributed_wind_3000mw_base", :);
trip_row = summary_table(ids == "distributed_wind_40pct_trip_record_only", :);
if logical(base_row.wind_trip_record_enabled(1))
    error('distributed_wind_3000mw_base不应启用风机脱网概率记录。');
end
if ~logical(trip_row.wind_trip_record_enabled(1))
    error('distributed_wind_40pct_trip_record_only必须启用风机脱网概率记录。');
end
if trip_row.wind_trip_detail_rows(1) <= 0 || isnan(trip_row.max_wind_trip_probability(1))
    error('trip_record_only风机脱网概率记录为空或最大概率为NaN。');
end

trip_table_dir = fullfile(scenario_root, 'distributed_wind_40pct_trip_record_only', 'tables');
detail_path = fullfile(trip_table_dir, 'wind_trip_probability_details.csv');
summary_path = fullfile(trip_table_dir, 'wind_trip_probability_summary.csv');
sample_path = fullfile(trip_table_dir, 'wind_trip_probability_details_sample.csv');
if ~exist(detail_path, 'file') || ~exist(summary_path, 'file') || ~exist(sample_path, 'file')
    error('trip_record_only缺少wind_trip_probability输出文件。');
end
detail = readtable(detail_path);
if height(detail) == 0
    error('wind_trip_probability_details.csv为空。');
end
if any(detail.trip_probability < -1e-12) || any(detail.trip_probability > 1 + 1e-12)
    error('风机脱网概率超出[0,1]。');
end
if any(detail.voltage_pu <= 0)
    error('风机电压存在非正值。');
end
if ~all(logical(detail.record_only))
    error('record_only字段必须全部为true。');
end
comparison_path = fullfile(scenario_root, 'renewable_trip_record_comparison.csv');
if ~exist(comparison_path, 'file') || height(readtable(comparison_path)) == 0
    error('缺少有效的renewable_trip_record_comparison.csv。');
end
end
