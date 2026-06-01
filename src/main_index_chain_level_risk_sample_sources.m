function main_index_chain_level_risk_sample_sources()
%MAIN_INDEX_CHAIN_LEVEL_RISK_SAMPLE_SOURCES Audit available chain/stage risk sample sources.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'diagnostics');
ensure_dir(out_dir);

files = [ ...
    list_files(fullfile(project_root, 'results', 'calibration', 'pilot'), 'markov_chain_summary.csv'); ...
    list_files(fullfile(project_root, 'results', 'calibration', 'pilot'), 'markov_var_metrics*.csv'); ...
    string(fullfile(project_root, 'results', 'composite', 'unified_state_probability_diagnostic_smoke', 'stage_severity_details.csv')); ...
    string(fullfile(project_root, 'results', 'composite', 'unified_state_probability_diagnostic_smoke', 'unified_state_probability_stage_details.csv')) ...
    ];
files = unique(files);

source_group = strings(0,1); parameter_set_id = strings(0,1); scenario_id = strings(0,1);
file_path = strings(0,1); has_chain_id = []; has_trial_id = []; has_initial_branch = [];
has_stage_id = []; has_LLR_sample = []; has_LFOR_sample = []; has_NVOR_sample = [];
has_CRI_sample = []; can_construct_chain_sample = []; construction_rule = strings(0,1);
sample_count = []; limitation_note = strings(0,1);

for i = 1:numel(files)
    f = files(i);
    if exist(f, 'file') ~= 2
        continue;
    end
    tbl = read_csv(f);
    vars = string(tbl.Properties.VariableNames);
    [pset, scen, group] = classify_path(f);
    h_chain = any(strcmpi(vars, 'chain_id'));
    h_trial = any(strcmpi(vars, 'trial_id'));
    h_initial = any(strcmpi(vars, 'initial_branch'));
    h_stage = any(strcmpi(vars, 'stage_id'));
    h_llr = has_any(vars, ["SLLR","LLR","severity_LLR","total_load_shed_frac"]);
    h_lfor = has_any(vars, ["SLFOR","LFOR","severity_LFOR","max_line_loading_pu"]);
    h_nvor = has_any(vars, ["SNVOR","NVOR","severity_NVOR","max_voltage_deviation_pu"]);
    h_cri = has_any(vars, ["CRI","severity_CRI"]);
    can = (h_initial && h_trial && (h_stage || h_chain) && h_llr && h_lfor && h_nvor) || ...
        contains(lower(f), "markov_chain_summary");
    if contains(lower(f), "stage_severity_details")
        rule = "group by initial_branch + trial_id; aggregate stage severity using sum/max/final/mean; join P_total for probability-weighted variant";
        note = "stage-level source; chain samples must be reconstructed offline";
    elseif contains(lower(f), "markov_chain_summary")
        rule = "use one row per initial_branch + trial_id as existing chain-level summary sample";
        note = "existing chain-level summary, but may use engineering severity definitions";
    elseif contains(lower(f), "markov_var_metrics")
        rule = "already aggregated VaR metrics; not a raw chain-level sample source";
        can = false;
        note = "VaR table cannot reconstruct distribution by itself";
    else
        rule = "unknown_from_source_inspection";
        note = "not enough recognized fields for preferred reconstruction";
    end
    source_group(end+1,1)=group; parameter_set_id(end+1,1)=pset; scenario_id(end+1,1)=scen; %#ok<AGROW>
    file_path(end+1,1)=f; has_chain_id(end+1,1)=h_chain; has_trial_id(end+1,1)=h_trial; %#ok<AGROW>
    has_initial_branch(end+1,1)=h_initial; has_stage_id(end+1,1)=h_stage; %#ok<AGROW>
    has_LLR_sample(end+1,1)=h_llr; has_LFOR_sample(end+1,1)=h_lfor; has_NVOR_sample(end+1,1)=h_nvor; has_CRI_sample(end+1,1)=h_cri; %#ok<AGROW>
    can_construct_chain_sample(end+1,1)=can; construction_rule(end+1,1)=rule; sample_count(end+1,1)=height(tbl); limitation_note(end+1,1)=note; %#ok<AGROW>
end

out = table(source_group, parameter_set_id, scenario_id, file_path, has_chain_id, has_trial_id, ...
    has_initial_branch, has_stage_id, has_LLR_sample, has_LFOR_sample, has_NVOR_sample, ...
    has_CRI_sample, can_construct_chain_sample, construction_rule, sample_count, limitation_note);
writetable(out, fullfile(out_dir, 'chain_level_risk_sample_source_audit.csv'));
fprintf('chain-level risk sample source audit written: %d rows\n', height(out));
end

function files = list_files(root_dir, pattern)
if exist(root_dir, 'dir') ~= 7
    files = strings(0,1); return;
end
d = dir(fullfile(root_dir, '**', pattern));
files = strings(numel(d),1);
for k = 1:numel(d)
    files(k) = string(fullfile(d(k).folder, d(k).name));
end
end

function [pset, scen, group] = classify_path(path_value)
parts = split(string(path_value), filesep);
pset = ""; scen = ""; group = "other";
idx = find(parts == "pilot", 1);
if ~isempty(idx) && numel(parts) >= idx + 2
    pset = parts(idx + 1); scen = parts(idx + 2); group = "calibration_pilot";
elseif contains(path_value, "unified_state_probability_diagnostic_smoke")
    group = "unified_state_probability_diagnostic_smoke"; pset = "unified_diagnostic"; scen = "distributed_wind_3000mw_base_smoke";
end
end

function tf = has_any(vars, names)
tf = any(ismember(lower(vars), lower(names)));
end

function tbl = read_csv(path_value)
opts = detectImportOptions(path_value, 'Delimiter', ',', 'TextType', 'string');
opts.VariableNamingRule = 'preserve';
tbl = readtable(path_value, opts);
end

function ensure_dir(path_value)
if exist(path_value, 'dir') ~= 7; mkdir(path_value); end
end
