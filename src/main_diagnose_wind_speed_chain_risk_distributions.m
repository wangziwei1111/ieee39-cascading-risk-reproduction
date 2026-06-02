function main_diagnose_wind_speed_chain_risk_distributions()
%MAIN_DIAGNOSE_WIND_SPEED_CHAIN_RISK_DISTRIBUTIONS Summarize wind-speed chain risk samples.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
params = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scenarios = ["wind_speed_11_28","wind_speed_12_00"];
summary = table();
for p = params
    for s = scenarios
        path = fullfile(out_root, p, s, 'tables', 'markov_chain_summary.csv');
        if ~isfile(path), continue; end
        T = readtable(path, 'TextType', 'string', 'Delimiter', ',');
        samples = build_samples(T);
        for i = 1:height(samples)
            vals = samples.values{i};
            st = describe(vals);
            summary = [summary; table(p, s, samples.metric_name(i), samples.sample_variant(i), ...
                numel(vals), st.mean, st.median, st.p90, st.p95, st.p98, st.max, ...
                st.zero_fraction, st.nonzero_fraction, samples.note(i), ...
                'VariableNames', {'parameter_set_id','scenario_id','metric_name','sample_variant','sample_count', ...
                'mean','median','p90','p95','p98','max','zero_fraction','nonzero_fraction','note'})]; %#ok<AGROW>
        end
    end
end
writetable(summary, fullfile(out_root, 'wind_speed_chain_risk_distribution_summary.csv'));

delta = table();
pairs = unique(summary(:, {'metric_name','sample_variant'}), 'rows');
for p = params
    for pair_idx = 1:height(pairs)
            m = pairs.metric_name(pair_idx);
            v = pairs.sample_variant(pair_idx);
            a = summary(summary.parameter_set_id == p & summary.scenario_id == "wind_speed_11_28" & ...
                summary.metric_name == m & summary.sample_variant == v, :);
            b = summary(summary.parameter_set_id == p & summary.scenario_id == "wind_speed_12_00" & ...
                summary.metric_name == m & summary.sample_variant == v, :);
            if isempty(a) || isempty(b)
                diagnosis = "insufficient_samples"; sim_direction = "missing"; dir_match = false;
                p11 = NaN; p12 = NaN; d = NaN; rd = NaN;
            else
                p11 = a.p95(1); p12 = b.p95(1); d = p12 - p11; rd = d / (abs(p11) + eps);
                sim_direction = direction_label(d);
                dir_match = d < 0;
                if dir_match
                    diagnosis = "wind_speed_trend_matches_paper";
                else
                    if v == "severity_only"
                        diagnosis = "wind_speed_trend_opposite_due_to_severity";
                    elseif v == "full_event_chain_risk_display"
                        diagnosis = infer_full_event_cause(summary, p, m);
                    else
                        diagnosis = "wind_speed_no_effect";
                    end
                end
            end
            delta = [delta; table(p, m, v, p11, p12, "12.00_lower_than_11.28", sim_direction, dir_match, d, rd, diagnosis, ...
                "Paper benchmark direction is lower risk at 12.00 m/s than 11.28 m/s.", ...
                'VariableNames', {'parameter_set_id','metric_name','sample_variant','value_11_28_p95','value_12_00_p95', ...
                'paper_direction','sim_direction','direction_match','delta_12_minus_11','relative_delta','diagnosis','note'})]; %#ok<AGROW>
    end
end
writetable(delta, fullfile(out_root, 'wind_speed_11_28_vs_12_00_distribution_delta.csv'));
end

function samples = build_samples(T)
initp = numcol(T, 'initial_line_probability');
chainp = numcol(T, 'chain_transition_probability');
scale = initp .* chainp / 1e-4;
llr = numcol(T, 'basic_LLR'); lfor = numcol(T, 'basic_LFOR'); nvor = numcol(T, 'basic_NVOR');
cri = 0.6 .* llr + 0.2 .* lfor + 0.2 .* nvor;
samples = table(["basic_LLR";"basic_LFOR";"basic_NVOR";"basic_CRI";"R1_display";"R2_display";"R3_display";"CRI_display"], ...
    ["severity_only";"severity_only";"severity_only";"severity_only";"full_event_chain_risk_display";"full_event_chain_risk_display";"full_event_chain_risk_display";"full_event_chain_risk_display"], ...
    {llr;lfor;nvor;cri;scale.*llr;scale.*lfor;scale.*nvor;0.6.*scale.*llr+0.2.*scale.*lfor+0.2.*scale.*nvor}, ...
    repmat("Existing full-event formal pilot samples; no new Markov run.", 8, 1), ...
    'VariableNames', {'metric_name','sample_variant','values','note'});
end

function x = numcol(T, name)
if ismember(name, T.Properties.VariableNames), x = str2double(string(T.(name))); else, x = NaN(height(T),1); end
end

function st = describe(vals)
vals = vals(~isnan(vals));
if isempty(vals), vals = NaN; end
st.mean = mean(vals, 'omitnan'); st.median = median(vals, 'omitnan');
st.p90 = q(vals, 0.90); st.p95 = q(vals, 0.95); st.p98 = q(vals, 0.98); st.max = max(vals, [], 'omitnan');
st.zero_fraction = mean(abs(vals) < 1e-12, 'omitnan'); st.nonzero_fraction = 1 - st.zero_fraction;
end

function y = q(x, p)
x = sort(x(~isnan(x))); if isempty(x), y = NaN; else, y = x(max(1, min(numel(x), ceil(p*numel(x))))); end
end

function s = direction_label(d)
if isnan(d), s = "missing"; elseif abs(d) < 1e-12, s = "no_effect"; elseif d < 0, s = "12_lower"; else, s = "12_higher"; end
end

function diagnosis = infer_full_event_cause(summary, p, m)
sev = summary(summary.parameter_set_id == p & summary.metric_name == replace_metric(m) & summary.sample_variant == "severity_only", :);
if height(sev) == 2
    a = sev(sev.scenario_id == "wind_speed_11_28", :); b = sev(sev.scenario_id == "wind_speed_12_00", :);
    if ~isempty(a) && ~isempty(b) && b.p95 > a.p95
        diagnosis = "wind_speed_trend_opposite_due_to_severity"; return;
    end
end
diagnosis = "wind_speed_trend_opposite_due_to_chain_probability";
end

function m2 = replace_metric(m)
m = string(m);
if m == "R1_display", m2 = "basic_LLR";
elseif m == "R2_display", m2 = "basic_LFOR";
elseif m == "R3_display", m2 = "basic_NVOR";
elseif m == "CRI_display", m2 = "basic_CRI";
else, m2 = m;
end
end
