function manifest_table = save_table_chunks(tbl, output_dir, base_name, chunk_size)
%SAVE_TABLE_CHUNKS 将大表按固定行数分块写出。
% 输入：
%   tbl - 需要分块保存的table。
%   output_dir - 分块CSV输出目录。
%   base_name - 文件名前缀，例如markov_candidate_details。
%   chunk_size - 每个分块最多包含的行数。
% 输出：
%   manifest_table - 分块清单，记录文件名、行范围、行数和文件大小。
% 物理含义：
%   大CSV在网页或连接器中可能展示异常。分块文件加manifest能稳定复核
%   完整候选线路抽样明细，避免只依赖单个大文件。

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

if chunk_size <= 0
    error('chunk_size必须为正数。');
end

total_rows = height(tbl);
num_chunks = max(1, ceil(total_rows / chunk_size));
rows = cell(num_chunks, 1);

for chunk_index = 1:num_chunks
    start_row = (chunk_index - 1) * chunk_size + 1;
    end_row = min(chunk_index * chunk_size, total_rows);
    if total_rows == 0
        chunk_tbl = tbl;
        start_row = 0;
        end_row = 0;
    else
        chunk_tbl = tbl(start_row:end_row, :);
    end

    file_name = sprintf('%s_part%03d.csv', base_name, chunk_index);
    file_path = fullfile(output_dir, file_name);
    save_result_table(chunk_tbl, file_path, true);

    file_bytes = get_file_bytes(file_path);
    if height(chunk_tbl) > 0 && file_bytes < 100
        error('分块文件过小：%s (%d bytes)', file_path, file_bytes);
    end
    readback = readtable(file_path);
    if height(chunk_tbl) > 0 && height(readback) == 0
        error('分块文件读回为空：%s', file_path);
    end
    if height(readback) ~= height(chunk_tbl)
        error('分块文件读回行数不一致：%s，期望%d，实际%d', ...
            file_path, height(chunk_tbl), height(readback));
    end

    row_count = height(chunk_tbl);
    rows{chunk_index} = table(chunk_index, string(file_name), start_row, end_row, row_count, file_bytes, ...
        'VariableNames', {'chunk_index', 'file_name', 'start_row', 'end_row', 'row_count', 'file_bytes'});
end

manifest_table = vertcat(rows{:});
end
