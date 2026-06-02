function main_audit_wind_speed_probability_severity_field_availability()
root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
psets = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scens = ["wind_speed_11_28","wind_speed_12_00"];
req = requirement_rows();
rows = {};
for p = 1:numel(psets)
    for s = 1:numel(scens)
        files = [
            fullfile(out_root, psets(p), scens(s), 'tables', 'candidate_probability_trace.csv')
            fullfile(out_root, psets(p), scens(s), 'tables', 'stage_transition_probability_details.csv')
            fullfile(out_root, psets(p), scens(s), 'tables', 'markov_chain_summary.csv')
        ];
        types = ["candidate_probability_trace","stage_transition_probability_details","markov_chain_summary"];
        for f = 1:numel(files)
            vars = strings(0,1);
            exists_file = exist(files(f), 'file') == 2;
            if exists_file
                T = readtable(files(f), 'TextType', 'string');
                vars = string(T.Properties.VariableNames);
            end
            for r = 1:height(req)
                if req.table_type(r) ~= types(f), continue; end
                field = req.required_field(r);
                available = any(vars == field) || alias_available(vars, field);
                fallback = fallback_possible(field, available);
                blocking = blocking_if_missing(field, available);
                fix = recommended_fix(field, available);
                rows{end+1,1} = table(string(files(f)), types(f), field, available, req.needed_for(r), fallback, blocking, fix, ...
                    "Availability audit only; missing probability components are not fabricated.", ...
                    'VariableNames', {'source_file','table_type','required_field','field_available','needed_for', ...
                    'fallback_possible','blocking_if_missing','recommended_fix','note'}); %#ok<AGROW>
            end
        end
    end
end
writetable(vertcat(rows{:}), fullfile(out_root, 'wind_speed_probability_severity_field_availability.csv'));
end

function R = requirement_rows()
fields = [
    "candidate_probability","candidate_probability_trace","line_probability_model_input"
    "candidate_branch","candidate_probability_trace","line_probability_model_input"
    "selected","candidate_probability_trace","line_probability_model_input"
    "random_u","candidate_probability_trace","line_probability_model_input"
    "P_flow","candidate_probability_trace","line_probability_model_input"
    "P_HF_D","candidate_probability_trace","line_probability_model_input"
    "P_HF_L","candidate_probability_trace","line_probability_model_input"
    "P_mis_r","candidate_probability_trace","line_probability_model_input"
    "P1","candidate_probability_trace","line_probability_model_input"
    "P2","candidate_probability_trace","line_probability_model_input"
    "P3","candidate_probability_trace","line_probability_model_input"
    "P_L","candidate_probability_trace","line_probability_model_input"
    "line_loading_pu","candidate_probability_trace","line_probability_model_input"
    "L","candidate_probability_trace","line_probability_model_input"
    "L_rated","candidate_probability_trace","line_probability_model_input"
    "L_max","candidate_probability_trace","line_probability_model_input"
    "L_rated_factor","candidate_probability_trace","line_probability_model_input"
    "L_max_factor","candidate_probability_trace","line_probability_model_input"
    "distance_hidden_failure_mode","candidate_probability_trace","line_probability_model_input"
    "stage_transition_probability","stage_transition_probability_details","chain_probability_decomposition"
    "selected_probability_product","stage_transition_probability_details","chain_probability_decomposition"
    "unselected_probability_product","stage_transition_probability_details","chain_probability_decomposition"
    "chain_transition_probability","markov_chain_summary","chain_probability_decomposition"
    "total_chain_probability_display","markov_chain_summary","chain_probability_decomposition"
    "basic_LLR","markov_chain_summary","severity_model_input"
    "basic_LFOR","markov_chain_summary","severity_model_input"
    "basic_NVOR","markov_chain_summary","severity_model_input"
    "basic_CRI","markov_chain_summary","severity_model_input"
    "total_load_shed_mw","markov_chain_summary","severity_model_input"
    "total_load_shed_frac","markov_chain_summary","severity_model_input"
    "max_line_loading_pu","markov_chain_summary","severity_model_input"
    "max_voltage_deviation_pu","markov_chain_summary","severity_model_input"
    "overloaded_branch_count","markov_chain_summary","severity_model_input"
    "voltage_violation_bus_count","markov_chain_summary","severity_model_input"
    "severity_formula_status","markov_chain_summary","severity_model_input"
];
R = array2table(fields, 'VariableNames', {'required_field','table_type','needed_for'});
end

function ok = alias_available(vars, field)
ok = false;
if field == "line_loading_pu"
    ok = any(vars == "loading_pu");
elseif field == "severity_formula_status"
    ok = any(vars == "basic_CRI");
end
end

function v = fallback_possible(field, available)
v = available || any(field == ["line_loading_pu","severity_formula_status"]);
end

function v = blocking_if_missing(field, available)
component_fields = ["P_flow","P_HF_D","P_HF_L","P_mis_r","P1","P2","P3","P_L"];
v = ~available && any(field == component_fields);
end

function s = recommended_fix(field, available)
if available
    s = "field_available";
elseif any(field == ["P_flow","P_HF_D","P_HF_L","P_mis_r","P1","P2","P3","P_L"])
    s = "need_probability_component_trace_smoke";
else
    s = "use_available_proxy_or_note_missing";
end
end
