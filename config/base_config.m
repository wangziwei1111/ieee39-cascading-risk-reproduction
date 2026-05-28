function cfg = base_config()
%BASE_CONFIG 最小复现实验的全局配置。
% 输入：
%   无。
% 输出：
%   cfg - 结构体，集中管理随机数、潮流阈值、Markov、VaR、paper严重度和场景扫描参数。
% 物理含义：
%   本文件只保存工程参数。论文未明确给出的参数均标注“待校准”，避免把工程假设写成论文数据。

cfg = struct();

% MATPOWER候选安装路径。迁移到其他电脑时可在此处修改。
cfg.matpower_candidate_paths = { ...
    'E:\Matlab\toolbox\matpower6.0\matpower6.0', ...
    'E:\matpower\matpower5.1\matpower5.1' ...
    };

% 随机数种子，保证Monte Carlo事故链可重复。
cfg.seed = 202405;

% 本阶段不建立动态频率模型，频率固定为50 Hz。
cfg.system_frequency_hz = 50.0;
cfg.enable_frequency_trip = false;

% 潮流与越限判据。minimal/basic阶段使用0.90/1.10。
cfg.voltage_min_pu = 0.90;
cfg.voltage_max_pu = 1.10;

% MATPOWER case39部分线路RATE_A为0；用默认容量补齐用于最小越限检查，待校准。
cfg.default_branch_rate_mva = 1000.0; % 待校准

% 简化切负荷参数。该方法不是论文最优负荷削减，仅用于潮流收敛校正。
cfg.load_shed_step = 0.05;       % 待校准：每轮削减5%
cfg.load_shed_max_frac = 0.30;   % 待校准：最大削减30%
cfg.load_shed_max_iter = 6;

% 论文式最优负荷削减（OLS）接口。默认仍使用simple，避免改变既有复现结果。
cfg.load_shedding_mode = 'simple'; % 可选：simple / paper_ols / both_diagnostic
cfg.paper_ols_enable = false;
cfg.paper_ols_solver = 'matpower_opf_dispatchable_shed';
cfg.paper_ols_shed_cost = 1.0;
cfg.paper_ols_generation_cost = 0.0;
cfg.paper_ols_q_shed_mode = 'constant_power_factor';
cfg.paper_ols_max_iterations = 1;
cfg.paper_ols_fail_policy = 'fallback_to_simple_with_warning';
cfg.paper_ols_opf_alg = 'DEFAULT';
cfg.paper_ols_relax_voltage_limits = false;
cfg.paper_ols_relaxed_voltage_min_pu = 0.85;
cfg.paper_ols_relaxed_voltage_max_pu = 1.15;
cfg.paper_ols_use_soft_rate_limits = false;
cfg.paper_ols_rate_limit_relax_factor = 1.0;
cfg.paper_ols_apply_solution_mode = 'load_only'; % load_only / load_and_dispatch / load_dispatch_and_voltage_init
cfg.paper_ols_pf_after_apply_mode = 'runpf_from_updated_dispatch'; % runpf_from_flat_or_existing / runpf_from_updated_dispatch / accept_opf_if_success_diagnostic_only
cfg.paper_ols_formulation = 'positive_injection_generator'; % positive_injection_generator / fixed_q_shed_generator / dispatchable_load / dc_ols_preview
cfg.paper_ols_shed_gen_q_mode = 'free_q'; % free_q / fixed_zero_q / constant_pf_q_bounds
cfg.load_shedding_trigger_mode = 'nonconverged_only'; % 可选：nonconverged_only / nonconverged_or_violation / violation_only_diagnostic
cfg.load_shedding_violation_check_enable = true;
cfg.load_shedding_trigger_line_overload = true;
cfg.load_shedding_trigger_voltage_violation = true;
cfg.load_shedding_line_overload_threshold_pu = 1.0;
cfg.load_shedding_voltage_min_pu = cfg.voltage_min_pu;
cfg.load_shedding_voltage_max_pu = cfg.voltage_max_pu;

% 风机电压穿越脱网概率只记录，默认不在当前line-only Markov中触发。
cfg.enable_wind_voltage_trip_sampling = false;
cfg.wind_trip_record_only = true;
cfg.wind_trip_probability_model = 'voltage_piecewise_diagnostic';
cfg.wind_trip_low_voltage_start_pu = 0.90;   % 待校准：低电压概率开始区
cfg.wind_trip_low_voltage_trip_pu = 0.20;    % 待校准：低于该电压概率记为1
cfg.wind_trip_high_voltage_start_pu = 1.10;  % 待校准：高电压概率开始区
cfg.wind_trip_high_voltage_trip_pu = 1.30;   % 待校准：高于该电压概率记为1
cfg.wind_trip_probability_cap = 1.0;

% 综合风险权重。用户提供的论文权重为0.6/0.2/0.2。
cfg.risk_weights = [0.6, 0.2, 0.2];

% 严重度函数模式。默认入口仍使用basic；paper公式由专用入口触发。
cfg.severity_mode = 'basic';
cfg.enable_paper_severity = true;
cfg.paper_severity_formula_confirmed = true;
cfg.paper_lfor_use_line_count = true;
cfg.paper_nvor_use_bus_count = true;
cfg.voltage_upper_limit_pu = 1.05;
cfg.voltage_lower_limit_pu = 0.95;
cfg.paper_severity_note = '论文严重度函数已按用户提供公式录入；当前为line-only近似，仍待扩展机组状态概率';
cfg.paper_probability_mode = 'line_only';
cfg.paper_voltage_lower_limit_pu = 0.9;
cfg.paper_voltage_upper_limit_pu = 1.1;
cfg.paper_line_limit_source = 'RATE_A_as_active_limit_approximation';
cfg.paper_stage_probability_mode = 'initial_probability_times_candidate_transition_probability';
cfg.paper_strict_convergence = true;
cfg.paper_nonconverged_stage_policy = 'exclude_lfor_nvor_with_diagnostic';
cfg.paper_max_reasonable_line_loading_pu = 5.0;
cfg.paper_min_reasonable_voltage_pu = 0.0;
cfg.paper_max_reasonable_voltage_pu = 2.0;
cfg.paper_max_exp_argument = 20.0;
cfg.paper_fail_if_inf_severity = true;
cfg.paper_max_invalid_chain_ratio_for_var = 0.05;

% 主岛选择规则参数。原平衡节点所在岛至少承担该负荷比例时才可优先保留，待校准。
cfg.main_island_min_load_share = 0.5; % 待校准
cfg.main_island_selection_mode = 'largest_load_with_slack_bonus';

% Markov线路事故链搜索参数。
cfg.markov_enable = true;
cfg.markov_num_trials_per_initial_fault = 20;   % 待校准
cfg.markov_max_depth = 5;                       % 待校准
cfg.markov_min_trip_probability = 1e-6;         % 待校准
cfg.markov_trip_sampling_mode = 'independent';
cfg.markov_allow_multiple_trips_per_stage = true;
cfg.markov_stop_if_no_new_outage = true;
cfg.markov_stop_if_load_loss_frac_gt = 0.30;
cfg.markov_random_seed = cfg.seed;

% 线路停运概率模型参数。论文完整模型含保护隐性故障等参数；此处为潮流负载率驱动简化版，均待校准。
cfg.line_outage_p0 = 1e-4;              % 待校准
cfg.line_rated_loading_pu = 0.80;       % 待校准
cfg.line_limit_loading_pu = 1.00;       % 待校准
cfg.line_prob_at_limit = 0.10;          % 待校准
cfg.line_forced_trip_loading_pu = 1.20; % 待校准
cfg.line_outage_prob_cap = 1.0;

% 经验VaR参数。
cfg.var_confidence_levels = [0.90, 0.95, 0.98];
cfg.var_method = 'empirical_quantile';
cfg.var_use_chain_weights = false;
cfg.var_tail_definition = 'right_tail';
cfg.initial_fault_probability_mode = 'uniform';
cfg.initial_fault_probability_file = fullfile('data', 'line_initial_outage_probability_template.csv');
cfg.initial_fault_probability_unit = 'probability';
cfg.export_probability_template_if_missing = true;

% 候选线路和paper明细大表归档设置。
cfg.candidate_detail_chunk_size = 10000;
cfg.export_candidate_detail_chunks = true;
cfg.export_candidate_detail_full_csv = true;
cfg.export_candidate_detail_sample = true;
cfg.paper_detail_chunk_size = 10000;
cfg.export_paper_detail_chunks = true;
cfg.export_paper_detail_full_csv = true;
cfg.export_paper_detail_sample = true;

% 第4章场景扫描框架参数。集中式接入节点、渗透率定义和扫描点均为待校准工程设置。
cfg.scenario_results_root = fullfile('results', 'scenarios');
cfg.scenario_smoke_trials_per_initial_fault = 5;
cfg.scenario_penetration_definition = 'wind_capacity_divided_by_base_load'; % 待校准
cfg.scenario_centralized_wind_bus = 39; % 待校准：论文未明确时先用39节点
cfg.scenario_penetration_ratios = 0.40:0.05:0.80; % 待校准
cfg.scenario_wind_speed_values_mps = [8, 10, 12, 14, 16]; % 待校准

% 默认输出目录。场景扫描入口会覆盖为 results/scenarios/<scenario_id>/...
cfg.results_table_dir = fullfile('results', 'tables');
cfg.results_log_dir = fullfile('results', 'logs');
cfg.results_chain_dir = fullfile('results', 'chains');
cfg.results_figure_dir = fullfile('results', 'figures');
end
