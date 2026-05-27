# 论文严重度函数公式说明

本文件记录当前工程中 `paper_formula` 严重度函数的公式来源、变量映射和实现边界。所有公式均来自用户本轮提供的论文公式；工程中不额外猜测论文未给出的严重度函数。

## basic 指标定义

`basic` 指标仍保留为流程验证版本：

- `basic_LLR = total_load_shed_frac`
- `basic_LFOR = max(max_line_loading_pu - 1, 0)`
- `basic_NVOR = max_voltage_deviation_pu`
- `basic_CRI = 0.6 * basic_LLR + 0.2 * basic_LFOR + 0.2 * basic_NVOR`

这些指标用于检查 Markov 事故链、VaR 和输出流程是否跑通，不能称为论文完整严重度函数。

## 当前 paper_formula 实现范围

当前实现属于 `line-only paper severity approximation`：

- 真实计入：初始线路停运概率、候选线路逐级转移概率、线路有功潮流越限、节点电压越限、负荷损失。
- 暂未计入：新能源机组实际脱网状态概率、传统机组停运状态概率。
- 当前取 `P_wt(E_k)=1`，`P_ge(E_k)=1`。
- 当前线路有功上限使用 MATPOWER `RATE_A` 作为近似，标注为待校准。

因此，本版本可以用于验证论文式严重度计算链路，但不能称为完整复现论文数值。

## 负荷损失严重度 LLR

对事故链第 `k` 级状态 `E_k`：

```text
sev_ev_llr(E_k) = C_c(E_k) / P_load * 100%
```

单条事故链负荷损失风险值：

```text
R_LLR = sum_{k=1}^{K} P_wt(E_k) * P_ge(E_k) * P_line(E_k) * sev_ev_llr(E_k)
```

变量说明：

- `C_c(E_k)`：状态 `E_k` 下负荷损失，当前用 `stage_load_shed_mw` 表示，单位 MW。
- `P_load`：系统基准总负荷，当前用基础算例总有功负荷 `base_load_mw` 表示，单位 MW。
- 输出 `sev_ev_llr(E_k)`：百分数，取值非负。
- 输出 `R_LLR`：单条事故链的负荷损失风险值。

## 新能源机组状态概率

```text
P_wt(E_k) = prod_{h in H_out} P_WT(h) * prod_{h' in H_on} [1 - P_WT(h')]
```

当前工程暂未真正触发风机脱网，因此在当前 line-only `paper_formula` 阶段：

```text
P_wt(E_k) = 1
```

后续完整版本需要接入新能源机组脱网状态和对应概率。

## 传统机组状态概率

```text
P_ge(E_k) = prod_{q in G_out} P_G(q) * prod_{q' in G_on} [1 - P_G(q')]
```

当前工程暂未真正触发传统机组停运，因此在当前 line-only `paper_formula` 阶段：

```text
P_ge(E_k) = 1
```

后续完整版本需要接入传统机组停运状态和对应概率。

## 输电线路状态概率

论文公式要求：

```text
P_line(E_k) = prod_{n in L_out} P_L(n) * prod_{n' in L_on} [1 - P_L(n')]
```

当前工程根据每级候选线路抽样明细构造逐级条件转移概率，作为线路主导版本的可复现近似。

若第 `k` 级由候选线路集合 `C_k` 产生，抽中停运线路集合为 `S_k`，则：

```text
P_trans(k) = prod_{i in S_k} p_i * prod_{j in C_k, j notin S_k} (1 - p_j)
```

其中 `p_i` 来自 `candidate_details` 或 `candidate_chunks` 中的 `outage_probability`。

事故链累计到第 `k` 级状态的概率定义为：

```text
P_stage(E_k) = P_initial * prod_{r=1}^{k} P_trans(r)
```

当前记录：

- `P_initial` 来自 `data/line_initial_outage_probability_paper_table_4_1.csv`。
- 若使用 uniform 模式，则 `P_initial = 1/46`。
- `stage_probability_source` 记录为 `paper_table_4_1_initial_probability + candidate_transition_probability` 或 `uniform_initial_probability + candidate_transition_probability`。
- 不允许概率缺失时自动回退。

## 线路潮流越限严重度 LFOR

论文中线路潮流越限严重度采用指数效用函数：

```text
sev_ev_lfor(E_k)
= sum_{n=1}^{N} [ exp(max(P_li(n) - P_li,max(n), 0)) - 1 ] / [ e - 1 ] * 100%
```

线路潮流越限风险值：

```text
R_LFOR = sum_{k=1}^{K} P_wt(E_k) * P_ge(E_k) * P_line(E_k) * sev_ev_lfor(E_k)
```

工程变量：

- `PF`、`PT`：MATPOWER 潮流结果中线路两端有功潮流，单位 MW。
- `active_flow_mw = max(abs(PF), abs(PT))`。
- `active_limit_mw`：当前用 `RATE_A` 近似有功潮流上限，待校准。
- `P_li_pu = active_flow_mw / active_limit_mw`。
- `P_li_max_pu = 1`。
- `line_overlimit_component = max(P_li_pu - P_li_max_pu, 0)`。
- `line_severity_component = (exp(line_overlimit_component)-1)/(exp(1)-1)*100`。

输出明细表：`results/tables/markov_line_flow_details.csv`。

## 节点电压越限严重度 NVOR

论文中节点电压越限严重度采用指数效用函数：

```text
sev_ev_nvor(E_k)
= sum_{m=1}^{M} [ exp(max(0.9 - U_m, U_m - 1.1, 0)) - 1 ] / [ e - 1 ] * 100%
```

节点电压越限风险值：

```text
R_NVOR = sum_{k=1}^{K} P_wt(E_k) * P_ge(E_k) * P_line(E_k) * sev_ev_nvor(E_k)
```

工程变量：

- `U_m`：节点电压标幺值，来自 MATPOWER `bus(:, VM)`。
- 电压下限：`0.9 pu`。
- 电压上限：`1.1 pu`。
- `voltage_deviation_component = max(0.9 - voltage_pu, voltage_pu - 1.1, 0)`。
- `voltage_severity_component = (exp(voltage_deviation_component)-1)/(exp(1)-1)*100`。

输出明细表：`results/tables/markov_bus_voltage_details.csv`。

## VaR 风险价值

论文 VaR 指标满足右尾概率：

```text
int_{R_SLLR}^{+inf} f(R_1)dR_1 = 1 - sigma
int_{R_SLFOR}^{+inf} f(R_2)dR_2 = 1 - sigma
int_{R_SNVOR}^{+inf} f(R_3)dR_3 = 1 - sigma
```

工程实现使用 Monte Carlo 样本的经验右尾分位数：

```text
VaR_sigma = quantile(R, sigma)
```

## 综合风险 CRI

当前论文权重采用：

```text
w_1 = 0.6
w_2 = 0.2
w_3 = 0.2
```

因此：

```text
CRI = 0.6 * SLLR + 0.2 * SLFOR + 0.2 * SNVOR
```

## 后续仍需补充

- 新能源机组脱网状态集合与 `P_WT(h)`。
- 传统机组停运状态集合与 `P_G(q)`。
- 线路容量和有功上限的论文一致性校准。
- 更严格的最优负荷削减模型。
- 与论文第4章场景结果的系统化对照。
