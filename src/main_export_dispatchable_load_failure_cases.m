function main_export_dispatchable_load_failure_cases()
%MAIN_EXPORT_DISPATCHABLE_LOAD_FAILURE_CASES Export replayable dispatchable-load failures.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
table_dir = fullfile(root_dir, 'tables');
case_root = fullfile(root_dir, 'dispatchable_failure_cases');
ensure_dir(case_root);
diag_path = fullfile(table_dir, 'dispatchable_load_failure_diagnosis.csv');
must_exist(diag_path);
diag = readtable(diag_path);
if isempty(diag)
    save_result_table(empty_index(), fullfile(table_dir, 'dispatchable_failure_case_index.csv'), true);
    return;
end

selected = select_cases(diag, 10);
cfg = base_config();
require_matpower(cfg);
rows = {};
for i = 1:height(selected)
    case_id = sprintf('dispatch_case_%03d', i);
    case_dir = fullfile(case_root, case_id);
    ensure_dir(case_dir);
    try
        [mpc_before, cumulative_load_shed_mw, stage_record, context] = ...
            rebuild_dispatchable_stage(project_root, root_dir, cfg, selected(i, :));
        dispatchable_ols_detail = extract_dispatchable_detail(stage_record);
        if isfield(dispatchable_ols_detail, 'mpc_after_apply')
            mpc_after_dispatchable_apply = dispatchable_ols_detail.mpc_after_apply; %#ok<NASGU>
        else
            mpc_after_dispatchable_apply = struct(); %#ok<NASGU>
        end
        save(fullfile(case_dir, 'mpc_before_ols.mat'), 'mpc_before', ...
            'cumulative_load_shed_mw', 'stage_record', 'context', 'cfg', '-v7.3');
        save(fullfile(case_dir, 'dispatchable_ols_detail.mat'), 'dispatchable_ols_detail');
        save(fullfile(case_dir, 'mpc_after_dispatchable_apply.mat'), 'mpc_after_dispatchable_apply');
        write_case_info(case_dir, case_id, selected(i, :), "exported");
        write_readme(case_dir, case_id, selected(i, :), "mpc_before_ols exported from dispatchable_load smoke chain_records.");
        note = "selected dispatchable-load failure case";
    catch ME
        write_case_info(case_dir, case_id, selected(i, :), "rebuild_failed: " + string(ME.message));
        write_readme(case_dir, case_id, selected(i, :), "Could not rebuild mpc_before_ols: " + string(ME.message));
        note = "rebuild_failed: " + string(ME.message);
    end
    case_dir_for_csv = string(strrep(case_dir, filesep, '/'));
    note_for_csv = sanitize_csv_text(note);
    message_for_csv = sanitize_csv_text(string(selected.message(i)));
    rows{end + 1, 1} = table(string(case_id), string(selected.scenario_id(i)), ...
        selected.initial_branch(i), selected.trial_id(i), selected.stage_id(i), ...
        string(selected.failure_type(i)), string(selected.trigger_reason(i)), ...
        message_for_csv, case_dir_for_csv, note_for_csv, ...
        'VariableNames', {'case_export_id', 'scenario_id', 'initial_branch', ...
        'trial_id', 'stage_id', 'failure_type', 'trigger_reason', 'message', ...
        'case_dir', 'why_selected'}); %#ok<AGROW>
end
index = vertcat(rows{:});
writetable(index, fullfile(table_dir, 'dispatchable_failure_case_index.csv'), 'Delimiter', ',');
fprintf('dispatchable failure cases exported: %s\n', fullfile(table_dir, 'dispatchable_failure_case_index.csv'));
end

function selected = select_cases(diag, max_count)
types = unique(string(diag.failure_type), 'stable');
idx = [];
for t = 1:numel(types)
    type_idx = find(string(diag.failure_type) == types(t));
    idx = [idx; type_idx(1:min(3, numel(type_idx)))]; %#ok<AGROW>
end
if numel(idx) < max_count
    rest = setdiff((1:height(diag))', idx, 'stable');
    idx = [idx; rest(1:min(max_count - numel(idx), numel(rest)))]; %#ok<AGROW>
end
idx = idx(1:min(max_count, numel(idx)));
selected = diag(idx, :);
end

function [mpc_before, cumulative_load_shed_mw, stage_record, context] = rebuild_dispatchable_stage(project_root, root_dir, cfg, row)
scenario_id = string(row.scenario_id(1));
mat_path = fullfile(root_dir, 'dispatchable_load', char(scenario_id), 'chains', 'markov_chain_records.mat');
must_exist(mat_path);
loaded = load(mat_path, 'chain_records', 'scenario');
chain_records = loaded.chain_records;
match_idx = find([chain_records.initial_branch]' == row.initial_branch(1) & ...
    [chain_records.trial_id]' == row.trial_id(1), 1);
if isempty(match_idx)
    error('Missing chain for %s initial=%g trial=%g.', scenario_id, row.initial_branch(1), row.trial_id(1));
end
stage_id = row.stage_id(1);
stage_record = chain_records(match_idx).stage_records(stage_id);
if ~isfield(stage_record, 'all_outaged_branches')
    error('stage_record lacks all_outaged_branches.');
end
base_mpc0 = build_case39_base(cfg);
scenario = get_scenario_by_id(char(scenario_id), cfg, sum(base_mpc0.bus(:, 3)));
[base_mpc, renewable_info] = apply_renewable_scenario(base_mpc0, scenario);
[mpc_fault, ~] = apply_line_outages(base_mpc, stage_record.all_outaged_branches);
[mpc_before, island_info] = normalize_case_after_contingency(mpc_fault, cfg, scenario, renewable_info);
if isfield(stage_record, 'shed') && isfield(stage_record.shed, 'island_load_shed_mw')
    cumulative_load_shed_mw = stage_record.shed.island_load_shed_mw;
else
    cumulative_load_shed_mw = island_info.disconnected_load_mw;
end
context = struct();
context.scenario = scenario;
context.renewable_info = renewable_info;
context.base_mpc = base_mpc;
context.chain_record = chain_records(match_idx);
context.chain_records_path = mat_path;
context.island_info = island_info;
end

function detail = extract_dispatchable_detail(stage_record)
detail = struct();
if isfield(stage_record, 'shed_detail')
    detail = stage_record.shed_detail;
    if isfield(detail, 'paper_ols_detail')
        detail = detail.paper_ols_detail;
    end
end
end

function write_case_info(case_dir, case_id, row, status)
tbl = table(string(case_id), string(row.scenario_id(1)), row.initial_branch(1), ...
    row.trial_id(1), row.stage_id(1), string(row.failure_type(1)), ...
    string(row.trigger_reason(1)), string(row.message(1)), string(status), ...
    'VariableNames', {'case_export_id', 'scenario_id', 'initial_branch', ...
    'trial_id', 'stage_id', 'failure_type', 'trigger_reason', 'message', 'export_status'});
writetable(tbl, fullfile(case_dir, 'case_info.csv'));
end

function write_readme(case_dir, case_id, row, note)
fid = fopen(fullfile(case_dir, 'README_case.md'), 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# %s\n\n', case_id);
fprintf(fid, '- scenario_id: %s\n', string(row.scenario_id(1)));
fprintf(fid, '- initial_branch: %g\n', row.initial_branch(1));
fprintf(fid, '- trial_id: %g\n', row.trial_id(1));
fprintf(fid, '- stage_id: %g\n', row.stage_id(1));
fprintf(fid, '- failure_type: %s\n', string(row.failure_type(1)));
fprintf(fid, '- note: %s\n', string(note));
fprintf(fid, '\nDiagnostic export only; not a benchmark result.\n');
end

function idx = empty_index()
idx = table(strings(0,1), strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
    strings(0,1), strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'case_export_id', 'scenario_id', 'initial_branch', ...
    'trial_id', 'stage_id', 'failure_type', 'trigger_reason', 'message', ...
    'case_dir', 'why_selected'});
end

function must_exist(path)
if ~exist(path, 'file'), error('Required file is missing: %s', path); end
end

function ensure_dir(path)
if ~exist(path, 'dir'), mkdir(path); end
end

function text = sanitize_csv_text(text)
text = string(text);
text = replace(text, newline, " ");
text = replace(text, char(13), " ");
text = replace(text, char(10), " ");
end
