function p = line_outage_probability(loading_pu, cfg)
%LINE_OUTAGE_PROBABILITY 计算线路基于负载率的简化停运概率。
% 输入：
%   loading_pu - 线路当前负载率，等于两端较大视在功率除以RATE_A。
%   cfg - 全局配置，包含线路停运概率待校准参数。
% 输出：
%   p - 当前状态下该线路的停运概率，范围[0,1]。
% 物理含义：
%   这是论文中“线路潮流相关停运概率”的最小可运行简化版。它只考虑
%   线路负载率随潮流升高导致停运概率增加，不包含完整的距离保护、
%   潮流越限保护隐性故障、断路器拒动/误动等保护模型参数。

if isnan(loading_pu) || loading_pu < 0
    loading_pu = 0;
end

p0 = cfg.line_outage_p0;
rated = cfg.line_rated_loading_pu;
limit = cfg.line_limit_loading_pu;
forced = cfg.line_forced_trip_loading_pu;
p_at_limit = cfg.line_prob_at_limit;

if loading_pu <= rated
    p = p0;
elseif loading_pu <= limit
    ratio = (loading_pu - rated) / max(limit - rated, eps);
    p = p0 + ratio * (p_at_limit - p0);
elseif loading_pu <= forced
    ratio = (loading_pu - limit) / max(forced - limit, eps);
    p = p_at_limit + ratio * (1 - p_at_limit);
else
    p = 1;
end

p = min(max(p, 0), cfg.line_outage_prob_cap);
end
