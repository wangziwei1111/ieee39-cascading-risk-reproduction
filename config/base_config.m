function cfg = base_config()
%BASE_CONFIG 最小复现实验的全局配置。
% 输入：
%   无。
% 输出：
%   cfg - 结构体，包含随机种子、潮流阈值、简化切负荷参数和风险权重。
% 物理含义：
%   本文件集中管理论文未明确给出的工程参数。标注“待校准”的参数
%   仅用于跑通最小闭环，后续应根据论文、标准或实测数据校准。

cfg = struct();

% MATPOWER候选安装路径。若MATLAB全局path未配置，main脚本会尝试自动加入。
% 这些是本机探测到的路径；迁移到其他电脑时可在此处修改。
cfg.matpower_candidate_paths = { ...
    'E:\Matlab\toolbox\matpower6.0\matpower6.0', ...
    'E:\matpower\matpower5.1\matpower5.1' ...
    };

% 随机数种子，保证每次运行结果可重复。
cfg.seed = 202405;

% 系统频率固定为 50 Hz。本阶段禁用频率脱网。
cfg.system_frequency_hz = 50.0;
cfg.enable_frequency_trip = false;

% 潮流与越限判据。
cfg.voltage_min_pu = 0.90;
cfg.voltage_max_pu = 1.10;

% MATPOWER case39 中部分 RATE_A 为 0，表示未设置线路热稳限值。
% 该默认线路容量用于最小版越限检查，待校准。
cfg.default_branch_rate_mva = 1000.0; % 待校准

% 简化切负荷参数：每轮按比例削减所有有功/无功负荷。
cfg.load_shed_step = 0.05;       % 待校准：每轮削减 5%
cfg.load_shed_max_frac = 0.30;   % 论文终止条件之一：负荷损失超过 30%
cfg.load_shed_max_iter = 6;      % 6 轮 * 5% = 30%

% 风机电压穿越脱网概率是否实际抽样触发。
% 最小版为了可追溯，默认计算概率但不二次扩展事故链。
cfg.enable_wind_voltage_trip_sampling = false;

% 简化风险指标权重。论文给出 SLLR/SLFOR/SNVOR 权重为 0.6/0.2/0.2。
cfg.risk_weights = [0.6, 0.2, 0.2];

% 主岛选择规则参数。原平衡节点所在岛至少承担该比例负荷时，才允许
% 优先保留原平衡节点所在岛；否则选择更能代表主网的最大负荷岛。
cfg.main_island_min_load_share = 0.5; % 待校准
cfg.main_island_selection_mode = 'largest_load_with_slack_bonus';

% 输出目录。
cfg.results_table_dir = fullfile('results', 'tables');
cfg.results_log_dir = fullfile('results', 'logs');
end
