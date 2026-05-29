# Composite State Probability Notes

## Paper Structure

The paper state probability structure can be written as:

`P(E_k) = P_line(E_k) * P_wt(E_k) * P_ge(E_k)`

This document records the current offline diagnostic implementation of that multiplication. It does not replace the formal `paper_formula` result and does not write anything to `final_summary`.

## Component Status

- `P_line(E_k)`: formula interface and parameter-set sensitivity diagnostics exist. Current parameter sets are diagnostic only, not calibrated paper values.
- `P_wt(E_k)`: wind unit trip probability and stage retention probability are implemented in record-only diagnostic mode. The current Markov smoke did not enter LVRT/HVRT risk regions, so `P_wt(E_k)=1`.
- `P_ge(E_k)`: traditional generator outage probability and stage retention probability are implemented in record-only diagnostic mode. The current static power-flow smoke uses nominal 50 Hz and did not enter voltage/frequency risk regions, so `P_ge(E_k)=1`.

## Offline Composite Diagnostic

The offline diagnostic joins stage-level `P_line`, `P_wt`, and `P_ge` by `initial_branch`, `trial_id`, and `stage_id`, then computes:

`P_total(E_k) = P_line(E_k) * P_wt(E_k) * P_ge(E_k)`

The default missing-component policy is `component_nan`: if any component is missing, `P_total(E_k)` is `NaN`.

## Current Result Meaning

In the current smoke outputs, both `P_wt(E_k)` and `P_ge(E_k)` are 1. Therefore the composite probability degenerates to the line probability:

`P_total(E_k) = P_line(E_k)`

This does not prove wind or generator state probability has no effect in the original paper. It only means the current small diagnostic Markov sample did not trigger the voltage/frequency regions used by the diagnostic assumptions.

## Why It Is Not Formal Paper Formula

The current component probabilities still rely on diagnostic assumptions:

- `P_line` lacks confirmed original paper values for several parameters.
- `P_wt` lacks the full original probability function and actual wind trip state transition.
- `P_ge` lacks the original voltage/frequency protection probability parameters and dynamic frequency response.

For these reasons, composite probability remains an offline diagnostic table and cannot be used to claim strict reproduction of Table 4-2, Table 4-4, Table 4-5, or Table 4-6.

## Next Inputs Needed

Formal integration requires:

- calibrated or paper-extracted `P_line` parameters;
- original `P_WT(h)` probability function and wind state transition rule;
- original `P_G(q)` probability parameters and generator state transition rule;
- confirmation of whether the paper multiplies these stage probabilities exactly as recorded or applies additional chain-level probability handling.

## Unified Markov Stage Composite State Probability Diagnostic

The previous composite table was built by joining separate diagnostic outputs offline. A new unified diagnostic smoke now records `P_line(E_k)`, `P_wt(E_k)`, `P_ge(E_k)`, and `P_total(E_k)` during the same small Markov run.

The unified smoke is still record-only. It does not change candidate line sampling, does not trip wind units, does not trip traditional generators, does not alter severity calculations, and does not write to `final_summary`.

Current unified smoke uses:

- line parameter set: `table41_P_L0_only`;
- wind parameter set: `diagnostic_linear_voltage_probability`;
- generator parameter set: `diagnostic_voltage_frequency_probability`.

In the current sample, `P_wt(E_k)=1` and `P_ge(E_k)=1`, so `P_total(E_k)` degenerates to `P_line(E_k)`. This is expected for the present smoke because neither wind nor traditional generator diagnostic risk regions were triggered. It is not a strict paper benchmark result.

Formal integration still requires calibrated paper parameters for `P_line`, a confirmed `P_WT(h)` function and wind state transition rule, and a confirmed `P_G(q)` function and traditional generator state transition rule.
