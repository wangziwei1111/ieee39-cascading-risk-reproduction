# Severity Formula Manual Confirmation Request

This pack pauses formula changes until the paper formulas are manually confirmed.
The current audit found that the repository has working engineering formulas for LLR/LFOR/NVOR/CRI, but the exact original-paper definitions and the stage-versus-chain aggregation level are not yet proven.

## Current Blocker

- `severity_formula_audit_check_log.txt` passed.
- `post_severity_formula_audit_action.csv` selects `need_manual_paper_confirmation_for_severity_formula`.
- `severity_metric_recompute_audit.csv` shows that the trace is not a clean match to a simple stage-level recomputation.
- Therefore the next allowed action is manual paper confirmation, not formula editing, local search, or parameter tuning.

## Current Code Formulas

- LLR/SLLR: `total_load_shed_mw / base_load_mw`.
- LFOR/SLFOR: `max(max_line_loading_pu - 1, 0) * max(num_overloaded_lines, 1)`.
- NVOR/SNVOR: `max_voltage_deviation_pu * max(num_voltage_violations, 1)`.
- CRI: weighted sum of SLLR, SLFOR, SNVOR with default weights `0.6 / 0.2 / 0.2`.

These are current code implementations. They must not be described as confirmed original-paper formulas until the user provides the paper equation screenshots or exact text.

## Why Not Change The Formula Yet

The wind-speed diagnostic is sensitive to severity definitions. Changing LFOR, NVOR, LLR, normalization, zero handling, or stage/chain aggregation before confirming the paper formula would mix a model correction with parameter tuning. That would make later benchmark differences hard to explain.

## Please Provide Or Confirm These Paper Items

1. The LLR or SLLR definition formula.
2. The LFOR or SLFOR definition formula.
3. The NVOR or SNVOR definition formula.
4. The CRI definition formula.
5. The CRI weights and whether components are normalized before weighting.
6. Whether severity is computed per accident-chain stage, terminal state, maximum over chain, cumulative over chain, or as a VaR sample.
7. Whether VaR is applied to severity directly or to probability-weighted risk.
8. Whether SLFOR/SNVOR are exactly zero when there is no overload or voltage violation.
9. How nonconverged power-flow stages or chains are treated.

## If Current Code Formulas Are Confirmed

Keep the formulas unchanged, label them as paper-confirmed, and only then run a targeted wind-speed diagnostic with higher trials or inspect tail composition. Do not start local search until the probability and severity formulas are both clear.

## If The Paper Formulas Are Different

Implement only the confirmed formula difference, preferably behind a clearly named paper-confirmed mode. Then run a small formula smoke and a wind-speed-only diagnostic rerun. Do not change Markov sampling, paper benchmark tables, or calibration parameters in the same step.

## If The Paper Is Not Clear

Keep the current implementation as a diagnostic assumption. Document the uncertainty explicitly and avoid claiming strict reproduction. The safe next step is either a non-formal sensitivity analysis or a request for more source material.

## Manual Confirmation Received

The user has confirmed the paper Section 3.2.4 formulas for LLR, LFOR, NVOR, VaR component risks, and CRI weighting.

- LLR uses `sev_load(E_k)=C_c(E_k)/P_load*100%`.
- LFOR uses the full-line exponential sum `sum((exp(max(P_l-P_lmax,0))-1)/(e-1))*100%`.
- NVOR uses the full-bus exponential sum `sum((exp(max(0.9-U_m,U_m-1.1,0))-1)/(e-1))*100%`.
- CRI is applied after VaR component risks: `R_w=0.6*R_SLLR+0.2*R_SLFOR+0.2*R_SNVOR`.
- Zero violation should naturally produce zero LFOR/NVOR severity.

The current legacy LFOR/NVOR code is therefore not paper-consistent. Follow-up work should use `paper_confirmed_exponential_sum` for paper-aligned diagnostics, while retaining the legacy formula only as an explicitly labeled legacy mode.
