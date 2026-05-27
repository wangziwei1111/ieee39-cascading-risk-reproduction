function severity_table = calc_paper_chain_severity(chain_summary_table, cfg, ...
    line_flow_detail_table, bus_voltage_detail_table, stage_probability_table)
%CALC_PAPER_CHAIN_SEVERITY 计算line-only论文公式版事故链严重度。
% 输入：
%   chain_summary_table - Markov事故链汇总表，每行一条事故链。
%   cfg - 全局配置，必须确认paper_severity_formula_confirmed=true。
%   line_flow_detail_table - 每级全线路有功潮流明细。
%   bus_voltage_detail_table - 每级全节点电压明细。
%   stage_probability_table - 每级初始概率、候选转移概率和累计概率明细。
% 输出：
%   severity_table - paper_LLR/paper_LFOR/paper_NVOR/paper_CRI。
% 物理含义：
%   按用户提供论文公式计算单条事故链风险值：
%   paper_LLR = sum_k P_stage(E_k) * C_c(E_k)/P_load*100%。
%   paper_LFOR = sum_k P_stage(E_k) * sum_n (exp(max(P_li-P_li,max,0))-1)/(e-1)*100。
%   paper_NVOR = sum_k P_stage(E_k) * sum_m (exp(max(0.9-U_m,U_m-1.1,0))-1)/(e-1)*100。
%   当前为line-only近似：P_wt(E_k)=1，P_ge(E_k)=1，P_line由初始线路概率和候选线路转移概率构造。

if ~isfield(cfg, 'paper_severity_formula_confirmed') || ~cfg.paper_severity_formula_confirmed
    error('论文严重度函数尚未确认，请先在 docs/paper_severity_formula_notes.md 中录入并核对公式。');
end
if nargin < 5
    error('paper_formula需要line_flow_detail_table、bus_voltage_detail_table和stage_probability_table，不能回退basic。');
end
if isempty(line_flow_detail_table) || isempty(bus_voltage_detail_table) || isempty(stage_probability_table)
    error('paper_formula明细表为空，无法计算论文公式严重度。');
end

required_line = {'initial_branch', 'trial_id', 'stage_id', 'line_severity_component'};
required_bus = {'initial_branch', 'trial_id', 'stage_id', 'voltage_severity_component'};
required_prob = {'initial_branch', 'trial_id', 'stage_id', 'stage_cumulative_probability', ...
    'stage_load_shed_mw', 'base_load_mw'};
check_required_columns(line_flow_detail_table, required_line, 'line_flow_detail_table');
check_required_columns(bus_voltage_detail_table, required_bus, 'bus_voltage_detail_table');
check_required_columns(stage_probability_table, required_prob, 'stage_probability_table');

n = height(chain_summary_table);
paper_LLR = NaN(n, 1);
paper_LFOR = NaN(n, 1);
paper_NVOR = NaN(n, 1);

for i = 1:n
    initial_branch = chain_summary_table.initial_branch(i);
    trial_id = chain_summary_table.trial_id(i);
    stage_mask = stage_probability_table.initial_branch == initial_branch & ...
        stage_probability_table.trial_id == trial_id;
    chain_stages = stage_probability_table(stage_mask, :);
    if isempty(chain_stages)
        error('事故链 initial_branch=%d trial_id=%d 没有stage_probability记录。', initial_branch, trial_id);
    end

    llr_value = 0;
    lfor_value = 0;
    nvor_value = 0;
    for s = 1:height(chain_stages)
        stage_id = chain_stages.stage_id(s);
        p_stage = chain_stages.stage_cumulative_probability(s);
        if isnan(p_stage) || p_stage < 0
            error('stage_cumulative_probability必须为非负数，initial_branch=%d trial_id=%d stage_id=%d。', ...
                initial_branch, trial_id, stage_id);
        end

        base_load_mw = chain_stages.base_load_mw(s);
        if base_load_mw <= 0 || isnan(base_load_mw)
            error('base_load_mw必须大于0。');
        end
        stage_llr_severity = chain_stages.stage_load_shed_mw(s) / base_load_mw * 100;

        line_mask = line_flow_detail_table.initial_branch == initial_branch & ...
            line_flow_detail_table.trial_id == trial_id & line_flow_detail_table.stage_id == stage_id;
        bus_mask = bus_voltage_detail_table.initial_branch == initial_branch & ...
            bus_voltage_detail_table.trial_id == trial_id & bus_voltage_detail_table.stage_id == stage_id;
        if ~any(line_mask)
            error('缺少线路潮流明细：initial_branch=%d trial_id=%d stage_id=%d。', initial_branch, trial_id, stage_id);
        end
        if ~any(bus_mask)
            error('缺少节点电压明细：initial_branch=%d trial_id=%d stage_id=%d。', initial_branch, trial_id, stage_id);
        end

        stage_lfor_severity = sum(line_flow_detail_table.line_severity_component(line_mask));
        stage_nvor_severity = sum(bus_voltage_detail_table.voltage_severity_component(bus_mask));

        llr_value = llr_value + p_stage * stage_llr_severity;
        lfor_value = lfor_value + p_stage * stage_lfor_severity;
        nvor_value = nvor_value + p_stage * stage_nvor_severity;
    end

    paper_LLR(i) = llr_value;
    paper_LFOR(i) = lfor_value;
    paper_NVOR(i) = nvor_value;
end

paper_CRI = calc_cri(paper_LLR, paper_LFOR, paper_NVOR, cfg.risk_weights);
if all(isnan(paper_LLR)) || all(isnan(paper_LFOR)) || all(isnan(paper_NVOR)) || all(isnan(paper_CRI))
    error('paper_formula结果不能全为NaN。');
end

severity_table = table(paper_LLR, paper_LFOR, paper_NVOR, paper_CRI);
end

function check_required_columns(tbl, required, label)
%CHECK_REQUIRED_COLUMNS 检查公式输入表字段是否齐全。
missing = setdiff(required, tbl.Properties.VariableNames);
if ~isempty(missing)
    error('%s缺少字段：%s', label, strjoin(missing, ', '));
end
end
