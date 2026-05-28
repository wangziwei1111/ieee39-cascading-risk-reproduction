# 第4章场景定义

本文档记录当前工程中的场景编号、物理含义、运行分组和待校准说明。场景结果统一保存在 `results/scenarios/<scenario_id>/`，最终论文图表汇总保存在 `results/final_summary/`。

## 基准与拓扑对比场景

| scenario_id | 场景含义 | 风电接入节点 | 总风电容量 | 风速 | 调度模式 | 说明 |
|---|---|---:|---:|---:|---|---|
| `no_renewable_base` | 无新能源对照 | - | 0 MW | NaN | `none` | 使用原始 IEEE 39 节点系统。 |
| `distributed_wind_3000mw_base` | 3000 MW 分散式基准 | 30:39 | 3000 MW | 12 m/s | `wind_plus_redispatch` | 当前基准复现场景，不代表按系统总负荷定义的 40% 渗透率。 |
| `centralized_wind_40pct` | 3000 MW 集中式接入 | 39 | 3000 MW | 12 m/s | `wind_plus_redispatch` | 集中接入节点暂取 39，待校准；当前 paper_formula 可能为 `diagnostic_only`。 |
| `distributed_wind_40pct` | legacy 别名 | 30:39 | 3000 MW | 12 m/s | `wind_plus_redispatch` | 历史兼容别名，不再用于 `penetration_scan`。 |
| `distributed_wind_40pct_trip_record_only` | 3000 MW 分散式脱网概率记录 | 30:39 | 3000 MW | 12 m/s | `wind_plus_redispatch` | 仅记录风机电压脱网概率，暂不实际触发风机脱网。 |

## 渗透率扫描场景

渗透率扫描使用统一定义：

```text
total_wind_capacity_mw = penetration_ratio * base_load_mw
```

该定义仍为待校准设置，后续需要与论文原文中的新能源渗透率定义核对。

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

风速扫描固定风电装机容量为 3000 MW，实际出力由 `wind_power_curve` 计算。当前 20-trial 结果如下：

| scenario_id | 总风电容量 | 实际风电出力 | 容量因子 | 接入节点 | 风速 | 说明 |
|---|---:|---:|---:|---:|---:|---|
| `wind_speed_8mps` | 3000 MW | 855.3792 MW | 0.2851 | 30:39 | 8 m/s | 风速扫描点，待校准。 |
| `wind_speed_10mps` | 3000 MW | 1716.0494 MW | 0.5720 | 30:39 | 10 m/s | 风速扫描点，待校准。 |
| `wind_speed_12mps` | 3000 MW | 3000 MW | 1.0000 | 30:39 | 12 m/s | 进入额定出力平台。 |
| `wind_speed_14mps` | 3000 MW | 3000 MW | 1.0000 | 30:39 | 14 m/s | 额定出力平台。 |
| `wind_speed_16mps` | 3000 MW | 3000 MW | 1.0000 | 30:39 | 16 m/s | 额定出力平台。 |

风速扫描横轴是 `wind_speed_mps`，对潮流运行点产生直接影响的是 `total_wind_output_mw` 和 `wind_capacity_factor`。

## Batch Mode 对应关系

| batch_mode | 场景列表 | 当前用途 |
|---|---|---|
| `smoke` | `no_renewable_base`, `distributed_wind_3000mw_base`, `centralized_wind_40pct` | 5-trial 快速框架检查，不作为最终结果。 |
| `topology_compare` | `no_renewable_base`, `distributed_wind_3000mw_base`, `centralized_wind_40pct` | 拓扑/接入方式对比。 |
| `penetration_scan` | `distributed_wind_penetration_40pct` 到 `distributed_wind_penetration_80pct` | 20-trial 渗透率趋势扫描。 |
| `wind_speed_scan` | `wind_speed_8mps` 到 `wind_speed_16mps` | 20-trial 风速趋势扫描。 |
| `renewable_trip_record` | `distributed_wind_3000mw_base`, `distributed_wind_40pct_trip_record_only` | 新能源脱网概率 record-only 诊断对比。 |
| `all_full` | 场景库全部场景 | 耗时较长，需要人工确认后再运行。 |

## 进入 final_summary 的场景组

`results/final_summary/` 汇总了当前已完成的 `topology_compare`、`penetration_scan`、`wind_speed_scan` 和 `renewable_trip_record`。其中：

- `penetration_scan` 和 `wind_speed_scan` 为 20-trial，可用于当前参数下的趋势分析。
- `topology_compare` 已按正式 20-trial 重跑，可用于拓扑/接入方式对比。
- `smoke` 只作为工程检查，不进入论文关键结果表或 `final_scenario_overview.csv`。
- `centralized_wind_40pct` 若为 `diagnostic_only`，表示程序运行完整，但 paper_formula 不能作为有效论文对照。
- `distributed_wind_40pct_trip_record_only` 是 record-only 诊断，不是完整新能源脱网仿真。
- `distributed_wind_40pct` 是 legacy alias，不进入最终汇总。
- `distributed_wind_3000mw_base` 是 3000 MW 基准；`distributed_wind_penetration_40pct` 是按 `wind_capacity/base_load` 定义的 40% 渗透率点。
## paper_wind_speed_scan 场景组

该组专门用于论文表4-6风速波动 benchmark 的复现实验，不复用早期工程扫描 `wind_speed_8mps`、`wind_speed_10mps`、`wind_speed_12mps`、`wind_speed_14mps`、`wind_speed_16mps`。

| scenario_id | source_paper_scenario_id | wind_speed_mps | total_wind_capacity_mw | wind_buses | 说明 |
|---|---:|---:|---:|---|---|
| `paper_wind_speed_11_28mps` | `wind_speed_11_28mps` | 11.28 | 3000 | 30-39 | 论文表4-6风速点；当前line-only模型 |
| `paper_wind_speed_11_52mps` | `wind_speed_11_52mps` | 11.52 | 3000 | 30-39 | 论文表4-6风速点；当前line-only模型 |
| `paper_wind_speed_11_76mps` | `wind_speed_11_76mps` | 11.76 | 3000 | 30-39 | 论文表4-6风速点；当前line-only模型 |
| `paper_wind_speed_12_00mps` | `wind_speed_12_00mps` | 12.00 | 3000 | 30-39 | 论文表4-6风速点；当前line-only模型 |

运行入口为 `main_run_scenario_batch_paper_wind_speed`，批次名为 `paper_wind_speed_scan`。该结果只能作为当前 line-only paper_formula 下对论文风速点的复现实验，不能称为严格复现论文表4-6。
