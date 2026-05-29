function main_run_generator_voltage_frequency_stress_diagnostic()
%MAIN_RUN_GENERATOR_VOLTAGE_FREQUENCY_STRESS_DIAGNOSTIC Synthetic P_ge(E_k) stress checks.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'generator');
ensure_dir(out_dir);
cfg = load_generator_outage_probability_parameter_set(base_config(), 'diagnostic_voltage_frequency_probability');
require_matpower(cfg);
mpc = build_case39_base(cfg);
gen_buses = mpc.gen(1:min(10, size(mpc.gen, 1)), 1);
gen_count = numel(gen_buses);

cases = build_cases(gen_count);
rows = {};
for c = 1:numel(cases)
    voltages = ones(gen_count, 1);
    freqs = repmat(50.0, gen_count, 1);
    voltages(cases(c).v_idx) = cases(c).v_value;
    freqs(cases(c).f_idx) = cases(c).f_value;
    [p, d] = compute_generator_outage_probability(voltages, freqs, cfg);
    trip_table = table((1:gen_count)', gen_buses(:), voltages, freqs, p, p, ...
        'VariableNames', {'gen_index', 'gen_bus', 'gen_voltage_pu', 'gen_frequency_hz', 'p_g_q', 'trip_probability'});
    [p_ge, sd] = compute_generator_state_probability(trip_table, cfg);
    for k = 1:gen_count
        rows{end+1,1} = table(string(cases(c).name), k, gen_buses(k), voltages(k), freqs(k), ...
            p(k), string(d(k).voltage_region), string(d(k).frequency_region), string(d(k).status), ...
            p_ge, sd.num_probability_positive, sd.max_p_g_q, sd.mean_p_g_q, ...
            string(cases(c).expected), check_case(cases(c).name, p_ge), ...
            'VariableNames', {'stress_case', 'gen_index', 'gen_bus', 'gen_voltage_pu', ...
            'gen_frequency_hz', 'p_g_q', 'voltage_region', 'frequency_region', ...
            'probability_status', 'p_ge_Ek', 'num_probability_positive', ...
            'max_p_g_q', 'mean_p_g_q', 'expected_behavior', 'test_status'}); %#ok<AGROW>
    end
end
tbl = vertcat(rows{:});
writetable(tbl, fullfile(out_dir, 'generator_voltage_frequency_stress_diagnostic.csv'));
fprintf('generator voltage/frequency stress diagnostic written.\n');
end

function cases = build_cases(gen_count)
blank = struct('name', "", 'v_idx', [], 'v_value', [], 'f_idx', [], 'f_value', [], 'expected', "");
cases = repmat(blank, 10, 1);
cases(1) = item("normal_all", [], [], [], [], "P_ge(E_k)=1");
cases(2) = item("one_low_voltage", 1, 0.8, [], [], "0<P_ge(E_k)<1");
cases(3) = item("one_forced_low_voltage", 1, 0.6, [], [], "P_ge(E_k)=0");
cases(4) = item("one_high_voltage", 1, 1.2, [], [], "0<P_ge(E_k)<1");
cases(5) = item("one_forced_high_voltage", 1, 1.4, [], [], "P_ge(E_k)=0");
cases(6) = item("one_low_frequency", [], [], 1, 49.0, "0<P_ge(E_k)<1");
cases(7) = item("one_forced_low_frequency", [], [], 1, 48.0, "P_ge(E_k)=0");
cases(8) = item("one_high_frequency", [], [], 1, 51.0, "0<P_ge(E_k)<1");
cases(9) = item("one_forced_high_frequency", [], [], 1, 52.0, "P_ge(E_k)=0");
cases(10) = item("mixed_voltage_frequency", [1 2], [0.8 1.2], [3 4], [49.0 52.0], "P_ge(E_k)=0 because one unit is forced high frequency");
for i = 1:numel(cases)
    cases(i).v_idx = cases(i).v_idx(cases(i).v_idx <= gen_count);
    cases(i).f_idx = cases(i).f_idx(cases(i).f_idx <= gen_count);
end
end

function s = item(name, v_idx, v_value, f_idx, f_value, expected)
s = struct('name', string(name), 'v_idx', v_idx, 'v_value', v_value, ...
    'f_idx', f_idx, 'f_value', f_value, 'expected', string(expected));
end

function status = check_case(name, p_ge)
if name == "normal_all"
    ok = abs(p_ge - 1) < 1e-12;
elseif contains(name, "forced") || name == "mixed_voltage_frequency"
    ok = abs(p_ge) < 1e-12;
else
    ok = p_ge > 0 && p_ge < 1;
end
status = "pass";
if ~ok
    status = "fail";
end
end

function ensure_dir(path)
if ~exist(path, 'dir')
    mkdir(path);
end
end
