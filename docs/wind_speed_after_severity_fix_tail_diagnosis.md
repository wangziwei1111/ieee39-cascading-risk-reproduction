# Wind-Speed Tail Diagnosis After Severity Formula Fix

## Purpose

After the paper-confirmed severity formulas were implemented, the wind-speed diagnostic still showed higher risk at 12.00 m/s than at 11.28 m/s. This report inspects the remaining probability tail composition rather than changing parameters.

## What Was Analyzed

- Tail chain samples at `sigma=0.95`
- Tail initial-branch composition
- Tail candidate-branch composition
- `P_L`, `P1`, `P2`, `P3`, hidden-failure terms, and line loading in tail candidates
- Base/stage line-loading relation to tail probability and tail risk

## Scope

This is diagnostic-only. It is not local search, not parameter tuning, not a final benchmark, and it does not write `final_summary`.

## Main Action Output

See `results/calibration/severity_formula/post_wind_speed_after_severity_fix_tail_action.csv` for the selected next action. If it recommends more wind-speed-only trials, that is a readiness recommendation only, not a full formal pilot.

## Interpretation

If 12.00 m/s remains higher because a small number of initial or candidate branches dominate the 0.95 tail, the next safe step is to increase wind-speed-only trials with confirmed formulas. If the difference is systematically tied to higher line loading at 12.00 m/s, the paper wind-speed scenario assumptions should be checked, especially wind dispatch, absorption, and power-flow redistribution.
