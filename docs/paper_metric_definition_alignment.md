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

## Original VaR Formula Completion And Empirical Quantile Reconstruction

The paper risk metric formula table has been added at:

`paper_inputs/filled/paper_risk_metric_formulas.csv`

The current extracted interpretation is:

- SLLR: `integral_{R_SLLR}^{+inf} f(R1)dR1 = 1 - sigma`
- SLFOR: `integral_{R_SLFOR}^{+inf} f(R2)dR2 = 1 - sigma`
- SNVOR: `integral_{R_SNVOR}^{+inf} f(R3)dR3 = 1 - sigma`
- CRI: `0.6*SLLR + 0.2*SLFOR + 0.2*SNVOR`

This means the paper table values should be treated as VaR quantiles of
accident-chain-level risk samples, not as simple stage-level probability-weighted
expectations. The paper table scale is recorded as risk value divided by `1e-4`.

The rebuilt paper definition table is:

`results/calibration/diagnostics/paper_metric_definition_table.csv`

SLLR/SLFOR/SNVOR are now marked as `VaR_quantile_metric`; CRI is marked as
`weighted_sum_of_var_metrics`. Remaining uncertainty is narrower than before: the
exact PDF fitting method and exact accident-chain sample construction remain partly
unknown.

## Chain-Level Sample Reconstruction

The chain-level source audit is:

`results/calibration/diagnostics/chain_level_risk_sample_source_audit.csv`

The current usable same-run source is the unified diagnostic smoke, which provides
stage-level probability and severity. From that source, the following candidate
accident-chain samples were reconstructed:

- `chain_sum_probability_weighted`: sum over stages of `P_total(E_k) * severity(E_k)`
- `chain_sum_severity`: sum over stages of severity
- `chain_max_severity`: maximum stage severity
- `chain_final_stage_severity`: final available stage severity
- `chain_mean_stage_severity`: mean stage severity

Each candidate is exported in both `per_unit` and `percent` scale:

`results/calibration/diagnostics/chain_level_risk_samples.csv`

These samples are diagnostic only. They are built from a 5x3 unified smoke and should
not be confused with a formal scenario-level accident-chain distribution.

## Reconstructed Empirical VaR

The empirical VaR reconstruction is:

`results/calibration/diagnostics/reconstructed_empirical_var_metrics.csv`

For each candidate sample variant and scale, the script computes:

`R_var = quantile(sample_values, sigma)`

for `sigma = 0.90, 0.95, 0.98`.

The paper comparison is:

`results/calibration/diagnostics/reconstructed_var_to_paper_gap.csv`

and the summary is:

`results/calibration/diagnostics/reconstructed_var_gap_summary.csv`

Current summary at `sigma=0.95`:

- `chain_sum_probability_weighted` remains many orders of magnitude below paper targets.
- `chain_sum_severity`, `chain_max_severity`, and `chain_final_stage_severity` are closer in some per-unit/percent scales but have unstable ratios.
- No variant is currently marked `candidate_metric_for_calibration`.
- Recommendations are `still_wrong_scale` or `not_recommended`.

Therefore, empirical VaR reconstruction clarifies the mismatch but does not yet justify
local search. The likely blockers are still scenario/sample incompleteness, exact chain
sample definition, and the paper's PDF fitting or empirical VaR convention.

## Updated Next Step

Do not continue probability parameter local search yet. The next defensible step is to
obtain the paper's risk-metric construction details or build scenario-aligned chain
samples from a formal rerun after metric definitions are fully fixed. Only after a
single metric source is selected should a scale-aware calibration pilot be considered.

## Scenario-Aligned VaR Reconstruction From Calibration Pilot

The small unified smoke was useful for checking `P_total(E_k) * severity(E_k)` at the
stage level, but it only contains a limited smoke scenario and cannot represent the
paper benchmark tables. For this reason, a second offline reconstruction now uses the
existing calibration pilot outputs:

`results/calibration/pilot/<parameter_set_id>/<scenario_id>/tables/markov_chain_summary.csv`

Each `markov_chain_summary.csv` row is treated as one accident-chain sample. In the
current pilot, each scenario has 230 chain samples (`46` initial line outages times
`5` trials). No new Markov simulation was run.

The scenario-aligned VaR table is:

`results/calibration/diagnostics/scenario_aligned_chain_var_metrics.csv`

It computes empirical quantiles for:

- `sigma = 0.90, 0.95, 0.98`
- metrics `SLLR`, `SLFOR`, `SNVOR`, `CRI_basic`, `CRI_recomputed`
- scales `raw`, `percent`, `paper_table_1e4`, and `paper_actual_from_table`

`CRI_recomputed` is calculated as:

`0.6*basic_LLR + 0.2*basic_LFOR + 0.2*basic_NVOR`

The comparison to paper targets is:

`results/calibration/diagnostics/scenario_aligned_var_to_paper_gap.csv`

Two table-unit interpretations are retained:

- `compare_to_paper_table_value`: compare directly with the displayed paper value.
- `compare_to_paper_actual_1e_minus_4`: compare with `paper_value * 1e-4`.

The project does not choose one interpretation by force. The unit diagnosis is written
to:

`results/calibration/diagnostics/paper_table_unit_convention_diagnosis.csv`

Current diagnosis:

- comparing to `paper_actual_1e_minus_4` is clearly far off in this pilot;
- comparing to displayed table values can be closer for selected metric/source choices,
  but trend alignment remains weak;
- the table header "risk value / 10^-4" still needs manual interpretation before it is
  used as a calibration convention.

The metric-source score table is:

`results/calibration/diagnostics/scenario_aligned_var_score_summary.csv`

The selection table is:

`results/calibration/diagnostics/selected_calibration_metric_source.csv`

Current decision:

- no metric source is selected for calibration;
- `go_no_go = do_not_calibrate_parameters`;
- the best-ranked row is still only a diagnostic hint and not a calibration target;
- the next action is to fix the metric definition or run a formal scenario-aligned VaR
  pilot before any local search.

This means the existing calibration pilot chain samples improve the diagnosis compared
with the small unified smoke, but they still do not justify scale-aware local search.
