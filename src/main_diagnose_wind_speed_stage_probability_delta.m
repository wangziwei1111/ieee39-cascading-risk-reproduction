function main_diagnose_wind_speed_stage_probability_delta()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'stage_probability_aggregation');
A = readtable(fullfile(out_dir, 'stage_probability_aggregation_audit.csv'), 'TextType','string', 'Delimiter', ',');
psets = unique(A.parameter_set_id);
rows = {};
for p = 1:numel(psets)
    A11 = A(A.parameter_set_id==psets(p)&A.scenario_id=="wind_speed_11_28",:);
    A12 = A(A.parameter_set_id==psets(p)&A.scenario_id=="wind_speed_12_00",:);
    keys = intersect(keyset(A11), keyset(A12));
    for k = 1:numel(keys)
        parts = split(keys(k), "_");
        ib = str2double(parts(1)); tr = str2double(parts(2)); st = str2double(parts(3));
        r11 = A11(A11.initial_branch==ib&A11.trial_id==tr&A11.stage_id==st,:);
        r12 = A12(A12.initial_branch==ib&A12.trial_id==tr&A12.stage_id==st,:);
        if isempty(r11)||isempty(r12), continue; end
        dsp = r12.selected_probability_product(1)-r11.selected_probability_product(1);
        dup = r12.unselected_probability_product(1)-r11.unselected_probability_product(1);
        dst = r12.stage_transition_probability(1)-r11.stage_transition_probability(1);
        dch = r12.chain_transition_probability(1)-r11.chain_transition_probability(1);
        driver = classify_driver(dsp, dup, dst, r11, r12);
        rows{end+1,1} = table(psets(p), ib, tr, st, r11.selected_probability_product(1), r12.selected_probability_product(1), dsp, ...
            r11.unselected_probability_product(1), r12.unselected_probability_product(1), dup, r11.stage_transition_probability(1), ...
            r12.stage_transition_probability(1), dst, r11.chain_transition_probability(1), r12.chain_transition_probability(1), dch, ...
            false, driver, "Paired stage comparison between wind_speed_12_00 and wind_speed_11_28 using existing traces.", ...
            'VariableNames', {'parameter_set_id','initial_branch','trial_id','stage_id','selected_probability_product_11_28', ...
            'selected_probability_product_12_00','delta_selected_probability_product','unselected_probability_product_11_28', ...
            'unselected_probability_product_12_00','delta_unselected_probability_product','stage_probability_11_28', ...
            'stage_probability_12_00','delta_stage_probability','chain_probability_11_28','chain_probability_12_00', ...
            'delta_chain_probability','tail_chain_flag','stage_probability_driver','note'}); %#ok<AGROW>
    end
end
if isempty(rows)
    T = empty_table();
else
    T = vertcat(rows{:});
end
writetable(T, fullfile(out_dir, 'wind_speed_stage_probability_delta.csv'));
end

function keys = keyset(T)
keys = string(T.initial_branch) + "_" + string(T.trial_id) + "_" + string(T.stage_id);
end

function s = classify_driver(dsp, dup, dst, r11, r12)
if r12.selected_candidate_count(1) > r11.selected_candidate_count(1) || dsp > 1e-10
    s = "selected_probability_increase";
elseif dup < -1e-10
    s = "complement_product_decrease";
elseif r12.stage_id(1) > r11.stage_id(1)
    s = "chain_depth_increase";
elseif string(r12.stage_probability_status(1)) ~= string(r11.stage_probability_status(1))
    s = "terminal_reason_change";
elseif abs(dst) > 1e-10
    s = "no_clear_stage_driver";
else
    s = "no_clear_stage_driver";
end
end

function T = empty_table()
T = table(strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
    zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
    zeros(0,1), false(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'parameter_set_id','initial_branch','trial_id','stage_id','selected_probability_product_11_28', ...
    'selected_probability_product_12_00','delta_selected_probability_product','unselected_probability_product_11_28', ...
    'unselected_probability_product_12_00','delta_unselected_probability_product','stage_probability_11_28', ...
    'stage_probability_12_00','delta_stage_probability','chain_probability_11_28','chain_probability_12_00', ...
    'delta_chain_probability','tail_chain_flag','stage_probability_driver','note'});
end
