function main_audit_initial_line_probability_mapping()
%MAIN_AUDIT_INITIAL_LINE_PROBABILITY_MAPPING Audit Table 4-1 initial probability mapping.

project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'formal_var_pilot');
if ~exist(out_root, 'dir'), mkdir(out_root); end

prob_file = fullfile(project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');
P = readtable(prob_file, 'TextType', 'string', 'Delimiter', ',');
parameter_sets = formal_parameter_sets();
scenario_ids = formal_scenario_ids();
formal_branches = [];
for p = 1:numel(parameter_sets)
    for s = 1:numel(scenario_ids)
        f = fullfile(out_root, char(parameter_sets(p)), char(scenario_ids(s)), 'tables', 'markov_chain_summary.csv');
        if exist(f, 'file') == 2
            C = readtable(f, 'TextType', 'string', 'Delimiter', ',');
            formal_branches = [formal_branches; C.initial_branch]; %#ok<AGROW>
        end
    end
end
formal_unique = unique(formal_branches);
rows = {};
all_branches = union(P.branch_index, formal_unique);
for i = 1:numel(all_branches)
    b = all_branches(i);
    pidx = find(P.branch_index == b, 1);
    matched = any(formal_branches == b);
    sample_count = sum(formal_branches == b);
    if isempty(pidx)
        table_value = NaN;
        actual = NaN;
        status = "missing_table4_1_probability";
    else
        table_value = P.paper_prob_times_1e_minus_4(pidx);
        actual = P.initial_outage_probability(pidx);
        if matched
            status = "matched";
        else
            status = "missing_formal_pilot_sample";
        end
    end
    rows(end + 1, :) = {b, table_value, actual, "paper table value times 1e-4", matched, ...
        sample_count, status, "actual probability = paper_table4_1_value * 1e-4"}; %#ok<AGROW>
end
T = cell2table(rows, 'VariableNames', {'initial_branch','paper_table4_1_value', ...
    'P_initial_line_actual','unit_convention','matched_in_formal_pilot', ...
    'formal_pilot_sample_count','mapping_status','note'});
writetable(T, fullfile(out_root, 'initial_line_probability_mapping_audit.csv'));
fprintf('Wrote %s\n', fullfile(out_root, 'initial_line_probability_mapping_audit.csv'));
end

function x = formal_parameter_sets()
x = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
end

function x = formal_scenario_ids()
x = ["concentrated_bus34","distributed_30_39","wind_speed_11_28","wind_speed_12_00", ...
    "penetration_40pct","penetration_60pct","penetration_80pct"];
end
