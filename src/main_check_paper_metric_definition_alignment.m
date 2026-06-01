function main_check_paper_metric_definition_alignment()
%MAIN_CHECK_PAPER_METRIC_DEFINITION_ALIGNMENT Check paper metric alignment diagnostics.
project_root = fileparts(fileparts(mfilename('fullpath')));
diag_dir = fullfile(project_root, 'results', 'calibration', 'diagnostics');
log_path = fullfile(diag_dir, 'paper_metric_definition_alignment_check_log.txt');
ensure_dir(diag_dir);

lines = strings(0, 1);
required = [
    string(fullfile(diag_dir, 'engineering_metric_definition_index.csv'))
    string(fullfile(diag_dir, 'paper_metric_definition_table.csv'))
    string(fullfile(diag_dir, 'metric_definition_gap_matrix.csv'))
    string(fullfile(diag_dir, 'paper_consistent_metric_preview.csv'))
    string(fullfile(diag_dir, 'paper_consistent_preview_gap.csv'))
    string(fullfile(project_root, 'docs', 'paper_metric_definition_alignment.md'))
    ];

ok = true;
lines(end+1) = "paper metric definition alignment check started: " + string(datetime('now'));
for i = 1:numel(required)
    exists_flag = exist(required(i), 'file') == 2;
    ok = ok && exists_flag;
    lines(end+1) = string(required(i)) + " exists=" + string(exists_flag);
end

local_search_results = fullfile(project_root, 'results', 'calibration', 'local_search_results.csv');
if exist(local_search_results, 'file') == 2
    ok = false;
    lines(end+1) = "forbidden local_search_results found: " + string(local_search_results);
else
    lines(end+1) = "local_search_results_absent=true";
end

lines(end+1) = "final_summary_not_written_by_this_check=true";

paper_table_path = fullfile(diag_dir, 'paper_metric_definition_table.csv');
if exist(paper_table_path, 'file') == 2
    paper_table = read_csv(paper_table_path);
    has_missing = ismember('missing_information', paper_table.Properties.VariableNames) && ...
        any(strlength(string(paper_table.missing_information)) > 0);
    lines(end+1) = "paper_metric_definition_has_missing_information=" + string(has_missing);
    if has_missing
        lines(end+1) = "action_required=ask user to provide original paper risk metric formulas before parameter local search";
    end
end

gap_path = fullfile(diag_dir, 'metric_definition_gap_matrix.csv');
if exist(gap_path, 'file') == 2
    gap = read_csv(gap_path);
    if ismember('match_status', gap.Properties.VariableNames)
        statuses = unique(string(gap.match_status));
        lines(end+1) = "gap_match_statuses=" + strjoin(statuses, ",");
    end
end

if ok
    lines(end+1) = "check_status=passed";
else
    lines(end+1) = "check_status=failed";
end
write_lines(log_path, lines);
fprintf('%s\n', lines);
if ~ok
    error('paper metric definition alignment check failed; see %s', log_path);
end
end

function ensure_dir(path_value)
if exist(path_value, 'dir') ~= 7
    mkdir(path_value);
end
end

function tbl = read_csv(path_value)
opts = detectImportOptions(path_value, 'Delimiter', ',', 'TextType', 'string');
opts.VariableNamingRule = 'preserve';
tbl = readtable(path_value, opts);
end

function write_lines(path_value, lines)
fid = fopen(path_value, 'w', 'n', 'UTF-8');
if fid < 0
    error('cannot write log: %s', path_value);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines(i));
end
end
