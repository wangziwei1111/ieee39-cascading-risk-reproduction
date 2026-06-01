# Formal Scenario-Aligned VaR Pilot Report

## Purpose

This pilot is a fixed-parameter, scenario-aligned VaR check after the wind
penetration basis fix. It is not a full benchmark, not a final reproduction, and
does not write `final_summary`.

## Scenario Configuration

The dry-run configuration gate confirmed the seven pilot scenarios:

- `concentrated_bus34`: bus 34, 3000 MW
- `distributed_30_39`: buses 30:39, 3000 MW
- `wind_speed_11_28`: buses 30:39, 3000 MW, 11.28 m/s
- `wind_speed_12_00`: buses 30:39, 3000 MW, 12.00 m/s
- `penetration_40pct`: buses 30:39, 3000 MW
- `penetration_60pct`: buses 30:39, 4500 MW
- `penetration_80pct`: buses 30:39, 6000 MW

All paper-aligned penetration capacities use `total_generation_capacity_mw = 7500`
as the denominator. The load-based penetration value is retained only as a
diagnostic field.

## Parameter Sets

The pilot runs four fixed parameter sets:

- `low_hidden_failure`
- `medium_hidden_failure`
- `high_hidden_failure`
- `benchmark_calibrated_seed`

These are diagnostic or benchmark-calibrated seeds, not original paper parameters.

## Sample Count

Each scenario uses `markov_num_trials_per_initial_fault = 10`, corresponding to
46 initial branches times 10 trials, or about 460 accident-chain samples per
scenario.

## VaR Reconstruction

The reconstruction reads each `markov_chain_summary.csv` and computes empirical
quantiles at sigma 0.90, 0.95, and 0.98:

- `SLLR = quantile(basic_LLR, sigma)`
- `SLFOR = quantile(basic_LFOR, sigma)`
- `SNVOR = quantile(basic_NVOR, sigma)`
- `CRI_basic = quantile(basic_CRI, sigma)`
- `CRI_recomputed_from_var = 0.6*SLLR + 0.2*SLFOR + 0.2*SNVOR`

The `paper_table_display` scale currently equals raw. No hidden `1e4` or `1e-4`
conversion is applied.

## Outputs

Main outputs are stored under:

`results/calibration/formal_var_pilot/`

Important summary files:

- `formal_scenario_aligned_var_metrics.csv`
- `formal_var_pilot_to_paper_gap.csv`
- `formal_var_pilot_score_summary.csv`
- `post_formal_var_pilot_action.csv`
- `formal_scenario_aligned_var_pilot_check_log.txt`

## Interpretation

The pilot completed for all 4 parameter sets and all 7 scenarios. Each completed
scenario produced 460 accident-chain samples.

At sigma 0.95, the reconstructed `CRI_recomputed_from_var` values are generally in
the same order of magnitude as the paper table values, but still substantially
lower than the benchmark targets. The relative gaps for CRI are mostly around
0.70 to 0.88. This is not close enough to call a calibrated reproduction.

The trend score also remains problematic. The post-pilot selector currently writes:

`go_no_go = fix_metric_or_scenario_first`

The selected row in `post_formal_var_pilot_action.csv` is not permission to run
local search. It means the next step should review metric definitions and scenario
behavior before parameter tuning.

This pilot should therefore be treated as a formal scenario-aligned diagnostic
pilot, not as final benchmark reproduction.

## Accident-Chain Risk Samples Versus Severity Samples

The first formal pilot reconstruction used severity-only VaR from
`markov_chain_summary.csv`. That is a useful diagnostic, but it should not be
treated as the paper's accident-chain risk VaR.

The offline chain-risk reconstruction now builds several sample variants from the
existing formal pilot results without running any new Markov simulation:

- `severity_only`: the original severity sample comparator.
- `initial_probability_weighted_actual`: `P_initial_line * severity`.
- `initial_probability_weighted_display`: `P_initial_line * severity / 1e-4`.
- `transition_probability_weighted`: unavailable in the current formal pilot
  because the chain summaries do not contain `chain_transition_probability` or
  `chain_probability`.

Table 4-1 initial outage probabilities are stored as paper table values in units of
`10^-4`; the actual probability is `table_value * 1e-4`. For direct comparison to
paper table display values, the diagnostic display risk is:

`P_initial_line * severity / 1e-4 = table_value * severity`

This display-weighted version moves many CRI values much closer to the paper-table
scale. For example, the sigma 0.95 `CRI_recomputed` gaps are often `close` or
`same_order` rather than uniformly too small. However, the trend checks still fail:
the topology, wind-speed, and penetration ordering are not reliable enough to enter
local parameter search.

The reconstruction also confirms a structural missing item:

`missing_transition_probability_sample_count > 0`

No transition probability was fabricated. The current post-chain-risk action is to
review the cascade transition probability mechanism before parameter tuning, not to
run local search.
