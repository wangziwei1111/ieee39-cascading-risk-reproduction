function init_random_seed(seed)
%INIT_RANDOM_SEED 初始化随机数种子。
% 输入：
%   seed - 随机数种子。
% 输出：
%   无。
% 物理含义：
%   保证含随机抽样的事故链搜索在未来扩展时可重复。本最小版目前
%   默认不抽样风机脱网，但仍保留可重复性入口。

rng(seed, 'twister');
end
