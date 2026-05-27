function markov_var_table = calc_markov_var_metrics(risk_samples, cfg, severity_prefix)
%CALC_MARKOV_VAR_METRICS 计算全局Markov样本经验VaR风险指标。
% 输入：
%   risk_samples - build_markov_risk_samples输出的事故链风险样本表。
%   cfg - 全局配置，包含置信水平、风险权重和样本权重。
%   severity_prefix - 可选，'basic'或'paper'；默认'basic'。
% 输出：
%   markov_var_table - 每个sigma一行，包含SLLR、SLFOR、SNVOR、CRI。
% 物理含义：
%   默认使用basic_*严重度，保证既有uniform/weighted VaR结果不被破坏。
%   若请求paper但样本中没有paper_*字段，直接报错，防止伪造论文公式结果。

if nargin < 3 || isempty(severity_prefix)
    severity_prefix = 'basic';
end
[llr_field, lfor_field, nvor_field] = resolve_severity_fields(risk_samples, severity_prefix);

sigmas = cfg.var_confidence_levels(:);
rows = cell(numel(sigmas), 1);
weights = [];
if isfield(cfg, 'var_use_chain_weights') && cfg.var_use_chain_weights
    weights = risk_samples.sample_weight;
end

for i = 1:numel(sigmas)
    sigma = sigmas(i);
    SLLR = calc_empirical_var(risk_samples.(llr_field), sigma, weights);
    SLFOR = calc_empirical_var(risk_samples.(lfor_field), sigma, weights);
    SNVOR = calc_empirical_var(risk_samples.(nvor_field), sigma, weights);
    CRI = calc_cri(SLLR, SLFOR, SNVOR, cfg.risk_weights);
    rows{i} = table(sigma, SLLR, SLFOR, SNVOR, CRI);
end

markov_var_table = vertcat(rows{:});
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
