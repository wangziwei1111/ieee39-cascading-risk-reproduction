function main_validate_basecase()
%MAIN_VALIDATE_BASECASE 校验新能源场景下的无故障基础运行点。
% 输入：
%   无。运行前需要MATPOWER可用。
% 输出：
%   results/tables/basecase_validation.csv - 基础运行点校验结果。
%   results/logs/basecase_validation_log.txt - 基础运行点校验日志。
% 物理含义：
%   在进入马尔可夫事故链前，先确认新能源注入后的基础潮流点是否合理，
%   包括发电/负荷平衡、平衡机出力、机组有功上下限、线路和电压越限。

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

log_path = fullfile(cfg.results_log_dir, 'basecase_validation_log.txt');
if exist(log_path, 'file')
    delete(log_path);
end
diary(log_path);
diary on;
cleanup_obj = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('基础运行点校验开始：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf('场景：%s\n', scenario.name);
fprintf('新能源调度模式：%s\n', scenario.renewable_dispatch_mode);
fprintf('%s\n', scenario.description);

require_matpower(cfg);

base_mpc = build_case39_base(cfg);
[mpc, renewable_info] = apply_renewable_scenario(base_mpc, scenario);
[pf_result, converged] = run_ac_powerflow(mpc);

if converged
    result_for_check = pf_result;
else
    result_for_check = mpc;
end

violations = check_violations(result_for_check, cfg);
gen_limit_table = check_pg_limits(result_for_check.gen);

total_load_mw = sum(result_for_check.bus(:, 3));
total_generation_mw = sum(result_for_check.gen(result_for_check.gen(:, 8) > 0, 2));
slack_bus = scenario.slack_bus;
slack_rows = find(result_for_check.gen(:, 1) == slack_bus & result_for_check.gen(:, 8) > 0);
if isfield(renewable_info, 'wind_gen_rows')
    slack_rows = setdiff(slack_rows, renewable_info.wind_gen_rows);
end
slack_pg_mw = sum(result_for_check.gen(slack_rows, 2));

num_pg_below_pmin = sum(gen_limit_table.below_pmin);
num_pg_above_pmax = sum(gen_limit_table.above_pmax);
num_pg_violations = num_pg_below_pmin + num_pg_above_pmax;

fprintf('潮流是否收敛：%d\n', converged);
fprintf('系统总负荷：%.6f MW\n', total_load_mw);
fprintf('系统总发电：%.6f MW\n', total_generation_mw);
fprintf('总风电出力：%.6f MW\n', renewable_info.total_wind_output_mw);
fprintf('平衡机节点：%d，平衡机总PG：%.6f MW\n', slack_bus, slack_pg_mw);
fprintf('机组PG越限数量：%d（低于PMIN=%d，高于PMAX=%d）\n', ...
    num_pg_violations, num_pg_below_pmin, num_pg_above_pmax);
fprintf('基础状态线路越限数量：%d，最大线路负载率：%.6f\n', ...
    violations.num_overloaded_lines, violations.max_line_loading_pu);
fprintf('基础状态电压越限节点数量：%d，最大电压越限偏差：%.6f p.u.\n', ...
    violations.num_voltage_violations, violations.max_voltage_deviation_pu);

validation = table( ...
    string(scenario.name), string(scenario.renewable_dispatch_mode), converged, ...
    total_load_mw, total_generation_mw, renewable_info.total_wind_output_mw, ...
    slack_bus, slack_pg_mw, ...
    num_pg_violations, num_pg_below_pmin, num_pg_above_pmax, ...
    violations.num_overloaded_lines, violations.max_line_loading_pu, ...
    violations.num_voltage_violations, violations.max_voltage_deviation_pu, ...
    renewable_info.redispatch_reduction_mw, renewable_info.redispatch_shortfall_mw, ...
    'VariableNames', {'scenario_name', 'renewable_dispatch_mode', 'converged', ...
    'total_load_mw', 'total_generation_mw', 'total_wind_output_mw', ...
    'slack_bus', 'slack_pg_mw', ...
    'num_pg_violations', 'num_pg_below_pmin', 'num_pg_above_pmax', ...
    'num_overloaded_lines', 'max_line_loading_pu', ...
    'num_voltage_violations', 'max_voltage_deviation_pu', ...
    'redispatch_reduction_mw', 'redispatch_shortfall_mw'});

out_csv = fullfile(cfg.results_table_dir, 'basecase_validation.csv');
save_result_table(validation, out_csv);

fprintf('基础运行点校验结果已写入：%s\n', out_csv);
fprintf('基础运行点校验日志已写入：%s\n', log_path);
fprintf('基础运行点校验结束：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
end

function gen_limit_table = check_pg_limits(gen)
%CHECK_PG_LIMITS 检查发电机有功出力上下限。
% 输入：
%   gen - MATPOWER gen矩阵。
% 输出：
%   gen_limit_table - 每台机组PG、PMIN、PMAX和越限标志。
% 物理含义：
%   若基础运行点已经存在PG越限，则后续N-1风险结果不宜直接解释。

gen_index = (1:size(gen, 1))';
bus = gen(:, 1);
pg = gen(:, 2);
pmin = gen(:, 10);
pmax = gen(:, 9);
below_pmin = pg < pmin - 1e-6;
above_pmax = pg > pmax + 1e-6;
gen_limit_table = table(gen_index, bus, pg, pmin, pmax, below_pmin, above_pmax);
end
