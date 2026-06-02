function main_diagnose_wind_speed_candidate_probability_changes()
%MAIN_DIAGNOSE_WIND_SPEED_CANDIDATE_PROBABILITY_CHANGES Summarize candidate probabilities.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
params = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scenarios = ["wind_speed_11_28","wind_speed_12_00"];
summary = table();
branch_rows = table();
for p = params
    for s = scenarios
        cpath = fullfile(out_root, p, s, 'tables', 'candidate_probability_trace.csv');
        mpath = fullfile(out_root, p, s, 'tables', 'markov_chain_summary.csv');
        if ~isfile(cpath), continue; end
        C = readtable(cpath, 'TextType', 'string', 'Delimiter', ',');
        P = numcol(C, 'candidate_probability');
        S = numcol(C, 'selected') > 0.5;
        M = readtable(mpath, 'TextType', 'string', 'Delimiter', ',');
        reasons = string(M.terminated_reason);
        summary = [summary; table(p, s, height(C), mean(P,'omitnan'), median(P,'omitnan'), q(P,0.95), max(P,[],'omitnan'), ...
            sum(abs(P-1) < 1e-12), sum(S), mean(S,'omitnan'), mean(P(S),'omitnan'), ...
            sum(reasons=="load_loss_threshold"), sum(reasons=="no_new_outage"), sum(contains(reasons,"nonconvergence")), ...
            "Candidate probability trace read from existing full-event pilot; no new Markov run.", ...
            'VariableNames', {'parameter_set_id','scenario_id','candidate_count','mean_candidate_probability', ...
            'median_candidate_probability','p95_candidate_probability','max_candidate_probability','probability_one_count', ...
            'selected_count','selected_rate','mean_selected_probability','terminal_load_loss_count', ...
            'terminal_no_new_outage_count','terminal_nonconvergence_count','note'})]; %#ok<AGROW>
        branches = unique(numcol(C, 'candidate_branch'));
        for b = branches'
            idx = numcol(C, 'candidate_branch') == b;
            branch_rows = [branch_rows; table(p, s, b, mean(P(idx),'omitnan'), sum(S(idx)), ...
                'VariableNames', {'parameter_set_id','scenario_id','branch_id','mean_probability','selected_count'})]; %#ok<AGROW>
        end
    end
end
writetable(summary, fullfile(out_root, 'wind_speed_candidate_probability_summary.csv'));

delta = table();
for p = params
    branches = unique(branch_rows.branch_id(branch_rows.parameter_set_id == p));
    for b = branches'
        a = branch_rows(branch_rows.parameter_set_id == p & branch_rows.scenario_id=="wind_speed_11_28" & branch_rows.branch_id==b,:);
        c = branch_rows(branch_rows.parameter_set_id == p & branch_rows.scenario_id=="wind_speed_12_00" & branch_rows.branch_id==b,:);
        if isempty(a), mp11 = NaN; sc11 = 0; else, mp11 = a.mean_probability(1); sc11 = a.selected_count(1); end
        if isempty(c), mp12 = NaN; sc12 = 0; else, mp12 = c.mean_probability(1); sc12 = c.selected_count(1); end
        delta = [delta; table(p, b, mp11, mp12, mp12-mp11, sc11, sc12, sc12-sc11, ...
            "Branch-level candidate probability comparison across the two wind speeds.", ...
            'VariableNames', {'parameter_set_id','branch_id','mean_probability_11_28','mean_probability_12_00', ...
            'delta_probability','selected_count_11_28','selected_count_12_00','delta_selected_count','loading_related_note'})]; %#ok<AGROW>
    end
end
writetable(delta, fullfile(out_root, 'wind_speed_branch_probability_delta.csv'));
end

function x = numcol(T, name)
if ismember(name, T.Properties.VariableNames), x = str2double(string(T.(name))); else, x = NaN(height(T),1); end
end

function y = q(x, p)
x = sort(x(~isnan(x))); if isempty(x), y = NaN; else, y = x(max(1, min(numel(x), ceil(p*numel(x))))); end
end
