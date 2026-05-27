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

for k = 1:width(tbl)
    if islogical(tbl.(k))
        tbl.(k) = double(tbl.(k));
    elseif iscell(tbl.(k))
        % 将含字符串的cell列标准化为string，避免不同MATLAB版本写CSV时异常。
        try
            tbl.(k) = string(tbl.(k));
        catch
            % 保留原列；writetable会处理普通cellstr。
        end
    end
end

writetable(tbl, file_path, 'WriteRowNames', true);
end
