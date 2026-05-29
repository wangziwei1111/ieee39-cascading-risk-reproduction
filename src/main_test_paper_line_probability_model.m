function main_test_paper_line_probability_model()
%MAIN_TEST_PAPER_LINE_PROBABILITY_MODEL Unit tests for thesis line probability interface.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'outage');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

cfg_missing = base_config();
cfg_missing.line_outage_probability_model = 'paper_formula';
cfg_missing.paper_line_missing_param_policy = 'fallback_to_engineering_with_warning';

cfg_param = cfg_missing;
cfg_param.paper_line_P_L0 = 1e-4;
cfg_param.paper_line_P_W_D = 2e-4;
cfg_param.paper_line_P_L_D = 3e-4;
cfg_param.paper_line_P_L_r = 0.2;
cfg_param.paper_line_P3 = 0;

branch_row = zeros(1, 13);
branch_row(6) = 100;
loadings = [0.5; 1.0; 1.1; 1.2; 1.4; 1.6];
rows = {};
for i = 1:numel(loadings)
    rows{end+1,1} = run_case("missing_param_fallback", loadings(i), branch_row, cfg_missing); %#ok<AGROW>
end
for i = 1:numel(loadings)
    rows{end+1,1} = run_case("temporary_uncalibrated_params", loadings(i), branch_row, cfg_param); %#ok<AGROW>
end

tbl = vertcat(rows{:});
param_rows = tbl(string(tbl.test_case) == "temporary_uncalibrated_params", :);
if any(diff(param_rows.P_flow) < -1e-12)
    error('P_flow must be nondecreasing in temporary parameter test.');
end
if any(tbl.p_line < -1e-12 | tbl.p_line > 1 + 1e-12, 'all')
    error('p_line must stay in [0,1].');
end
if any(string(tbl.test_case) == "missing_param_fallback" & string(tbl.status) == "calibrated")
    error('Missing-parameter case must not be marked calibrated.');
end

writetable(tbl, fullfile(out_dir, 'paper_line_probability_unit_test.csv'));
fprintf('paper line probability unit test written: %s\n', fullfile(out_dir, 'paper_line_probability_unit_test.csv'));
end

function row = run_case(test_case, loading, branch_row, cfg)
[p_line, detail] = compute_paper_line_outage_probability(loading, branch_row, cfg, ...
    'fallback_probability', line_outage_probability(loading, cfg), ...
    'Z_m', 1.0, 'Z_III', 1.0, 'protection_mode', "unit_test");
row = table(string(test_case), loading, p_line, detail.P_flow, ...
    detail.P_hidden_distance, detail.P_hidden_loading, ...
    string(detail.missing_parameters), logical(detail.used_fallback), ...
    string(detail.status), string(detail.note), ...
    'VariableNames', {'test_case', 'line_loading_pu', 'p_line', 'P_flow', ...
    'P_hidden_distance', 'P_hidden_loading', 'missing_parameters', ...
    'used_fallback', 'status', 'note'});
end
