function main_test_paper_ols_load_shedding()
%MAIN_TEST_PAPER_OLS_LOAD_SHEDDING 运行论文式OLS切负荷单元诊断。
% 输入：
%   无。使用默认配置和 distributed_wind_3000mw_base 场景。
% 输出：
%   results/loadshedding/ols_test_comparison.csv - simple与OLS对比表。
%   results/loadshedding/ols_test_bus_shed_details.csv - OLS逐节点切负荷明细。
%   results/loadshedding/ols_test_log.txt - 诊断日志。
% 物理含义：
%   该脚本只验证OLS求解接口，不运行完整Markov场景，不改变任何基准结果。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'loadshedding');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

log_path = fullfile(out_dir, 'ols_test_log.txt');
if exist(log_path, 'file')
    delete(log_path);
end
diary(log_path);
diary on;
cleanup_obj = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('paper OLS切负荷单元诊断开始：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

cfg = base_config();
require_matpower(cfg);
base_mpc = build_case39_base(cfg);
scenario = get_scenario_by_id('distributed_wind_3000mw_base', cfg, sum(base_mpc.bus(:, 3)));
[mpc0, renewable_info] = apply_renewable_scenario(base_mpc, scenario);

test_cases = build_test_cases(mpc0);
comparison_rows = {};
bus_detail_rows = {};

for k = 1:numel(test_cases)
    tc = test_cases(k);
    fprintf('测试样例 %s，停运线路：%s\n', tc.case_id, mat2str(tc.outaged_branches));
    [mpc_fault, applied] = apply_line_outages(mpc0, tc.outaged_branches);
    [mpc_norm, island_info] = normalize_case_after_contingency(mpc_fault, cfg, scenario, renewable_info);
    cumulative = island_info.disconnected_load_mw;
    [pf_before, converged_before] = run_ac_powerflow(mpc_norm);
    pre_v = check_violations(pf_before, cfg);
    pre_min_voltage_pu = NaN;
    pre_max_voltage_pu = NaN;
    if isstruct(pf_before) && isfield(pf_before, 'bus')
        pre_min_voltage_pu = min(pf_before.bus(:, 8), [], 'omitnan');
        pre_max_voltage_pu = max(pf_before.bus(:, 8), [], 'omitnan');
    end
    cfg_nonconv = cfg;
    cfg_nonconv.load_shedding_trigger_mode = 'nonconverged_only';
    [trigger_nonconv, ~, ~] = should_trigger_load_shedding(pf_before, converged_before, pre_v, cfg_nonconv);
    cfg_violation = cfg;
    cfg_violation.load_shedding_trigger_mode = 'nonconverged_or_violation';
    [trigger_violation, trigger_reason_violation, ~] = should_trigger_load_shedding(pf_before, converged_before, pre_v, cfg_violation);
    fprintf('  初始停运实际应用线路：%s；切孤岛负荷 %.4f MW；切负荷前潮流收敛=%d\n', ...
        mat2str(applied), cumulative, converged_before);

    [~, pf_simple, shed_simple] = simple_load_shedding(mpc_norm, cfg, cumulative);

    cfg_ols = cfg;
    cfg_ols.load_shedding_mode = 'paper_ols';
    cfg_ols.paper_ols_enable = true;
    [~, pf_ols, shed_ols, ols_detail] = solve_paper_ols_load_shedding(mpc_norm, cfg_ols, cumulative);

    simple_v = check_violations(pf_simple, cfg);
    ols_v = check_violations(pf_ols, cfg);
    comparison_rows{end + 1, 1} = table( ... %#ok<AGROW>
        string(tc.case_id), string(mat2str(tc.outaged_branches)), ...
        logical(pf_result_success(pf_before)), pre_v.max_line_loading_pu, ...
        pre_min_voltage_pu, pre_max_voltage_pu, ...
        logical(pre_v.max_line_loading_pu > cfg.load_shedding_line_overload_threshold_pu), ...
        logical(pre_min_voltage_pu < cfg.load_shedding_voltage_min_pu || pre_max_voltage_pu > cfg.load_shedding_voltage_max_pu), ...
        logical(trigger_nonconv), logical(trigger_violation), string(trigger_reason_violation), ...
        logical(shed_simple.converged_after_shed), logical(shed_ols.converged_after_shed), ...
        shed_simple.total_load_shed_mw, shed_ols.total_load_shed_mw, ...
        shed_ols.total_load_shed_mw - shed_simple.total_load_shed_mw, ...
        simple_v.max_line_loading_pu, ols_v.max_line_loading_pu, ...
        simple_v.max_voltage_deviation_pu, ols_v.max_voltage_deviation_pu, ...
        string(ols_detail.status), string(ols_detail.message), ...
        'VariableNames', {'case_id', 'outaged_branches', 'pre_shed_converged', ...
        'pre_max_line_loading_pu', 'pre_min_voltage_pu', 'pre_max_voltage_pu', ...
        'pre_has_line_overload', 'pre_has_voltage_violation', ...
        'trigger_nonconverged_only', 'trigger_nonconverged_or_violation', ...
        'trigger_reason_nonconverged_or_violation', ...
        'simple_converged', 'ols_converged', ...
        'simple_total_load_shed_mw', 'ols_total_load_shed_mw', 'delta_load_shed_mw', ...
        'simple_max_line_loading_pu', 'ols_max_line_loading_pu', ...
        'simple_max_voltage_deviation_pu', 'ols_max_voltage_deviation_pu', ...
        'ols_status', 'note'});

    if isfield(ols_detail, 'bus_shed_table') && ~isempty(ols_detail.bus_shed_table)
        tbl = ols_detail.bus_shed_table;
        tbl = [table(repmat(string(tc.case_id), height(tbl), 1), ...
            'VariableNames', {'case_id'}), tbl];
        bus_detail_rows{end + 1, 1} = tbl; %#ok<AGROW>
    end

end

comparison = vertcat(comparison_rows{:});
if isempty(bus_detail_rows)
    bus_details = table();
else
    bus_details = vertcat(bus_detail_rows{:});
end

save_result_table(comparison, fullfile(out_dir, 'ols_test_comparison.csv'), true);
save_result_table(bus_details, fullfile(out_dir, 'ols_test_bus_shed_details.csv'), false);

fprintf('OLS测试样例数：%d\n', height(comparison));
fprintf('OLS状态：%s\n', strjoin(string(comparison.ols_status), ', '));
fprintf('paper OLS切负荷单元诊断完成。\n');
write_plain_log(log_path, comparison);
end

function cases = build_test_cases(mpc)
%BUILD_TEST_CASES 构造确定性的N-1/N-2/N-3线路停运样例。
% 样例来自IEEE39常见联络线/发电机送出通道的确定性组合，不使用随机选择。
cases = struct('case_id', {}, 'outaged_branches', {});
cases(end + 1).case_id = 'n1_high_loading_branch_1';
cases(end).outaged_branches = 1;
cases(end + 1).case_id = 'n2_branch_1_2';
cases(end).outaged_branches = [1 2];
cases(end + 1).case_id = 'n2_branch_6_7';
cases(end).outaged_branches = [6 7];
cases(end + 1).case_id = 'n3_branch_1_2_3';
cases(end).outaged_branches = [1 2 3];
cases(end + 1).case_id = 'n2_last_corridor';
cases(end).outaged_branches = [max(1, size(mpc.branch, 1) - 1), size(mpc.branch, 1)];
end

function ok = pf_result_success(result)
ok = isstruct(result) && isfield(result, 'success') && result.success == 1;
end

function write_plain_log(log_path, comparison)
fid = fopen(log_path, 'w');
if fid < 0
    warning('无法写入OLS测试日志：%s', log_path);
    return;
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'paper OLS切负荷单元诊断日志\n');
fprintf(fid, '生成时间：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, '测试样例数：%d\n', height(comparison));
for i = 1:height(comparison)
    fprintf(fid, '%s: pre_converged=%d, pre_overload=%d, trigger_violation=%d, simple=%.6f MW, ols=%.6f MW, status=%s, note=%s\n', ...
        char(string(comparison.case_id(i))), comparison.pre_shed_converged(i), ...
        comparison.pre_has_line_overload(i), comparison.trigger_nonconverged_or_violation(i), ...
        comparison.simple_total_load_shed_mw(i), comparison.ols_total_load_shed_mw(i), ...
        char(string(comparison.ols_status(i))), char(string(comparison.note(i))));
end
end
