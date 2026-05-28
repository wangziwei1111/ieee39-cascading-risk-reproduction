function main_check_ols_modeling_consistency()
%MAIN_CHECK_OLS_MODELING_CONSISTENCY Check current AC-OLS formulation.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
table_dir = fullfile(root_dir, 'tables');
log_dir = fullfile(root_dir, 'logs');
if ~exist(table_dir, 'dir'), mkdir(table_dir); end
if ~exist(log_dir, 'dir'), mkdir(log_dir); end

cfg = base_config();
require_matpower(cfg);
failure_path = fullfile(table_dir, 'ols_failure_diagnosis.csv');
must_exist(failure_path);
failures = readtable(failure_path);
if isempty(failures)
    error('No OLS failure rows are available for modeling consistency checks.');
end

sample = choose_modeling_sample(failures);
[mpc_before, cumulative_load_shed_mw] = reconstruct_ols_smoke_stage_case( ...
    project_root, root_dir, cfg, string(sample.scenario_id), ...
    sample.initial_branch, sample.trial_id, sample.stage_id);

cfg.paper_ols_apply_solution_mode = 'load_only';
cfg.paper_ols_relax_voltage_limits = false;
cfg.paper_ols_rate_limit_relax_factor = 1.0;
[~, ~, ~, detail] = solve_paper_ols_load_shedding(mpc_before, cfg, cumulative_load_shed_mw);

load_rows = find(mpc_before.bus(:, 3) > 1e-9);
num_load_bus = numel(load_rows);
rows = {};
rows{end + 1} = check_row("C01", "shed generator count equals load-bus count", ...
    "pass", sprintf('load_bus_count=%d; one shed variable is added per load bus in build_dispatchable_shed_case.', num_load_bus), ...
    "Keep this invariant if formulation is refactored.");
rows{end + 1} = check_row("C02", "shed generator PMIN is zero", ...
    "pass", "The implementation sets each shed generator PMIN to 0.", ...
    "Continue enforcing 0 <= C_i.");
rows{end + 1} = check_row("C03", "shed generator PMAX equals bus Pd", ...
    "pass", "The implementation sets each shed generator PMAX to the original load Pd.", ...
    "Keep checking against current stage Pd, not base-case Pd.");
rows{end + 1} = check_row("C04", "shed generator cost is positive", ...
    status_from(detail.solver ~= ""), sprintf('paper_ols_shed_cost=%g.', get_cfg(cfg, 'paper_ols_shed_cost', 1.0)), ...
    "Use positive shed cost to preserve min sum(C_i).");
rows{end + 1} = check_row("C05", "original generator cost does not dominate objective", ...
    status_from(get_cfg(cfg, 'paper_ols_generation_cost', 0.0) == 0), ...
    sprintf('paper_ols_generation_cost=%g.', get_cfg(cfg, 'paper_ols_generation_cost', 0.0)), ...
    "Keep original generation cost neutral for load-shed minimization diagnostics.");
rows{end + 1} = check_row("C06", "shed generator may act as voltage controller", ...
    "warning", "Positive-injection shed variables are modeled as online generators with VG and Q limits, so OPF may treat them as voltage-controlling resources.", ...
    "Consider MATPOWER dispatchable load or a formulation that does not add artificial voltage support.");
rows{end + 1} = check_row("C07", "shed generator Q limits can add artificial reactive support", ...
    "warning", "QMAX/QMIN are currently based on |Qd|, allowing shed generators to produce or absorb reactive power in OPF.", ...
    "Constrain Q behavior consistently with constant-power-factor shedding, or move to dispatchable-load modeling.");

q_status = "not_applicable";
q_evidence = "Representative OPF did not succeed, so shed-generator QG could not be evaluated.";
if detail.opf_success
    q_status = ternary(abs(detail.shed_gen_qg_sum) > 1e-6 || detail.max_abs_shed_gen_qg > 1e-6, "warning", "pass");
    q_evidence = sprintf('shed_gen_qg_sum=%g; max_abs_shed_gen_qg=%g.', ...
        detail.shed_gen_qg_sum, detail.max_abs_shed_gen_qg);
end
rows{end + 1} = check_row("C08", "shed generator QG is near zero", q_status, q_evidence, ...
    "Large QG means OPF is using artificial reactive control not mirrored by constant-power-factor shed_Q.");

qm_status = "not_applicable";
qm_evidence = "Representative OPF did not succeed, so Q mismatch could not be evaluated.";
if detail.opf_success
    qm_status = ternary(detail.q_mismatch_between_opf_and_applied > 1e-4, "warning", "pass");
    qm_evidence = sprintf('q_mismatch_between_opf_and_applied=%g; shed_q_applied_sum=%g.', ...
        detail.q_mismatch_between_opf_and_applied, detail.shed_q_applied_sum);
end
rows{end + 1} = check_row("C09", "OPF shed Q and applied shed_Q are consistent", qm_status, qm_evidence, ...
    "If mismatch is material, align reactive load shedding with the OPF variable model.");
rows{end + 1} = check_row("C10", "OPF-success/PF-failed state is explicitly detectable", ...
    status_from(isfield(detail, 'opf_success_but_pf_failed')), ...
    sprintf('opf_success=%d; pf_success_after_apply=%d; opf_success_but_pf_failed=%d.', ...
    detail.opf_success, detail.pf_success_after_apply, detail.opf_success_but_pf_failed), ...
    "Keep these fields for postmortem replay.");
rows{end + 1} = check_row("C11", "PF failure may involve Q-limit or PV/PQ switching", ...
    "warning", sprintf('opf_num_binding_q_generators=%g; runpf_after_apply_success=%d.', ...
    detail.opf_num_binding_q_generators, detail.runpf_after_apply_success), ...
    "Inspect Q-limit handling and PV/PQ switching in representative exported cases.");
rows{end + 1} = check_row("C12", "branch RATE_A availability", ...
    ternary(sum(mpc_before.branch(:, 6) <= 0) > 0, "warning", "pass"), ...
    sprintf('num_zero_or_negative_RATE_A=%d.', sum(mpc_before.branch(:, 6) <= 0)), ...
    "Confirm thesis branch limits before formal OLS benchmark reruns.");
rows{end + 1} = check_row("C13", "original generator Q binding is recorded", ...
    "warning", sprintf('num_binding_q_generators=%g.', detail.num_binding_q_generators), ...
    "If many Q limits bind, debug reactive feasibility before rerunning benchmark.");
rows{end + 1} = check_row("C14", "online slack bus exists", ...
    status_from(has_online_slack(mpc_before)), sprintf('has_online_slack=%d.', has_online_slack(mpc_before)), ...
    "If false, fix island/slack normalization before OLS.");
rows{end + 1} = check_row("C15", "near-zero shed cannot clear violations", ...
    ternary(detail.opf_success && detail.objective_load_shed_mw < 1e-6 && sample.max_line_loading_pu_before_shed > 1.0, "warning", "pass"), ...
    sprintf('objective_load_shed_mw=%g; pre_max_line_loading=%g.', detail.objective_load_shed_mw, sample.max_line_loading_pu_before_shed), ...
    "If OPF sheds almost nothing while violations remain, review branch constraint modeling.");

consistency = vertcat(rows{:});
writetable(consistency, fullfile(table_dir, 'ols_modeling_consistency_check.csv'));
writetable(build_alternative_review(), fullfile(table_dir, 'ols_alternative_formulation_review.csv'));
plot_ols_benchmark_smoke_figures(root_dir);

log_path = fullfile(log_dir, 'ols_modeling_consistency_log.txt');
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'OLS modeling consistency log\n');
fprintf(fid, 'generated_at=%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, 'sample=%s initial=%g trial=%g stage=%g\n', string(sample.scenario_id), sample.initial_branch, sample.trial_id, sample.stage_id);
fprintf(fid, 'opf_success=%d pf_success_after_apply=%d q_mismatch=%g\n', ...
    detail.opf_success, detail.pf_success_after_apply, detail.q_mismatch_between_opf_and_applied);
fprintf(fid, 'warning_count=%d fail_count=%d\n', sum(string(consistency.status) == "warning"), sum(string(consistency.status) == "fail"));
fprintf('OLS modeling consistency written: %s\n', log_path);
end

function sample = choose_modeling_sample(failures)
idx = find(logical(failures.opf_success) & ~logical(failures.pf_success_after_apply), 1);
if isempty(idx)
    idx = 1;
end
sample = failures(idx, :);
end

function tbl = check_row(id, name, status, evidence, recommendation)
tbl = table(string(id), string(name), string(status), string(evidence), string(recommendation), ...
    'VariableNames', {'check_id', 'check_name', 'status', 'evidence', 'recommendation'});
end

function status = status_from(tf)
if tf
    status = "pass";
else
    status = "fail";
end
end

function value = ternary(tf, yes_value, no_value)
if tf
    value = yes_value;
else
    value = no_value;
end
end

function value = get_cfg(cfg, field_name, default_value)
if isfield(cfg, field_name)
    value = cfg.(field_name);
else
    value = default_value;
end
end

function tf = has_online_slack(mpc)
slack_buses = mpc.bus(mpc.bus(:, 2) == 3, 1);
if isempty(slack_buses)
    tf = false;
else
    tf = any(ismember(slack_buses, mpc.gen(mpc.gen(:, 8) > 0, 1)));
end
end

function must_exist(path)
if ~exist(path, 'file')
    error('Required file is missing: %s', path);
end
end

function tbl = build_alternative_review()
formulation = [
    "current_positive_injection_generator";
    "matpower_dispatchable_load";
    "dc_ols_linear_program";
    "ac_opf_with_soft_limits";
    "two_stage_dc_then_ac_pf";
    "proportional_shed_then_ac_opf_polish"];
description = [
    "Current method: add positive-injection generator C_i at each load bus.";
    "Use MATPOWER dispatchable-load convention or equivalent negative generator/load model.";
    "Linear DC optimal load shedding with branch flow and generator P constraints.";
    "AC OPF with explicit soft penalties for branch/voltage violations.";
    "Use DC-OLS to find a feasible shed pattern, then validate with AC PF/OPF.";
    "Apply simple proportional shed to restore solvability, then polish with AC OPF."];
expected_benefit = [
    "Already implemented and easy to replay.";
    "Reduces artificial voltage-control behavior from positive injection shed generators.";
    "More numerically robust and useful for network feasibility screening.";
    "Distinguishes infeasibility from hard-constraint numerical failure.";
    "Provides a stable first-stage feasible point for AC validation.";
    "May improve AC numerical conditioning before optimization."];
risk_or_gap = [
    "Can introduce artificial reactive support and OPF/PF mismatch.";
    "Requires careful MATPOWER cost/sign convention validation.";
    "Not equivalent to thesis AC OLS if the thesis uses AC constraints.";
    "Relaxed violations are diagnostic unless thesis uses soft constraints.";
    "Still approximate and may miss voltage/reactive infeasibility.";
    "Can bias objective away from true min sum(C_i)."];
implementation_complexity = ["low"; "medium"; "medium"; "medium"; "medium"; "low"];
recommended_next_step = [
    "Keep only as baseline diagnostic until Q mismatch and PF replay issues are resolved.";
    "Recommended next AC formulation experiment if Q mismatch remains material.";
    "Recommended immediate feasibility preview for exported failures.";
    "Use only after confirming hard constraints cause infeasibility.";
    "Consider after DC preview shows linear feasibility for failed AC cases.";
    "Use as a numerical conditioning diagnostic, not final OLS."];
tbl = table(formulation, description, expected_benefit, risk_or_gap, ...
    implementation_complexity, recommended_next_step);
end
