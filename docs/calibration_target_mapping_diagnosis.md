# Calibration Target Mapping Diagnosis

## Purpose

This diagnostic audits the calibration benchmark targets and pilot scenario mapping
before any further parameter calibration. No new Markov simulation, no local search,
and no `final_summary` update were run.

The motivation is that scenario-aligned VaR reconstruction still returned
`do_not_calibrate_parameters`. The next likely source of error was target/scenario
mapping rather than protection-parameter values.

## Paper Benchmark Index

The paper benchmark index is written to:

`results/calibration/diagnostics/paper_benchmark_calibration_index.csv`

It is built from:

`paper_inputs/filled/paper_result_benchmark.csv`

The index covers:

- Table 4-2: renewable trip comparison rows
- Table 4-4: centralized bus 34 and distributed 3000 MW topology comparison
- Table 4-5: penetration scan 40% to 80%
- Table 4-6: wind-speed scan 11.28, 11.52, 11.76, 12.00 m/s

Rows keep separate confidence levels where available. No original benchmark file is
overwritten.

## Calibration Target Mapping Audit

The target mapping audit is written to:

`results/calibration/diagnostics/calibration_target_mapping_audit.csv`

Current result:

- `concentrated_bus34` maps exactly to Table 4-4 `centralized_3000mw` at sigma 0.95.
- `distributed_30_39` maps exactly to Table 4-4 `distributed_3000mw` at sigma 0.95.
- `penetration_40pct`, `penetration_60pct`, and `penetration_80pct` map exactly to
  Table 4-5 rows at sigma 0.95.
- `wind_speed_11_28` and `wind_speed_12_00` map exactly to Table 4-6 rows at sigma 0.95.

The current target table does not appear to mix paper tables or confidence levels for
the pilot target subset.

## Pilot Scenario Mapping Audit

The pilot scenario audit is written to:

`results/calibration/diagnostics/pilot_scenario_mapping_audit.csv`

Current interpretation:

- `concentrated_bus34`: intended centralized 3000 MW wind at bus 34.
- `distributed_30_39`: intended distributed 3000 MW wind at buses 30:39.
- `wind_speed_11_28` and `wind_speed_12_00`: intended Table 4-6 wind-speed points.
- `penetration_40pct`, `penetration_60pct`, `penetration_80pct`: intended Table 4-5
  penetration points, using 7500 MW total generation capacity convention.

Important caveat: this audit uses pilot directory names and established scenario
conventions. It does not rerun or inspect every runtime state. The rows are marked
`needs_config_file_confirmation` before formal calibration.

## Candidate Target Table V2

The non-destructive candidate target table is:

`results/calibration/diagnostics/calibration_target_benchmark_candidate_v2.csv`

Rules used:

- keep only clear benchmark-index mappings;
- prefer sigma 0.95;
- keep paper table display values as `paper_table_display_value`;
- do not multiply by `1e-4`;
- do not overwrite `paper_inputs/filled/calibration_target_benchmark.csv`.

Current result: all 28 current calibration target rows are high-confidence exact
matches and are unchanged in candidate_v2.

## Trend Comparison

The current-vs-candidate trend comparison is:

`results/calibration/diagnostics/current_vs_candidate_target_trend_comparison.csv`

Candidate_v2 preserves the current target trends:

- distributed topology is lower than concentrated topology;
- Table 4-6 risk decreases from 11.28 m/s to 12.00 m/s;
- penetration risk increases from 40% to 80%;
- CRI/SLLR/SLFOR/SNVOR directions are internally consistent for the audited rows.

Therefore, the low trend match in reconstructed simulation outputs is not explained
by an obvious target table or sigma mapping error in the current calibration target
subset.

## Recommendation

Do not proceed to local search.

Since target mapping is largely clean, the next issue is likely on the simulation metric
side or scenario implementation side:

- verify pilot scenario runtime configuration against the scenario library;
- verify that `markov_chain_summary` basic metrics correspond to the paper's chain-level
  VaR samples;
- run a formal scenario-aligned VaR pilot only after the metric source and scenario
  configuration are confirmed.

The next step is not parameter calibration. It is either scenario configuration audit
or a formal VaR pilot with a fixed, reviewed metric source.
