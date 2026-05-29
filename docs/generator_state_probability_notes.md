# Generator State Probability Notes

## Scope

This diagnostic layer implements record-only interfaces for the traditional generator outage probability `P_G(q)` and the stage state probability `P_ge(E_k)`.

It does not trip traditional generators, does not change generator online status, does not change Markov line sampling, and does not feed `P_ge(E_k)` into the formal `paper_formula` risk result.

## Paper Formula Role

The paper's Chapter 3 generator outage model includes frequency protection and voltage protection probability structures:

- normal frequency or voltage ranges use a base probability term;
- transition ranges use piecewise linear probability functions;
- beyond limit thresholds the outage probability becomes 1.

The complete numerical parameters for `P_G_f0`, `P_G_U0`, frequency thresholds, voltage thresholds, and any fitted probability coefficients are still not confirmed from the paper. Therefore the current implementation is diagnostic only.

## Parameter Sets

- `strict_missing`: all thresholds and probability curves remain missing. This verifies that missing original parameters are not silently replaced.
- `paper_formula_structure_only`: records that the formula structure is known, but numerical thresholds/probability parameters are missing.
- `diagnostic_voltage_frequency_probability`: uses diagnostic voltage/frequency thresholds and piecewise linear probabilities. This is not an original paper probability function.

## Record-Only Mode

For each converged Markov stage, the diagnostic records traditional generator bus voltage and nominal frequency, computes `P_G(q)`, and aggregates:

`P_ge(E_k) = product_q [1 - P_G(q)]`

All traditional generators are treated as online because this stage does not implement actual generator trip state transition. The output is only an online-state retention probability diagnostic value.

## Traditional Generator Identification

The implementation excludes added wind equivalent generator rows when renewable metadata is present. The original case39 generator rows are treated as traditional generators unless an explicit renewable marker exists.

## Frequency Limitation

The current model is based on static AC power flow and does not simulate dynamic frequency. The diagnostic therefore uses the nominal/system frequency, currently 50 Hz. This must not be described as a real dynamic frequency response.

## Next Inputs Needed

To move from diagnostic to paper-calibrated use, the following are still needed:

- original frequency protection thresholds and probability parameters;
- original voltage protection thresholds and probability parameters;
- clarification of whether the paper samples generator outage states or only weights stage probabilities;
- clarification of how generator trips interact with cascade state transitions.

Until then, `P_ge(E_k)` remains outside formal benchmark reproduction.
