function main_diagnose_wind_speed_after_severity_fix_tail_samples()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root,'results','calibration','severity_formula');
after_root = fullfile(out_dir,'wind_speed_after_severity_fix_diagnostic_rerun');
source_root = fullfile(root,'results','calibration','wind_speed_component_diagnostic_rerun');
psets = ["high_hidden_failure","benchmark_calibrated_seed"];
scens = ["wind_speed_11_28","wind_speed_12_00"];
metrics = ["SLLR","SLFOR","SNVOR","CRI"];
rows = {};
for p=1:numel(psets)
    for s=1:numel(scens)
        sev_file = fullfile(after_root,psets(p),scens(s),'tables','severity_vector_trace.csv');
        stage_file = fullfile(source_root,psets(p),scens(s),'tables','markov_stage_probability_details.csv');
        chain_file = fullfile(after_root,psets(p),scens(s),'tables','markov_chain_summary.csv');
        if exist(sev_file,'file')~=2 || exist(stage_file,'file')~=2 || exist(chain_file,'file')~=2
            continue;
        end
        Sev = readtable(sev_file,'TextType','string','Delimiter',',');
        Stage = readtable(stage_file,'TextType','string','Delimiter',',');
        Chain = readtable(chain_file,'TextType','string','Delimiter',',');
        Risk = build_chain_risk(Sev, Stage, Chain);
        for m=1:numel(metrics)
            values = Risk.(char(metrics(m)));
            var_value = empirical_var(values, 0.95);
            [~, order] = sort(values, 'descend', 'MissingPlacement','last');
            ranks = NaN(height(Risk),1);
            ranks(order) = (1:height(Risk)).';
            tail = values >= var_value & ~isnan(values);
            for i=1:height(Risk)
                rows{end+1,1}=table(psets(p),scens(s),metrics(m),0.95,var_value, ...
                    Risk.initial_branch(i),Risk.trial_id(i),Risk.chain_depth(i),string(Risk.terminated_reason(i)), ...
                    ranks(i),tail(i),values(i),Risk.SLLR(i),Risk.SLFOR(i),Risk.SNVOR(i),Risk.CRI(i), ...
                    Risk.initial_line_probability(i),Risk.chain_transition_probability(i), ...
                    Risk.initial_line_probability(i)*Risk.chain_transition_probability(i)/1e-4, ...
                    Risk.max_line_loading_pu(i),Risk.max_voltage_deviation_pu(i),Risk.total_load_shed_frac(i), ...
                    "paper_confirmed_exponential_sum","Tail flag uses sigma=0.95 quantile over chain-level paper-confirmed risk display.", ...
                    'VariableNames',{'parameter_set_id','scenario_id','metric_name','sigma','var_value', ...
                    'initial_branch','trial_id','chain_depth','terminated_reason','tail_rank','tail_flag', ...
                    'R_metric_display','R_LLR_display','R_LFOR_display','R_NVOR_display','R_CRI_display', ...
                    'initial_line_probability','chain_transition_probability','total_chain_probability_display', ...
                    'max_line_loading_pu','max_voltage_deviation_pu','total_load_shed_frac','paper_severity_formula_mode','note'}); %#ok<AGROW>
            end
        end
    end
end
writetable(vertcat(rows{:}), fullfile(out_dir,'wind_speed_after_severity_fix_tail_samples.csv'));
end

function Risk = build_chain_risk(Sev, Stage, Chain)
keys = unique(Sev(:, {'initial_branch','trial_id'}), 'rows');
rows = cell(height(keys),1);
for i=1:height(keys)
    m = Sev.initial_branch==keys.initial_branch(i) & Sev.trial_id==keys.trial_id(i);
    vals = zeros(1,4);
    for j=find(m).'
        pm = Stage.initial_branch==Sev.initial_branch(j) & Stage.trial_id==Sev.trial_id(j) & Stage.stage_id==Sev.stage_id(j);
        if any(pm), p = Stage.stage_cumulative_probability(find(pm,1)); else, p = NaN; end
        vals = vals + p .* [Sev.LLR_paper(j), Sev.LFOR_paper(j), Sev.NVOR_paper(j), Sev.CRI_stage_reference_paper(j)];
    end
    cm = Chain.initial_branch==keys.initial_branch(i) & Chain.trial_id==keys.trial_id(i);
    ch = Chain(find(cm,1),:);
    rows{i}=table(keys.initial_branch(i),keys.trial_id(i),vals(1)/1e-4,vals(2)/1e-4,vals(3)/1e-4,(0.6*vals(1)+0.2*vals(2)+0.2*vals(3))/1e-4, ...
        pick(ch,'chain_depth'), string(pick(ch,'terminated_reason')), pick(ch,'initial_outage_probability'), pick(ch,'chain_transition_probability'), ...
        pick(ch,'max_line_loading_pu'), pick(ch,'max_voltage_deviation_pu'), pick(ch,'total_load_shed_frac'), ...
        'VariableNames',{'initial_branch','trial_id','SLLR','SLFOR','SNVOR','CRI','chain_depth','terminated_reason','initial_line_probability','chain_transition_probability','max_line_loading_pu','max_voltage_deviation_pu','total_load_shed_frac'});
end
Risk = vertcat(rows{:});
end

function v = pick(T,name)
if isempty(T) || ~ismember(name,T.Properties.VariableNames), v=NaN; else, v=T.(name)(1); end
end

function v = empirical_var(x,sigma)
x=sort(x(~isnan(x)));
if isempty(x), v=NaN; else, v=x(max(1,min(numel(x),ceil(sigma*numel(x))))); end
end
