function cfg_out = load_paper_line_probability_parameter_set(cfg_in, parameter_set_id)
%LOAD_PAPER_LINE_PROBABILITY_PARAMETER_SET Load diagnostic P_L parameter set.
project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
param_path = fullfile(project_root, 'paper_inputs', 'filled', 'paper_line_probability_parameter_sets.csv');
if ~exist(param_path, 'file')
    error('Missing parameter set file: %s', param_path);
end

tbl = readtable(param_path, 'TextType', 'string');
idx = find(tbl.parameter_set_id == string(parameter_set_id), 1);
if isempty(idx)
    error('Unknown paper line probability parameter_set_id: %s', string(parameter_set_id));
end
row = tbl(idx, :);

cfg_out = cfg_in;
cfg_out.paper_line_parameter_set_id = char(row.parameter_set_id);
cfg_out.paper_line_parameter_set_type = char(row.parameter_set_type);
cfg_out.paper_line_parameter_calibration_status = char(row.calibration_status);
cfg_out.paper_line_P_L0_source = char(row.P_L0_source);
cfg_out.paper_line_L_rated_factor = row.L_rated_factor;
cfg_out.paper_line_L_max_factor = row.L_max_factor;
cfg_out.paper_line_P_overload_max = get_cfg(cfg_out, 'paper_line_P_overload_max', 1.0);
cfg_out.paper_line_P_W_D = table_value(row.P_W_D);
cfg_out.paper_line_ZIII_factor = table_value(row.ZIII_factor);
cfg_out.paper_line_P_L_D = table_value(row.P_L_D);
cfg_out.paper_line_P_L_r = table_value(row.P_L_r);
cfg_out.paper_line_P3 = table_value(row.P3);
cfg_out.paper_line_hidden_distance_enable = parse_bool(row.hidden_distance_enable);
cfg_out.paper_line_hidden_loading_enable = parse_bool(row.hidden_loading_enable);
cfg_out.paper_line_source_note = char(row.source_note);

if string(row.P_L0_source) == "table4_1_initial_probability"
    cfg_out.paper_line_P_L0 = NaN;
    cfg_out.paper_line_P_L0_by_branch = load_table41_probabilities(cfg_out, project_root);
else
    cfg_out.paper_line_P_L0 = table_value(row.P_L0_value);
    cfg_out.paper_line_P_L0_by_branch = [];
end
end

function value = table_value(x)
if iscell(x), x = x{1}; end
if isstring(x) || ischar(x)
    if strlength(string(x)) == 0 || ismissing(string(x))
        value = NaN;
    else
        value = str2double(string(x));
    end
else
    value = x;
end
if isempty(value), value = NaN; end
end

function probs = load_table41_probabilities(cfg, project_root)
path = fullfile(project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');
tbl = readtable(path);
if ~ismember('initial_outage_probability', tbl.Properties.VariableNames)
    error('Table 4-1 file lacks initial_outage_probability: %s', path);
end
probs = NaN(max(tbl.branch_index), 1);
probs(tbl.branch_index) = tbl.initial_outage_probability;
end

function value = parse_bool(x)
if iscell(x), x = x{1}; end
if islogical(x)
    value = x;
elseif isnumeric(x)
    value = x ~= 0;
else
    sx = lower(string(x));
    value = sx == "true" || sx == "1" || sx == "yes";
end
end

function value = get_cfg(cfg, name, default_value)
if isfield(cfg, name)
    value = cfg.(name);
else
    value = default_value;
end
end
