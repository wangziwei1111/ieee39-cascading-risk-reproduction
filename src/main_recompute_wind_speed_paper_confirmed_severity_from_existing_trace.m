function main_recompute_wind_speed_paper_confirmed_severity_from_existing_trace()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'severity_formula');
ensure_dir(out_dir);
base_dir = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun');
psets = ["high_hidden_failure","benchmark_calibrated_seed"];
scens = ["wind_speed_11_28","wind_speed_12_00"];
rows = {};
for p = 1:numel(psets)
    for s = 1:numel(scens)
        scen_dir = fullfile(base_dir, psets(p), scens(s), 'tables');
        if exist(fullfile(scen_dir,'severity_component_trace.csv'),'file') ~= 2
            continue;
        end
        legacy = readtable(fullfile(scen_dir,'severity_component_trace.csv'), 'TextType','string', 'Delimiter', ',');
        stage = readtable(fullfile(scen_dir,'markov_stage_probability_details.csv'), 'TextType','string', 'Delimiter', ',');
        line = readtable(fullfile(scen_dir,'markov_line_flow_details.csv'), 'TextType','string', 'Delimiter', ',');
        bus = readtable(fullfile(scen_dir,'markov_bus_voltage_details.csv'), 'TextType','string', 'Delimiter', ',');
        V = build_vector_trace(psets(p), scens(s), stage, line, bus);
        for i = 1:height(V)
            m = legacy.initial_branch == V.initial_branch(i) & legacy.trial_id == V.trial_id(i) & legacy.stage_id == V.stage_id(i);
            if any(m)
                idx = find(m,1);
                LLR_legacy = legacy.basic_LLR(idx);
                LFOR_legacy = legacy.basic_LFOR(idx);
                NVOR_legacy = legacy.basic_NVOR(idx);
                CRI_legacy = legacy.basic_CRI(idx);
            else
                LLR_legacy = NaN; LFOR_legacy = NaN; NVOR_legacy = NaN; CRI_legacy = NaN;
            end
            rows{end+1,1} = table(psets(p), scens(s), V.initial_branch(i), V.trial_id(i), V.stage_id(i), ...
                LLR_legacy, V.LLR_paper(i), LFOR_legacy, V.LFOR_paper(i), NVOR_legacy, V.NVOR_paper(i), ...
                CRI_legacy, V.CRI_stage_reference_paper(i), V.normalization_status(i), V.proxy_status(i), ...
                V.missing_fields(i), V.note(i), ...
                'VariableNames', {'parameter_set_id','scenario_id','initial_branch','trial_id','stage_id', ...
                'LLR_legacy','LLR_paper_recomputed','LFOR_legacy','LFOR_paper_recomputed', ...
                'NVOR_legacy','NVOR_paper_recomputed','CRI_stage_reference_legacy','CRI_stage_reference_paper', ...
                'normalization_status','proxy_status','missing_fields','note'});
        end
    end
end
writetable(vertcat_or_empty(rows), fullfile(out_dir, 'wind_speed_paper_confirmed_severity_recompute_from_existing_trace.csv'));
end

function V = build_vector_trace(parameter_set_id, scenario_id, stage, line, bus)
keys = unique(stage(:, {'initial_branch','trial_id','stage_id'}), 'rows');
rows = cell(height(keys),1);
for i = 1:height(keys)
    mstage = stage.initial_branch == keys.initial_branch(i) & stage.trial_id == keys.trial_id(i) & stage.stage_id == keys.stage_id(i);
    mline = line.initial_branch == keys.initial_branch(i) & line.trial_id == keys.trial_id(i) & line.stage_id == keys.stage_id(i);
    mbus = bus.initial_branch == keys.initial_branch(i) & bus.trial_id == keys.trial_id(i) & bus.stage_id == keys.stage_id(i);
    st = stage(find(mstage,1),:);
    if any(mline)
        lvec = line.P_li_pu(mline);
        lim = line.P_li_max_pu(mline);
        lfor = sum((exp(max(lvec - lim, 0)) - 1) ./ (exp(1)-1), 'omitnan') * 100;
        overloaded = sum(max(lvec-lim,0) > 0);
        line_vec_str = join(string(lvec(:).'), ';');
        line_lim_str = join(string(lim(:).'), ';');
    else
        lfor = NaN; overloaded = NaN; line_vec_str = ""; line_lim_str = "";
    end
    if any(mbus)
        vvec = bus.voltage_pu(mbus);
        dev = max([0.9-vvec, vvec-1.1, zeros(numel(vvec),1)], [], 2);
        nvor = sum((exp(dev)-1)./(exp(1)-1), 'omitnan') * 100;
        violated = sum(dev > 0);
        bus_vec_str = join(string(vvec(:).'), ';');
    else
        nvor = NaN; violated = NaN; bus_vec_str = "";
    end
    llr = st.stage_load_shed_mw / st.base_load_mw * 100;
    cri = 0.6*llr + 0.2*lfor + 0.2*nvor;
    proxy = "exact_from_existing_markov_line_flow_and_bus_voltage_details";
    missing = "";
    if ~any(mline) || ~any(mbus)
        proxy = "insufficient_vector_fields_for_exact_paper_formula";
        missing = "line_or_bus_vector_missing_for_invalid_stage";
    end
    rows{i} = table(string(parameter_set_id), string(scenario_id), keys.initial_branch(i), keys.trial_id(i), keys.stage_id(i), ...
        line_vec_str, line_lim_str, bus_vec_str, st.stage_load_shed_mw, st.base_load_mw, ...
        llr, lfor, nvor, cri, overloaded, violated, ...
        "paper_confirmed_percent_units", proxy, missing, ...
        "Offline recompute from existing wind-speed component diagnostic trace; no Markov rerun.", ...
        'VariableNames', {'parameter_set_id','scenario_id','initial_branch','trial_id','stage_id', ...
        'branch_loading_pu_vector','branch_limit_pu_vector','bus_voltage_pu_vector', ...
        'total_load_shed_mw','base_load_mw','LLR_paper','LFOR_paper','NVOR_paper', ...
        'CRI_stage_reference_paper','overloaded_branch_count','voltage_violation_bus_count', ...
        'normalization_status','proxy_status','missing_fields','note'});
end
V = vertcat(rows{:});
end

function T = vertcat_or_empty(rows)
if isempty(rows)
    T = table();
else
    T = vertcat(rows{:});
end
end

function ensure_dir(p)
if exist(p,'dir')~=7, mkdir(p); end
end
