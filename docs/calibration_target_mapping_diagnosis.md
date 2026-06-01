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

## Pilot Scenario Config Snapshot Confirmation

The follow-up dry-run snapshot diagnosis writes:

`results/calibration/diagnostics/pilot_scenario_config_source_trace.csv`

`results/calibration/diagnostics/pilot_scenario_config_snapshot.csv`

`results/calibration/diagnostics/pilot_scenario_snapshot_target_alignment.csv`

`results/calibration/diagnostics/formal_scenario_aligned_var_pilot_readiness.csv`

`results/calibration/diagnostics/pilot_scenario_mapping_audit_v2.csv`

This step reads `base_config`, `public_fixed_parameters`, and
`build_scenario_library` only. It does not call power flow, Markov cascade,
calibration search, local search, or `final_summary`.

Current findings:

- `concentrated_bus34` is confirmed as a calibration alias with wind connected at
  bus 34 and 3000 MW total wind capacity. This deliberately overrides the older
  default centralized-bus setting in `base_config`.
- `distributed_30_39` is confirmed as distributed wind at buses 30:39 with
  3000 MW total wind capacity.
- `wind_speed_11_28` and `wind_speed_12_00` are confirmed as distributed
  3000 MW wind cases at 11.28 m/s and 12.00 m/s.
- `penetration_40pct`, `penetration_60pct`, and `penetration_80pct` are only
  partially confirmed. The current scenario library computes total wind capacity
  from `base_load_mw = 6254.23`, giving approximately 2501.692 MW,
  3752.538 MW, and 5003.384 MW. The pilot target audit expects the Table 4-5
  convention based on 7500 MW total generation capacity, namely 3000 MW,
  4500 MW, and 6000 MW.

This is a blocking scenario-definition issue for a formal scenario-aligned VaR
pilot. The target benchmark mapping itself remains high-confidence, but the pilot
scenario implementation is not yet fully aligned for the penetration-scan rows.

Recommended next step: fix or explicitly version the penetration-scan scenario
builder convention before running any formal VaR pilot. Do not proceed to local
parameter search while this scenario configuration mismatch remains.

## Wind Penetration Basis Fix

The blocking issue above came from the old scenario-library convention: penetration
scan capacities were computed with `base_load_mw = 6254.23` as the denominator.
That produced 2501.692 MW, 3752.538 MW, and 5003.384 MW for the 40%, 60%, and
80% pilot scenarios.

For paper-aligned benchmark and calibration scenarios, the denominator is now the
public fixed total generation capacity:

`total_generation_capacity_mw = 7500`

The dry-run scenario builder now routes penetration capacity through
`compute_wind_capacity_from_penetration`, with
`wind_penetration_basis = total_generation_capacity`.

After the fix, the paper-aligned capacities are:

- 40% = 3000 MW
- 60% = 4500 MW
- 80% = 6000 MW

The 3000 MW topology and wind-speed pilot scenarios keep their fixed 3000 MW
capacity, and the snapshot reports:

- `paper_wind_penetration = 0.40`
- `load_based_wind_penetration = 0.479675...`

Only `paper_wind_penetration` is used for target alignment. The load-based value is
retained as a diagnostic field and is no longer a blocking mismatch.

The updated readiness output is:

`results/calibration/diagnostics/formal_scenario_aligned_var_pilot_readiness.csv`

If `formal_var_pilot_ready = 1`, the next step is a formal scenario-aligned VaR
pilot, not local search. If it is still 0, the check log lists the remaining
blocking issues explicitly.

The formal scenario-aligned VaR pilot has been added as a separate output family
under `results/calibration/formal_var_pilot/`. It does not replace `final_summary`
and is used only to decide whether the next step should be scale-aware calibration
planning, parameter-refinement planning, or another metric/scenario review.
