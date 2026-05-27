function markov_var_table = calc_markov_var_metrics(risk_samples, cfg)
%CALC_MARKOV_VAR_METRICS 计算全局Markov样本经验VaR风险指标。
% 输入：
%   risk_samples - build_markov_risk_samples输出的事故链风险样本表。
%   cfg - 全局配置，包含置信水平和风险权重。
% 输出：
%   markov_var_table - 每个sigma一行，包含SLLR、SLFOR、SNVOR、CRI。
% 物理含义：
%   这里的SLLR/SLFOR/SNVOR是基于当前Markov样本的经验VaR最小版，
%   可用于验证流程；尚不是论文完整参数校准后的结果。

sigmas = cfg.var_confidence_levels(:);
rows = cell(numel(sigmas), 1);
weights = [];
if isfield(cfg, 'var_use_chain_weights') && cfg.var_use_chain_weights
    weights = risk_samples.sample_weight;
end

for i = 1:numel(sigmas)
    sigma = sigmas(i);
    SLLR = calc_empirical_var(risk_samples.chain_LLR, sigma, weights);
    SLFOR = calc_empirical_var(risk_samples.chain_LFOR, sigma, weights);
    SNVOR = calc_empirical_var(risk_samples.chain_NVOR, sigma, weights);
    CRI = calc_cri(SLLR, SLFOR, SNVOR, cfg.risk_weights);
    rows{i} = table(sigma, SLLR, SLFOR, SNVOR, CRI);
end

markov_var_table = vertcat(rows{:});
end
