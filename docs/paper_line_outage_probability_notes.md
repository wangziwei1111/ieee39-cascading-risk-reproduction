# 论文式线路后续停运概率说明

本文档记录论文第3.1.1节输电线路后续停运概率模型的工程接口状态。当前实现是公式结构化与诊断对比，不是已校准的论文参数复现。

## 模型结构

论文第3.1.1节将输电线路后续停运概率拆分为潮流相关故障概率、保护隐性故障概率和其他因素导致的停运概率。当前接口 `compute_paper_line_outage_probability` 按以下结构记录：

- `P_flow`：随线路负载率变化的三段式概率，低于额定负载为 `P_L0`，额定负载到 `L_max` 之间线性增加，超过 `L_max` 后达到上限。
- `P_hidden_distance`：距离保护隐性故障概率，对应论文式(3-4)，需要 `Z_m`、`Z_III` 和 `P_W_D`。
- `P_hidden_loading`：潮流越限保护隐性故障概率，对应论文式(3-5)，需要 `P_L_D`、`P_L_r` 和 `L_max`。
- `P3`：其他因素导致停运概率，目前默认 0，待原文参数确认。

综合概率按 `P_L = P1 + P2 + P3` 形成，并限制在 `[0, 1]`。

## 当前缺失参数

以下参数仍未从原文中完整确认，默认保持 NaN 或待校准：

- `paper_line_P_L0`
- `paper_line_P_W_D`
- `paper_line_ZIII_factor`
- `paper_line_P_L_D`
- `paper_line_P_L_r`
- 距离保护阻抗量 `Z_m`、`Z_III`
- `L_Rated` 与 `L_max` 相对线路容量的精确定义

缺参数时，接口不会静默把 NaN 当作 0。默认策略 `fallback_to_engineering_with_warning` 会返回 engineering 概率供主链路使用，同时在 detail 中标记 `missing_parameter_fallback`。

## 与 engineering 模型的区别

当前 engineering 模型只根据线路负载率做简化分段概率，参数来自工程待校准设置。paper_formula 接口显式保留论文中的 `P_flow`、距离保护隐性故障、潮流越限隐性故障和 `P3` 结构，但在参数缺失时只作为诊断。

## 使用方式

默认配置仍为：

```matlab
cfg.line_outage_probability_model = 'engineering';
```

诊断模式：

```matlab
cfg.line_outage_probability_model = 'paper_formula_diagnostic';
```

该模式下 Markov 主链路仍使用 engineering 概率，candidate table 会额外输出 `paper_formula_probability`、`paper_formula_status`、`paper_formula_missing_parameters` 和 `paper_formula_used_fallback`。

## 后续工作

后续需要从论文中继续确认 `P_L0`、`P_W_D`、`P_L_D`、`P_L_r`、`Z_III`、`L_Rated`、`L_max` 的数值或计算方式。确认前不能把当前 paper_formula 线路概率称为已校准，也不能将其设置为默认正式 benchmark 模型。
