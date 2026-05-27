function severity_table = calc_paper_chain_severity(chain_summary_table, cfg)
%CALC_PAPER_CHAIN_SEVERITY 计算论文公式版事故链严重度。
% 输入：
%   chain_summary_table - Markov事故链汇总表。
%   cfg - 全局配置，必须确认 paper_severity_formula_confirmed=true。
% 输出：
%   severity_table - 包含 paper_LLR/paper_LFOR/paper_NVOR/paper_CRI 的表。
% 物理含义：
%   该函数用于承载论文完整 LLR/LFOR/NVOR 严重度函数。当前仓库尚未人工核对并录入
%   论文公式，因此函数默认报错，防止把basic指标伪装成论文公式结果。

if ~isfield(cfg, 'paper_severity_formula_confirmed') || ~cfg.paper_severity_formula_confirmed
    error('论文严重度函数尚未确认，请先在 docs/paper_severity_formula_notes.md 中录入并核对公式。');
end

% 论文公式确认后，必须在此处逐项实现并在注释中写明公式来源。
% 当前不返回伪结果。
error('论文严重度函数接口已建立，但具体公式尚未实现。请先录入并核对论文公式。');

% 该占位用于说明未来返回结构，当前不会执行到这里。
paper_LLR = NaN(height(chain_summary_table), 1); %#ok<UNRCH>
paper_LFOR = NaN(height(chain_summary_table), 1);
paper_NVOR = NaN(height(chain_summary_table), 1);
paper_CRI = calc_cri(paper_LLR, paper_LFOR, paper_NVOR, cfg.risk_weights);
severity_table = table(paper_LLR, paper_LFOR, paper_NVOR, paper_CRI);
end
