function ols_summary = summarize_ols_records(ols_stage_details)
%SUMMARIZE_OLS_RECORDS 汇总 OLS 触发与切负荷诊断表。
% 输入：
%   ols_stage_details - flatten_ols_records 输出的逐级诊断表。
% 输出：
%   ols_summary - 阶段数、触发原因、OLS成败和切负荷量统计。
% 物理含义：
%   用于区分“潮流不收敛触发”和“线路/电压越限触发”，并检查 OLS 是否回退。

if isempty(ols_stage_details) || height(ols_stage_details) == 0
    ols_summary = build_summary_row(0, 0, 0, 0, 0, 0, 0, 0, 0, ...
        NaN, NaN, NaN, NaN);
    return;
end

reason = string(ols_stage_details.load_shedding_trigger_reason);
triggered = logical(ols_stage_details.load_shedding_trigger);
is_ols_attempt = ismember(string(ols_stage_details.load_shedding_mode), ...
    ["paper_ols", "both_diagnostic", "violation_only_diagnostic"]);

attempts = ols_stage_details(is_ols_attempt, :);
attempt_status = string(attempts.ols_status);

success_count = sum(attempt_status == "success");
fallback_count = sum(attempt_status == "fallback_to_simple");
failed_count = sum(contains(attempt_status, "failed") | attempt_status == "fallback_to_simple");
diagnostic_only_count = sum(reason == "diagnostic_violation_only");

ols_summary = build_summary_row( ...
    height(ols_stage_details), sum(triggered), ...
    sum(reason == "nonconverged_powerflow"), ...
    sum(contains(reason, "line_overload") | reason == "line_and_voltage_violation"), ...
    sum(contains(reason, "voltage_violation") | reason == "line_and_voltage_violation"), ...
    diagnostic_only_count, success_count, failed_count, fallback_count, ...
    safe_mean(attempts, 'objective_load_shed_mw'), ...
    safe_max(attempts, 'objective_load_shed_mw'), ...
    safe_mean(attempts, 'corrective_load_shed_mw'), ...
    safe_max(attempts, 'corrective_load_shed_mw'));

% 保留上一轮字段名，方便旧脚本读取。
ols_summary.total_ols_attempts = height(attempts);
ols_summary.successful_ols_count = success_count;
ols_summary.num_fallback_to_simple = fallback_count;
end

function value = safe_mean(tbl, field_name)
if isempty(tbl) || height(tbl) == 0
    value = NaN;
else
    value = mean(tbl.(field_name), 'omitnan');
end
end

function value = safe_max(tbl, field_name)
if isempty(tbl) || height(tbl) == 0
    value = NaN;
else
    value = max(tbl.(field_name), [], 'omitnan');
end
end

function tbl = build_summary_row(total_stage_count, triggered_stage_count, nonconv_count, ...
    line_count, voltage_count, diagnostic_count, success_count, failed_count, fallback_count, ...
    mean_obj, max_obj, mean_corr, max_corr)
tbl = table(total_stage_count, triggered_stage_count, nonconv_count, line_count, ...
    voltage_count, diagnostic_count, success_count, failed_count, fallback_count, ...
    mean_obj, max_obj, mean_corr, max_corr, ...
    'VariableNames', {'total_stage_count', 'triggered_stage_count', ...
    'nonconverged_trigger_count', 'line_overload_trigger_count', ...
    'voltage_violation_trigger_count', 'diagnostic_only_trigger_count', ...
    'successful_ols_count', 'failed_ols_count', 'fallback_count', ...
    'mean_objective_load_shed_mw', 'max_objective_load_shed_mw', ...
    'mean_corrective_load_shed_mw', 'max_corrective_load_shed_mw'});
end
