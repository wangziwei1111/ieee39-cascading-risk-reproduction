function save_result_table(tbl, file_path)
%SAVE_RESULT_TABLE 保存结果表格。
% 输入：
%   tbl - MATLAB table。
%   file_path - 输出CSV路径。
% 输出：
%   无。
% 物理含义：
%   将每个N-1初始故障的后果和简化风险指标落盘，方便复核和扩展。

out_dir = fileparts(file_path);
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

writetable(tbl, file_path, 'WriteRowNames', true);
end
