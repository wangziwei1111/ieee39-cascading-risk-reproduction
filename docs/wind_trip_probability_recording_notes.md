# Wind Trip Probability Recording Notes

## Why This Diagnostic Was Added

The post wind-curve-fix full-event pilot still did not align with the paper
wind-speed trend. The next missing mechanism was the wind-unit trip probability
term `P_WT(h)` and its possible role in the chain state probability.

This round only records `P_WT(h)` diagnostics. It does not trip wind units,
does not change Markov line sampling, does not multiply `P_WT` into chain
probability, and does not update `final_summary`.

## Paper Formula Structure

The paper threshold structure has been fixed in:

`paper_inputs/filled/wind_trip_probability_formula.csv`

The recorded structure is:

- Low voltage: forced trip at `U <= 0.20`, interval risk for `0.20 < U < 0.90`, zero low-voltage risk for `U >= 0.90`.
- High voltage: forced trip at `U >= 1.30`, interval risk for `1.10 < U < 1.30`, zero high-voltage risk for `U <= 1.10`.
- Low frequency: forced trip at `f <= 46.5 Hz`, interval risk for `46.5 < f < 48.5 Hz`, zero low-frequency risk for `f >= 48.5 Hz`.
- High frequency: forced trip at `f >= 51.5 Hz`, interval risk for `50.5 < f < 51.5 Hz`, zero high-frequency risk for `f <= 50.5 Hz`.
- Combined probability:
  `P_WT = 1 - (1-P_U_low)(1-P_U_high)(1-P_f_low)(1-P_f_high)`.

The interval function used in this diagnostic is linear. It is marked as
`original_paper_thresholds_with_diagnostic_interval_function`, not as an
original paper probability function.

## Input Source Audit

`wind_trip_probability_input_source_audit.csv` shows:

- Wind bus voltage can be read from stage power-flow bus voltages.
- Static system frequency is available as `cfg.system_frequency_hz = 50 Hz`.
- PCC, generator-specific, or dynamic wind-unit frequency records are not
  available.
- Renewable trip event records remain record-only probability traces, not
  actual trip state transitions.

Therefore the current smoke can compute voltage-based `P_WT` and nominal
frequency-based `P_WT`, but it cannot claim to represent dynamic frequency
protection.

## Dry-Run Result

`wind_trip_probability_dry_run_table.csv` passed all expected points:

- Normal voltage/frequency gives `P_WT = 0`.
- Forced low/high voltage and forced high frequency cases give `P_WT = 1`.
- Low-voltage, high-voltage, low-frequency, and high-frequency interval cases
  give intermediate probabilities.

This verifies the calculation chain.

## Wind-Speed Smoke Result

The record-only smoke ran:

- `wind_speed_11_28`
- `wind_speed_12_00`

with `low_hidden_failure`, first 3 initial branches, and 2 trials per branch.

Both scenarios produced 150 valid wind probability rows. For both:

- `mean_P_wt = 0`
- `p95_P_wt = 0`
- `max_P_wt = 0`
- `missing_input_count = 0`

This means the smoke stages did not push wind bus voltages or nominal frequency
into the LVRT/HVRT/FRT risk regions.

## Next Action

`post_wind_trip_probability_action.csv` recommends:

`keep_as_diagnostic_only`

The reason is:

`P_WT_all_zero_in_wind_speed_smoke`

So `P_WT` works in dry-run and can be recorded, but it does not explain the
current wind-speed trend gap in this small smoke. The current trend issue
remains driven by line probability, severity, or scenario/metric basis rather
than wind trip probability.

No local search or parameter refinement should start from this result.
