function severity_table = calc_paper_chain_severity(chain_summary_table, cfg, ...
    line_flow_detail_table, bus_voltage_detail_table, stage_probability_table)
%CALC_PAPER_CHAIN_SEVERITY 计算line-only论文公式版事故链严重度。
% 输入：
%   chain_summary_table - Markov事故链汇总表，每行一条事故链。
%   cfg - 全局配置，必须确认paper_severity_formula_confirmed=true。
%   line_flow_detail_table - 仅物理有效stage的全线路有功潮流明细。
%   bus_voltage_detail_table - 仅物理有效stage的全节点电压明细。
%   stage_probability_table - 所有stage的概率、负荷损失和severity_valid标记。
% 输出：
%   severity_table - paper_LLR/paper_LFOR/paper_NVOR/paper_CRI及完整性诊断。
% 物理含义：
%   LLR只依赖负荷损失和阶段概率；LFOR/NVOR只允许使用收敛且数值合理的stage。
%   非收敛stage不回退basic，也不把最后迭代PF/PT/VM当作论文严重度输入。

if ~isfield(cfg, 'paper_severity_formula_confirmed') || ~cfg.paper_severity_formula_confirmed
    error('论文严重度函数尚未确认，请先核对公式。');
end
if nargin < 5
    error('paper_formula需要line/bus/stage明细表，不能回退basic。');
end

required_prob = {'initial_branch', 'trial_id', 'stage_id', 'stage_cumulative_probability', ...
    'stage_load_shed_mw', 'base_load_mw', 'severity_valid'};
check_required_columns(stage_probability_table, required_prob, 'stage_probability_table');

n = height(chain_summary_table);
paper_LLR = NaN(n, 1);
paper_LFOR = NaN(n, 1);
paper_NVOR = NaN(n, 1);
paper_CRI = NaN(n, 1);
paper_valid_stage_count = zeros(n, 1);
paper_invalid_stage_count = zeros(n, 1);
paper_lfor_nvor_complete = false(n, 1);

for i = 1:n
    initial_branch = chain_summary_table.initial_branch(i);
    trial_id = chain_summary_table.trial_id(i);
    chain_stages = stage_probability_table(stage_probability_table.initial_branch == initial_branch & ...
        stage_probability_table.trial_id == trial_id, :);
    if isempty(chain_stages)
        error('事故链 initial_branch=%d trial_id=%d 没有stage_probability记录。', initial_branch, trial_id);
    end

    llr_value = 0;
    lfor_value = 0;
    nvor_value = 0;
    valid_count = 0;
    invalid_count = 0;

    for s = 1:height(chain_stages)
        stage_id = chain_stages.stage_id(s);
        p_stage = chain_stages.stage_cumulative_probability(s);
        if isnan(p_stage) || p_stage < 0
            error('stage_cumulative_probability必须为非负且非NaN。');
        end
        base_load_mw = chain_stages.base_load_mw(s);
        if base_load_mw <= 0 || isnan(base_load_mw)
            error('base_load_mw必须大于0。');
        end

        stage_llr_severity = chain_stages.stage_load_shed_mw(s) / base_load_mw * 100;
        llr_value = llr_value + p_stage * stage_llr_severity;

        if chain_stages.severity_valid(s) == 1
            line_mask = line_flow_detail_table.initial_branch == initial_branch & ...
                line_flow_detail_table.trial_id == trial_id & line_flow_detail_table.stage_id == stage_id;
            bus_mask = bus_voltage_detail_table.initial_branch == initial_branch & ...
                bus_voltage_detail_table.trial_id == trial_id & bus_voltage_detail_table.stage_id == stage_id;
            if ~any(line_mask) || ~any(bus_mask)
                error('severity_valid=1的stage缺少line/bus明细：branch=%d trial=%d stage=%d。', ...
                    initial_branch, trial_id, stage_id);
            end
            stage_lfor_severity = sum(line_flow_detail_table.line_severity_component(line_mask));
            stage_nvor_severity = sum(bus_voltage_detail_table.voltage_severity_component(bus_mask));
            if isinf(stage_lfor_severity) || isnan(stage_lfor_severity) || ...
                    isinf(stage_nvor_severity) || isnan(stage_nvor_severity)
                error('有效stage中出现Inf或NaN严重度。');
            end
            lfor_value = lfor_value + p_stage * stage_lfor_severity;
            nvor_value = nvor_value + p_stage * stage_nvor_severity;
            valid_count = valid_count + 1;
        else
            invalid_count = invalid_count + 1;
        end
    end

    paper_LLR(i) = llr_value;
    paper_valid_stage_count(i) = valid_count;
    paper_invalid_stage_count(i) = invalid_count;
    paper_lfor_nvor_complete(i) = valid_count > 0;
    if valid_count > 0
        paper_LFOR(i) = lfor_value;
        paper_NVOR(i) = nvor_value;
        paper_CRI(i) = calc_cri(paper_LLR(i), paper_LFOR(i), paper_NVOR(i), cfg.risk_weights);
    end
end

if all(isnan(paper_LLR))
    error('paper_LLR不能全为NaN。');
end
severity_table = table(paper_LLR, paper_LFOR, paper_NVOR, paper_CRI, ...
    paper_valid_stage_count, paper_invalid_stage_count, paper_lfor_nvor_complete);
end

function check_required_columns(tbl, required, label)
missing = setdiff(required, tbl.Properties.VariableNames);
if ~isempty(missing)
    error('%s缺少字段：%s', label, strjoin(missing, ', '));
end
end
