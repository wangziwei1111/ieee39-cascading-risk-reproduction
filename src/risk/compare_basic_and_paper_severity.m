function severity_status_table = compare_basic_and_paper_severity(risk_samples, output_path)
%COMPARE_BASIC_AND_PAPER_SEVERITY 输出basic与paper严重度可用性状态。
% 输入：
%   risk_samples - 风险样本表。
%   output_path - severity_formula_status.csv输出路径。
% 输出：
%   severity_status_table - 状态表。
% 物理含义：
%   paper公式未确认前，不应输出假paper风险值。本函数用状态表明确说明当前仅basic可用。

has_paper = all(ismember({'paper_LLR', 'paper_LFOR', 'paper_NVOR', 'paper_CRI'}, ...
    risk_samples.Properties.VariableNames)) && ...
    ~all(isnan(risk_samples.paper_CRI));

if has_paper
    severity_type = ["basic"; "paper_formula"];
    status = ["available"; "available"];
    note = ["当前最小版严重度"; "论文公式严重度已由人工确认并计算"];
else
    severity_type = ["basic"; "paper_formula"];
    status = ["available"; "not_available"];
    note = ["当前最小版严重度"; "论文公式尚未确认"];
end

severity_status_table = table(severity_type, status, note);
if nargin >= 2 && ~isempty(output_path)
    save_result_table(severity_status_table, output_path, true);
end
end
