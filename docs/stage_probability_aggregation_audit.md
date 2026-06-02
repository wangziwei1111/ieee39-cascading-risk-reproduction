# Stage Probability Aggregation Audit

## Why This Follows P_L Confirmation

The user manually confirmed that paper formula (3-6) uses:

```text
P_L = P1 + P2 + P3
```

Therefore the wind-speed direction issue should not be addressed by changing `P_L` to independent union. The next probability-side question is whether candidate probabilities are aggregated correctly at the Markov stage and chain levels.

## Current Stage Full-Event Definition

For a stage with candidate outage probabilities `p_i`, the current full-event probability is:

```text
product(p_i for selected candidates) * product(1-p_i for unselected candidates)
```

Terminal stages that should not multiply candidate complements are recorded as probability one.

## Candidate Probability And P_L

The candidate trace records `candidate_probability`, which equals the confirmed `P_L` value from the line outage probability formula. This audit does not alter `P_L`.

## Probability Multiplication Chain

The current chain is:

```text
candidate probability P_L -> stage transition probability -> chain transition probability
```

The initial line probability is recorded separately in chain summaries and is not supposed to be silently multiplied again inside `stage_transition_probability`.

## Wind-Speed Stage Probability Delta

The audit compares paired `wind_speed_11_28` and `wind_speed_12_00` stage records for:

- selected probability product;
- unselected complement product;
- stage transition probability;
- chain transition probability.

The goal is to decide whether the 12.00 m/s risk increase is caused by selected candidate probability increases, complement product decreases, deeper chains, or whether the next audit should move to severity formulas.

## Guardrails

This audit does not run Markov, does not rerun cascade, does not change `P_L`, does not run local search, and does not write `final_summary`.

## Severity Follow-Up

Because the stage aggregation audit matched the recorded candidate/stage/chain traces, the next diagnostic target is severity formula response. The severity audit adds an artifact integrity check for the stage audit outputs and then examines LLR/LFOR/NVOR/CRI formulas and wind-speed response from existing traces.
