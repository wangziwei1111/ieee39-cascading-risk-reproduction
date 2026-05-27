function severity_table = calc_chain_severity(chain_summary_table, cfg, varargin)
%CALC_CHAIN_SEVERITY 根据配置计算事故链严重度。
% 输入：
%   chain_summary_table - Markov事故链汇总表。
%   cfg - 全局配置，包含 severity_mode 和论文公式确认标志。
% 输出：
%   severity_table - basic和/或paper严重度字段。
% 物理含义：
%   将basic流程验证指标与paper公式指标解耦。默认basic正常输出；当请求paper但公式未确认时，
%   明确报错或返回NaN状态，避免静默编造论文结果。

mode = 'basic';
if isfield(cfg, 'severity_mode')
    mode = lower(string(cfg.severity_mode));
end

switch mode
    case "basic"
        severity_table = calc_basic_chain_severity(chain_summary_table, cfg);

    case "paper_formula"
        severity_table = calc_paper_chain_severity(chain_summary_table, cfg, varargin{:});

    case "both"
        basic_table = calc_basic_chain_severity(chain_summary_table, cfg);
        if isfield(cfg, 'paper_severity_formula_confirmed') && cfg.paper_severity_formula_confirmed
            if isempty(varargin)
                n = height(chain_summary_table);
                paper_LLR = NaN(n, 1);
                paper_LFOR = NaN(n, 1);
                paper_NVOR = NaN(n, 1);
                paper_CRI = NaN(n, 1);
                paper_table = table(paper_LLR, paper_LFOR, paper_NVOR, paper_CRI);
            else
                paper_table = calc_paper_chain_severity(chain_summary_table, cfg, varargin{:});
            end
        else
            n = height(chain_summary_table);
            paper_LLR = NaN(n, 1);
            paper_LFOR = NaN(n, 1);
            paper_NVOR = NaN(n, 1);
            paper_CRI = NaN(n, 1);
            paper_table = table(paper_LLR, paper_LFOR, paper_NVOR, paper_CRI);
        end
        severity_table = [basic_table, paper_table];

    otherwise
        error('未知严重度模式：%s', mode);
end
end
