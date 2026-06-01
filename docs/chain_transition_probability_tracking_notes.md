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

## Selected-Only Approximation And Bernoulli Full-Event Probability

`selected_only_product` is defined as:

`prod(P_i for selected candidates)`

It is easy to compute and useful as a trace smoke, but it ignores the probability
that all non-selected candidates did not trip.

The Bernoulli full-event probability is:

`prod(P_i for selected candidates) * prod(1 - P_j for unselected candidates)`

Because `candidate_probability_trace.csv` now stores candidate probability,
`random_u`, and `selected`, the full-event probability can be reconstructed
offline from the existing selected-only trace.

The offline reconstruction writes:

- `full_event_reconstruction_from_trace_stage.csv`
- `full_event_reconstruction_from_trace_chain.csv`
- `full_event_chain_risk_trace_preview.csv`

A separate tiny smoke also runs the same 3-by-2 Markov sample with
`cfg.chain_transition_probability_mode = 'bernoulli_full_event'`. This changes
only the recorded probability definition, not candidate generation or candidate
selection.

The full-event preview is still a diagnostic smoke. If the full-event smoke
passes, the next permitted step is to rerun a formal scenario-aligned VaR pilot
with full-event chain probability recorded. Until then, selected-only results
must not be described as complete accident-chain probabilities.

In the current tiny trace, all 15 reconstructed stages are marked
`full_event_reconstructed`, and the full-event smoke marks all 15 stages as
`full_event_available`. Some chain probabilities become zero because the full
Bernoulli event includes the complement probability of unselected candidates;
when an unselected candidate has probability 1, the full event probability is
zero. This is a useful mechanism check, not a benchmark conclusion.
