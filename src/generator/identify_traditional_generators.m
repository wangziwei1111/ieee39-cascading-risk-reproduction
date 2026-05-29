function gen_table = identify_traditional_generators(mpc, scenario, cfg)
%IDENTIFY_TRADITIONAL_GENERATORS Identify conventional generator rows without tripping them.
if nargin < 1 || isempty(mpc) || ~isfield(mpc, 'gen') || isempty(mpc.gen)
    gen_table = empty_table();
    return;
end

gen_count = size(mpc.gen, 1);
gen_index = (1:gen_count)';
gen_bus = mpc.gen(:, 1);
is_online = mpc.gen(:, 8) > 0;
is_renewable = false(gen_count, 1);
role_status = repmat("case39_original_generator_assumed_traditional", gen_count, 1);
note = repmat("Original case39 generator row is treated as traditional unless an explicit renewable marker is present.", gen_count, 1);

wind_rows = [];
if isfield(mpc, 'userdata') && isfield(mpc.userdata, 'wind_gen_rows')
    wind_rows = mpc.userdata.wind_gen_rows(:);
elseif nargin >= 2 && isstruct(scenario) && isfield(scenario, 'wind_gen_rows')
    wind_rows = scenario.wind_gen_rows(:);
end
wind_rows = wind_rows(~isnan(wind_rows) & wind_rows >= 1 & wind_rows <= gen_count);
if ~isempty(wind_rows)
    is_renewable(wind_rows) = true;
    role_status(wind_rows) = "renewable_marker_from_scenario_userdata";
    note(wind_rows) = "Added wind equivalent generator is excluded from P_ge traditional generator diagnostics.";
end

if isfield(mpc, 'genfuel') && numel(mpc.genfuel) == gen_count
    fuel = string(mpc.genfuel(:));
    renewable_fuels = ["wind", "solar", "renewable"];
    is_renewable = is_renewable | ismember(lower(fuel), renewable_fuels);
    role_status(ismember(lower(fuel), renewable_fuels)) = "renewable_marker_from_genfuel";
end

is_traditional = is_online & ~is_renewable;
gen_table = table(gen_index, gen_bus, is_online, is_traditional, is_renewable, role_status, note, ...
    'VariableNames', {'gen_index', 'gen_bus', 'is_online', 'is_traditional', ...
    'is_renewable', 'role_status', 'note'});
end

function tbl = empty_table()
tbl = table([], [], false(0, 1), false(0, 1), false(0, 1), strings(0, 1), strings(0, 1), ...
    'VariableNames', {'gen_index', 'gen_bus', 'is_online', 'is_traditional', ...
    'is_renewable', 'role_status', 'note'});
end
