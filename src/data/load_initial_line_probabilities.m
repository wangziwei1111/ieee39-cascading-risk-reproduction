function probability_table = load_initial_line_probabilities(cfg, mpc)
%LOAD_INITIAL_LINE_PROBABILITIES 加载或生成初始线路故障概率权重。
% 输入：
%   cfg - 全局配置，包含初始故障概率模式和文件路径。
%   mpc - MATPOWER算例，用于校验线路数量和导出模板。
% 输出：
%   probability_table - 每条线路的初始故障概率与归一化权重。
% 物理含义：
%   当前默认uniform表示每条初始线路等权。paper_table_4_1模式要求用户
%   先按论文表4-1填写模板，否则明确报错，不自动填默认值。

mode = cfg.initial_fault_probability_mode;
file_path = cfg.initial_fault_probability_file;
if ~isabsolute_path(file_path)
    project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    file_path = fullfile(project_root, file_path);
end

if cfg.export_probability_template_if_missing && ~exist(file_path, 'file')
    export_line_probability_template(mpc, file_path);
end

branch_index = (1:size(mpc.branch, 1))';
from_bus = mpc.branch(:, 1);
to_bus = mpc.branch(:, 2);

switch lower(mode)
    case 'uniform'
        initial_outage_probability = ones(size(branch_index)) / numel(branch_index);

    case 'paper_table_4_1'
        if ~exist(file_path, 'file')
            error('找不到初始停运概率文件：%s。请先导出并根据论文表4-1填写数据。', file_path);
        end
        input_table = readtable(file_path);
        required = {'branch_index', 'from_bus', 'to_bus', 'initial_outage_probability'};
        missing = setdiff(required, input_table.Properties.VariableNames);
        if ~isempty(missing)
            error('初始停运概率文件缺少字段：%s', strjoin(missing, ', '));
        end
        if height(input_table) ~= numel(branch_index)
            error('初始停运概率文件线路数量不是46条，请检查是否与case39一致。');
        end
        input_table = sortrows(input_table, 'branch_index');
        if any(input_table.branch_index ~= branch_index) || ...
                any(input_table.from_bus ~= from_bus) || any(input_table.to_bus ~= to_bus)
            error('初始停运概率文件的branch_index/from_bus/to_bus与当前case39不一致。');
        end
        initial_outage_probability = input_table.initial_outage_probability;
        if any(isnan(initial_outage_probability)) || any(initial_outage_probability < 0)
            error('请先根据论文表4-1填写数据：initial_outage_probability存在NaN或负数。');
        end

    otherwise
        error('未知初始故障概率模式：%s', mode);
end

if sum(initial_outage_probability) <= 0
    error('初始故障概率总和必须大于0。');
end

normalized_weight = initial_outage_probability / sum(initial_outage_probability);
probability_table = table(branch_index, from_bus, to_bus, ...
    initial_outage_probability, normalized_weight);
end

function tf = isabsolute_path(path_text)
%ISABSOLUTE_PATH 判断路径是否为绝对路径。
% 输入：
%   path_text - 路径字符串。
% 输出：
%   tf - 是否为绝对路径。
% 物理含义：
%   允许配置文件使用相对路径，运行时转换到项目根目录。

path_text = char(path_text);
tf = numel(path_text) >= 2 && path_text(2) == ':';
end
