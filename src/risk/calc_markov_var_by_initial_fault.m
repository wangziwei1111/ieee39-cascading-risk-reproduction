function initial_fault_var_table = calc_markov_var_by_initial_fault(risk_samples, cfg, severity_prefix)
%CALC_MARKOV_VAR_BY_INITIAL_FAULT 按初始线路故障计算条件VaR指标。
% 输入：
%   risk_samples - Markov事故链风险样本表。
%   cfg - 全局配置，当前按sigma=0.95输出分初始线路风险。
%   severity_prefix - 可选，'basic'或'paper'；默认'basic'。
% 输出：
%   initial_fault_var_table - 每条初始线路一行的条件风险指标表。
% 物理含义：
%   分初始线路VaR表示“已知该线路为初始故障”时的条件风险。组内分位数不再
%   乘初始线路权重；initial_branch_weight仅作为该初始故障全局概率权重展示。

if nargin < 3 || isempty(severity_prefix)
    severity_prefix = 'basic';
end
[llr_field, lfor_field, nvor_field] = resolve_severity_fields(risk_samples, severity_prefix);

sigma = 0.95;
branches = unique(risk_samples.initial_branch);
rows = cell(numel(branches), 1);

for i = 1:numel(branches)
    branch = branches(i);
    group = risk_samples(risk_samples.initial_branch == branch, :);
    SLLR = calc_empirical_var(group.(llr_field), sigma, []);
    SLFOR = calc_empirical_var(group.(lfor_field), sigma, []);
    SNVOR = calc_empirical_var(group.(nvor_field), sigma, []);
    CRI = calc_cri(SLLR, SLFOR, SNVOR, cfg.risk_weights);
    sample_count = height(group);
    if ismember('initial_branch_weight', group.Properties.VariableNames)
        initial_branch_weight = group.initial_branch_weight(1);
    else
        initial_branch_weight = NaN;
    end
    rows{i} = table(branch, sigma, sample_count, initial_branch_weight, ...
        SLLR, SLFOR, SNVOR, CRI, ...
        'VariableNames', {'initial_branch', 'sigma', 'sample_count', ...
        'initial_branch_weight', 'SLLR', 'SLFOR', 'SNVOR', 'CRI'});
end

initial_fault_var_table = sortrows(vertcat(rows{:}), 'CRI', 'descend');
end

function [llr_field, lfor_field, nvor_field] = resolve_severity_fields(risk_samples, severity_prefix)
%RESOLVE_SEVERITY_FIELDS 根据前缀解析严重度字段名。
severity_prefix = lower(string(severity_prefix));
switch severity_prefix
    case "basic"
        llr_field = 'basic_LLR';
        lfor_field = 'basic_LFOR';
        nvor_field = 'basic_NVOR';
    case "paper"
        llr_field = 'paper_LLR';
        lfor_field = 'paper_LFOR';
        nvor_field = 'paper_NVOR';
    otherwise
        error('未知严重度前缀：%s', severity_prefix);
end

required = {llr_field, lfor_field, nvor_field};
missing = setdiff(required, risk_samples.Properties.VariableNames);
if ~isempty(missing)
    error('风险样本缺少%s严重度字段：%s', severity_prefix, strjoin(missing, ', '));
end
end
