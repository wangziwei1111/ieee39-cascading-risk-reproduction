# P_L Event Probability Formula Audit

## Why This Audit Was Needed

The previous audits ruled out two suspected formula issues:

- `P_flow` is constant below `L_Rated` in paper mode;
- `P_HF_L` is constant below `L_max` in paper mode.

The remaining probability-side question is whether the total line outage probability `P_L` and the Markov candidate/stage/chain probability aggregation are internally consistent, and whether a simple sum versus independent-union interpretation could explain the wind-speed direction.

## Current Formula Structure

The current implementation follows the extracted formula structure:

- `P1 = P_flow * (1 - P_in_r) * (1 - P_in_c)`;
- `P_mis_r = P_HF_D + P_HF_L - P_HF_D * P_HF_L`;
- `P2 = P_mis_c + P_mis_r * (1 - P_in_c)`;
- `P_L = P1 + P2 + P3`, clipped to `[0,1]`.

Available extracted inputs do not explicitly confirm that `P_L` should instead be computed as `1 - (1-P1)(1-P2)(1-P3)`. Therefore this audit does not change the formula to union.

## Candidate, Stage, and Chain Probability Path

The candidate probability trace records `candidate_probability = P_L`. The full-event stage probability then uses the sampled candidate event:

- selected candidates contribute `p`;
- non-selected candidates contribute `1-p`;
- the stage contribution is the product of those terms.

The chain probability is the product of stage transition probabilities. This is Bernoulli event aggregation, not a second application of the `P_L` formula.

## Simple Sum Versus Independent Union

`PL_sum_vs_union_difference_audit.csv` compares current clipped simple-sum `P_L` with an independent-union diagnostic proxy. Material differences are flagged for interpretation only. A formula switch would require manual paper confirmation.

## Wind-Speed Sensitivity

`wind_speed_PL_aggregation_sensitivity.csv` compares:

- recorded chain risk;
- offline simple-sum proxy;
- offline independent-union proxy.

The proxy variants reuse the same sampled selected flags and do not rerun Markov. They are not formal results.

## Next Step

If the simple-sum and union difference is material but paper confirmation is missing, the next step is to ask for or inspect the original formula context. If the probability path is consistent, the next likely audit target is stage probability aggregation details or severity response.

This audit is not local search, does not tune parameters, does not run a full formal pilot, and does not write `final_summary`.
