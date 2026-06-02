function main_diagnose_wind_speed_wt_probability_smoke()
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'renewable_trip');
smoke_root = fullfile(out_dir, 'wind_trip_record_smoke');
scenario_ids = ["wind_speed_11_28", "wind_speed_12_00"];
summary_rows = cell(numel(scenario_ids), 1);
for i = 1:numel(scenario_ids)
    scenario_id = scenario_ids(i);
    path = fullfile(smoke_root, char(scenario_id), 'wind_trip_probability_trace.csv');
    if exist(path, 'file') ~= 2
        summary_rows{i} = empty_summary_row(scenario_id, "missing trace file");
        continue;
    end
    T = readtable(path, 'TextType', 'string');
    p = T.P_wt;
    valid = ~isnan(p);
    missing = sum(string(T.input_status) == "missing_voltage_frequency_inputs");
    forced = sum(p >= 1 - 1e-12, 'omitnan');
    interval = sum(p > 0 & p < 1, 'omitnan');
    zero = sum(p == 0, 'omitnan');
    wind_speed = resolve_wind_speed(scenario_id);
    note = "P_WT is record-only and is not multiplied into chain probability.";
    if all(p(valid) == 0)
        note = note + " Current smoke did not produce wind trip risk.";
    end
    summary_rows{i} = table(scenario_id, height(T), sum(valid), missing, ...
        mean(p(valid), 'omitnan'), quantile(p(valid), 0.95), max(p(valid), [], 'omitnan'), ...
        forced, interval, zero, wind_speed, note, ...
        'VariableNames', {'scenario_id','sample_count','valid_probability_count','missing_input_count', ...
        'mean_P_wt','p95_P_wt','max_P_wt','forced_trip_count','interval_trip_count','zero_trip_count', ...
        'wind_speed_mps','note'});
end
summary = vertcat(summary_rows{:});
writetable(summary, fullfile(out_dir, 'wind_speed_wt_probability_smoke_summary.csv'));

delta = build_delta(summary);
writetable(delta, fullfile(out_dir, 'wind_speed_wt_probability_delta.csv'));
end

function row = empty_summary_row(scenario_id, note)
row = table(string(scenario_id), 0, 0, 0, NaN, NaN, NaN, 0, 0, 0, resolve_wind_speed(string(scenario_id)), string(note), ...
    'VariableNames', {'scenario_id','sample_count','valid_probability_count','missing_input_count', ...
    'mean_P_wt','p95_P_wt','max_P_wt','forced_trip_count','interval_trip_count','zero_trip_count', ...
    'wind_speed_mps','note'});
end

function delta = build_delta(summary)
metrics = ["mean_P_wt","p95_P_wt","max_P_wt","missing_input_count","forced_trip_count","interval_trip_count"];
rows = cell(numel(metrics), 1);
for m = 1:numel(metrics)
    metric = metrics(m);
    v11 = lookup(summary, "wind_speed_11_28", metric);
    v12 = lookup(summary, "wind_speed_12_00", metric);
    d = v12 - v11;
    if isnan(v11) || isnan(v12)
        diagnosis = "missing_probability_input_or_trace";
    elseif metric == "missing_input_count" && (v11 > 0 || v12 > 0)
        diagnosis = "must_fix_voltage_frequency_inputs_first";
    elseif any(startsWith(metric, ["mean","p95","max"])) && v11 == 0 && v12 == 0
        diagnosis = "both_wind_speed_cases_have_zero_P_WT; trend remains line_probability_or_severity_driven";
    elseif any(startsWith(metric, ["mean","p95","max"])) && v12 > v11
        diagnosis = "P_WT_higher_at_12mps_may_contribute_to_reverse_trend";
    else
        diagnosis = "P_WT_does_not_explain_reverse_wind_speed_trend";
    end
    rows{m} = table(metric, v11, v12, d, "paper expects lower risk at 12.00 than 11.28", diagnosis, ...
        "record-only diagnostic; not formal paper_formula", ...
        'VariableNames', {'metric','value_11_28','value_12_00','delta_12_minus_11', ...
        'paper_expected_direction','diagnosis','note'});
end
delta = vertcat(rows{:});
end

function v = lookup(T, scenario_id, metric)
row = T(string(T.scenario_id) == scenario_id, :);
if isempty(row)
    v = NaN;
else
    v = row.(metric)(1);
end
end

function ws = resolve_wind_speed(scenario_id)
if scenario_id == "wind_speed_11_28"
    ws = 11.28;
elseif scenario_id == "wind_speed_12_00"
    ws = 12.00;
else
    ws = NaN;
end
end
