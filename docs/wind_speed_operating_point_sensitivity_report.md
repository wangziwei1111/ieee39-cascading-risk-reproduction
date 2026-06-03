# Wind-Speed Operating-Point Sensitivity Report

This report is diagnostic-only. It is not a Markov run, not a cascade run, not local search, not parameter tuning, and not final reproduction.

## Why This Sensitivity Is Needed

The paper confirms that Table 4-6 risk decreases from 11.28 m/s to 12.00 m/s, but does not state how the operating point is rebuilt when wind output increases. The current engineering implementation uses `wind_plus_redispatch`, which increases absorbed wind power and redispatches conventional generation. Existing diagnostics show a baseflow-driven probability tail under that assumption.

## Paper-Confirmed Facts

- Section 4.5 / Table 4-6 is the wind-speed scan.
- Wind buses are distributed from bus 30 to bus 39.
- Wind speeds include 11.28, 11.52, 11.76, and 12.00 m/s.
- Reported risk decreases as wind speed approaches rated speed.

## Not Stated In The Paper

- Conventional generator redispatch rule.
- Whether slack bus alone balances wind-output changes.
- Whether curtailment or fixed absorbed wind power is used.
- Base power-flow table for each wind speed.
- Line-loading table or conventional generator PG table.
- Detailed flow mechanism explaining the lower 12.00 m/s risk.

## Current Engineering Policy

`wind_plus_redispatch_current` adds wind generators at buses 30:39 and reduces non-slack conventional generation through the current engineering redispatch rule while preserving bus 31 as slack.

## Sensitivity Policies

- `wind_plus_redispatch_current`: current implementation baseline.
- `slack_only_balance`: keep non-wind generator PG fixed and let slack balance the wind change.
- `proportional_conventional_redispatch`: reduce conventional PG proportionally to current PG.
- `designated_generator_redispatch`: let a small designated high-PG conventional generator set absorb the reduction.
- `wind_curtail_to_constant_absorbed_power`: cap absorbed 12.00 m/s wind power at the 11.28 m/s absorbed value.
- `constant_total_generation_dispatch`: reduce non-slack conventional generation by equal-share style dispatch.

All policies are marked `diagnostic_sensitivity_not_paper_confirmed`.

## Outputs

The sensitivity outputs compare wind absorption, conventional PG, slack PG, base-case line loading, and base-case `P_L` for 11.28 and 12.00 m/s. They are intended to identify which operating-point assumptions might explain the paper trend before any Markov rerun is considered.

## Interpretation Rule

If a policy makes 12.00 m/s base-case loading and top-tail branch `P_L` lower than 11.28 m/s, the next step is to ask the user whether that policy is defensible from the paper before any wind-speed-only diagnostic rerun.

If all policies remain higher or mixed, the current public information is insufficient to reproduce the wind-speed trend without additional assumptions.

## Current Diagnostic Result

All base-case power-flow sensitivity cases converged. The current `wind_plus_redispatch_current` policy still shows a 12.00 m/s baseflow pattern that is not aligned with the paper trend. `constant_total_generation_dispatch` lowers the global max/mean line-loading proxy at 12.00 m/s, but the top-tail branch comparison does not show a policy that simultaneously lowers the dominant tail-branch loading and `P_L` basis.

The selected post-sensitivity action is therefore to document public information as insufficient for a defensible policy rerun. No Markov rerun, local search, parameter refinement, or final-summary update is recommended from this sensitivity alone.
