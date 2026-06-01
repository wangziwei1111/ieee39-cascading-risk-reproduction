function main_build_formal_chain_risk_samples()
%MAIN_BUILD_FORMAL_CHAIN_RISK_SAMPLES Build offline chain-level risk samples.

project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'formal_var_pilot');
P = readtable(fullfile(project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv'), 'TextType', 'string', 'Delimiter', ',');
prob_map = containers.Map(num2cell(P.branch_index), num2cell(P.initial_outage_probability));
parameter_sets = formal_parameter_sets();
scenario_ids = formal_scenario_ids();
rows = {};
for p = 1:numel(parameter_sets)
    for s = 1:numel(scenario_ids)
        source_file = fullfile(out_root, char(parameter_sets(p)), char(scenario_ids(s)), 'tables', 'markov_chain_summary.csv');
        if exist(source_file, 'file') ~= 2
            continue;
        end
        C = readtable(source_file, 'TextType', 'string', 'Delimiter', ',');
        has_transition = any(ismember(["chain_transition_probability","chain_probability"], string(C.Properties.VariableNames)));
        for i = 1:height(C)
            initial_branch = C.initial_branch(i);
            if isKey(prob_map, initial_branch)
                p_initial = prob_map(initial_branch);
                initial_status = "initial_probability_only";
            else
                p_initial = NaN;
                initial_status = "missing_initial_probability";
            end
            rows = append_sample(rows, parameter_sets(p), scenario_ids(s), "severity_only", C(i, :), ...
                p_initial, NaN, "severity_only", C.basic_LLR(i), C.basic_LFOR(i), C.basic_NVOR(i), ...
                C.basic_CRI(i), 0.6*C.basic_LLR(i)+0.2*C.basic_LFOR(i)+0.2*C.basic_NVOR(i), ...
                "severity", source_file, "Severity-only comparator; not paper risk VaR.");
            rows = append_sample(rows, parameter_sets(p), scenario_ids(s), "initial_probability_weighted_actual", C(i, :), ...
                p_initial, NaN, initial_status, p_initial*C.basic_LLR(i), p_initial*C.basic_LFOR(i), p_initial*C.basic_NVOR(i), ...
                p_initial*C.basic_CRI(i), p_initial*(0.6*C.basic_LLR(i)+0.2*C.basic_LFOR(i)+0.2*C.basic_NVOR(i)), ...
                "actual_probability", source_file, "R = P_initial_line * severity.");
            rows = append_sample(rows, parameter_sets(p), scenario_ids(s), "initial_probability_weighted_display", C(i, :), ...
                p_initial, NaN, initial_status, p_initial*C.basic_LLR(i)/1e-4, p_initial*C.basic_LFOR(i)/1e-4, p_initial*C.basic_NVOR(i)/1e-4, ...
                p_initial*C.basic_CRI(i)/1e-4, p_initial*(0.6*C.basic_LLR(i)+0.2*C.basic_LFOR(i)+0.2*C.basic_NVOR(i))/1e-4, ...
                "paper_table_display_probability_divided_by_1e_minus_4", source_file, "Display risk = P_initial_line * severity / 1e-4.");
            if has_transition
                transition_p = read_transition_probability(C(i, :));
                status = "initial_and_transition_probability";
                note = "R = P_initial_line * chain_transition_probability * severity.";
            else
                transition_p = NaN;
                status = "missing_transition_probability";
                note = "No chain_transition_probability or chain_probability field in formal pilot chain summary; not fabricated.";
            end
            rows = append_sample(rows, parameter_sets(p), scenario_ids(s), "transition_probability_weighted", C(i, :), ...
                p_initial, transition_p, status, p_initial*transition_p*C.basic_LLR(i)/1e-4, ...
                p_initial*transition_p*C.basic_LFOR(i)/1e-4, p_initial*transition_p*C.basic_NVOR(i)/1e-4, ...
                p_initial*transition_p*C.basic_CRI(i)/1e-4, p_initial*transition_p*(0.6*C.basic_LLR(i)+0.2*C.basic_LFOR(i)+0.2*C.basic_NVOR(i))/1e-4, ...
                "unavailable_transition_probability", source_file, note);
        end
    end
end
T = cell2table(rows, 'VariableNames', {'parameter_set_id','scenario_id','sample_variant', ...
    'initial_branch','trial_id','chain_depth','terminated_reason','P_initial_line', ...
    'chain_transition_probability','probability_status','R1_LLR','R2_LFOR','R3_NVOR', ...
    'R_CRI_basic','R_CRI_recomputed','scale_convention','source_file','note'});
writetable(T, fullfile(out_root, 'formal_chain_risk_samples.csv'));
fprintf('Wrote %s\n', fullfile(out_root, 'formal_chain_risk_samples.csv'));
end

function rows = append_sample(rows, parameter_set_id, scenario_id, sample_variant, c, p_initial, transition_p, probability_status, r1, r2, r3, cri_basic, cri_recomputed, scale, source_file, note)
rows(end + 1, :) = {parameter_set_id, scenario_id, sample_variant, c.initial_branch, c.trial_id, ...
    c.chain_depth, string(c.terminated_reason), p_initial, transition_p, probability_status, ...
    r1, r2, r3, cri_basic, cri_recomputed, scale, string(source_file), note}; %#ok<AGROW>
end

function p = read_transition_probability(row)
if ismember('chain_transition_probability', row.Properties.VariableNames)
    p = row.chain_transition_probability(1);
elseif ismember('chain_probability', row.Properties.VariableNames)
    p = row.chain_probability(1);
else
    p = NaN;
end
end

function x = formal_parameter_sets()
x = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
end

function x = formal_scenario_ids()
x = ["concentrated_bus34","distributed_30_39","wind_speed_11_28","wind_speed_12_00", ...
    "penetration_40pct","penetration_60pct","penetration_80pct"];
end
