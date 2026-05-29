# Benchmark Calibration Plan

## Why Reverse Calibration Is Needed

The paper formula structure for the line subsequent outage probability is now implemented, but several relay, breaker, and hidden-failure statistical parameters are not fully public in the target paper or the currently checked references. These parameters must not be marked as `original_paper_extracted`.

The calibration goal is therefore limited: use fixed public parameters and benchmark-calibrated statistical parameters to seek trends and order-of-magnitude agreement with the paper benchmarks. This is not a strict reproduction claim.

## Fixed Public Parameters

The fixed layer is recorded in `paper_inputs/filled/public_fixed_parameters.csv`. It includes IEEE39 size data, wind access buses, wind speed points, turbine speed thresholds, wind ride-through thresholds, and the load-loss termination threshold. These values are not part of reverse calibration.

## Missing Calibrated Parameters

The missing statistical layer is recorded in `paper_inputs/filled/missing_calibrated_parameters_register.csv`. It includes `P_W_D`, `P_L_D`, `P_L_r`, relay and breaker failure/misoperation probabilities, `P3`, loading breakpoints, and a distance-zone proxy factor.

## Calibration Parameter Sets

`paper_inputs/filled/benchmark_calibration_parameter_sets.csv` contains:

- `strict_missing`: formula structure with missing parameters.
- `low_hidden_failure`, `medium_hidden_failure`, `high_hidden_failure`: diagnostic assumptions, not paper parameters.
- `benchmark_calibrated_seed`: initial seed for reverse calibration, not original paper parameter.

Every calibrated parameter set is explicitly marked `benchmark_calibrated_not_original_paper` or `diagnostic_assumption_not_paper`.

## Target Function

`src/calibration/compute_benchmark_calibration_error.m` computes weighted squared relative error:

`relative_error = (sim_value - paper_value) / (abs(paper_value) + epsilon)`

`weighted_error = weight * relative_error^2`

Missing rows are recorded but excluded from the score. Missing values are never filled with zero.

## Pilot Result And Local Search

The pilot writes:

- `results/calibration/pilot/calibration_pilot_sim_metrics.csv`
- `results/calibration/pilot/calibration_pilot_error_detail.csv`
- `results/calibration/pilot/calibration_pilot_score_summary.csv`

The next local-search candidates are written to `results/calibration/local_search_plan.csv`. These candidates are only a plan and are not run automatically.

Current pilot score summary:

| parameter_set_id | valid_target_count | score_total | rank |
|---|---:|---:|---:|
| low_hidden_failure | 28 | 0.2464644704 | 1 |
| medium_hidden_failure | 28 | 0.2467359158 | 2 |
| benchmark_calibrated_seed | 28 | 0.2467359158 | 3 |
| high_hidden_failure | 28 | 0.2475356804 | 4 |

`low_hidden_failure` is therefore used as the first local-search base in `results/calibration/local_search_plan.csv`. The score differences are small, so this should be treated as a seed-selection diagnostic rather than a completed calibration.

## Interpretation Limit

Benchmark-calibrated parameters are not original paper parameters. Current outputs can only support “similar trend reproduction” or “interpretable reproduction under calibrated assumptions”, not strict numerical reproduction.
