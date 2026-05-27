# 论文严重度函数核对记录

## 当前 basic 指标定义

当前工程中的 basic 指标仅用于流程验证，不等同于论文完整严重度函数：

```text
basic_LLR  = total_load_shed_frac
basic_LFOR = max(max_line_loading_pu - 1, 0)
basic_NVOR = max_voltage_deviation_pu
basic_CRI  = 0.6*basic_LLR + 0.2*basic_LFOR + 0.2*basic_NVOR
```

## 待录入的论文公式

以下公式尚未人工核对并录入：

- 负荷损失严重度函数 LLR：
- 线路潮流越限严重度函数 LFOR：
- 节点电压越限严重度函数 NVOR：
- 综合风险 CRI 权重：
- VaR 计算方式是否对严重度后果值取分位数：

## 安全规则

若论文公式未核对，不允许启用 `paper_formula` 模式。

当前配置保持：

```matlab
cfg.enable_paper_severity = false;
cfg.paper_severity_formula_confirmed = false;
```

在上述标志未改为 true 前，`calc_paper_chain_severity` 必须报错，不能返回伪造的 `paper_LLR/paper_LFOR/paper_NVOR/paper_CRI`。
