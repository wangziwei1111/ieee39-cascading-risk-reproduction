function [is_terminal, detail] = is_terminal_stage_for_transition_probability(stage_record, chain_context, cfg) %#ok<INUSD>
%IS_TERMINAL_STAGE_FOR_TRANSITION_PROBABILITY Decide whether a stage is terminal-only for probability recording.
% Terminal recording stages should not multiply candidate complement probabilities.

if nargin < 2
    chain_context = struct();
end

reason = "";
if isfield(stage_record, 'terminated_reason')
    reason = string(stage_record.terminated_reason);
elseif isfield(chain_context, 'terminated_reason')
    reason = string(chain_context.terminated_reason);
end

new_outages = [];
if isfield(stage_record, 'new_outaged_branches')
    new_outages = stage_record.new_outaged_branches;
end

detail = struct();
detail.terminal_reason = reason;
detail.terminal_stage_flag = false;
detail.should_multiply_candidate_complements = true;
detail.note = "Actual sampling stage; Bernoulli complements may be multiplied.";

switch reason
    case {"load_loss_threshold", "max_depth_reached", "powerflow_not_converged"}
        detail.terminal_stage_flag = true;
        detail.should_multiply_candidate_complements = false;
        detail.note = "Terminal recording stage excluded from Bernoulli complement product.";
    case "no_new_outage"
        detail.terminal_stage_flag = true;
        detail.should_multiply_candidate_complements = true;
        detail.note = "No-new-outage is a real sampled event; non-selected complements remain part of the full event.";
    otherwise
        if isempty(new_outages) && isfield(stage_record, 'converged') && ~stage_record.converged
            detail.terminal_stage_flag = true;
            detail.should_multiply_candidate_complements = false;
            detail.terminal_reason = "powerflow_not_converged";
            detail.note = "Nonconverged terminal stage excluded from Bernoulli complement product.";
        elseif isempty(reason)
            detail.note = "No terminal reason recorded; treated as actual sampling stage.";
        end
end

is_terminal = detail.terminal_stage_flag;
end
