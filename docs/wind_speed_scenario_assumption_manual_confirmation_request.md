# Wind-Speed Scenario Assumption Manual Confirmation Request

This pack is diagnostic-only. It does not run Markov, does not tune parameters, does not write `final_summary`, and does not modify the wind curve, severity formula, `P_L` formula, or stage probability formula.

## Current Blocker

After the confirmed formula fixes, the wind-speed diagnostic still shows the current 12.00 m/s case producing higher tail risk than the 11.28 m/s case. The selected post-diagnostic action is to inspect the paper wind-speed dispatch, absorption, and power-flow redistribution assumptions before any formal pilot.

## Already Fixed Or Confirmed

- `P_L = P1 + P2 + P3` structure is retained.
- `P_flow`, `P_HF_L`, full-event chain probability aggregation, and paper severity formulas have been corrected or diagnosed.
- The wind power curve profile for benchmark wind-speed cases is `paper_2_12_20`.
- The current curve gives about 2489 MW at 11.28 m/s and 3000 MW at 12.00 m/s for 3000 MW installed wind capacity.

## Why 12.00 m/s Is Still Higher In The Current Diagnostic

The current implementation absorbs the higher wind output at 12.00 m/s and redispatches conventional generation through `wind_plus_redispatch`. Existing tail diagnostics indicate a `baseflow_driven_probability_tail`: some branch loading, `P_L`, and tail contribution increase at 12.00 m/s.

This does not prove the paper used the same operating-point construction. It only describes the current engineering model.

## Current Wind-Speed Scenario Assumption

- Wind buses: 30:39.
- Total wind capacity: 3000 MW.
- Wind capacity is currently distributed across the wind buses.
- Wind speed changes from 11.28 to 12.00 m/s.
- Current absorbed wind PG changes from about 2489 MW to 3000 MW.
- Current mode: `wind_plus_redispatch`.
- Current slack bus: 31.
- No explicit curtailment is observed in the current snapshots.
- Conventional generation reduction and slack balancing are code-defined assumptions, not yet paper-confirmed assumptions.

## Information Needed From The Paper

Please provide or confirm screenshots/text for:

- The text around Table 4-5/Table 4-6 wind-speed scan.
- Whether wind output at 11.28 and 12.00 m/s is explicitly listed.
- How conventional generator output changes when wind output rises.
- Slack bus or balancing-generator policy.
- Whether wind curtailment is used.
- Whether total load is fixed.
- Whether base power flow or line loading is given for the two wind speeds.
- Whether the paper explains why 12.00 m/s has lower risk.
- Whether renewable trip probability changes with wind speed in the scenario.
- Whether a complete parameter table for the wind-speed scan is provided.

## If The Paper Confirms Current Dispatch

The next safe step is a wind-speed-only diagnostic rerun with confirmed formulas and a larger sample. If the trend remains opposite, the report should document a reproducible diagnostic divergence rather than tune parameters blindly.

## If The Paper Gives Different Dispatch, Curtailment, Or Absorption

The next step should be to implement a named paper-confirmed scenario mode, validate its base wind PG / generator PG / line loading first, and only then run a wind-speed-only diagnostic rerun.

## If The Paper Does Not State The Assumption

The result should be written conservatively: public information is insufficient to confirm the wind-speed operating-point assumption. Sensitivity cases may be useful, but they must not be claimed as strict reproduction.
