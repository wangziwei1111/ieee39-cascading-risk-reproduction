# P_L Formula Manual Confirmation Request

## Current Blocker

The `P_flow` and `P_HF_L` audits did not confirm implementation bugs. The current blocker is the total line outage probability aggregation:

- current code uses `P_L = min(max(P1 + P2 + P3, 0), 1)`;
- an independent-union diagnostic comparator `1 - (1-P1)(1-P2)(1-P3)` has material differences in the existing traces;
- the repository does not yet contain an original-paper formula screenshot or text proving that union/inclusion-exclusion is required.

Therefore the formula must not be changed until the paper formula is manually confirmed.

## Current Code Formula

The current implementation is:

```text
P1 = P_flow * (1 - P_in_r) * (1 - P_in_c)
P_mis_r = P_HF_D + P_HF_L - P_HF_D * P_HF_L
P2 = P_mis_c + P_mis_r * (1 - P_in_c)
P_L = clip(P1 + P2 + P3, 0, 1)
```

This is the current code implementation. It must not be treated as confirmed original-paper text unless the paper explicitly states it.

## Simple Sum Versus Independent Union

Simple sum:

```text
P_L = P1 + P2 + P3
```

Independent union:

```text
P_L = 1 - (1-P1)(1-P2)(1-P3)
```

These are not equivalent unless probabilities are very small. The current audit found material differences, so this is a real modeling question rather than a cosmetic detail.

## Why We Cannot Change It Yet

Changing from simple sum to union would be a formula change, not parameter calibration. Without paper confirmation, doing so would replace an extracted assumption with an unverified interpretation.

## Please Provide Or Confirm

Please provide screenshots or exact text from the paper for:

- the definition of `P1`;
- the definition of `P2`;
- the definition of `P3`;
- the definition of `P_L`;
- whether the paper states `P_L = P1 + P2 + P3`;
- whether the paper states a union or inclusion-exclusion expression for `P_L`;
- whether the paper says `P1/P2/P3` are mutually exclusive;
- whether the paper says `P1/P2/P3` are independent but not mutually exclusive;
- how candidate outage probability enters Markov transition probability.

## If Simple Sum Is Confirmed

Keep the current formula, record the confirmation, and move to the next likely audit target: stage probability aggregation or severity formula response.

## Manual Confirmation Received

The user confirmed that paper formula (3-6) defines:

```text
P_L = P1 + P2 + P3
P1 = P(L) * (1 - P_in_r) * (1 - P_in_c)
P2 = P_mis_c + P_mis_r * (1 - P_in_c)
P_mis_r = P_HF_D + P_HF_L - P_HF_D * P_HF_L
```

The user also confirmed that `P3` is an other-factor outage probability, such as secondary equipment aging, operation error, or extreme weather, and is generally treated as a constant.

Therefore union/inclusion-exclusion is rejected as a formula modification path. `PL_sum_vs_union` remains only a diagnostic sensitivity comparison. The next audit target is stage probability aggregation and severity response.

## If Union Is Confirmed

Add a paper-confirmed aggregation mode, run formula smoke tests, and only then run a wind-speed-only diagnostic rerun. Do not run the full formal pilot immediately.

## If The Paper Is Unclear

Keep the current simple-sum implementation as an explicitly labeled extracted assumption, do not tune parameters to hide the uncertainty, and continue with stage probability or severity diagnostics.
