function export_line_probability_template(mpc, output_path)
%EXPORT_LINE_PROBABILITY_TEMPLATE 导出论文表4-1线路初始停运概率模板。
% 输入：
%   mpc - MATPOWER算例结构体。
%   output_path - 模板CSV输出路径。
% 输出：
%   无。
% 物理含义：
%   模板只导出case39线路编号和两端母线，概率列留空为NaN，等待用户
%   根据论文表4-1手动填写。函数不会编造任何初始停运概率。

out_dir = fileparts(output_path);
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

branch_index = (1:size(mpc.branch, 1))';
from_bus = mpc.branch(:, 1);
to_bus = mpc.branch(:, 2);
paper_prob_times_1e_minus_4 = NaN(size(branch_index));
initial_outage_probability = NaN(size(branch_index));
source_note = repmat("待用户根据论文表4-1填写", size(branch_index));

template = table(branch_index, from_bus, to_bus, paper_prob_times_1e_minus_4, ...
    initial_outage_probability, source_note);
writetable(template, output_path);
end
