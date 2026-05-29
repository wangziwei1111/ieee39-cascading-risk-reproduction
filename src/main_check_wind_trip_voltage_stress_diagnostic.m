function main_check_wind_trip_voltage_stress_diagnostic()
%MAIN_CHECK_WIND_TRIP_VOLTAGE_STRESS_DIAGNOSTIC Validate artificial wind voltage stress outputs.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'renewable');
log_path = fullfile(out_dir, 'wind_trip_voltage_stress_check_log.txt');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));

unit_path = fullfile(out_dir, 'wind_trip_probability_unit_test.csv');
stress_path = fullfile(out_dir, 'wind_trip_voltage_stress_diagnostic.csv');
range_path = fullfile(out_dir, 'markov_wind_voltage_range_summary.csv');
must_exist(unit_path);
must_exist(stress_path);
must_exist(range_path);

unit_tbl = readtable(unit_path, 'TextType', 'string');
stress_tbl = readtable(stress_path, 'TextType', 'string');
range_tbl = readtable(range_path, 'TextType', 'string');
assert_all_pass(unit_tbl, 'wind_trip_probability_unit_test');
assert_all_pass(stress_tbl, 'wind_trip_voltage_stress_diagnostic');

normal_p = unique(stress_tbl.p_wt_Ek(stress_tbl.stress_case == "normal_all"));
forced_low_p = unique(stress_tbl.p_wt_Ek(stress_tbl.stress_case == "one_forced_low_voltage"));
forced_high_p = unique(stress_tbl.p_wt_Ek(stress_tbl.stress_case == "one_forced_high_voltage"));
if numel(normal_p) ~= 1 || abs(normal_p - 1) > 1e-9
    error('normal_all P_wt_Ek must be 1.');
end
if numel(forced_low_p) ~= 1 || abs(forced_low_p) > 1e-9
    error('one_forced_low_voltage P_wt_Ek must be 0.');
end
if numel(forced_high_p) ~= 1 || abs(forced_high_p) > 1e-9
    error('one_forced_high_voltage P_wt_Ek must be 0.');
end

if range_tbl.count_below_0p9(1) == 0 && range_tbl.count_above_1p1(1) == 0
    fprintf(fid, 'markov_threshold_hit_status=no_threshold_hits\n');
    fprintf(fid, 'note=P_wt(E_k)=1 is due to sample voltages not entering risk zones, not because the model is ineffective.\n');
else
    fprintf(fid, 'markov_threshold_hit_status=threshold_hits_present\n');
end
fprintf(fid, 'wind_trip_voltage_stress_check passed.\n');
fprintf('wind trip voltage stress check passed: %s\n', log_path);
end

function must_exist(path)
if exist(path, 'file') ~= 2
    error('Required file missing: %s', path);
end
end

function assert_all_pass(tbl, label)
if ~ismember('test_status', tbl.Properties.VariableNames)
    error('%s missing test_status column.', label);
end
if any(string(tbl.test_status) ~= "pass")
    error('%s contains failed rows.', label);
end
end
