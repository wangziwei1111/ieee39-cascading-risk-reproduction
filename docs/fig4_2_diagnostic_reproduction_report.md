# Fig.4-2 diagnostic reproduction report

This report describes a public-information-constrained diagnostic reproduction of the paper's Fig.4-2 style probability density plots. It is not a strict original-paper reproduction.

## Figure meaning

Fig.4-2 compares cascading-failure risk indicator distributions before and after renewable generation access. The diagnostic reproduction builds two comparable cases:

- `fig4_2_no_renewable`: no renewable access, all original generator buses treated as conventional units.
- `fig4_2_distributed_renewable_3000MW`: distributed renewable access at buses 30-39 with total wind capacity 3000 MW.

## Formula settings

The run uses the currently confirmed public formula chain:

- wind power curve profile: `paper_2_12_20`;
- line flow outage probability: paper piecewise `P_flow`;
- loading hidden failure probability: paper piecewise `P_HF_L`;
- line outage aggregation: `P_L = P1 + P2 + P3`;
- chain transition probability: full-event Bernoulli probability;
- severity formula: `paper_confirmed_exponential_sum`;
- CRI reference weights: `0.6/0.2/0.2`.

The statistical protection and hidden-failure parameters are benchmark-calibrated or diagnostic assumptions, not original paper parameters.

## Samples and density

Each scenario uses 20 Markov trials per initial branch. The task recommendation was 30, but this diagnostic run uses 20 to keep desktop runtime bounded and remains above the minimum of 10.

Risk samples are constructed as:

`R_metric = initial_line_probability * chain_transition_probability * basic_metric`

The display columns divide the risk value by `1e-4`, consistent with the prior VaR display path. KDE is used when available; if the samples are too sparse or degenerate, histogram density is used. Zero-risk samples are retained.

## Outputs

Main figure:

`results/figures/fig4_2_diagnostic_reproduction/fig4_2_diagnostic_reproduction.png`

Supporting outputs:

- `fig4_2_density_data.csv`
- `fig4_2_metric_summary.csv`
- `fig4_2_trend_comparison.csv`
- per-scenario `risk_samples_for_density.csv`
- per-scenario `severity_vector_trace.csv`

## Interpretation limits

This figure should be described as a diagnostic reproduction under public information constraints. It should not be described as a strict original reproduction of Fig.4-2.

If the diagnostic distributions differ from the paper figure, likely causes include unavailable original IEEE39 modifications, unavailable protection/hidden-failure statistics, unpublished Markov sampling details, unavailable CloudPSS case settings, and incomplete operating-point assumptions.
