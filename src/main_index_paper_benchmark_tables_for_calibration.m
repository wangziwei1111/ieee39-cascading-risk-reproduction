function main_index_paper_benchmark_tables_for_calibration()
%MAIN_INDEX_PAPER_BENCHMARK_TABLES_FOR_CALIBRATION Build index of paper benchmark values for calibration.
project_root = fileparts(fileparts(mfilename('fullpath')));
diag_dir = fullfile(project_root, 'results', 'calibration', 'diagnostics');
ensure_dir(diag_dir);
src = fullfile(project_root, 'paper_inputs', 'filled', 'paper_result_benchmark.csv');
out_path = fullfile(diag_dir, 'paper_benchmark_calibration_index.csv');
if exist(src, 'file') ~= 2
    writetable(empty_index(), out_path);
    return;
end
T = read_csv(src);
n = height(T);
paper_table_id = string(T.paper_figure_or_table);
paper_table_name = paper_table_id;
scenario_group = strings(n,1);
scenario_label = string(T.scenario_id);
confidence_sigma = T.confidence_level;
metric_name = string(T.metric_name);
paper_table_value = T.paper_value;
paper_unit = string(T.unit);
source_file = repmat(string(src), n, 1);
source_row_id = (1:n)';
candidate_for_calibration = true(n,1);
note = strings(n,1);
for i=1:n
    [scenario_group(i), note(i)] = classify_group(paper_table_id(i), scenario_label(i), confidence_sigma(i));
    if isnan(confidence_sigma(i))
        note(i) = note(i) + "; sigma_unknown";
    end
end
out = table(paper_table_id, paper_table_name, scenario_group, scenario_label, confidence_sigma, ...
    metric_name, paper_table_value, paper_unit, source_file, source_row_id, ...
    candidate_for_calibration, note);
writetable(out, out_path);
fprintf('paper benchmark calibration index written: %d rows\n', height(out));
end

function [group,note] = classify_group(table_id, scenario, varargin)
note = "indexed from paper_inputs/filled/paper_result_benchmark.csv";
switch string(table_id)
    case "Table 4-2"
        group = "renewable_trip_compare";
    case "Table 4-4"
        group = "topology_compare";
    case "Table 4-5"
        group = "penetration_scan";
    case "Table 4-6"
        group = "wind_speed_scan";
    otherwise
        group = "unknown_group";
        note = note + "; table group unknown";
end
if contains(string(scenario), "scenario_")
    note = note + "; scenario label is paper generic label";
end
end

function out = empty_index()
out = table(strings(0,1),strings(0,1),strings(0,1),strings(0,1),[],strings(0,1),[],strings(0,1),strings(0,1),[],false(0,1),strings(0,1), ...
    'VariableNames', {'paper_table_id','paper_table_name','scenario_group','scenario_label','confidence_sigma','metric_name','paper_table_value','paper_unit','source_file','source_row_id','candidate_for_calibration','note'});
end

function tbl=read_csv(path_value); opts=detectImportOptions(path_value,'Delimiter',',','TextType','string'); opts.VariableNamingRule='preserve'; tbl=readtable(path_value,opts); end
function ensure_dir(path_value); if exist(path_value,'dir')~=7; mkdir(path_value); end; end
