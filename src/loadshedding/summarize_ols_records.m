function ols_summary = summarize_ols_records(ols_stage_details)
%SUMMARIZE_OLS_RECORDS 汇总 OLS 切负荷诊断表。
% 输入：
%   ols_stage_details - flatten_ols_records 输出的逐级诊断表。
% 输出：
%   ols_summary - OLS尝试次数、成功/失败次数和切负荷统计。
% 物理含义：
%   为 both_diagnostic smoke 提供快速判断：OLS是否被触发、是否回退、切负荷量
%   与 simple 主链路是否存在明显差异。

if isempty(ols_stage_details) || height(ols_stage_details) == 0
    ols_summary = build_summary_row(0, 0, 0, NaN, NaN, NaN, NaN, 0);
    return;
end

is_ols_attempt = ismember(string(ols_stage_details.load_shedding_mode), ["paper_ols", "both_diagnostic"]);
attempts = ols_stage_details(is_ols_attempt, :);
if isempty(attempts)
    ols_summary = build_summary_row(0, 0, 0, NaN, NaN, NaN, NaN, 0);
    return;
end

status = string(attempts.ols_status);
success_count = sum(status == "success");
fallback_count = sum(status == "fallback_to_simple");
failed_count = sum(contains(status, "failed") | status == "fallback_to_simple");
ols_summary = build_summary_row( ...
    height(attempts), success_count, failed_count, ...
    mean(attempts.objective_load_shed_mw, 'omitnan'), ...
    max(attempts.objective_load_shed_mw, [], 'omitnan'), ...
    mean(attempts.corrective_load_shed_mw, 'omitnan'), ...
    max(attempts.corrective_load_shed_mw, [], 'omitnan'), ...
    fallback_count);
end

function tbl = build_summary_row(total_attempts, success_count, failed_count, mean_obj, max_obj, mean_corr, max_corr, fallback_count)
tbl = table(total_attempts, success_count, failed_count, mean_obj, max_obj, ...
    mean_corr, max_corr, fallback_count, ...
    'VariableNames', {'total_ols_attempts', 'successful_ols_count', 'failed_ols_count', ...
    'mean_objective_load_shed_mw', 'max_objective_load_shed_mw', ...
    'mean_corrective_load_shed_mw', 'max_corrective_load_shed_mw', ...
    'num_fallback_to_simple'});
end
