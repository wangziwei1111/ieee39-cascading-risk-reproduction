function ols_stage_details = flatten_ols_records(chain_records)
%FLATTEN_OLS_RECORDS 展开 Markov 事故链中的 OLS/切负荷诊断记录。
% 输入：
%   chain_records - search_cascade_markov_line 输出的事故链结构体数组。
% 输出：
%   ols_stage_details - 每条事故链每一级一行的切负荷诊断表。
% 物理含义：
%   用于检查 paper_ols 或 both_diagnostic 是否在非收敛阶段被触发，以及 OLS
%   求解量、回退情况和最终潮流收敛情况。

rows = {};
for i = 1:numel(chain_records)
    c = chain_records(i);
    for s = 1:numel(c.stage_records)
        st = c.stage_records(s);
        detail = extract_detail(st);
        rows{end + 1, 1} = table( ... %#ok<AGROW>
            c.initial_branch, c.trial_id, st.stage_id, ...
            string(detail.mode), string(detail.status), ...
            detail.objective_load_shed_mw, detail.total_load_shed_mw, ...
            detail.corrective_load_shed_mw, detail.island_load_shed_mw, ...
            logical_value(detail.converged_after_shed), logical_value(detail.opf_success), ...
            logical_value(detail.pf_success_after_apply), detail.num_shed_buses, ...
            detail.max_bus_shed_mw, string(detail.message), ...
            'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
            'load_shedding_mode', 'ols_status', ...
            'objective_load_shed_mw', 'total_load_shed_mw', ...
            'corrective_load_shed_mw', 'island_load_shed_mw', ...
            'converged_after_shed', 'opf_success', 'pf_success_after_apply', ...
            'num_shed_buses', 'max_bus_shed_mw', 'message'});
    end
end

if isempty(rows)
    ols_stage_details = table();
else
    ols_stage_details = vertcat(rows{:});
end
end

function detail = extract_detail(stage_record)
if ~isfield(stage_record, 'shed_detail') || isempty(stage_record.shed_detail)
    detail = empty_detail("missing", "missing_shed_detail", "stage中没有shed_detail。");
    return;
end

raw = stage_record.shed_detail;
if isfield(raw, 'paper_ols_detail')
    detail = raw.paper_ols_detail;
    detail.mode = string(raw.mode);
    return;
end

detail = raw;
detail = ensure_field(detail, 'mode', "unknown");
detail = ensure_field(detail, 'status', "unknown");
detail = ensure_field(detail, 'objective_load_shed_mw', NaN);
detail = ensure_field(detail, 'total_load_shed_mw', NaN);
detail = ensure_field(detail, 'corrective_load_shed_mw', NaN);
detail = ensure_field(detail, 'island_load_shed_mw', NaN);
detail = ensure_field(detail, 'converged_after_shed', false);
detail = ensure_field(detail, 'opf_success', NaN);
detail = ensure_field(detail, 'pf_success_after_apply', NaN);
detail = ensure_field(detail, 'num_shed_buses', NaN);
detail = ensure_field(detail, 'max_bus_shed_mw', NaN);
detail = ensure_field(detail, 'message', "");
end

function detail = empty_detail(mode, status, message)
detail = struct('mode', string(mode), 'status', string(status), ...
    'objective_load_shed_mw', NaN, 'total_load_shed_mw', NaN, ...
    'corrective_load_shed_mw', NaN, 'island_load_shed_mw', NaN, ...
    'converged_after_shed', false, 'opf_success', NaN, ...
    'pf_success_after_apply', NaN, 'num_shed_buses', NaN, ...
    'max_bus_shed_mw', NaN, 'message', string(message));
end

function s = ensure_field(s, name, default_value)
if ~isfield(s, name)
    s.(name) = default_value;
end
end

function value = logical_value(x)
if islogical(x)
    value = x;
elseif isnumeric(x) && isscalar(x) && ~isnan(x)
    value = logical(x);
else
    value = false;
end
end
