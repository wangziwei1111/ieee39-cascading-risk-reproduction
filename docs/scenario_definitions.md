# 第4章场景定义

本文件记录当前第4章场景扫描框架中的工程场景。除论文已经明确给出的表4-1线路初始停运概率外，集中式接入节点、渗透率定义、风速扫描点等均属于“待校准”参数。

| scenario_id | 风电接入节点 | 总容量 | 风速 | 调度模式 | 脱网概率 | 用途 | 待校准说明 |
|---|---:|---:|---:|---|---|---|---|
| `no_renewable_base` | 无 | 0 MW | NaN | `none` | false | smoke/full | 原始IEEE39对照场景 |
| `distributed_wind_40pct` | 30-39 | 3000 MW | 12 m/s | `wind_plus_redispatch` | false | smoke/full | 沿用当前默认场景；渗透率定义待校准 |
| `centralized_wind_40pct` | 39 | 3000 MW | 12 m/s | `wind_plus_redispatch` | false | smoke/full | 集中接入节点暂取39节点，待校准 |
| `distributed_wind_40pct_trip_record_only` | 30-39 | 3000 MW | 12 m/s | `wind_plus_redispatch` | true | full候选 | 当前只记录风机电压脱网概率，暂不实际触发风机脱网 |
| `distributed_wind_40pct` 到 `distributed_wind_80pct` | 30-39 | `penetration_ratio * base_load_mw` | 12 m/s | `wind_plus_redispatch` | false | full候选 | 当前按“风电装机容量/系统总负荷”定义渗透率，待校准 |
| `wind_speed_8mps` 到 `wind_speed_16mps` | 30-39 | 3000 MW | 8/10/12/14/16 m/s | `wind_plus_redispatch` | false | full候选 | 风速扫描点为工程设置，待校准 |

## 输出隔离

每个场景的结果写入：

```text
results/scenarios/<scenario_id>/
  config/
  tables/
  logs/
  chains/
  figures/
```

`main_run_scenario_batch_smoke` 仅运行 `no_renewable_base`、`distributed_wind_40pct`、`centralized_wind_40pct` 三个场景，并把每个初始故障的Markov样本数设为5。该结果只用于检查框架，不作为最终论文结果。

## Smoke Test 当前状态语义

当前 smoke test 汇总表使用多层状态：

| 字段 | 含义 |
|---|---|
| `run_status` | 程序流程是否跑完 |
| `basic_result_status` | basic VaR是否可用 |
| `weighted_result_status` | 表4-1加权basic VaR是否可用 |
| `paper_result_status` | paper_formula是否可用于论文对照 |
| `overall_status` | 综合状态 |

当前 `no_renewable_base` 和 `distributed_wind_40pct` 的 paper_formula 结果为 `valid`，综合状态应为 `success_all_valid`。`centralized_wind_40pct` 可能因为集中接入导致无效阶段比例较高，当前 paper_formula 可被标记为 `diagnostic_only`，综合状态应为 `success_with_diagnostic_paper`，不能作为有效论文对照。集中接入节点仍暂取39节点，属于待校准设置。

## Batch Mode 与场景对应

| batch_mode | 场景 |
|---|---|
| `smoke` | `no_renewable_base`, `distributed_wind_40pct`, `centralized_wind_40pct` |
| `topology_compare` | `no_renewable_base`, `distributed_wind_40pct`, `centralized_wind_40pct` |
| `penetration_scan` | `distributed_wind_40pct`, `distributed_wind_45pct`, `distributed_wind_50pct`, `distributed_wind_55pct`, `distributed_wind_60pct`, `distributed_wind_65pct`, `distributed_wind_70pct`, `distributed_wind_75pct`, `distributed_wind_80pct` |
| `wind_speed_scan` | `wind_speed_8mps`, `wind_speed_10mps`, `wind_speed_12mps`, `wind_speed_14mps`, `wind_speed_16mps` |
| `renewable_trip_record` | `distributed_wind_40pct`, `distributed_wind_40pct_trip_record_only` |
| `all_full` | 场景库中的全部场景 |

已在 `smoke` 中运行的场景也是 `topology_compare` 的全部场景。因此在 `resume_existing=true`、`force_rerun=false` 时，`main_run_scenario_batch_topology` 应跳过已有完整场景，并在 `scenario_batch_summary_topology_compare.csv` 中记录 `execution_status=skipped_existing`。当前 `centralized_wind_40pct` 的 paper结果为 `diagnostic_only`，该场景运行完整但不能作为有效paper_formula论文对照。
