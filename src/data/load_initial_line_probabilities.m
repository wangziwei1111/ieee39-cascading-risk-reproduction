function probability_table = load_initial_line_probabilities(cfg, mpc)
%LOAD_INITIAL_LINE_PROBABILITIES 加载初始线路停运概率。
% 输入：
%   cfg - 全局配置，包含 initial_fault_probability_mode 和概率文件路径。
%   mpc - MATPOWER 算例，用于校验线路编号和两端母线。
% 输出：
%   probability_table - 每条线路的初始停运概率和归一化权重。
% 物理含义：
%   uniform 模式表示每条初始线路故障等权；paper_table_4_1 模式表示
%   使用用户从论文表4-1手动录入的线路初始停运概率。若表4-1数据缺失，
%   本函数必须报错，不能自动编造或回退到 uniform。

mode = cfg.initial_fault_probability_mode;
file_path = cfg.initial_fault_probability_file;
if ~isabsolute_path(file_path)
    project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    file_path = fullfile(project_root, file_path);
end

branch_index = (1:size(mpc.branch, 1))';
from_bus = mpc.branch(:, 1);
to_bus = mpc.branch(:, 2);

switch lower(mode)
    case 'uniform'
        initial_outage_probability = ones(size(branch_index)) / numel(branch_index);
        paper_prob_times_1e_minus_4 = NaN(size(branch_index));
        source_note = repmat("uniform default; paper table 4-1 not used", size(branch_index));

    case 'paper_table_4_1'
        if ~exist(file_path, 'file')
            error('找不到论文表4-1线路初始停运概率文件：%s。请先根据论文表4-1填写数据。', file_path);
        end
        input_table = readtable(file_path);
        validate_probability_table_topology(input_table, branch_index, from_bus, to_bus);

        if ismember('paper_prob_times_1e_minus_4', input_table.Properties.VariableNames)
            paper_prob_times_1e_minus_4 = input_table.paper_prob_times_1e_minus_4;
        else
            paper_prob_times_1e_minus_4 = NaN(size(branch_index));
        end
        if ismember('initial_outage_probability', input_table.Properties.VariableNames)
            initial_outage_probability = input_table.initial_outage_probability;
        else
            initial_outage_probability = NaN(size(branch_index));
        end

        paper_filled = ~isnan(paper_prob_times_1e_minus_4);
        prob_filled = ~isnan(initial_outage_probability);
        if ~any(paper_filled | prob_filled)
            error('请先根据论文表4-1填写线路初始停运概率，不能自动编造。');
        end
        if any(~(paper_filled | prob_filled))
            error('请先根据论文表4-1填写全部46条线路初始停运概率，不能自动编造。');
        end

        converted_probability = paper_prob_times_1e_minus_4 * 1e-4;
        both_filled = paper_filled & prob_filled;
        if any(abs(initial_outage_probability(both_filled) - converted_probability(both_filled)) > 1e-12)
            error('paper_prob_times_1e_minus_4 与 initial_outage_probability 不一致，请检查论文表4-1录入值。');
        end
        only_paper = paper_filled & ~prob_filled;
        initial_outage_probability(only_paper) = converted_probability(only_paper);

        if any(isnan(initial_outage_probability)) || any(initial_outage_probability < 0)
            error('请先根据论文表4-1填写线路初始停运概率，不能自动编造。');
        end
        if any(paper_prob_times_1e_minus_4(paper_filled) < 0)
            error('paper_prob_times_1e_minus_4 不能为负值。');
        end

        if ismember('source_note', input_table.Properties.VariableNames)
            source_note = string(input_table.source_note);
        else
            source_note = repmat("paper table 4-1 user input", size(branch_index));
        end

    otherwise
        error('未知初始故障概率模式：%s', mode);
end

if sum(initial_outage_probability) <= 0
    error('初始故障概率总和必须大于0。');
end

normalized_weight = initial_outage_probability / sum(initial_outage_probability);
probability_table = table(branch_index, from_bus, to_bus, paper_prob_times_1e_minus_4, ...
    initial_outage_probability, normalized_weight, source_note);
end

function validate_probability_table_topology(input_table, branch_index, from_bus, to_bus)
%VALIDATE_PROBABILITY_TABLE_TOPOLOGY 校验概率文件线路拓扑与当前case39一致。
% 输入：
%   input_table - 用户填写的概率表。
%   branch_index, from_bus, to_bus - 当前MATPOWER case39的线路编号和两端母线。
% 输出：
%   无。校验失败时报错。
% 物理含义：
%   保证论文表4-1概率映射到正确的线路，避免因线路顺序或编号错误污染VaR权重。
required = {'branch_index', 'from_bus', 'to_bus'};
missing = setdiff(required, input_table.Properties.VariableNames);
if ~isempty(missing)
    error('线路初始停运概率文件缺少字段：%s', strjoin(missing, ', '));
end
if height(input_table) ~= numel(branch_index)
    error('线路初始停运概率文件应包含%d条线路，实际为%d条。', ...
        numel(branch_index), height(input_table));
end
input_table = sortrows(input_table, 'branch_index');
if any(input_table.branch_index ~= branch_index) || ...
        any(input_table.from_bus ~= from_bus) || any(input_table.to_bus ~= to_bus)
    error('概率文件的 branch_index/from_bus/to_bus 与当前 case39 不一致。');
end
end

function tf = isabsolute_path(path_text)
%ISABSOLUTE_PATH 判断路径是否为绝对路径。
% 输入：
%   path_text - 文件路径。
% 输出：
%   tf - true表示绝对路径。
path_text = char(path_text);
tf = numel(path_text) >= 2 && path_text(2) == ':';
end
