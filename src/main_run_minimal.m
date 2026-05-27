function main_run_minimal()
%MAIN_RUN_MINIMAL IEEE39最小连锁故障风险评估一键运行入口。
% 输入：
%   无。运行前需要 MATLAB 路径中可找到 MATPOWER 的 case39/runpf/loadcase。
% 输出：
%   results/tables/minimal_result.csv - 每条N-1线路故障与汇总风险指标。
%   results/logs/minimal_run_log.txt - 运行日志。
% 物理含义：
%   本脚本枚举IEEE39中每条线路开断后的静态后果，形成“初始故障 ->
%   潮流计算 -> 简化切负荷 -> 风险统计”的最小闭环。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

cfg = base_config();
cfg.results_table_dir = fullfile(project_root, cfg.results_table_dir);
cfg.results_log_dir = fullfile(project_root, cfg.results_log_dir);
scenario = scenario_config();
init_random_seed(cfg.seed);

if ~exist(cfg.results_table_dir, 'dir')
    mkdir(cfg.results_table_dir);
end
if ~exist(cfg.results_log_dir, 'dir')
    mkdir(cfg.results_log_dir);
end

log_path = fullfile(cfg.results_log_dir, 'minimal_run_log.txt');
if exist(log_path, 'file')
    delete(log_path);
end
diary(log_path);
diary on;
cleanup_obj = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('最小复现实验开始：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf('场景：%s\n%s\n', scenario.name, scenario.description);
fprintf('随机种子：%d\n', cfg.seed);

require_matpower(cfg);

base_mpc = build_case39_base(cfg);
[mpc, renewable_info] = apply_renewable_scenario(base_mpc, scenario);
faults = enumerate_initial_faults(mpc);

fprintf('基础系统：%d个节点，%d条线路，%d台机组。\n', ...
    size(mpc.bus, 1), size(mpc.branch, 1), size(mpc.gen, 1));
fprintf('枚举初始线路故障数：%d\n', height(faults));

base_load_mw = sum(mpc.bus(:, 3));
rows = cell(height(faults), 1);

for i = 1:height(faults)
    fault_branch = faults.branch_index(i);
    case_i = mpc;
    case_i.branch(fault_branch, 11) = 0; % BR_STATUS=0，表示线路开断。

    [pf_result, converged] = run_ac_powerflow(case_i);
    shed = struct('load_shed_mw', 0, 'load_shed_frac', 0, ...
        'iterations', 0, 'converged_after_shed', converged);

    if ~converged
        [case_i, pf_result, shed] = simple_load_shedding(case_i, cfg);
        converged = shed.converged_after_shed;
    end

    violations = check_violations(pf_result, cfg);

    % 最小版只计算风机电压穿越脱网概率，不扩展后续事故链。
    wind_trip_probs = zeros(numel(renewable_info.wind_buses), 1);
    if converged
        for k = 1:numel(renewable_info.wind_buses)
            bus_id = renewable_info.wind_buses(k);
            bus_row = find(pf_result.bus(:, 1) == bus_id, 1);
            if ~isempty(bus_row)
                wind_trip_probs(k) = wind_voltage_trip_probability(pf_result.bus(bus_row, 8));
            end
        end
    end

    metrics = calc_basic_risk_metrics(pf_result, violations, shed, base_load_mw);
    cri = calc_cri(metrics.SLLR, metrics.SLFOR, metrics.SNVOR, cfg.risk_weights);

    rows{i} = table( ...
        fault_branch, faults.from_bus(i), faults.to_bus(i), converged, ...
        shed.load_shed_mw, shed.load_shed_frac, ...
        violations.num_overloaded_lines, violations.max_line_loading_pu, ...
        violations.num_voltage_violations, violations.max_voltage_deviation_pu, ...
        mean(wind_trip_probs), max(wind_trip_probs), ...
        metrics.SLLR, metrics.SLFOR, metrics.SNVOR, cri, ...
        'VariableNames', {'branch_index', 'from_bus', 'to_bus', 'converged', ...
        'load_shed_mw', 'load_shed_frac', 'num_overloaded_lines', ...
        'max_line_loading_pu', 'num_voltage_violations', 'max_voltage_deviation_pu', ...
        'mean_wind_voltage_trip_prob', 'max_wind_voltage_trip_prob', ...
        'SLLR', 'SLFOR', 'SNVOR', 'CRI'});
end

result_table = vertcat(rows{:});
summary = table( ...
    NaN, NaN, NaN, all(result_table.converged), ...
    sum(result_table.load_shed_mw), mean(result_table.load_shed_frac), ...
    sum(result_table.num_overloaded_lines, 'omitnan'), max(result_table.max_line_loading_pu, [], 'omitnan'), ...
    sum(result_table.num_voltage_violations, 'omitnan'), max(result_table.max_voltage_deviation_pu, [], 'omitnan'), ...
    mean(result_table.mean_wind_voltage_trip_prob), max(result_table.max_wind_voltage_trip_prob), ...
    mean(result_table.SLLR), mean(result_table.SLFOR), mean(result_table.SNVOR), mean(result_table.CRI), ...
    'VariableNames', result_table.Properties.VariableNames);

summary.Properties.RowNames = {'SUMMARY'};
result_table.Properties.RowNames = cellstr("fault_" + string((1:height(result_table))'));
final_table = [result_table; summary];

out_csv = fullfile(cfg.results_table_dir, 'minimal_result.csv');
save_result_table(final_table, out_csv);

fprintf('结果已写入：%s\n', out_csv);
fprintf('日志已写入：%s\n', log_path);
fprintf('汇总指标：SLLR=%.6f, SLFOR=%.6f, SNVOR=%.6f, CRI=%.6f\n', ...
    summary.SLLR, summary.SLFOR, summary.SNVOR, summary.CRI);
fprintf('最小复现实验结束：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
end

function require_matpower(cfg)
%REQUIRE_MATPOWER 检查MATPOWER核心函数是否可用。
% 输入：
%   cfg - 全局配置，包含MATPOWER候选路径。
% 输出：
%   无。若缺失MATPOWER则报错。
% 物理含义：
%   潮流计算必须依赖MATPOWER，不能退化为非MATPOWER实现。

needed = {'case39', 'runpf', 'loadcase', 'mpoption'};

if any(cellfun(@(f) exist(f, 'file') ~= 2, needed)) ...
        && isfield(cfg, 'matpower_candidate_paths')
    for p = 1:numel(cfg.matpower_candidate_paths)
        candidate = cfg.matpower_candidate_paths{p};
        if exist(candidate, 'dir')
            addpath(genpath(candidate));
            if all(cellfun(@(f) exist(f, 'file') == 2, needed))
                fprintf('已自动加入MATPOWER路径：%s\n', candidate);
                break;
            end
        end
    end
end

missing = {};
for k = 1:numel(needed)
    if exist(needed{k}, 'file') ~= 2
        missing{end + 1} = needed{k}; %#ok<AGROW>
    end
end
if ~isempty(missing)
    error(['MATPOWER路径未配置，缺少函数：%s。\n', ...
        '请先在MATLAB中 addpath(genpath(''你的MATPOWER目录'')) 或运行 savepath 后重试。'], ...
        strjoin(missing, ', '));
end
end
