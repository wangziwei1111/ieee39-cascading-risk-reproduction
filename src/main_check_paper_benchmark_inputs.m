function main_check_paper_benchmark_inputs()
%MAIN_CHECK_PAPER_BENCHMARK_INPUTS 校验已录入的论文第4章 benchmark 表。
% 输入：
%   paper_inputs/filled/paper_result_benchmark.csv
% 输出：
%   paper_inputs/validated/paper_result_benchmark_summary.csv
%   paper_inputs/logs/check_paper_benchmark_inputs_log.txt
% 物理含义：
%   该脚本只检查论文原文 benchmark 数据是否完整、非负、单位一致；
%   不代表当前复现实验结果已经与论文数值对齐。

project_root = fileparts(fileparts(mfilename('fullpath')));
benchmark_path = fullfile(project_root, 'paper_inputs', 'filled', 'paper_result_benchmark.csv');
validated_dir = fullfile(project_root, 'paper_inputs', 'validated');
log_dir = fullfile(project_root, 'paper_inputs', 'logs');
if ~exist(validated_dir, 'dir')
    mkdir(validated_dir);
end
if ~exist(log_dir, 'dir')
    mkdir(log_dir);
end
if ~exist(benchmark_path, 'file')
    error('缺少 paper_result_benchmark.csv：%s', benchmark_path);
end

tbl = readtable(benchmark_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
required_cols = ["paper_figure_or_table","scenario_id","metric_name","confidence_level","paper_value","unit","source_note"];
missing_cols = setdiff(required_cols, string(tbl.Properties.VariableNames));
if ~isempty(missing_cols)
    error('paper_result_benchmark.csv 缺少列：%s', strjoin(missing_cols, ', '));
end

checks = [
    make_check("Table 4-2", 2, 1, 4)
    make_check("Table 4-4", 2, 3, 4)
    make_check("Table 4-5", 9, 1, 4)
    make_check("Table 4-6", 4, 1, 4)
    ];

summary = table('Size', [0, 7], ...
    'VariableTypes', {'string','double','double','double','logical','string','string'}, ...
    'VariableNames', {'paper_figure_or_table','scenario_count','metric_count','row_count','has_missing_value','status','note'});

for i = 1:numel(checks)
    sub = tbl(string(tbl.paper_figure_or_table) == checks(i).table_name, :);
    expected_rows = checks(i).scenario_count * checks(i).confidence_count * checks(i).metric_count;
    has_missing = height(sub) == 0 || any(ismissing(sub.paper_value));
    status = "validated";
    note = "benchmark table rows complete";
    if height(sub) ~= expected_rows
        status = "failed";
        note = sprintf('row_count=%d, expected=%d', height(sub), expected_rows);
    elseif numel(unique(string(sub.scenario_id))) ~= checks(i).scenario_count
        status = "failed";
        note = "scenario count mismatch";
    elseif numel(unique(sub.confidence_level)) ~= checks(i).confidence_count
        status = "failed";
        note = "confidence level count mismatch";
    elseif numel(unique(string(sub.metric_name))) ~= checks(i).metric_count
        status = "failed";
        note = "metric count mismatch";
    elseif has_missing
        status = "failed";
        note = "missing paper_value";
    elseif any(sub.paper_value < 0)
        status = "failed";
        note = "negative paper_value";
    elseif any(string(sub.unit) ~= "10^-4")
        status = "failed";
        note = "unit must be 10^-4";
    end
    summary = [summary; {checks(i).table_name, numel(unique(string(sub.scenario_id))), ...
        numel(unique(string(sub.metric_name))), height(sub), has_missing, status, string(note)}]; %#ok<AGROW>
end

check_table45_trend(tbl);
check_table46_wind_speeds(tbl);

if any(summary.status == "failed")
    error('论文 benchmark 输入校验失败，请查看 summary。');
end

summary_path = fullfile(validated_dir, 'paper_result_benchmark_summary.csv');
writetable(summary, summary_path);

log_file = fullfile(log_dir, 'check_paper_benchmark_inputs_log.txt');
fid = fopen(log_file, 'w', 'n', 'UTF-8');
cleaner = onCleanup(@() fclose(fid));
fprintf(fid, 'Paper benchmark input check passed.\n');
fprintf(fid, 'benchmark_rows=%d\n', height(tbl));
for i = 1:height(summary)
    fprintf(fid, '%s rows=%d status=%s\n', summary.paper_figure_or_table(i), summary.row_count(i), summary.status(i));
end
fprintf('Paper benchmark input check passed: %s\n', log_file);
end

function s = make_check(table_name, scenario_count, confidence_count, metric_count)
s.table_name = table_name;
s.scenario_count = scenario_count;
s.confidence_count = confidence_count;
s.metric_count = metric_count;
end

function check_table45_trend(tbl)
sub = tbl(string(tbl.paper_figure_or_table) == "Table 4-5" & string(tbl.metric_name) == "CRI", :);
scenario_ids = string(sub.scenario_id);
percent = zeros(height(sub), 1);
for i = 1:height(sub)
    token = regexp(scenario_ids(i), 'penetration_(\d+)pct', 'tokens', 'once');
    if isempty(token)
        error('Table 4-5 scenario_id 格式错误：%s', scenario_ids(i));
    end
    percent(i) = str2double(token{1});
end
[percent_sorted, order] = sort(percent); %#ok<ASGLU>
values = sub.paper_value(order);
if values(end) <= values(end-1)
    error('Table 4-5 80%% CRI 应大于 75%% CRI。');
end
if any(diff(percent_sorted) <= 0)
    error('Table 4-5 渗透率场景重复或未正确排序。');
end
end

function check_table46_wind_speeds(tbl)
sub = tbl(string(tbl.paper_figure_or_table) == "Table 4-6", :);
scenario_ids = unique(string(sub.scenario_id));
expected = ["wind_speed_11_28mps"; "wind_speed_11_52mps"; "wind_speed_11_76mps"; "wind_speed_12_00mps"];
if ~isequal(sort(scenario_ids), sort(expected))
    error('Table 4-6 风速场景必须为 11.28、11.52、11.76、12.00 m/s。');
end
end
