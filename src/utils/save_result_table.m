function save_result_table(tbl, file_path, strict_mode)
%SAVE_RESULT_TABLE 保存结果表格。
% 输入：
%   tbl - MATLAB table。
%   file_path - 输出CSV路径。
%   strict_mode - 可选，true时写入异常直接报错，false时仅警告。
% 输出：
%   无。
% 物理含义：
%   将每个N-1初始故障的后果和简化风险指标落盘，方便复核和扩展。

if nargin < 3
    strict_mode = true;
end

out_dir = fileparts(file_path);
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

original_height = height(tbl);
original_width = width(tbl);

for k = 1:width(tbl)
    if islogical(tbl.(k))
        tbl.(k) = double(tbl.(k));
    elseif isstring(tbl.(k))
        tbl.(k) = string(tbl.(k));
    elseif iscellstr(tbl.(k))
        tbl.(k) = string(tbl.(k));
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

if ~exist(file_path, 'file')
    error('结果表写入失败，文件不存在：%s', file_path);
end

file_info = dir(file_path);
if original_height > 0 && file_info.bytes < 100
    message = sprintf('结果表写入异常：原表%d行%d列，但文件过小(%d bytes)：%s', ...
        original_height, original_width, file_info.bytes, file_path);
    handle_write_issue(message, strict_mode);
end

if original_height > 0
    readback = readtable(file_path);
    if height(readback) == 0
        handle_write_issue(sprintf('结果表写入异常：原表非空，但读回为空：%s', file_path), strict_mode);
    end
    if height(readback) ~= original_height
        handle_write_issue(sprintf('结果表写入异常：原表%d行，读回%d行：%s', ...
            original_height, height(readback), file_path), strict_mode);
    end
end
end

function handle_write_issue(message, strict_mode)
%HANDLE_WRITE_ISSUE 按严格模式处理写表异常。
% 输入：
%   message - 异常说明。
%   strict_mode - true时报错，false时警告。
% 输出：
%   无。
% 物理含义：
%   大表写出在不同环境中可能出现读回异常；严格模式用于关键结果硬校验。

if strict_mode
    error('%s', message);
else
    warning('%s', message);
end
end
