function main_audit_current_markov_transition_logic()
%MAIN_AUDIT_CURRENT_MARKOV_TRANSITION_LOGIC Audit current transition-probability observability.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'calibration', 'transition_probability');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

search_file = fullfile(project_root, 'src', 'cascade', 'search_cascade_markov_line.m');
update_file = fullfile(project_root, 'src', 'outage', 'update_line_outage_probabilities.m');
flatten_file = fullfile(project_root, 'src', 'cascade', 'flatten_chain_records.m');

rows = {
    'candidate_probability', contains_file(update_file, 'outage_probability'), true, 'candidate_table.outage_probability', 'available for each candidate line';
    'candidate_random_u', contains_file(update_file, 'random_u'), true, 'candidate_table.random_u', 'available for sampled Bernoulli trace';
    'candidate_trip_selected', contains_file(update_file, 'trip_selected'), true, 'candidate_table.trip_selected', 'available for selected outage trace';
    'stage_candidate_table_saved', contains_file(search_file, 'candidate_table'), true, 'stage_records.stage_id.candidate_table', 'stage candidate table is saved';
    'stage_transition_probability_detail', contains_file(search_file, 'transition_probability_detail'), false, 'stage_records.stage_id.transition_probability_detail', 'added by transition probability tracing patch';
    'chain_transition_probability_field', contains_file(search_file, 'chain_transition_probability'), false, 'chain_record.chain_transition_probability', 'added by transition probability tracing patch';
    'chain_summary_transition_columns', contains_file(flatten_file, 'chain_transition_probability'), false, 'markov_chain_summary.csv', 'flattened after patch for smoke and future reruns'
    };

logic_item = string(rows(:, 1));
probability_available = cell2mat(rows(:, 2));
random_number_available = cell2mat(rows(:, 3));
storage_location = string(rows(:, 4));
audit_note = string(rows(:, 5));
tbl = table(logic_item, probability_available, random_number_available, storage_location, audit_note);
writetable(tbl, fullfile(out_dir, 'current_markov_transition_logic_audit.csv'));
fprintf('transition logic audit written: %s\n', out_dir);
end

function tf = contains_file(path, pattern)
if exist(path, 'file') ~= 2
    tf = false;
    return;
end
txt = fileread(path);
tf = contains(txt, pattern);
end
