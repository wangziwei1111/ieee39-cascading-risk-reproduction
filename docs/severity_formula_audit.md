# Severity Formula Audit

## Why This Audit Comes Next

`P_L = P1 + P2 + P3` has been manually confirmed by the user, and stage probability aggregation matches the recorded candidate/stage/chain traces. The remaining wind-speed mismatch may therefore come from the severity model or from sample-path composition rather than from the line outage probability formula.

## Current Code Formulas

The current basic severity implementation is:

```text
LLR  = total_load_shed_mw / base_load_mw
LFOR = max(max_line_loading_pu - 1, 0) * max(num_overloaded_lines, 1)
NVOR = max_voltage_deviation_pu * max(num_voltage_violations, 1)
CRI  = 0.6*LLR + 0.2*LFOR + 0.2*NVOR
```

These formulas are current code behavior. The exact paper formulas and normalization bases for LFOR and NVOR still need paper confirmation before any formal benchmark claim.

## Trace Recompute

`severity_metric_recompute_audit.csv` recomputes LLR, LFOR, NVOR, and CRI from the existing wind-speed component diagnostic severity trace. This checks whether the trace values match current code formulas without running Markov again.

## Wind-Speed Response

`wind_speed_severity_response_summary.csv` and `wind_speed_severity_response_delta.csv` compare `wind_speed_11_28` and `wind_speed_12_00` severity components under the same existing diagnostic traces. This helps determine whether the higher 12.00 m/s risk is driven by load shedding, line overload, voltage violations, or mixed CRI weighting.

## VaR Proxy

`wind_speed_var_sensitivity_to_severity_formula.csv` builds an offline proxy using the same chain transition probabilities and recorded/recomputed severity values. It is not formal VaR and does not replace `final_summary`.

## Guardrails

This audit does not run local search, does not tune parameters, does not run the full formal pilot, and does not write `final_summary`.
