function bytes = get_file_bytes(file_path)
%GET_FILE_BYTES 获取文件大小。
% 输入：
%   file_path - 文件路径。
% 输出：
%   bytes - 文件大小，单位bytes。
% 物理含义：
%   结果归档时用文件大小判断CSV是否实际落盘，而不是只生成空文件。

if ~exist(file_path, 'file')
    error('文件不存在：%s', file_path);
end
file_info = dir(file_path);
bytes = file_info.bytes;
end
