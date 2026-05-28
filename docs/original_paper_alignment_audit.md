# 原文学位论文对齐审计

## 1. 当前工程复现范围

当前工程已经完成 IEEE39 + MATPOWER 基础潮流、N-1 和 Markov 线路事故链、表4-1初始停运概率、basic/weighted/paper_formula VaR、分组场景扫描以及 final_summary 汇总。当前 final_summary 场景行数为 18，正式 Markov 样本数为每条初始线路 20 次。

## 2. 与原文第3章风险模型的对齐情况

已实现 LLR、LFOR、NVOR、CRI 的 line-only paper_formula 框架，并基于候选线路转移概率构造 P_line(E_k)。但是 P_wt(E_k) 和 P_ge(E_k) 当前仍简化为 1，新能源和传统机组实际状态转移尚未实现，因此不能声称完整复现原文第3章风险模型。

## 3. 与原文第4章 IEEE39 算例的对齐情况

当前使用 MATPOWER case39 作为基础系统，并构建 3000MW 基准、拓扑对比、渗透率扫描、风速扫描和新能源脱网概率记录场景。尚未确认原文是否修改了 IEEE39 的负荷、机组、线路容量、接入节点和风电功率曲线。

## 4. 当前已完成的模块

- IEEE39 基础潮流和新能源重调度。
- 故障后孤岛识别和主岛标准化。
- 线路停运概率驱动的 Markov 事故链搜索。
- 表4-1初始停运概率接口和加权 VaR。
- line-only paper_formula 严重度函数和非收敛阶段诊断。
- topology_compare、penetration_scan、wind_speed_scan、renewable_trip_record 和 final_summary。

## 5. 当前简化假设清单

- P_wt(E_k)=1。
- P_ge(E_k)=1。
- 新能源脱网仅 record_only，不实际切除风机。
- 传统机组停运尚未实现。
- 线路后续停运概率模型为工程近似。
- LFOR 的 active_limit_mw 使用 RATE_A 近似。
- 切负荷策略仍为简化切负荷。
- 非收敛阶段处理为工程安全机制，需确认原文规则。

## 6. diagnostic_only 与 record_only 的含义

diagnostic_only 表示程序运行完成，但 paper_formula 因无效阶段比例等原因不能作为有效论文对照。record_only 表示只记录新能源脱网概率 P_WT(h)，不改变风机状态、不影响线路事故链随机序列。

## 7. 必须补充的原文资料清单

详见 `docs/required_original_paper_inputs.md`。

## 8. 下一阶段实现优先级

详见 `docs/next_reproduction_steps.md`。优先级最高的是补齐 P_wt、P_ge、线路后续停运概率、IEEE39 修改参数和第4章场景定义。

## 9. 不允许继续猜测的参数和公式

集中式接入节点、渗透率定义、线路后续停运概率参数、新能源脱网模型、传统机组停运模型、最优切负荷模型和原文第4章结果数据不得继续猜测。

## 10. 当前结果可以如何用于硕士论文

可以表述为：完成了基于 IEEE39 的连锁故障风险评估复现实验框架，并在当前参数和 line-only paper_formula 近似下获得趋势性结果。

## 11. 当前结果不能如何表述

不能表述为：已完全复现原文学位论文第4章全部数值；也不能把 record_only 说成完整新能源脱网模型，不能把 diagnostic_only 作为有效 paper_formula 对照。

