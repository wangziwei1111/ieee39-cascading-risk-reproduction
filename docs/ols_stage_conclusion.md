# OLS 阶段性结论

本阶段只完成 OLS 诊断与小样本 smoke，不建议把 OLS 作为正式 20-trial benchmark 的主切负荷策略。

## 已测试变体

- `simple_load_shedding`：当前默认工程切负荷策略，保持既有结果可复现。
- `positive_injection_generator + free_q`：用正注入 generator 表示负荷削减变量。
- `positive_injection_generator + fixed_zero_q`：禁止 shed generator 提供无功支撑的诊断变体。
- `dispatchable_load + variable_absorption`：用 MATPOWER 可调负荷/负 generator 表示可削减负荷。
- `dc_preshed_ac_pf`：先做 DC-OLS 预切负荷，再直接运行 AC PF。
- `dc_preshed_ac_ols_polish`：先做 DC-OLS 预切负荷，再做 dispatchable AC-OLS polish。

## 主要结论

`positive_injection_generator + free_q` 存在明显人工无功支撑和 Q mismatch：OPF 中的 shed generator 可能提供电压/无功调节，但实际应用到负荷侧时只按负荷削减更新 Pd/Qd，两者不严格等价。

`fixed_zero_q` 能显著降低 Q mismatch，也能修复部分导出失败样本，但在完整 5-trial smoke 中失败率反而升高，因此不能作为默认 OLS。

`dispatchable_load + variable_absorption` 消除了正无功支撑问题，在导出的失败样本上明显优于 positive-injection 建模，但在 5-trial smoke 中 failure rate 仍高于 0.1。

DC-OLS preshed 对部分失败样本有帮助：DC LP 对导出失败样本可找到线性可行解，且 DC preshed 后直接 AC PF 可使部分样本收敛。但 `dc_preshed_ac_ols_polish` 的后验 PF 成功率仍不足，完整 smoke 的失败率仍高于 0.1。

## 当前决策

当前不建议用 OLS 替代 `simple_load_shedding` 进行正式 20-trial benchmark。OLS 保留为 diagnostic-only 模块，不进入 `final_summary`，不作为当前论文 benchmark 的正式结果。

## 后续建议

正式风险复现主线先推进线路后续停运概率 `P_L`、新能源状态概率 `P_wt(E_k)`、传统机组状态概率 `P_ge(E_k)` 等概率模型。OLS 后续可作为独立小节说明原文模型实现难点；若继续推进 OLS，应优先确认原文使用 AC-OLS、DC-OLS 还是其他 OPF 求解设置。
