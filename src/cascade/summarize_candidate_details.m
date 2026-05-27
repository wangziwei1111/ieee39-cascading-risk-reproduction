function candidate_summary_table = summarize_candidate_details(candidate_detail_table)
%SUMMARIZE_CANDIDATE_DETAILS 汇总候选线路抽样明细。
% 输入：
%   candidate_detail_table - flatten_candidate_tables输出的候选线路明细表。
% 输出：
%   candidate_summary_table - 单行汇总表。
% 物理含义：
%   大CSV不便快速人工检查时，该汇总表提供候选数量、抽中数量、最大负载
%   和高概率候选数量等关键诊断信息。

if isempty(candidate_detail_table) || height(candidate_detail_table) == 0
    total_candidate_rows = 0;
    selected_candidate_rows = 0;
    max_loading_pu = NaN;
    max_outage_probability = NaN;
    mean_outage_probability = NaN;
    p95_loading_pu = NaN;
    p95_outage_probability = NaN;
    num_probability_above_0_1 = 0;
    num_probability_equal_1 = 0;
    num_selected_with_probability_equal_1 = 0;
else
    total_candidate_rows = height(candidate_detail_table);
    selected_candidate_rows = sum(candidate_detail_table.trip_selected == 1);
    max_loading_pu = max(candidate_detail_table.loading_pu);
    max_outage_probability = max(candidate_detail_table.outage_probability);
    mean_outage_probability = mean(candidate_detail_table.outage_probability);
    p95_loading_pu = calc_empirical_var(candidate_detail_table.loading_pu, 0.95, []);
    p95_outage_probability = calc_empirical_var(candidate_detail_table.outage_probability, 0.95, []);
    num_probability_above_0_1 = sum(candidate_detail_table.outage_probability > 0.1);
    num_probability_equal_1 = sum(abs(candidate_detail_table.outage_probability - 1) < 1e-12);
    num_selected_with_probability_equal_1 = sum(candidate_detail_table.trip_selected == 1 & ...
        abs(candidate_detail_table.outage_probability - 1) < 1e-12);
end

candidate_summary_table = table(total_candidate_rows, selected_candidate_rows, ...
    max_loading_pu, max_outage_probability, mean_outage_probability, ...
    p95_loading_pu, p95_outage_probability, num_probability_above_0_1, ...
    num_probability_equal_1, num_selected_with_probability_equal_1);
end
