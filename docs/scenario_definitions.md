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
