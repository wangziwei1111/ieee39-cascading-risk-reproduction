# 第4章场景定义

本文档记录当前工程中的场景编号、物理含义和待校准项。场景结果分目录保存到 `results/scenarios/<scenario_id>/`，smoke test 和 full scan 结果不能混用。

## 基准与拓扑对比场景

| scenario_id | 场景含义 | 风电接入节点 | 总风电容量 | 风速 | 调度模式 | 说明 |
|---|---|---:|---:|---:|---|---|
| `no_renewable_base` | 无新能源对照 | - | 0 MW | NaN | `none` | 使用原始 IEEE 39 节点系统。 |
| `distributed_wind_3000mw_base` | 3000 MW 分散式基准 | 30:39 | 3000 MW | 12 m/s | `wind_plus_redispatch` | 当前基准复现场景，不代表按系统总负荷定义的 40% 渗透率。 |
| `centralized_wind_40pct` | 3000 MW 集中式接入 | 39 | 3000 MW | 12 m/s | `wind_plus_redispatch` | 集中接入节点暂取 39，待校准。 |
| `distributed_wind_40pct` | legacy 别名 | 30:39 | 3000 MW | 12 m/s | `wind_plus_redispatch` | 兼容旧结果；它是 `distributed_wind_3000mw_base` 的历史别名，不再用于 `penetration_scan`。 |
| `distributed_wind_40pct_trip_record_only` | 3000 MW 分散式脱网概率记录 | 30:39 | 3000 MW | 12 m/s | `wind_plus_redispatch` | 仅记录风机电压脱网概率，暂不实际触发风机脱网。 |

## 渗透率扫描场景

渗透率扫描使用统一定义：

`total_wind_capacity_mw = penetration_ratio * base_load_mw`

其中 `base_load_mw` 来自当前 case39 基础负荷。该定义仍为待校准设置，后续需要与论文原文中的新能源渗透率定义核对。

| scenario_id | penetration_ratio | 容量计算方式 | 接入节点 | 风速 | batch_mode |
|---|---:|---|---:|---:|---|
| `distributed_wind_penetration_40pct` | 0.40 | `0.40 * base_load_mw` | 30:39 | 12 m/s | `penetration_scan` |
| `distributed_wind_penetration_45pct` | 0.45 | `0.45 * base_load_mw` | 30:39 | 12 m/s | `penetration_scan` |
| `distributed_wind_penetration_50pct` | 0.50 | `0.50 * base_load_mw` | 30:39 | 12 m/s | `penetration_scan` |
| `distributed_wind_penetration_55pct` | 0.55 | `0.55 * base_load_mw` | 30:39 | 12 m/s | `penetration_scan` |
| `distributed_wind_penetration_60pct` | 0.60 | `0.60 * base_load_mw` | 30:39 | 12 m/s | `penetration_scan` |
| `distributed_wind_penetration_65pct` | 0.65 | `0.65 * base_load_mw` | 30:39 | 12 m/s | `penetration_scan` |
| `distributed_wind_penetration_70pct` | 0.70 | `0.70 * base_load_mw` | 30:39 | 12 m/s | `penetration_scan` |
| `distributed_wind_penetration_75pct` | 0.75 | `0.75 * base_load_mw` | 30:39 | 12 m/s | `penetration_scan` |
| `distributed_wind_penetration_80pct` | 0.80 | `0.80 * base_load_mw` | 30:39 | 12 m/s | `penetration_scan` |

`distributed_wind_40pct` 不是渗透率扫描中的 40% 点；真正的 40% 点是 `distributed_wind_penetration_40pct`。

## 风速扫描场景

风速扫描固定风电装机容量为 3000 MW，实际出力由 `wind_power_curve` 计算。当前 20-trial 结果中的出力如下：

| scenario_id | 总风电容量 | 实际风电出力 | 容量因子 | 接入节点 | 风速 | 说明 |
|---|---:|---:|---:|---:|---:|---|
| `wind_speed_8mps` | 3000 MW | 855.3792 MW | 0.2851 | 30:39 | 8 m/s | 风速扫描点，待校准。 |
| `wind_speed_10mps` | 3000 MW | 1716.0494 MW | 0.5720 | 30:39 | 10 m/s | 风速扫描点，待校准。 |
| `wind_speed_12mps` | 3000 MW | 3000 MW | 1.0000 | 30:39 | 12 m/s | 进入额定出力平台。 |
| `wind_speed_14mps` | 3000 MW | 3000 MW | 1.0000 | 30:39 | 14 m/s | 额定出力平台。 |
| `wind_speed_16mps` | 3000 MW | 3000 MW | 1.0000 | 30:39 | 16 m/s | 额定出力平台。 |

风速扫描横轴是 `wind_speed_mps`，而对潮流运行点产生直接影响的是 `total_wind_output_mw` 和 `wind_capacity_factor`。12 m/s 及以上进入额定平台是当前风电功率曲线设置下的结果，仍需与论文或实际风机参数校准。

## Batch Mode 对应关系

| batch_mode | 场景列表 | 当前用途 |
|---|---|---|
| `smoke` | `no_renewable_base`, `distributed_wind_3000mw_base`, `centralized_wind_40pct` | 小样本框架检查。 |
| `topology_compare` | `no_renewable_base`, `distributed_wind_3000mw_base`, `centralized_wind_40pct` | 拓扑/接入方式对比。 |
| `penetration_scan` | `distributed_wind_penetration_40pct` 到 `distributed_wind_penetration_80pct` | 按比例渗透率扫描。 |
| `wind_speed_scan` | `wind_speed_8mps` 到 `wind_speed_16mps` | 风速扫描，尚未在本轮运行。 |
| `renewable_trip_record` | `distributed_wind_3000mw_base`, `distributed_wind_40pct_trip_record_only` | 新能源脱网概率记录对比。 |
| `all_full` | 场景库全部场景 | 完整批量，耗时较长，需人工确认后运行。 |

## 当前结果状态

- `smoke` 和 `topology_compare` 是工程框架检查结果，不作为最终论文结果。
- `penetration_scan` 必须使用 20-trial Markov 样本，且不得复用 5-trial smoke 结果。
- `centralized_wind_40pct` 可能出现 `paper_result_status=diagnostic_only`，表示程序运行完整，但 paper_formula 因无效阶段比例较高，不能作为有效论文对照。
