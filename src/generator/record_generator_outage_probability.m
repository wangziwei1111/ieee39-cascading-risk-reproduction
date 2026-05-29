function generator_trip_table = record_generator_outage_probability(mpc, pf_result, stage_id, initial_branch, trial_id, scenario, renewable_info, cfg)
%RECORD_GENERATOR_OUTAGE_PROBABILITY Record traditional generator P_G(q) diagnostics.
generator_trip_table = empty_generator_trip_table();
if nargin < 2 || isempty(pf_result) || ~isstruct(pf_result) || ...
        ~isfield(pf_result, 'success') || ~logical(pf_result.success) || ~isfield(pf_result, 'bus')
    return;
end

mpc_role = mpc;
if nargin >= 7 && isstruct(renewable_info) && isfield(renewable_info, 'wind_gen_rows')
    if ~isfield(mpc_role, 'userdata') || ~isstruct(mpc_role.userdata)
        mpc_role.userdata = struct();
    end
    mpc_role.userdata.wind_gen_rows = renewable_info.wind_gen_rows(:);
end
gen_role_table = identify_traditional_generators(mpc_role, scenario, cfg);
if isempty(gen_role_table) || height(gen_role_table) == 0
    return;
end
gen_role_table = gen_role_table(gen_role_table.is_traditional, :);
if height(gen_role_table) == 0
    return;
end

gen_index = gen_role_table.gen_index;
gen_bus = gen_role_table.gen_bus;
gen_voltage_pu = nan(height(gen_role_table), 1);
for k = 1:height(gen_role_table)
    bus_row = find(pf_result.bus(:, 1) == gen_bus(k), 1);
    if ~isempty(bus_row)
        gen_voltage_pu(k) = pf_result.bus(bus_row, 8);
    end
end

frequency_hz = get_cfg(cfg, 'nominal_frequency_hz', get_cfg(cfg, 'system_frequency_hz', 50.0));
gen_frequency_hz = repmat(frequency_hz, height(gen_role_table), 1);
[trip_probability, probability_detail] = compute_generator_outage_probability(gen_voltage_pu, gen_frequency_hz, cfg);

voltage_region = strings(height(gen_role_table), 1);
frequency_region = strings(height(gen_role_table), 1);
generator_outage_probability_model = strings(height(gen_role_table), 1);
generator_trip_calibration_status = strings(height(gen_role_table), 1);
probability_status = strings(height(gen_role_table), 1);
threshold_hit = false(height(gen_role_table), 1);
for k = 1:height(gen_role_table)
    voltage_region(k) = string(probability_detail(k).voltage_region);
    frequency_region(k) = string(probability_detail(k).frequency_region);
    generator_outage_probability_model(k) = string(probability_detail(k).model_name);
    generator_trip_calibration_status(k) = string(probability_detail(k).calibration_status);
    probability_status(k) = string(probability_detail(k).status);
    threshold_hit(k) = logical(probability_detail(k).threshold_hit);
end

n = height(gen_role_table);
generator_trip_table = table(repmat(initial_branch, n, 1), repmat(trial_id, n, 1), ...
    repmat(stage_id, n, 1), gen_index, gen_bus, gen_voltage_pu, gen_frequency_hz, ...
    trip_probability(:), trip_probability(:), generator_outage_probability_model, ...
    generator_trip_calibration_status, threshold_hit, voltage_region, frequency_region, ...
    probability_status, true(n, 1), gen_role_table.is_traditional, gen_role_table.role_status, ...
    repmat("Static power flow has no dynamic frequency; nominal frequency is used for diagnostic P_G(q).", n, 1), ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', 'gen_index', ...
    'gen_bus', 'gen_voltage_pu', 'gen_frequency_hz', 'p_g_q', 'trip_probability', ...
    'generator_outage_probability_model', 'generator_trip_calibration_status', ...
    'threshold_hit', 'voltage_region', 'frequency_region', 'probability_status', ...
    'record_only', 'is_traditional', 'role_status', 'note'});
end

function value = get_cfg(cfg, field_name, default_value)
if isfield(cfg, field_name)
    value = cfg.(field_name);
else
    value = default_value;
end
end

function tbl = empty_generator_trip_table()
tbl = table([], [], [], [], [], [], [], [], [], strings(0, 1), strings(0, 1), ...
    false(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), false(0, 1), ...
    false(0, 1), strings(0, 1), strings(0, 1), ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', 'gen_index', ...
    'gen_bus', 'gen_voltage_pu', 'gen_frequency_hz', 'p_g_q', 'trip_probability', ...
    'generator_outage_probability_model', 'generator_trip_calibration_status', ...
    'threshold_hit', 'voltage_region', 'frequency_region', 'probability_status', ...
    'record_only', 'is_traditional', 'role_status', 'note'});
end
