function main_test_generator_outage_probability_model()
%MAIN_TEST_GENERATOR_OUTAGE_PROBABILITY_MODEL Unit checks for diagnostic P_G(q).
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'generator');
ensure_dir(out_dir);
cfg0 = base_config();
parameter_sets = ["strict_missing", "paper_formula_structure_only", "diagnostic_voltage_frequency_probability"];
voltage_points = [0.60, 0.70, 0.80, 0.90, 1.00, 1.10, 1.20, 1.30, 1.40];
frequency_points = [48.0, 48.5, 49.0, 49.5, 50.0, 50.5, 51.0, 51.5, 52.0];

rows = {};
for ps = parameter_sets
    cfg = load_generator_outage_probability_parameter_set(cfg0, ps);
    for v = voltage_points
        rows{end+1,1} = run_case(cfg, ps, v, 50.0, "voltage_sweep"); %#ok<AGROW>
    end
    for f = frequency_points
        rows{end+1,1} = run_case(cfg, ps, 1.0, f, "frequency_sweep"); %#ok<AGROW>
    end
end
tbl = vertcat(rows{:});
writetable(tbl, fullfile(out_dir, 'generator_outage_probability_unit_test.csv'));
fprintf('generator outage probability unit test written.\n');
end

function row = run_case(cfg, parameter_set_id, voltage, frequency, sweep_type)
[p, d] = compute_generator_outage_probability(voltage, frequency, cfg);
expected = expected_behavior(parameter_set_id, voltage, frequency);
test_status = "pass";
if parameter_set_id == "diagnostic_voltage_frequency_probability"
    if voltage == 1.0 && frequency == 50.0 && abs(p) > 1e-12
        test_status = "fail";
    elseif (voltage <= 0.70 || voltage >= 1.30 || frequency <= 48.5 || frequency >= 51.5) && abs(p - 1) > 1e-12
        test_status = "fail";
    elseif (voltage > 0.70 && voltage < 0.90) && ~(p > 0 && p < 1)
        test_status = "fail";
    elseif (voltage > 1.10 && voltage < 1.30) && ~(p > 0 && p < 1)
        test_status = "fail";
    elseif (frequency > 48.5 && frequency < 49.5) && ~(p > 0 && p < 1)
        test_status = "fail";
    elseif (frequency > 50.5 && frequency < 51.5) && ~(p > 0 && p < 1)
        test_status = "fail";
    end
elseif contains(string(d.status), "calibrated")
    test_status = "fail";
end
row = table(string(parameter_set_id), voltage, frequency, p, string(d.voltage_region), ...
    string(d.frequency_region), logical(d.threshold_hit), string(d.status), ...
    string(d.calibration_status), expected, test_status, sweep_type, ...
    'VariableNames', {'parameter_set_id', 'gen_voltage_pu', 'gen_frequency_hz', ...
    'p_g_q', 'voltage_region', 'frequency_region', 'threshold_hit', ...
    'probability_status', 'calibration_status', 'expected_behavior', ...
    'test_status', 'sweep_type'});
end

function expected = expected_behavior(parameter_set_id, voltage, frequency)
if parameter_set_id == "strict_missing"
    expected = "missing paper probability function; not calibrated";
elseif parameter_set_id == "paper_formula_structure_only"
    expected = "paper formula structure recorded, numerical thresholds/probability missing";
elseif voltage <= 0.70 || voltage >= 1.30 || frequency <= 48.5 || frequency >= 51.5
    expected = "forced outage diagnostic probability equals 1";
elseif (voltage < 0.90 || voltage > 1.10 || frequency < 49.5 || frequency > 50.5)
    expected = "transition risk region diagnostic probability between 0 and 1";
else
    expected = "normal voltage/frequency diagnostic probability equals 0";
end
end

function ensure_dir(path)
if ~exist(path, 'dir')
    mkdir(path);
end
end
