function main_build_final_summary()
%MAIN_BUILD_FINAL_SUMMARY 生成第4章已完成场景的最终汇总表和论文图。
% 输入：
%   无。仅读取 results/scenarios 下已完成的分组结果，不重新运行仿真。
% 输出：
%   results/final_summary/tables、figures、logs 下的最终结果包。
% 物理含义：
%   将当前参数、20-trial 场景扫描和 line-only paper_formula 结果整理为论文可用材料，
%   同时保留 diagnostic_only、record_only 等限制说明。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();

scenario_root = fullfile(project_root, cfg.scenario_results_root);
final_root = fullfile(project_root, 'results', 'final_summary');
table_dir = fullfile(final_root, 'tables');
figure_dir = fullfile(final_root, 'figures');
log_dir = fullfile(final_root, 'logs');
ensure_dir(table_dir);
ensure_dir(figure_dir);
ensure_dir(log_dir);

topology = load_summary(scenario_root, 'topology_compare');
penetration = load_summary(scenario_root, 'penetration_scan');
wind_speed = load_summary(scenario_root, 'wind_speed_scan');
trip_record = load_summary(scenario_root, 'renewable_trip_record');

overview = build_overview({topology, penetration, wind_speed, trip_record}, cfg);
save_result_table(overview, fullfile(table_dir, 'final_scenario_overview.csv'), true);

topology_final = build_topology_table(topology, trip_record);
save_result_table(topology_final, fullfile(table_dir, 'final_topology_comparison.csv'), true);

penetration_final = build_penetration_table(penetration);
save_result_table(penetration_final, fullfile(table_dir, 'final_penetration_scan.csv'), true);

wind_final = build_wind_speed_table(wind_speed);
save_result_table(wind_final, fullfile(table_dir, 'final_wind_speed_scan.csv'), true);

trip_final = build_trip_record_table(trip_record, fullfile(scenario_root, 'renewable_trip_record_comparison.csv'));
save_result_table(trip_final, fullfile(table_dir, 'final_renewable_trip_record.csv'), true);

validity = build_validity_matrix();
save_result_table(validity, fullfile(table_dir, 'final_metric_validity_matrix.csv'), true);

key_results = build_key_results(penetration_final, wind_final, trip_final, topology_final);
save_result_table(key_results, fullfile(table_dir, 'final_thesis_key_results.csv'), true);

plot_final_summary_figures(final_root, cfg);
fprintf('最终汇总已生成：%s\n', final_root);
end

function tbl = load_summary(scenario_root, batch_mode)
path = fullfile(scenario_root, sprintf('scenario_batch_summary_%s.csv', batch_mode));
if ~exist(path, 'file')
    error('缺少分组汇总表：%s', path);
end
tbl = readtable(path);
tbl = ensure_common_columns(tbl);
tbl = normalize_text_columns(tbl);
tbl = enrich_from_basecase_validation(tbl, scenario_root);
end

function tbl = ensure_common_columns(tbl)
defaults = {
    'batch_mode', "";
    'total_wind_capacity_mw', NaN;
    'total_wind_output_mw', NaN;
    'wind_capacity_factor', NaN;
    'wind_buses', "";
    'wind_speed_mps', NaN;
    'markov_trials_per_initial_fault', NaN;
    'chain_count', NaN;
    'invalid_stage_ratio', NaN;
    'basic_CRI_095', NaN;
    'weighted_CRI_095', NaN;
    'paper_CRI_095', NaN;
    'paper_result_status', "";
    'overall_status', "";
    'note', "";
    'wind_trip_record_enabled', false;
    'wind_trip_detail_rows', 0;
    'max_wind_trip_probability', NaN;
    'p95_wind_trip_probability', NaN;
    'num_wind_trip_probability_positive', 0;
    'basecase_slack_pg_mw', NaN;
    'basecase_overloaded_line_count', NaN;
    'basecase_voltage_violation_count', NaN
    };
for k = 1:size(defaults, 1)
    name = defaults{k, 1};
    value = defaults{k, 2};
    if ~ismember(name, tbl.Properties.VariableNames)
        tbl.(name) = repmat(value, height(tbl), 1);
    end
end
end

function tbl = enrich_from_basecase_validation(tbl, scenario_root)
%ENRICH_FROM_BASECASE_VALIDATION 从场景基础潮流校验表回填实际风电出力和基础越限信息。
for i = 1:height(tbl)
    scenario_id = string(tbl.scenario_id(i));
    scenario_path = fullfile(scenario_root, char(scenario_id), 'config', 'scenario_used.mat');
    if exist(scenario_path, 'file')
        loaded = load(scenario_path, 'scenario');
        if isfield(loaded, 'scenario') && ...
                (strlength(string(tbl.wind_buses(i))) == 0 || string(tbl.wind_buses(i)) == "NaN" || ismissing(string(tbl.wind_buses(i))))
            tbl.wind_buses(i) = join_vector(loaded.scenario.wind_buses);
        end
    end
    basecase_path = fullfile(scenario_root, char(scenario_id), 'tables', 'basecase_validation.csv');
    if ~exist(basecase_path, 'file')
        continue;
    end
    basecase = readtable(basecase_path);
    if height(basecase) == 0
        continue;
    end
    if ismember('total_wind_output_mw', basecase.Properties.VariableNames) && isnan(tbl.total_wind_output_mw(i))
        tbl.total_wind_output_mw(i) = basecase.total_wind_output_mw(1);
    end
    if ismember('slack_pg_mw', basecase.Properties.VariableNames) && isnan(tbl.basecase_slack_pg_mw(i))
        tbl.basecase_slack_pg_mw(i) = basecase.slack_pg_mw(1);
    end
    if ismember('base_overloaded_line_count', basecase.Properties.VariableNames) && isnan(tbl.basecase_overloaded_line_count(i))
        tbl.basecase_overloaded_line_count(i) = basecase.base_overloaded_line_count(1);
    end
    if ismember('base_voltage_violation_count', basecase.Properties.VariableNames) && isnan(tbl.basecase_voltage_violation_count(i))
        tbl.basecase_voltage_violation_count(i) = basecase.base_voltage_violation_count(1);
    end
    if isnan(tbl.wind_capacity_factor(i)) && tbl.total_wind_capacity_mw(i) > 0
        tbl.wind_capacity_factor(i) = tbl.total_wind_output_mw(i) / tbl.total_wind_capacity_mw(i);
    end
end
end

function text = join_vector(values)
%JOIN_VECTOR 将场景中的节点向量写成稳定的逗号分隔字符串。
if isempty(values)
    text = "";
else
    text = strjoin(string(values(:).'), ",");
end
end

function overview = build_overview(groups, cfg)
overview_cols = {'scenario_id', 'batch_mode', ...
    'total_wind_capacity_mw', 'total_wind_output_mw', 'wind_capacity_factor', ...
    'wind_buses', 'wind_speed_mps', 'markov_trials_per_initial_fault', ...
    'chain_count', 'invalid_stage_ratio', 'basic_CRI_095', 'weighted_CRI_095', ...
    'paper_CRI_095', 'paper_result_status', 'overall_status', 'note'};
for k = 1:numel(groups)
    groups{k} = ensure_common_columns(groups{k});
    groups{k} = groups{k}(:, overview_cols);
    groups{k} = normalize_text_columns(groups{k});
end
all_tbl = vertcat(groups{:});
all_tbl.scenario_group = strings(height(all_tbl), 1);
for i = 1:height(all_tbl)
    all_tbl.scenario_group(i) = infer_group(string(all_tbl.scenario_id(i)), string(all_tbl.batch_mode(i)));
end
is_final_trial = all_tbl.markov_trials_per_initial_fault == cfg.markov_num_trials_per_initial_fault;
is_not_smoke = string(all_tbl.batch_mode) ~= "smoke";
is_not_legacy = string(all_tbl.scenario_id) ~= "distributed_wind_40pct";
all_tbl = all_tbl(is_final_trial & is_not_smoke & is_not_legacy, :);
if isempty(all_tbl)
    error('final_scenario_overview 没有可用的正式20-trial场景结果。');
end

ids = unique(string(all_tbl.scenario_id), 'stable');
rows = cell(numel(ids), 1);
for k = 1:numel(ids)
    subset = all_tbl(string(all_tbl.scenario_id) == ids(k), :);
    [~, order] = sort(subset.markov_trials_per_initial_fault, 'descend');
    rows{k} = subset(order(1), :);
end
dedup = vertcat(rows{:});
overview = dedup(:, {'scenario_id', 'scenario_group', 'batch_mode', ...
    'total_wind_capacity_mw', 'total_wind_output_mw', 'wind_capacity_factor', ...
    'wind_buses', 'wind_speed_mps', 'markov_trials_per_initial_fault', ...
    'chain_count', 'invalid_stage_ratio', 'basic_CRI_095', 'weighted_CRI_095', ...
    'paper_CRI_095', 'paper_result_status', 'overall_status', 'note'});
end

function tbl = normalize_text_columns(tbl)
%NORMALIZE_TEXT_COLUMNS 将不同 CSV 读入后的字符/元胞/字符串列统一为 string。
text_cols = {'scenario_id', 'batch_mode', 'wind_buses', 'paper_result_status', ...
    'overall_status', 'note'};
for k = 1:numel(text_cols)
    name = text_cols{k};
    if ismember(name, tbl.Properties.VariableNames)
        tbl.(name) = string(tbl.(name));
    end
end
end

function group = infer_group(scenario_id, batch_mode)
if contains(scenario_id, "penetration")
    group = "penetration_scan";
elseif startsWith(scenario_id, "wind_speed_")
    group = "wind_speed_scan";
elseif contains(scenario_id, "trip_record")
    group = "renewable_trip_record";
elseif scenario_id == "distributed_wind_40pct"
    group = "legacy";
else
    group = batch_mode;
end
end

function tbl = build_topology_table(topology, trip_record)
topology = normalize_text_columns(ensure_common_columns(topology));
rows = topology(:, {'scenario_id', 'total_wind_capacity_mw', 'total_wind_output_mw', ...
    'wind_buses', 'basic_CRI_095', 'weighted_CRI_095', 'paper_CRI_095', ...
    'paper_result_status', 'invalid_stage_ratio', 'overall_status', 'note'});
wanted = ["no_renewable_base", "distributed_wind_3000mw_base", "centralized_wind_40pct"];
rows = rows(ismember(string(rows.scenario_id), wanted), :);
[~, order] = ismember(wanted, string(rows.scenario_id));
if any(order == 0)
    error('正式 topology_compare 缺少场景：%s', strjoin(wanted(order == 0), ', '));
end
rows = rows(order, :);
tbl = rows;
end

function tbl = build_penetration_table(penetration)
penetration = penetration(startsWith(string(penetration.scenario_id), "distributed_wind_penetration_"), :);
penetration_percent = parse_percent(penetration.scenario_id);
[penetration_percent, order] = sort(penetration_percent);
penetration = penetration(order, :);
tbl = table(string(penetration.scenario_id), penetration_percent, ...
    penetration.total_wind_capacity_mw, penetration.total_wind_output_mw, penetration.wind_capacity_factor, ...
    penetration.basic_CRI_095, penetration.weighted_CRI_095, penetration.paper_CRI_095, ...
    string(penetration.paper_result_status), penetration.invalid_stage_ratio, string(penetration.overall_status), ...
    'VariableNames', {'scenario_id', 'penetration_percent', 'total_wind_capacity_mw', ...
    'total_wind_output_mw', 'wind_capacity_factor', 'basic_CRI_095', 'weighted_CRI_095', ...
    'paper_CRI_095', 'paper_result_status', 'invalid_stage_ratio', 'overall_status'});
end

function tbl = build_wind_speed_table(wind_speed)
speed = wind_speed.wind_speed_mps;
[speed, order] = sort(speed);
wind_speed = wind_speed(order, :);
tbl = table(string(wind_speed.scenario_id), speed, wind_speed.total_wind_capacity_mw, ...
    wind_speed.total_wind_output_mw, wind_speed.wind_capacity_factor, wind_speed.basecase_slack_pg_mw, ...
    wind_speed.basic_CRI_095, wind_speed.weighted_CRI_095, wind_speed.paper_CRI_095, ...
    string(wind_speed.paper_result_status), wind_speed.invalid_stage_ratio, string(wind_speed.overall_status), ...
    'VariableNames', {'scenario_id', 'wind_speed_mps', 'total_wind_capacity_mw', ...
    'total_wind_output_mw', 'wind_capacity_factor', 'basecase_slack_pg_mw', ...
    'basic_CRI_095', 'weighted_CRI_095', 'paper_CRI_095', 'paper_result_status', ...
    'invalid_stage_ratio', 'overall_status'});
end

function tbl = build_trip_record_table(trip_record, comparison_path)
trip_record = normalize_text_columns(ensure_common_columns(trip_record));
comparison = readtable(comparison_path);
basic_delta = delta_at(comparison, "basic", 0.95);
weighted_delta = delta_at(comparison, "weighted", 0.95);
paper_delta = delta_at(comparison, "paper_formula", 0.95);

conclusion = strings(height(trip_record), 1);
for i = 1:height(trip_record)
    if logical(trip_record.wind_trip_record_enabled(i))
        parts = strings(0, 1);
        if trip_record.max_wind_trip_probability(i) == 0
            parts(end + 1, 1) = "Current cascade samples did not enter the wind voltage trip probability region.";
        end
        if all(abs([basic_delta, weighted_delta, paper_delta]) < 1e-12 | isnan([basic_delta, weighted_delta, paper_delta]))
            parts(end + 1, 1) = "record_only did not change line-cascade risk results.";
        end
        parts(end + 1, 1) = "This mode records P_WT(h) only and does not trip wind generators.";
        conclusion(i) = strjoin(parts, " ");
    else
        conclusion(i) = "Base scenario does not enable wind trip probability recording.";
    end
end

tbl = table(string(trip_record.scenario_id), logical(trip_record.wind_trip_record_enabled), ...
    trip_record.wind_trip_detail_rows, trip_record.max_wind_trip_probability, ...
    trip_record.p95_wind_trip_probability, trip_record.num_wind_trip_probability_positive, ...
    repmat(basic_delta, height(trip_record), 1), repmat(weighted_delta, height(trip_record), 1), ...
    repmat(paper_delta, height(trip_record), 1), conclusion, ...
    'VariableNames', {'scenario_id', 'wind_trip_record_enabled', 'wind_trip_detail_rows', ...
    'max_wind_trip_probability', 'p95_wind_trip_probability', ...
    'num_wind_trip_probability_positive', 'basic_delta_CRI_095', ...
    'weighted_delta_CRI_095', 'paper_delta_CRI_095', 'record_only_conclusion'});
end

function tbl = build_validity_matrix()
tbl = table( ...
    ["risk_metric"; "risk_metric"; "risk_metric"; "scenario"; "scenario"; "batch"; "batch"; "batch"], ...
    ["all"; "all"; "all"; "topology_compare"; "renewable_trip_record"; "smoke"; "penetration_scan"; "wind_speed_scan"], ...
    ["basic VaR"; "weighted VaR"; "paper_formula VaR"; "paper_formula VaR"; "P_WT record_only"; "all"; "all"; "all"], ...
    ["valid_for_process_check"; "valid_for_table_4_1_weighting"; "line_only_approximation"; "diagnostic_only_if_flagged"; "diagnostic_only"; "not_final"; "20_trial_trend"; "20_trial_trend"], ...
    [true; true; true; false; false; false; true; true], ...
    ["Process-check metric, not the full paper severity."; ...
    "Uses Table 4-1 initial line outage probability weights."; ...
    "Current line-only approximation; P_wt and P_ge are not coupled yet."; ...
    "If centralized_wind_40pct is diagnostic_only, it is not valid for thesis comparison."; ...
    "Records P_WT(h) only and does not trip renewable generators."; ...
    "Smoke uses 5 trials and is not a final result."; ...
    "20-trial trend result under current parameters; penetration definition needs calibration."; ...
    "20-trial trend result under current parameters; wind speed points need calibration."], ...
    'VariableNames', {'result_family', 'scenario_group', 'metric_type', ...
    'validity_status', 'can_use_for_thesis_comparison', 'limitation_note'});
end

function tbl = build_key_results(penetration, wind_speed, trip_record, topology)
rows = {};
rows{end+1,1} = make_key("penetration_scan", "80pct penetration basic_CRI_095", "distributed_wind_penetration_80pct", ...
    "basic_CRI_095", penetration.basic_CRI_095(end), "p.u.", "Basic risk metric at the high-penetration point under current parameters.", ...
    "Penetration definition and outage probability model still need calibration.");
idx12 = find(wind_speed.wind_speed_mps == 12, 1);
rows{end+1,1} = make_key("wind_speed_scan", "Wind output reaches rated platform at and above 12mps", "wind_speed_scan", ...
    "total_wind_output_mw", wind_speed.total_wind_output_mw(idx12), "MW", ...
    "The current wind power curve reaches the 3000MW rated platform at 12m/s and above.", "Wind speed scan points are engineering settings and need paper-parameter calibration.");
idx_trip = string(trip_record.scenario_id) == "distributed_wind_40pct_trip_record_only";
rows{end+1,1} = make_key("trip_record", "Maximum wind trip probability", "distributed_wind_40pct_trip_record_only", ...
    "max_wind_trip_probability", trip_record.max_wind_trip_probability(idx_trip), "probability", ...
    "Wind-bus voltages in current samples did not enter the trip-probability region.", "record_only does not actually trip wind generators.");
idx_base = string(topology.scenario_id) == "distributed_wind_3000mw_base";
rows{end+1,1} = make_key("table_4_1_weighting", "3000MW baseline weighted-basic difference", "distributed_wind_3000mw_base", ...
    "weighted_CRI_095 - basic_CRI_095", topology.weighted_CRI_095(idx_base) - topology.basic_CRI_095(idx_base), ...
    "p.u.", "Shows the influence of Table 4-1 initial probability weighting on CRI.", "This is not a complete numerical reproduction of the thesis.");
tbl = vertcat(rows{:});
end

function row = make_key(section_hint, result_name, scenario_or_group, metric, value, unit, interpretation, caution)
row = table(string(section_hint), string(result_name), string(scenario_or_group), string(metric), ...
    value, string(unit), string(interpretation), string(caution), ...
    'VariableNames', {'section_hint', 'result_name', 'scenario_or_group', 'metric', ...
    'value', 'unit', 'interpretation', 'caution'});
end

function percent = parse_percent(ids)
ids = string(ids);
percent = nan(numel(ids), 1);
for i = 1:numel(ids)
    token = regexp(char(ids(i)), '(\d+)pct', 'tokens', 'once');
    if ~isempty(token)
        percent(i) = str2double(token{1});
    end
end
end

function value = delta_at(comparison, metric_type, sigma)
idx = string(comparison.metric_type) == metric_type & abs(comparison.sigma - sigma) < 1e-12;
if any(idx)
    value = comparison.delta_CRI(find(idx, 1));
else
    value = NaN;
end
end

function ensure_dir(path)
if ~exist(path, 'dir')
    mkdir(path);
end
end
