# Severity Formula Confirmation And Fix Report

## Confirmed Formulas

The user confirmed the paper Section 3.2.4 severity formulas:

- `sev_load(E_k)=C_c(E_k)/P_load*100%`
- `sev_lfor(E_k)=sum_n((exp(max(P_l(n)-P_lmax(n),0))-1)/(e-1))*100%`
- `sev_nvor(E_k)=sum_m((exp(max(0.9-U_m,U_m-1.1,0))-1)/(e-1))*100%`
- `R_w=0.6*R_SLLR+0.2*R_SLFOR+0.2*R_SNVOR`

The CRI formula is applied to VaR component risks, not treated as the final interpretation of a single arbitrary stage severity.

## Difference From Current Legacy Code

The legacy code used:

- `LLR = total_load_shed_mw / base_load_mw`
- `LFOR = max(max_line_loading_pu-1,0) * max(num_overloaded_lines,1)`
- `NVOR = max_voltage_deviation_pu * max(num_voltage_violations,1)`
- `CRI = 0.6*SLLR + 0.2*SLFOR + 0.2*SNVOR`

LLR was close in direction but lacked the confirmed percent display. LFOR and NVOR were not the paper exponential full-line/full-bus sums.

## Implemented Mode

`paper_confirmed_exponential_sum` was added as the paper-confirmed severity mode. The legacy max-count product remains available as `legacy_max_count_product` and must not be used as the paper benchmark default.

## Vector Trace Availability

Existing wind-speed diagnostic outputs already contain `markov_line_flow_details.csv` and `markov_bus_voltage_details.csv`, so exact paper-confirmed stage severity can be reconstructed from existing line and bus vectors. The severity vector smoke pack was reconstructed from existing detailed traces and did not require a new Markov run.

## Wind-Speed Diagnostic

The wind-speed after-fix diagnostic reuses existing 30-trial wind-speed component diagnostic chains and recomputes paper-confirmed severity only. This avoids changing Markov sampling, protection parameters, or calibration settings.

Outputs:

- `wind_speed_after_severity_fix_var_metrics.csv`
- `wind_speed_before_after_severity_fix_comparison.csv`
- `wind_speed_after_severity_fix_to_paper_gap.csv`
- `post_severity_formula_fix_action.csv`

The current diagnostic action result is:

- `go_no_go = inspect_remaining_probability_tail_composition`
- The paper-confirmed severity formula did not by itself correct the key wind-speed direction issue.
- The recommended next step is to inspect the remaining probability tail composition before any full formal pilot.

## Scope Guardrails

This work is not local search, not parameter tuning, and not a final benchmark. It does not write `final_summary`, does not run the full seven-scenario formal pilot, and does not claim strict reproduction.
