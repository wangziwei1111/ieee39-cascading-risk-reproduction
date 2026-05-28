# OLS Failure Case case_003

- scenario_id: `distributed_wind_3000mw_base`
- initial_branch: 12
- trial_id: 3
- stage_id: 1
- failure_type: `opf_nonconverged`
- trigger_reason: `line_overload`
- why_selected: representative OPF nonconverged failure

This case was reconstructed from existing OLS benchmark smoke `chain_records`. It does not rerun Markov sampling.

Replay files include `mpc_before_ols.mat`, `mpc_opf_with_shed_generators.mat`, `opf_result.mat`, `mpc_after_apply_load_only.mat`, `runpf_after_apply_result.mat`, and `ols_detail.mat`.

Recorded replay status: opf_success=0, pf_success_after_apply=0, message=OLS OPF did not converge.
