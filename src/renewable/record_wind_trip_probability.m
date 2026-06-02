function wind_trip_table = record_wind_trip_probability(pf_result, stage_id, initial_branch, trial_id, renewable_info, cfg)
%RECORD_WIND_TRIP_PROBABILITY 记录单个Markov阶段的风机电压脱网概率。
% 输入：
%   pf_result - 收敛后的MATPOWER潮流结果。
%   stage_id - 事故链阶段编号。
%   initial_branch - 初始线路故障编号。
%   trial_id - 当前Monte Carlo样本编号。
%   renewable_info - 新能源接入信息，包含风电节点、风电机组行和容量。
%   cfg - 全局配置，包含电压-脱网概率诊断参数。
% 输出：
%   wind_trip_table - 逐风机电压脱网概率诊断表。
% 物理含义：
%   只读取风机接入节点电压并计算P_WT(h)，不调用随机数、不改变机组状态、
%   不改变线路事故链，是record-only诊断输出。

wind_trip_table = empty_wind_trip_table();
if nargin < 5 || isempty(renewable_info) || ~isfield(renewable_info, 'wind_buses') || isempty(renewable_info.wind_buses)
    return;
end
if ~isfield(pf_result, 'success') || ~logical(pf_result.success)
    return;
end

wind_buses = renewable_info.wind_buses(:);
wind_gen_rows = get_info_vector(renewable_info, 'wind_gen_rows', nan(size(wind_buses)));
wind_capacity = get_info_vector(renewable_info, 'wind_capacity_mw', nan(size(wind_buses)));
if numel(wind_gen_rows) ~= numel(wind_buses)
    wind_gen_rows = nan(size(wind_buses));
end
if numel(wind_capacity) ~= numel(wind_buses)
    wind_capacity = nan(size(wind_buses));
end

wind_index = (1:numel(wind_buses))';
voltage_pu = nan(numel(wind_buses), 1);
wind_output_mw = nan(numel(wind_buses), 1);
for k = 1:numel(wind_buses)
    bus_row = find(pf_result.bus(:, 1) == wind_buses(k), 1);
    if ~isempty(bus_row)
        voltage_pu(k) = pf_result.bus(bus_row, 8);
    end
    gen_row = wind_gen_rows(k);
    if ~isnan(gen_row) && gen_row >= 1 && gen_row <= size(pf_result.gen, 1)
        wind_output_mw(k) = pf_result.gen(gen_row, 2);
    end
end

system_frequency_hz = NaN;
if isfield(cfg, 'system_frequency_hz')
    system_frequency_hz = cfg.system_frequency_hz;
end
wind_frequency_hz = repmat(system_frequency_hz, numel(wind_buses), 1);
[trip_probability, probability_detail] = compute_wind_trip_probability_paper(voltage_pu, wind_frequency_hz, cfg);
trip_region = strings(numel(wind_buses), 1);
voltage_region = strings(numel(wind_buses), 1);
frequency_region = strings(numel(wind_buses), 1);
wind_trip_probability_model = strings(numel(wind_buses), 1);
wind_trip_calibration_status = strings(numel(wind_buses), 1);
probability_status = strings(numel(wind_buses), 1);
wind_trip_U_pu_source = repmat("stage_power_flow_bus_voltage", numel(wind_buses), 1);
wind_trip_f_hz_source = repmat("cfg.system_frequency_hz_nominal_static_pf", numel(wind_buses), 1);
wind_trip_source_status = strings(numel(wind_buses), 1);
P_U_low = nan(numel(wind_buses), 1);
P_U_high = nan(numel(wind_buses), 1);
P_f_low = nan(numel(wind_buses), 1);
P_f_high = nan(numel(wind_buses), 1);
threshold_hit = false(numel(wind_buses), 1);
for k = 1:numel(wind_buses)
    trip_region(k) = string(probability_detail(k).voltage_trip_region) + "+" + string(probability_detail(k).frequency_trip_region);
    voltage_region(k) = string(probability_detail(k).voltage_trip_region);
    frequency_region(k) = string(probability_detail(k).frequency_trip_region);
    wind_trip_probability_model(k) = "paper_thresholds_record_only";
    wind_trip_calibration_status(k) = "diagnostic_assumption_not_paper";
    probability_status(k) = string(probability_detail(k).source_status);
    wind_trip_source_status(k) = string(probability_detail(k).source_status);
    P_U_low(k) = probability_detail(k).P_U_low;
    P_U_high(k) = probability_detail(k).P_U_high;
    P_f_low(k) = probability_detail(k).P_f_low;
    P_f_high(k) = probability_detail(k).P_f_high;
    threshold_hit(k) = trip_probability(k) > 0;
end
initial_branch_col = repmat(initial_branch, numel(wind_buses), 1);
trial_id_col = repmat(trial_id, numel(wind_buses), 1);
stage_id_col = repmat(stage_id, numel(wind_buses), 1);
record_only = true(numel(wind_buses), 1);

wind_trip_table = table(initial_branch_col, trial_id_col, stage_id_col, wind_index, ...
    wind_buses, wind_gen_rows(:), voltage_pu, wind_frequency_hz, wind_output_mw, wind_capacity(:), ...
    trip_probability(:), trip_probability(:), string(trip_region(:)), record_only, ...
    wind_trip_probability_model, wind_trip_calibration_status, threshold_hit, ...
    voltage_region, frequency_region, probability_status, P_U_low, P_U_high, P_f_low, P_f_high, ...
    wind_trip_U_pu_source, wind_trip_f_hz_source, wind_trip_source_status, ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', 'wind_index', ...
    'wind_bus', 'wind_gen_row', 'voltage_pu', 'frequency_hz', 'wind_output_mw', 'wind_capacity_mw', ...
    'trip_probability', 'p_wt_h', 'trip_region', 'record_only', ...
    'wind_trip_probability_model', 'wind_trip_calibration_status', 'threshold_hit', ...
    'voltage_region', 'frequency_region', 'probability_status', 'P_U_low', 'P_U_high', 'P_f_low', 'P_f_high', ...
    'wind_trip_U_pu_source', 'wind_trip_f_hz_source', 'wind_trip_source_status'});
end

function v = get_info_vector(info, field_name, default_value)
if isfield(info, field_name)
    v = info.(field_name);
else
    v = default_value;
end
v = v(:);
end

function tbl = empty_wind_trip_table()
tbl = table([], [], [], [], [], [], [], [], [], [], [], [], strings(0, 1), false(0, 1), ...
    strings(0, 1), strings(0, 1), false(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
    [], [], [], [], strings(0, 1), strings(0, 1), strings(0, 1), ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', 'wind_index', ...
    'wind_bus', 'wind_gen_row', 'voltage_pu', 'frequency_hz', 'wind_output_mw', 'wind_capacity_mw', ...
    'trip_probability', 'p_wt_h', 'trip_region', 'record_only', ...
    'wind_trip_probability_model', 'wind_trip_calibration_status', 'threshold_hit', ...
    'voltage_region', 'frequency_region', 'probability_status', 'P_U_low', 'P_U_high', 'P_f_low', 'P_f_high', ...
    'wind_trip_U_pu_source', 'wind_trip_f_hz_source', 'wind_trip_source_status'});
end
