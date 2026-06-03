# Reproduction Status And Public Information Gap Report

This is a staged reproduction closure report. It does not run Markov, cascade, local search, parameter refinement, a full formal pilot, or `final_summary`.

## Current Project Goal

The project implements the paper's cascading-risk reproduction framework for IEEE39 with high renewable penetration, while separating paper-confirmed formulas from diagnostic assumptions and benchmark-calibrated parameters.

## Current Completion

The framework and major formula blocks are reproducible as code. Strict numerical reproduction is not currently defensible because key scenario operating-point data and statistical parameters are not public.

## Completed Or Confirmed

- Wind power curve uses the confirmed 2/12/20 profile.
- Wind-speed Table 4-6 values and decreasing risk trend were manually confirmed.
- `P_flow` piecewise formula was corrected.
- `P_HF_L` piecewise formula was corrected.
- `P_L = P1 + P2 + P3` simple sum is retained.
- Full-event chain probability and terminal-aware handling are implemented.
- Paper severity formula for LLR/LFOR/NVOR/CRI is implemented.
- VaR construction exists for diagnostic and pilot outputs.

## Parts Closer To Paper

The formula skeleton now matches the confirmed paper structure much better than earlier engineering versions. The wind curve, line probability formula branches, event probability sum, full-event probability handling, and severity formula no longer look like the primary blocker.

## Wind-Speed Scan Still Inconsistent

The paper reports lower risk at 12.00 m/s than at 11.28 m/s. Current diagnostics under public implementation assumptions cannot strictly reproduce this trend. The current dominant mechanism remains a baseflow-driven probability tail under the current operating-point assumption.

## Issues Already Checked

The remaining wind-speed trend issue is not currently attributed to:

- the wind curve,
- the `P_flow` branch,
- the `P_HF_L` branch,
- union versus simple-sum `P_L`,
- legacy severity formula,
- current `P_WT` diagnostic behavior,
- unpairable random samples.

## Current Root-Cause Judgment

The best current diagnosis is:

`baseflow-driven probability tail under current operating-point assumption`

The paper does not state dispatch, absorption, slack, curtailment, baseflow, line loading, or conventional generator PG details for the wind-speed scan.

## Operating-Point Sensitivity

Six base-case-only policies were tested. They are all diagnostic and not paper-confirmed. `constant_total_generation_dispatch` can reduce some global loading proxies at 12.00 m/s, but no tested policy simultaneously resolves the global proxy and dominant tail-branch loading/`P_L` basis. The selected action is to document public information as insufficient rather than tune parameters blindly.

## Why Blind Tuning Should Stop

Blind local search could force the numbers closer to Table 4-6 while hiding the missing operating-point assumption. That would not be a strict reproduction and would confuse benchmark-calibrated parameters with original paper parameters.

## Needed For Strict Reproduction

Strict reproduction needs the wind-speed operating-point data or author/model confirmation: conventional generator PG, slack policy, curtailment, absorbed wind power, base power flow, branch loading, random-chain policy, and whether Table 4-6 shares the same probability parameters as other tables.

## Conservative Wording

Safe claims:

- "The framework and confirmed formulas are reproducible."
- "Several scenario results are diagnostic and partly close in scale."
- "The wind-speed trend is affected by operating-point assumptions that are not public."
- "Current benchmark-calibrated parameters are not original paper parameters."

Unsafe claims:

- "The paper is strictly reproduced."
- "The sensitivity policy is paper-confirmed."
- "The wind-speed discrepancy is solved by parameter tuning."
- "The current static-frequency or diagnostic probability assumptions are original paper settings."
