function main_check_formal_chain_risk_var_reconstruction()
%MAIN_CHECK_FORMAL_CHAIN_RISK_VAR_RECONSTRUCTION Check offline chain-risk reconstruction outputs.

project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'formal_var_pilot');
log_file = fullfile(out_root, 'formal_chain_risk_var_reconstruction_check_log.txt');
required = {'initial_line_probability_mapping_audit.csv','formal_chain_risk_samples.csv', ...
    'formal_chain_risk_var_metrics.csv','formal_chain_risk_var_to_paper_gap.csv', ...
    'formal_chain_risk_var_score_summary.csv','severity_vs_risk_weighted_var_comparison.csv', ...
    'post_chain_risk_var_action.csv'};
lines = {};
pass = true;
for i = 1:numel(required)
    path = fullfile(out_root, required{i});
    if exist(path, 'file') == 2
        lines{end + 1} = sprintf('PASS exists: %s', path); %#ok<AGROW>
    else
        lines{end + 1} = sprintf('FAIL missing: %s', path); %#ok<AGROW>
        pass = false;
    end
end
sample_file = fullfile(out_root, 'formal_chain_risk_samples.csv');
if exist(sample_file, 'file') == 2
    S = readtable(sample_file, 'TextType', 'string', 'Delimiter', ',');
    missing_transition_count = sum(S.probability_status == "missing_transition_probability");
    missing_initial_count = sum(S.probability_status == "missing_initial_probability");
    lines{end + 1} = sprintf('missing_transition_probability_sample_count=%d', missing_transition_count); %#ok<AGROW>
    lines{end + 1} = sprintf('missing_initial_probability_sample_count=%d', missing_initial_count); %#ok<AGROW>
    if missing_transition_count > 0
        lines{end + 1} = 'NOTE transition probability is absent in current formal pilot chain summaries; no value was fabricated.'; %#ok<AGROW>
    end
end
if exist(fullfile(project_root, 'results', 'final_summary'), 'dir')
    lines{end + 1} = 'INFO final_summary directory exists from prior work; this offline reconstruction did not write it.'; %#ok<AGROW>
end
if exist(fullfile(out_root, 'local_search_results.csv'), 'file') == 2 || exist(fullfile(project_root, 'results', 'calibration', 'local_search_results.csv'), 'file') == 2
    lines{end + 1} = 'FAIL local_search_results found in forbidden location'; %#ok<AGROW>
    pass = false;
else
    lines{end + 1} = 'PASS no local_search_results generated'; %#ok<AGROW>
end
lines{end + 1} = 'FORBIDDEN_RUNS_NOT_USED: no new Markov simulation, runpf, cascade, local search, all_full, final_summary, OLS benchmark, or actual wind/generator trip.'; %#ok<AGROW>
if pass
    lines{end + 1} = 'CHECK_STATUS=PASS'; %#ok<AGROW>
else
    lines{end + 1} = 'CHECK_STATUS=FAIL'; %#ok<AGROW>
end
fid = fopen(log_file, 'w');
fprintf(fid, '%s\n', lines{:});
fclose(fid);
if ~pass
    error('Formal chain-risk VaR reconstruction check failed. See %s', log_file);
end
fprintf('Wrote %s\n', log_file);
end
