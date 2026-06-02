function main_analyze_wind_speed_component_diagnostic_rerun()
root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun');
psets = ["high_hidden_failure","benchmark_calibrated_seed"];
scens = ["wind_speed_11_28","wind_speed_12_00"];
metrics = ["SLLR","SLFOR","SNVOR","CRI"];
sigmas = [0.90 0.95 0.98];
var_rows = {};
delta_rows = {};
for p = 1:numel(psets)
    data = struct();
    for s = 1:numel(scens)
        T = readtable(fullfile(out_root, psets(p), scens(s), 'tables', 'markov_chain_summary.csv'), 'TextType', 'string');
        R = add_risk(T);
        data.(char(scens(s))) = R;
        for si = 1:numel(sigmas)
            for m = 1:numel(metrics)
                vals = R.(char("R_"+metrics(m)));
                valid = ~isnan(vals);
                var_rows{end+1,1} = table(psets(p), scens(s), sigmas(si), metrics(m), quantile(vals(valid), sigmas(si)), ...
                    height(R), sum(valid), "bernoulli_full_event", "paper_2_12_20", ...
                    "wind-speed-only component diagnostic rerun; not formal benchmark", ...
                    'VariableNames', {'parameter_set_id','scenario_id','sigma','metric_name','var_value','sample_count', ...
                    'valid_sample_count','stage_probability_mode','wind_power_curve_profile','note'}); %#ok<AGROW>
            end
        end
    end
    A = suffix(data.wind_speed_11_28, "11");
    B = suffix(data.wind_speed_12_00, "12");
    J = innerjoin(A, B, 'Keys', {'initial_branch','trial_id'});
    for i = 1:height(J)
        for m = 1:numel(metrics)
            metric = metrics(m);
            r11 = J.(char("R_"+metric+"_11"))(i); r12 = J.(char("R_"+metric+"_12"))(i);
            b11 = basic(J, metric, "11", i); b12 = basic(J, metric, "12", i);
            p11 = J.chain_transition_probability_11(i); p12 = J.chain_transition_probability_12(i);
            ml11 = J.max_line_loading_pu_11(i); ml12 = J.max_line_loading_pu_12(i);
            delta_rows{end+1,1} = table(psets(p), J.initial_branch(i), J.trial_id(i), metric, r11, r12, r12-r11, ...
                b11, b12, b12-b11, p11, p12, p12-p11, ml11, ml12, ml12-ml11, ...
                string(J.terminated_reason_11(i)), string(J.terminated_reason_12(i)), "paired_by_initial_branch_trial", ...
                classify_driver(r12-r11, b12-b11, p12-p11, ml12-ml11), "common-random diagnostic pair; not formal benchmark", ...
                'VariableNames', {'parameter_set_id','initial_branch','trial_id','metric_name','R_11_28','R_12_00', ...
                'delta_12_minus_11','basic_metric_11_28','basic_metric_12_00','delta_basic_metric', ...
                'chain_prob_11_28','chain_prob_12_00','delta_chain_prob','max_line_loading_11_28', ...
                'max_line_loading_12_00','delta_max_line_loading','terminated_reason_11_28','terminated_reason_12_00', ...
                'pair_status','likely_driver','note'}); %#ok<AGROW>
        end
    end
end
writetable(vertcat(var_rows{:}), fullfile(out_root, 'wind_speed_component_diagnostic_var_metrics.csv'));
writetable(vertcat(delta_rows{:}), fullfile(out_root, 'wind_speed_component_diagnostic_paired_delta.csv'));
end

function T = add_risk(T)
scale = T.initial_line_probability .* T.chain_transition_probability ./ 1e-4;
T.R_SLLR = scale .* T.basic_LLR;
T.R_SLFOR = scale .* T.basic_LFOR;
T.R_SNVOR = scale .* T.basic_NVOR;
T.R_CRI = 0.6*T.R_SLLR + 0.2*T.R_SLFOR + 0.2*T.R_SNVOR;
end

function T = suffix(T, suf)
keep = {'initial_branch','trial_id','terminated_reason','chain_transition_probability','max_line_loading_pu', ...
    'R_SLLR','R_SLFOR','R_SNVOR','R_CRI','basic_LLR','basic_LFOR','basic_NVOR','basic_CRI'};
T = T(:, keep);
for i = 3:numel(keep)
    idx = find(strcmp(T.Properties.VariableNames, keep{i}), 1);
    T.Properties.VariableNames{idx} = char(string(keep{i}) + "_" + suf);
end
end

function v = basic(J, metric, suf, i)
switch metric
    case "SLLR", v = J.(char("basic_LLR_"+suf))(i);
    case "SLFOR", v = J.(char("basic_LFOR_"+suf))(i);
    case "SNVOR", v = J.(char("basic_NVOR_"+suf))(i);
    otherwise, v = J.(char("basic_CRI_"+suf))(i);
end
end

function s = classify_driver(~, db, dp, dl)
if dp > 0 && db > 0
    s = "mixed_probability_and_severity";
elseif dp > 0
    s = "chain_probability_increase";
elseif db > 0
    s = "severity_increase";
elseif dl > 0
    s = "line_loading_increase";
else
    s = "no_clear_driver";
end
end
