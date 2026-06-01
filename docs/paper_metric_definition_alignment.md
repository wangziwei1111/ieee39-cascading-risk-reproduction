# Paper Metric Definition Alignment Diagnosis

## Conclusion

The calibration pilot should not proceed to parameter local search yet. The current
paper/simulation gap is not a clean one-factor scale problem: ratios vary strongly by
metric and scenario group, trend alignment is only about 58.33%, and the previous
diagnosis flagged likely metric definition/source mismatches.

This round did not run new Markov simulation, did not run local search, and did not
write `final_summary`.

## Why Local Search Is Paused

The current pilot mixes metric sources:

- `paper_severity_markov_var` where available;
- `weighted_markov_var` fallback where paper severity is unavailable;
- line-only and diagnostic probability components in several preview paths.

Because the target paper metric definition is not fully present in
`paper_inputs/filled/paper_risk_metric_formulas.csv` (the file is currently missing),
continuing probability-parameter tuning would tune against an uncertain metric pipeline.
That would risk fitting code/source mismatch rather than model parameters.

## Existing Engineering Metric Sources

The engineering index is written to:

`results/calibration/diagnostics/engineering_metric_definition_index.csv`

It covers:

- `raw_markov_var`: uniform chain empirical VaR from basic chain severity.
- `weighted_markov_var`: empirical VaR with Table 4-1 initial outage weights.
- `paper_severity_markov_var`: line-only paper-severity path when available.
- `chain_summary`: end-of-chain consequence summary, not a paper risk metric by itself.
- `stage_level_risk_preview`: same-stage diagnostic `sum(P_total(E_k) * severity(E_k))`.
- `calibration_pilot_used`: mixed source used in the calibration pilot.

The important limitation is that no existing variant is confirmed to implement the
paper's full SLLR/SLFOR/SNVOR/CRI definition end to end.

## Paper Metric Definition Status

The paper metric definition table is written to:

`results/calibration/diagnostics/paper_metric_definition_table.csv`

Current status:

- SLLR: missing from current paper inputs.
- SLFOR: missing from current paper inputs.
- SNVOR: missing from current paper inputs.
- CRI: missing from current paper inputs.

Missing items include exact formula, required inputs, probability weighting, severity
mapping, aggregation rule, percent/per-unit convention, and confidence/VaR rule.

The check log therefore explicitly asks for the original paper risk metric formula
text or screenshots before parameter search resumes.

## Definition Gap Matrix

The feature comparison table is written to:

`results/calibration/diagnostics/metric_definition_gap_matrix.csv`

Because the paper formulas are not available in the current inputs, all paper-required
features are marked as unconfirmed rather than force-matched. This is intentional:
it prevents diagnostic assumptions from being treated as original paper definitions.

## Paper-Consistent Preview Candidates

The offline preview table is written to:

`results/calibration/diagnostics/paper_consistent_metric_preview.csv`

Candidate variants:

- `stage_probability_sum`: `sum(P_total(E_k) * stage_severity(E_k))`
- `stage_probability_percent`: `100 * sum(P_total(E_k) * stage_severity(E_k))`
- `stage_mean_severity`: `mean(stage_severity(E_k))`
- `stage_mean_severity_percent`: `100 * mean(stage_severity(E_k))`
- `chain_probability_proxy`: unavailable because chain probability is not recorded in the unified smoke

Observed preview values from the current 23-stage unified smoke:

- SLLR `stage_mean_severity_percent`: about 6.70
- SLFOR `stage_mean_severity_percent`: about 16.46
- SNVOR `stage_mean_severity_percent`: about 0.96
- CRI `stage_mean_severity_percent`: about 7.50

The percent mean-severity variant is closest in raw magnitude for some target groups,
but it does not use `P_total(E_k)` and is not a confirmed VaR/aggregation rule. It is
therefore not suitable as a calibration objective without paper formula confirmation.

The probability-weighted variants use `P_total(E_k)`, but their values remain orders
of magnitude below the benchmark means. This supports the diagnosis that metric
definition, aggregation, probability basis, or scale convention is still mismatched.

## Preview Versus Paper Targets

The preview gap table is written to:

`results/calibration/diagnostics/paper_consistent_preview_gap.csv`

The comparison uses target-group means because the unified smoke is a small diagnostic
run and is not scenario-aligned with every calibration target.

Interpretation:

- `stage_probability_sum` and `stage_probability_percent` are far below paper target
  means.
- `stage_mean_severity_percent` is closer in scale for several metrics, but it is not
  a probability-weighted paper risk value.
- `chain_probability_proxy` is unavailable and should not be filled with zero.

## Next Step

Before any further local search, the user should provide or confirm the paper's risk
metric formulas, especially:

- whether SLLR/SLFOR/SNVOR are multiplied by 100;
- whether CRI is exactly `0.6*SLLR + 0.2*SLFOR + 0.2*SNVOR`;
- whether risk is computed by chain-level VaR, stage-level expectation, or another
  aggregation;
- whether initial line outage probability and Markov stage probability are both used;
- whether topology / wind-speed / penetration table values are per scenario, per
  initial fault, or averaged over scenario groups.

If formulas remain unavailable, the project should report the current pipeline as a
reproduction skeleton plus sensitivity/diagnostic analysis, not as strict numerical
reproduction.

## Prohibited Claim

Do not claim calibration is complete, do not treat preview scale fitting as formal
paper reproduction, and do not continue probability parameter search until metric
definitions are aligned.
