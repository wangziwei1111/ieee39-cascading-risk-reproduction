function pw = wind_power_curve(v, p_rated, v_in, v_rated, v_out)
%WIND_POWER_CURVE 计算风机在给定风速下的有功出力。
% 输入：
%   v - 风速，单位m/s。
%   p_rated - 风机额定功率，单位MW。
%   v_in - 切入风速，单位m/s。
%   v_rated - 额定风速，单位m/s。
%   v_out - 切出风速，单位m/s。
% 输出：
%   pw - 风机有功出力，单位MW。
% 物理含义：
%   对应论文风电机组有功出力曲线。低于切入或高于切出时停机；
%   切入至额定风速之间按三次关系上升；额定至切出之间保持额定出力。

if v < v_in || v > v_out
    pw = 0;
elseif v <= v_rated
    pw = p_rated * (v^3 - v_in^3) / (v_rated^3 - v_in^3);
else
    pw = p_rated;
end
end
