function p = wind_voltage_trip_probability(v_pu)
%WIND_VOLTAGE_TRIP_PROBABILITY 计算风机电压穿越失败脱网概率。
% 输入：
%   v_pu - 风机并网点/机端电压标幺值。
% 输出：
%   p - 电压穿越失败脱网概率，范围[0,1]。
% 物理含义：
%   对应论文式(3-13)的折线概率模型。0.9-1.1 p.u.内不脱网；
%   严重低压或高压时脱网概率为1，中间区间线性变化。

if v_pu < 0.2
    p = 1;
elseif v_pu < 0.9
    p = (0.9 - v_pu) / 0.7;
elseif v_pu <= 1.1
    p = 0;
elseif v_pu <= 1.3
    p = (v_pu - 1.1) / 0.2;
else
    p = 1;
end

p = min(max(p, 0), 1);
end
