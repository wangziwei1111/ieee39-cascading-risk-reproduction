# Chain Transition Probability Tracking Notes

This diagnostic layer records Markov accident-chain transition probabilities without changing the outage sampling logic.

## What Was Added

- `candidate_table` already contained candidate outage probability, random number, and selected flag.
- Each stage now records `transition_probability_detail`.
- Each chain now records `chain_transition_probability`.
- The smoke output writes:
  - `stage_transition_probability_details.csv`
  - `candidate_probability_trace.csv`
  - `markov_chain_summary.csv`

## Probability Basis

The default mode is `selected_only_product`.

This means each stage probability is computed as the product of probabilities for the lines actually selected in that stage. If no line is selected, the stage contribution is recorded as 1.

This is a diagnostic approximation. It does not multiply the complement probabilities for all non-selected candidates.

The optional `bernoulli_full_event` mode is available in the new helper function, but it is not used for formal paper results in this step.

## Why This Matters

The previous formal chain-risk reconstruction could recover the initial line probability, but it could not recover the Markov transition probability because historical summaries did not persist per-stage chain transition products.

With this trace layer, future Markov reruns can export both:

- initial outage probability;
- subsequent stage transition probability.

The full chain probability can then be reconstructed as:

`P(chain) = P(initial line outage) * product(P(stage transition))`

## Current Scope

The current smoke uses only a small 3 initial line by 2 trial run. It is not a formal benchmark, not a final VaR result, and not written to `final_summary`.

## Remaining Limitations

- `selected_only_product` is not the full Bernoulli event probability.
- Existing historical formal pilot summaries still lack transition fields and are not retroactively fixed.
- This diagnostic does not change candidate generation, random numbers, or outage selection.
