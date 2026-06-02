function main_run_severity_vector_trace_smoke()
% Build a tiny severity vector trace pack from existing detailed traces when available.
% No Markov is run if existing line/bus vectors are present.
root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(root, 'results', 'calibration', 'severity_formula', 'severity_vector_trace_smoke');
ensure_dir(out_root);
base_dir = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun', 'high_hidden_failure');
scens = ["wind_speed_11_28","wind_speed_12_00"];
for s = 1:numel(scens)
    src_tables = fullfile(base_dir, scens(s), 'tables');
    out_dir = fullfile(out_root, scens(s));
    ensure_dir(out_dir);
    ensure_dir(fullfile(out_dir, 'tables'));
    if exist(fullfile(src_tables,'markov_line_flow_details.csv'),'file') == 2 && ...
            exist(fullfile(src_tables,'markov_bus_voltage_details.csv'),'file') == 2
        stage = readtable(fullfile(src_tables,'markov_stage_probability_details.csv'), 'TextType','string', 'Delimiter', ',');
        line = readtable(fullfile(src_tables,'markov_line_flow_details.csv'), 'TextType','string', 'Delimiter', ',');
        bus = readtable(fullfile(src_tables,'markov_bus_voltage_details.csv'), 'TextType','string', 'Delimiter', ',');
        keep = stage.initial_branch <= 3 & stage.trial_id <= 2;
        stage = stage(keep,:);
        key = unique(stage(:, {'initial_branch','trial_id','stage_id'}), 'rows');
        line = filter_by_key(line, key);
        bus = filter_by_key(bus, key);
        V = local_vector_trace("high_hidden_failure", scens(s), stage, line, bus);
        writetable(V, fullfile(out_dir, 'severity_vector_trace.csv'));
        copyfile(fullfile(src_tables,'markov_chain_summary.csv'), fullfile(out_dir,'markov_chain_summary.csv'));
        writelines(["severity vector trace smoke"; "reconstructed_from_existing_detailed_trace"; "No Markov run executed."], fullfile(out_dir, 'smoke_log.txt'));
    else
        writelines(["severity vector trace smoke"; "missing_existing_vectors"; "Markov smoke not run automatically in this script."], fullfile(out_dir, 'smoke_log.txt'));
    end
end
end

function T = filter_by_key(T, key)
keep = false(height(T),1);
for i = 1:height(key)
    keep = keep | (T.initial_branch == key.initial_branch(i) & T.trial_id == key.trial_id(i) & T.stage_id == key.stage_id(i));
end
T = T(keep,:);
end

function V = local_vector_trace(parameter_set_id, scenario_id, stage, line, bus)
keys = unique(stage(:, {'initial_branch','trial_id','stage_id'}), 'rows');
rows = cell(height(keys),1);
for i = 1:height(keys)
    st = stage(find(stage.initial_branch==keys.initial_branch(i) & stage.trial_id==keys.trial_id(i) & stage.stage_id==keys.stage_id(i),1),:);
    mline = line.initial_branch==keys.initial_branch(i) & line.trial_id==keys.trial_id(i) & line.stage_id==keys.stage_id(i);
    mbus = bus.initial_branch==keys.initial_branch(i) & bus.trial_id==keys.trial_id(i) & bus.stage_id==keys.stage_id(i);
    lvec = line.P_li_pu(mline); lim = line.P_li_max_pu(mline);
    vvec = bus.voltage_pu(mbus);
    lfor = sum((exp(max(lvec-lim,0))-1)./(exp(1)-1),'omitnan')*100;
    dev = max([0.9-vvec, vvec-1.1, zeros(numel(vvec),1)],[],2);
    nvor = sum((exp(dev)-1)./(exp(1)-1),'omitnan')*100;
    llr = st.stage_load_shed_mw / st.base_load_mw * 100;
    rows{i}=table(string(parameter_set_id),string(scenario_id),keys.initial_branch(i),keys.trial_id(i),keys.stage_id(i), ...
        join(string(lvec(:).'),';'),join(string(lim(:).'),';'),join(string(vvec(:).'),';'), ...
        st.stage_load_shed_mw,st.base_load_mw,llr,lfor,nvor,sum(max(lvec-lim,0)>0),sum(dev>0), ...
        "paper_confirmed_percent_units","reconstructed smoke from existing line/bus detail", ...
        'VariableNames',{'parameter_set_id','scenario_id','initial_branch','trial_id','stage_id','branch_loading_pu_vector','branch_limit_pu_vector','bus_voltage_pu_vector','total_load_shed_mw','base_load_mw','LLR_paper','LFOR_paper','NVOR_paper','overloaded_branch_count','voltage_violation_bus_count','normalization_status','note'});
end
V=vertcat(rows{:});
end

function ensure_dir(p)
if exist(p,'dir')~=7, mkdir(p); end
end
