function main_analyze_wind_speed_after_severity_formula_fix()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'severity_formula');
rerun_root = fullfile(out_dir, 'wind_speed_after_severity_fix_diagnostic_rerun');
psets = ["high_hidden_failure","benchmark_calibrated_seed"];
scens = ["wind_speed_11_28","wind_speed_12_00"];
sigmas = [0.90, 0.95, 0.98];
metric_rows = {};
chain_rows = {};
for p = 1:numel(psets)
    for s = 1:numel(scens)
        scen_dir = fullfile(rerun_root, psets(p), scens(s), 'tables');
        src_dir = fullfile(root, '..', 'wind_speed_component_diagnostic_rerun', psets(p), scens(s), 'tables');
        src_dir = fullfile(fileparts(out_dir), 'wind_speed_component_diagnostic_rerun', psets(p), scens(s), 'tables');
        sev_file = fullfile(scen_dir, 'severity_vector_trace.csv');
        prob_file = fullfile(src_dir, 'markov_stage_probability_details.csv');
        if exist(sev_file,'file') ~= 2 || exist(prob_file,'file') ~= 2
            continue;
        end
        Sev = readtable(sev_file, 'TextType','string', 'Delimiter', ',');
        Prob = readtable(prob_file, 'TextType','string', 'Delimiter', ',');
        C = chain_risk(Sev, Prob);
        C.parameter_set_id = repmat(psets(p), height(C), 1);
        C.scenario_id = repmat(scens(s), height(C), 1);
        chain_rows{end+1,1} = C; %#ok<AGROW>
        for m = ["SLLR","SLFOR","SNVOR","CRI"]
            vals = C.(char(m));
            for q = 1:numel(sigmas)
                var_value = empirical_var(vals, sigmas(q)) / 1e-4;
                metric_rows{end+1,1}=table(psets(p), scens(s), sigmas(q), m, var_value, numel(vals), sum(~isnan(vals)), ...
                    "paper_confirmed_exponential_sum", "stage_probability_weighted_chain_risk", "actual_divided_by_1e_minus_4_display", ...
                    "Severity-only diagnostic; not final benchmark.", ...
                    'VariableNames', {'parameter_set_id','scenario_id','sigma','metric_name','var_value','sample_count','valid_sample_count','severity_formula_mode','risk_aggregation_level','proxy_status','note'}); %#ok<AGROW>
            end
        end
    end
end
Metrics = vertcat(metric_rows{:});
writetable(Metrics, fullfile(out_dir, 'wind_speed_after_severity_fix_var_metrics.csv'));
write_before_after(out_dir, Metrics);
end

function C = chain_risk(Sev, Prob)
keys = unique(Sev(:, {'initial_branch','trial_id'}), 'rows');
rows = cell(height(keys),1);
for i = 1:height(keys)
    m = Sev.initial_branch==keys.initial_branch(i) & Sev.trial_id==keys.trial_id(i);
    risk = zeros(1,4);
    for j = find(m).'
        pm = Prob.initial_branch==Sev.initial_branch(j) & Prob.trial_id==Sev.trial_id(j) & Prob.stage_id==Sev.stage_id(j);
        if any(pm)
            p = Prob.stage_cumulative_probability(find(pm,1));
        else
            p = NaN;
        end
        risk = risk + p .* [Sev.LLR_paper(j), Sev.LFOR_paper(j), Sev.NVOR_paper(j), Sev.CRI_stage_reference_paper(j)];
    end
    rows{i}=table(keys.initial_branch(i), keys.trial_id(i), risk(1), risk(2), risk(3), 0.6*risk(1)+0.2*risk(2)+0.2*risk(3), ...
        'VariableNames', {'initial_branch','trial_id','SLLR','SLFOR','SNVOR','CRI'});
end
C = vertcat(rows{:});
end

function v = empirical_var(x, sigma)
x = sort(x(~isnan(x)));
if isempty(x), v = NaN; return; end
idx = max(1, min(numel(x), ceil(sigma*numel(x))));
v = x(idx);
end

function write_before_after(out_dir, After)
before_file = fullfile(out_dir, 'wind_speed_var_sensitivity_to_severity_formula.csv');
if exist(before_file,'file') == 2
    Before = readtable(before_file, 'TextType','string', 'Delimiter', ',');
else
    Before = table();
end
psets = unique(After.parameter_set_id,'stable');
metrics = unique(After.metric_name,'stable');
sigmas = unique(After.sigma,'stable');
rows = {};
for p=1:numel(psets)
    for m=1:numel(metrics)
        for q=1:numel(sigmas)
            a11 = get_after(After,psets(p),"wind_speed_11_28",metrics(m),sigmas(q));
            a12 = get_after(After,psets(p),"wind_speed_12_00",metrics(m),sigmas(q));
            after_dir = direction(a11,a12);
            [b11,b12,bdir] = get_before(Before,psets(p),metrics(m),sigmas(q));
            paper_dir = "12mps_expected_lower_or_not_higher";
            before_match = bdir ~= "" && bdir ~= "12mps_higher_than_11p28";
            after_match = after_dir ~= "12mps_higher_than_11p28";
            interp = "severity_fix_no_effect";
            if after_match && ~before_match
                interp = "severity_fix_corrected_wind_speed_direction";
            elseif ~after_match && ~before_match && abs(a12-a11) < abs(b12-b11)
                interp = "severity_fix_reduced_but_not_corrected";
            elseif ~after_match && before_match
                interp = "severity_fix_worsened";
            end
            rows{end+1,1}=table(psets(p),metrics(m),sigmas(q),b11,b12,bdir,a11,a12,after_dir, ...
                bdir~=after_dir,paper_dir,before_match,after_match,interp, ...
                "before uses previous recorded/recomputed proxy; after uses paper-confirmed chain risk display", ...
                'VariableNames', {'parameter_set_id','metric_name','sigma','before_11_28_var','before_12_00_var','before_direction','after_11_28_var','after_12_00_var','after_direction','direction_changed','paper_expected_direction','before_match','after_match','interpretation','note'}); %#ok<AGROW>
        end
    end
end
writetable(vertcat(rows{:}), fullfile(out_dir,'wind_speed_before_after_severity_fix_comparison.csv'));
end

function val = get_after(T,p,s,m,sigma)
idx = T.parameter_set_id==p & T.scenario_id==s & T.metric_name==m & abs(T.sigma-sigma)<1e-9;
if any(idx), val=T.var_value(find(idx,1)); else, val=NaN; end
end

function [v11,v12,dir] = get_before(B,p,m,sigma)
v11=NaN; v12=NaN; dir="";
if isempty(B), return; end
old_metric = map_metric_name(m);
idx = B.parameter_set_id==p & B.metric_name==old_metric & abs(B.sigma-sigma)<1e-9 & B.variant=="recorded_severity";
if any(idx)
    r=B(find(idx,1),:); v11=r.wind_speed_11_28_var; v12=r.wind_speed_12_00_var; dir=r.direction;
end
end

function old_metric = map_metric_name(metric)
metric = string(metric);
if metric == "SLLR"
    old_metric = "LLR";
elseif metric == "SLFOR"
    old_metric = "LFOR";
elseif metric == "SNVOR"
    old_metric = "NVOR";
else
    old_metric = metric;
end
end

function d = direction(v11,v12)
if isnan(v11)||isnan(v12), d="insufficient_data"; elseif v12>v11, d="12mps_higher_than_11p28"; else, d="12mps_lower_or_equal_11p28"; end
end
