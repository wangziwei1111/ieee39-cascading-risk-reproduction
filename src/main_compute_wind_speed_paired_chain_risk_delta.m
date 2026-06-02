function main_compute_wind_speed_paired_chain_risk_delta()
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
parameter_sets = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
metrics = ["SLLR","SLFOR","SNVOR","CRI"];
rows = {};
for p = 1:numel(parameter_sets)
    ps = parameter_sets(p);
    A = prepare_for_join(add_risk(readtable(fullfile(out_root, ps, 'wind_speed_11_28', 'tables', 'markov_chain_summary.csv'), 'TextType', 'string')), "11");
    B = prepare_for_join(add_risk(readtable(fullfile(out_root, ps, 'wind_speed_12_00', 'tables', 'markov_chain_summary.csv'), 'TextType', 'string')), "12");
    J = innerjoin(A, B, 'Keys', {'initial_branch','trial_id'});
    for i = 1:height(J)
        for m = 1:numel(metrics)
            metric = metrics(m);
            r11 = J.(char("R_"+metric+"_11"))(i); r12 = J.(char("R_"+metric+"_12"))(i);
            b11 = basic_value(J, metric, "11", i); b12 = basic_value(J, metric, "12", i);
            p11 = J.chain_transition_probability_11(i); p12 = J.chain_transition_probability_12(i);
            driver = classify_driver(r12-r11, b12-b11, p12-p11);
            rows{end+1,1} = table(ps, J.initial_branch(i), J.trial_id(i), metric, r11, r12, r12-r11, ...
                b11, b12, b12-b11, p11, p12, p12-p11, string(J.terminated_reason_11(i)), string(J.terminated_reason_12(i)), ...
                "paired_by_initial_branch_trial", driver, "Paired chain delta from existing after-curve-fix pilot.", ...
                'VariableNames', {'parameter_set_id','initial_branch','trial_id','metric_name','R_11_28','R_12_00', ...
                'delta_12_minus_11','basic_metric_11_28','basic_metric_12_00','delta_basic_metric', ...
                'chain_prob_11_28','chain_prob_12_00','delta_chain_prob','terminated_reason_11_28','terminated_reason_12_00', ...
                'pair_status','likely_driver','note'}); %#ok<AGROW>
        end
    end
end
D = vertcat(rows{:});
writetable(D, fullfile(out_root, 'wind_speed_paired_chain_risk_delta.csv'));
writetable(build_summary(D), fullfile(out_root, 'wind_speed_paired_chain_risk_delta_summary.csv'));
end

function T = add_risk(T)
scale = T.initial_line_probability .* T.chain_transition_probability ./ 1e-4;
T.R_SLLR = scale .* T.basic_LLR;
T.R_SLFOR = scale .* T.basic_LFOR;
T.R_SNVOR = scale .* T.basic_NVOR;
T.R_CRI = 0.6*T.R_SLLR + 0.2*T.R_SLFOR + 0.2*T.R_SNVOR;
end

function T = prepare_for_join(T, suffix)
keep = {'initial_branch','trial_id','terminated_reason','R_SLLR','R_SLFOR','R_SNVOR','R_CRI', ...
    'basic_LLR','basic_LFOR','basic_NVOR','basic_CRI','chain_transition_probability'};
T = T(:, keep);
for i = 3:numel(keep)
    old = keep{i};
    idx = find(strcmp(T.Properties.VariableNames, old), 1);
    T.Properties.VariableNames{idx} = char(string(old) + "_" + suffix);
end
end

function v = basic_value(J, metric, suffix, i)
switch metric
    case "SLLR", v = J.(char("basic_LLR_"+suffix))(i);
    case "SLFOR", v = J.(char("basic_LFOR_"+suffix))(i);
    case "SNVOR", v = J.(char("basic_NVOR_"+suffix))(i);
    otherwise, v = J.(char("basic_CRI_"+suffix))(i);
end
end

function driver = classify_driver(~, db, dp)
if dp > 0 && db > 0
    driver = "both_probability_and_severity";
elseif dp > 0
    driver = "chain_probability_increase";
elseif db > 0
    driver = "severity_increase";
else
    driver = "no_clear_driver";
end
end

function S = build_summary(D)
keys = unique(D(:, {'parameter_set_id','metric_name'}), 'rows');
rows = cell(height(keys), 1);
for i = 1:height(keys)
    mask = D.parameter_set_id == keys.parameter_set_id(i) & D.metric_name == keys.metric_name(i);
    G = D(mask, :);
    dominant = mode(categorical(G.likely_driver));
    paper_match = mean(G.delta_12_minus_11 < 0, 'omitnan');
    rows{i} = table(keys.parameter_set_id(i), keys.metric_name(i), height(G), ...
        mean(G.delta_12_minus_11, 'omitnan'), median(G.delta_12_minus_11, 'omitnan'), quantile(G.delta_12_minus_11, 0.95), ...
        mean(G.delta_12_minus_11 > 0, 'omitnan'), mean(G.delta_12_minus_11 < 0, 'omitnan'), ...
        mean(G.delta_basic_metric, 'omitnan'), mean(G.delta_chain_prob, 'omitnan'), string(dominant), paper_match, ...
        "paper_expected_direction_match is fraction with 12.00 lower than 11.28", ...
        'VariableNames', {'parameter_set_id','metric_name','paired_sample_count','mean_delta','median_delta','p95_delta', ...
        'fraction_delta_positive','fraction_delta_negative','mean_delta_basic_metric','mean_delta_chain_prob', ...
        'dominant_driver','paper_expected_direction_match','note'});
end
S = vertcat(rows{:});
end
