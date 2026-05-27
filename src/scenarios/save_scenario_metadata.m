function save_scenario_metadata(scenario, cfg, config_dir)
%SAVE_SCENARIO_METADATA 保存场景运行使用的配置快照。
% 输入：
%   scenario - 本次运行的场景结构体。
%   cfg - 本次运行的配置结构体。
%   config_dir - 场景config输出目录。
% 输出：
%   无。
% 物理含义：
%   将每个场景实际使用的参数落盘，保证后续可以复核该场景的风电容量、接入点和输出目录。

if ~exist(config_dir, 'dir')
    mkdir(config_dir);
end

save(fullfile(config_dir, 'scenario_used.mat'), 'scenario');
save(fullfile(config_dir, 'cfg_used.mat'), 'cfg');

scenario_table = struct_to_key_value_table(scenario);
cfg_table = struct_to_key_value_table(cfg);
% 元数据中含中文说明和向量字符串；CSV仅作人工查看，严格可复现信息以MAT/JSON为准。
writetable(scenario_table, fullfile(config_dir, 'scenario_used.csv'), 'WriteRowNames', false);
writetable(cfg_table, fullfile(config_dir, 'cfg_used.csv'), 'WriteRowNames', false);

json_text = jsonencode(scenario);
fid = fopen(fullfile(config_dir, 'scenario_used.json'), 'w');
if fid < 0
    error('无法写入场景JSON文件。');
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', json_text);
clear cleanup;
end

function tbl = struct_to_key_value_table(s)
%STRUCT_TO_KEY_VALUE_TABLE 将结构体转成key/value表，向量字段转字符串。
fields = fieldnames(s);
field = strings(numel(fields), 1);
value = strings(numel(fields), 1);
for k = 1:numel(fields)
    field(k) = string(fields{k});
    value(k) = stringify_value(s.(fields{k}));
end
tbl = table(field, value);
end

function out = stringify_value(v)
%STRINGIFY_VALUE 将MATLAB值转为便于CSV保存的字符串。
if isnumeric(v) || islogical(v)
    if isempty(v)
        out = "<empty>";
    elseif isscalar(v)
        if isnumeric(v) && isnan(v)
            out = "NaN";
        else
            out = string(v);
        end
    else
        parts = string(v(:).');
        parts(isnan(v(:).')) = "NaN";
        out = "[" + strjoin(parts, ";") + "]";
    end
elseif ischar(v) || isstring(v)
    out = sanitize_csv_text(string(v));
elseif iscell(v)
    out = sanitize_csv_text(string(jsonencode(v)));
elseif isstruct(v)
    out = sanitize_csv_text(string(jsonencode(v)));
else
    out = sanitize_csv_text(string(v));
end
end

function out = sanitize_csv_text(in)
%SANITIZE_CSV_TEXT 让元数据文本在不同MATLAB版本中稳定写入CSV。
out = replace(in, newline, " ");
out = replace(out, ",", ";");
end
