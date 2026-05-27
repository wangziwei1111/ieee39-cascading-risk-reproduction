function [mpc, info] = apply_renewable_scenario(mpc, scenario)
%APPLY_RENEWABLE_SCENARIO 将新能源场景应用到IEEE39系统。
% 输入：
%   mpc - MATPOWER算例结构体。
%   scenario - 新能源场景配置，包含接入节点、容量、风速和调度模式。
% 输出：
%   mpc - 修改后的算例结构体。
%   info - 新能源接入信息，包括风电节点、容量、出力和再调度结果。
% 物理含义：
%   mode='none'保持原始case39；replace_pg_current用于早期流程测试，物理意义较弱；
%   wind_plus_redispatch新增风电注入并下调常规机组，使基础运行点接近功率平衡。

if ~isfield(scenario, 'renewable_dispatch_mode')
    scenario.renewable_dispatch_mode = 'wind_plus_redispatch';
end

mode = lower(string(scenario.renewable_dispatch_mode));
wind_buses = get_field_or_default(scenario, 'wind_buses', []);
wind_buses = wind_buses(:);

info = struct();
info.mode = char(mode);
info.wind_buses = wind_buses;
info.wind_capacity_mw = zeros(numel(wind_buses), 1);
info.wind_output_mw = zeros(numel(wind_buses), 1);
info.total_wind_output_mw = 0;
info.redispatch_reduction_mw = 0;
info.redispatch_shortfall_mw = 0;
info.slack_limit_adjustment_mw = 0;
info.wind_gen_rows = [];
info.limit_check = table();

if mode == "none"
    % 无新能源场景：不新增风电、不修改原机组PG，作为第4章对照基准。
    info.limit_check = check_generator_pg_limits(mpc);
    mpc.userdata.wind_gen_rows = [];
    mpc.userdata.wind_buses = [];
    mpc.userdata.renewable_dispatch_mode = 'none';
    return;
end

wind_capacity = resolve_wind_capacity(scenario, wind_buses);
wind_p = zeros(numel(wind_buses), 1);

for k = 1:numel(wind_buses)
    wind_p(k) = wind_power_curve(get_field_or_default(scenario, 'wind_speed_mps', 12), wind_capacity(k), ...
        get_field_or_default(scenario, 'cut_in_speed_mps', 3), ...
        get_field_or_default(scenario, 'rated_speed_mps', 12), ...
        get_field_or_default(scenario, 'cut_out_speed_mps', 25));
end

info.wind_capacity_mw = wind_capacity;
info.wind_output_mw = wind_p;
info.total_wind_output_mw = sum(wind_p);

switch mode
    case "replace_pg_current"
        % 该模式沿用第一版做法：把指定节点已有机组PG直接替换为风电PG。
        % 物理意义较弱，因为它没有同步重分配其他常规机组出力，仅用于流程对照。
        wind_gen_rows = zeros(numel(wind_buses), 1);
        for k = 1:numel(wind_buses)
            gen_row = find(mpc.gen(:, 1) == wind_buses(k), 1);
            if ~isempty(gen_row)
                mpc.gen(gen_row, 2) = wind_p(k);
                mpc.gen(gen_row, 9) = wind_capacity(k);
                mpc.gen(gen_row, 10) = 0;
                wind_gen_rows(k) = gen_row;
            end
        end
        info.wind_gen_rows = wind_gen_rows(wind_gen_rows > 0);

    case "wind_plus_redispatch"
        % 新增风电机组，并在非平衡常规机组中按可下调裕度比例降低PG。
        % 保留slack_bus对应常规机组用于潮流平衡微调。
        original_total_pg = sum(mpc.gen(:, 2));
        [mpc, wind_gen_rows] = append_wind_generators(mpc, wind_buses, wind_p, wind_capacity);

        slack_bus = get_field_or_default(scenario, 'slack_bus', 31);
        conventional_rows = setdiff((1:size(mpc.gen, 1))', wind_gen_rows);
        redispatch_rows = conventional_rows(mpc.gen(conventional_rows, 1) ~= slack_bus);
        reducible = max(mpc.gen(redispatch_rows, 2) - mpc.gen(redispatch_rows, 10), 0);
        total_reducible = sum(reducible);
        target_reduction = min(sum(wind_p), total_reducible);

        if target_reduction > 0 && total_reducible > 0
            reduction = target_reduction * reducible / total_reducible;
            mpc.gen(redispatch_rows, 2) = mpc.gen(redispatch_rows, 2) - reduction;
            info.redispatch_reduction_mw = sum(reduction);
        end

        [mpc, slack_adjustment] = relieve_slack_pg_limit(mpc, wind_gen_rows, redispatch_rows, slack_bus);
        info.slack_limit_adjustment_mw = slack_adjustment;
        info.redispatch_reduction_mw = info.redispatch_reduction_mw - slack_adjustment;
        info.redispatch_shortfall_mw = sum(wind_p) - info.redispatch_reduction_mw;
        info.original_total_pg_mw = original_total_pg;
        info.final_total_pg_setpoint_mw = sum(mpc.gen(:, 2));
        info.wind_gen_rows = wind_gen_rows;

    otherwise
        error('未知新能源调度模式：%s', scenario.renewable_dispatch_mode);
end

info.limit_check = check_generator_pg_limits(mpc);
mpc.userdata.wind_gen_rows = info.wind_gen_rows;
mpc.userdata.wind_buses = wind_buses;
mpc.userdata.renewable_dispatch_mode = char(mode);
end

function wind_capacity = resolve_wind_capacity(scenario, wind_buses)
%RESOLVE_WIND_CAPACITY 解析风电容量配置。
% 输入：
%   scenario - 场景结构体，可含total_wind_capacity_mw或wind_capacity_mw。
%   wind_buses - 风电接入节点。
% 输出：
%   wind_capacity - 与wind_buses等长的容量向量，MW。
% 物理含义：
%   支持总容量等分、标量容量复制、向量容量逐节点指定三种写法，便于场景扫描扩展。
if isempty(wind_buses)
    total_capacity = get_field_or_default(scenario, 'total_wind_capacity_mw', 0);
    explicit_capacity = get_field_or_default(scenario, 'wind_capacity_mw', []);
    if total_capacity > 0 || (~isempty(explicit_capacity) && any(explicit_capacity > 0))
        error('风电容量大于0时必须指定wind_buses。');
    end
    wind_capacity = zeros(0, 1);
    return;
end

if isfield(scenario, 'wind_capacity_mw') && ~isempty(scenario.wind_capacity_mw)
    raw_capacity = scenario.wind_capacity_mw;
    if isscalar(raw_capacity)
        wind_capacity = raw_capacity * ones(numel(wind_buses), 1);
    else
        wind_capacity = raw_capacity(:);
        if numel(wind_capacity) ~= numel(wind_buses)
            error('wind_capacity_mw向量长度必须等于wind_buses数量。');
        end
    end
elseif isfield(scenario, 'total_wind_capacity_mw')
    wind_capacity = (scenario.total_wind_capacity_mw / numel(wind_buses)) * ones(numel(wind_buses), 1);
else
    error('新能源场景必须设置wind_capacity_mw或total_wind_capacity_mw。');
end
end

function value = get_field_or_default(s, field_name, default_value)
%GET_FIELD_OR_DEFAULT 读取结构体字段，缺失时返回默认值。
if isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end

function [mpc, wind_gen_rows] = append_wind_generators(mpc, wind_buses, wind_p, wind_capacity)
%APPEND_WIND_GENERATORS 在指定节点追加风电机组。
% 输入：
%   mpc - MATPOWER算例。
%   wind_buses - 风电接入节点。
%   wind_p - 风电有功出力，MW。
%   wind_capacity - 风电容量，MW。
% 输出：
%   mpc - 追加风电机组后的算例。
%   wind_gen_rows - 新增风电机组在mpc.gen中的行号。
% 物理含义：
%   风电作为额外有功注入进入系统，原常规机组仍保留，便于再调度。
gen_template = mpc.gen(1, :);
new_gens = zeros(numel(wind_buses), size(mpc.gen, 2));

for k = 1:numel(wind_buses)
    bus_id = wind_buses(k);
    local_gen = find(mpc.gen(:, 1) == bus_id, 1);
    if ~isempty(local_gen)
        gen_template = mpc.gen(local_gen, :);
    end

    new_gens(k, :) = gen_template;
    new_gens(k, 1) = bus_id;
    new_gens(k, 2) = wind_p(k);
    new_gens(k, 3) = 0;
    new_gens(k, 6) = 1.0;
    new_gens(k, 8) = 1;
    new_gens(k, 9) = wind_capacity(k);
    new_gens(k, 10) = 0;
end

mpc.gen = [mpc.gen; new_gens];
wind_gen_rows = ((size(mpc.gen, 1) - numel(wind_buses) + 1):size(mpc.gen, 1))';

if isfield(mpc, 'gencost') && size(mpc.gencost, 1) >= 1
    mpc.gencost = [mpc.gencost; repmat(mpc.gencost(1, :), numel(wind_buses), 1)];
end
end

function limit_check = check_generator_pg_limits(mpc)
%CHECK_GENERATOR_PG_LIMITS 检查机组有功出力是否越过上下限。
% 输入：
%   mpc - MATPOWER算例。
% 输出：
%   limit_check - 每台机组PG/PMIN/PMAX及越限标志。
% 物理含义：
%   确认新能源注入和常规机组再调度后，机组设定值仍处于允许范围。
gen_index = (1:size(mpc.gen, 1))';
bus = mpc.gen(:, 1);
pg = mpc.gen(:, 2);
pmax = mpc.gen(:, 9);
pmin = mpc.gen(:, 10);
below_pmin = pg < pmin - 1e-6;
above_pmax = pg > pmax + 1e-6;

limit_check = table(gen_index, bus, pg, pmin, pmax, below_pmin, above_pmax);
end

function [mpc, total_adjustment] = relieve_slack_pg_limit(mpc, wind_gen_rows, redispatch_rows, slack_bus)
%RELIEVE_SLACK_PG_LIMIT 给平衡机有功出力留出运行裕度。
% 输入：
%   mpc - 新增风电并初步再调度后的算例。
%   wind_gen_rows - 风电机组行号。
%   redispatch_rows - 可参与再调度的非平衡常规机组行号。
%   slack_bus - 平衡机节点编号。
% 输出：
%   mpc - 修正后的算例。
%   total_adjustment - 返回给非平衡常规机组的总有功，MW。
% 物理含义：
%   潮流求解后平衡机承担系统损耗和剩余不平衡。若平衡机PG超过PMAX，则适当提高
%   非平衡常规机组PG，减少平衡机承担的功率。
total_adjustment = 0;
max_iter = 5;

for iter = 1:max_iter
    [pf_result, converged] = run_ac_powerflow(mpc);
    if ~converged
        return;
    end

    conventional_slack_rows = find(pf_result.gen(:, 1) == slack_bus);
    conventional_slack_rows = setdiff(conventional_slack_rows, wind_gen_rows);
    if isempty(conventional_slack_rows)
        return;
    end

    slack_excess = max(pf_result.gen(conventional_slack_rows, 2) - ...
        pf_result.gen(conventional_slack_rows, 9), 0);
    needed = sum(slack_excess);
    if needed <= 1e-6
        return;
    end

    upward_room = max(mpc.gen(redispatch_rows, 9) - mpc.gen(redispatch_rows, 2), 0);
    total_room = sum(upward_room);
    if total_room <= 1e-6
        return;
    end

    adjustment = min(needed * 1.02, total_room);
    delta = adjustment * upward_room / total_room;
    mpc.gen(redispatch_rows, 2) = mpc.gen(redispatch_rows, 2) + delta;
    total_adjustment = total_adjustment + sum(delta);
end
end
