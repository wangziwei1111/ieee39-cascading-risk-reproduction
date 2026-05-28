# 论文式最优负荷削减 OLS 接口说明

## 对应论文公式

本阶段建立论文第 3.2.3 节式(3-19)至式(3-26)的最优负荷削减接口：

- 目标函数：`min sum(C_i)`，即最小化所有负荷节点的削减量。
- 约束包括系统有功/无功功率平衡、发电机有功/无功上下限、负荷削减量 `0 <= C_i <= P_LDi`、线路容量约束和节点电压上下限。

## 当前工程实现

新增 `src/loadshedding/solve_paper_ols_load_shedding.m`，使用 MATPOWER AC OPF 的等效建模：

- 对每个有负荷节点增加一个可调正注入发电机，表示负荷削减变量 `C_i`。
- 该等效变量的有功范围为 `[0, P_Di]`。
- OPF 目标中等效削减变量使用 `cfg.paper_ols_shed_cost`，原有发电机成本使用 `cfg.paper_ols_generation_cost`，使求解优先减少总切负荷。
- 线路约束沿用 MATPOWER `RATE_A`。
- 电压上下限沿用 case39 的 `Vmin/Vmax`。
- 若 `cfg.paper_ols_q_shed_mode='constant_power_factor'`，应用削减结果时按原负荷功率因数同步削减无功负荷。

## 与 simple_load_shedding 的区别

`simple_load_shedding` 是工程简化方法，按比例逐步削减全部负荷以恢复潮流收敛。`paper_ols` 则通过优化模型选择切负荷节点和切负荷量，更接近论文“最小负荷削减”的结构。

## 配置开关

默认配置保持：

```matlab
cfg.load_shedding_mode = 'simple';
cfg.paper_ols_enable = false;
```

可选模式：

- `simple`：保持原流程，默认使用。
- `paper_ols`：使用 OLS 结果作为主链路切负荷。
- `both_diagnostic`：主链路仍返回 simple 结果，同时在同一输入上运行 OLS 并记录诊断；不改变 Markov 线路抽样结果。

## 尚待校准

当前 OLS 仍可能与原文不同：

- 原文使用 AC-OLS 还是 DC-OLS 需要进一步确认。
- 线路容量、节点电压上下限、发电机无功约束是否与论文算例完全一致仍需校准。
- 当前使用 `RATE_A` 作为线路容量约束，仍待原文参数确认。
- 负荷削减成本权重暂设为统一值，只用于实现最小总切负荷目标。

## 诊断输出

本阶段只运行：

- `main_test_paper_ols_load_shedding`
- `main_run_markov_ols_diagnostic_smoke`
- `main_check_paper_ols_outputs`

输出位于 `results/loadshedding/`。这些结果只用于验证 OLS 接口，不进入 `final_summary`，也不代表已完成论文 benchmark 重跑。
