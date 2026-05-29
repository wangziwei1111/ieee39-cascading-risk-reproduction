function main_check_benchmark_calibration_framework()
%MAIN_CHECK_BENCHMARK_CALIBRATION_FRAMEWORK Validate reverse-calibration artifacts.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
log_path = fullfile(out_dir, 'benchmark_calibration_framework_check_log.txt');
fid = fopen(log_path, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'benchmark_calibration_framework_check_log\n');
fprintf(fid, 'generated_at=%s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

required = [
    "paper_inputs/filled/public_fixed_parameters.csv"
    "paper_inputs/filled/missing_calibrated_parameters_register.csv"
    "paper_inputs/filled/benchmark_calibration_parameter_sets.csv"
    "paper_inputs/filled/calibration_target_benchmark.csv"
    "src/calibration/load_benchmark_calibration_parameter_set.m"
    "src/calibration/compute_benchmark_calibration_error.m"
    "results/calibration/pilot/calibration_pilot_score_summary.csv"
    "results/calibration/local_search_plan.csv"
    "docs/benchmark_calibration_plan.md"
    ];
for i = 1:numel(required)
    exists_flag = exist(fullfile(project_root, required(i)), 'file') == 2;
    fprintf(fid, 'required_file=%s exists=%d\n', required(i), exists_flag);
    if ~exists_flag
        error('Missing required benchmark calibration artifact: %s', required(i));
    end
end

formula_text = string(fileread(fullfile(project_root, 'src', 'outage', 'compute_paper_line_outage_probability.m')));
for token = ["P_mis_r","P1","P2","P3","P_L"]
    has_token = contains(formula_text, token);
    fprintf(fid, 'formula_contains_%s=%d\n', token, has_token);
    if ~has_token
        error('compute_paper_line_outage_probability.m missing formula detail token: %s', token);
    end
end

sets = readtable(fullfile(project_root, 'paper_inputs', 'filled', 'benchmark_calibration_parameter_sets.csv'), 'TextType', 'string');
bad_benchmark = contains(sets.calibration_status, "benchmark_calibrated") & ~contains(sets.calibration_status, "not_original_paper");
if any(bad_benchmark)
    error('benchmark_calibrated parameter set lacks not_original_paper marker.');
end
if any(sets.calibration_status == "original_paper_extracted")
    error('Reverse-calibration parameter sets must not be original_paper_extracted.');
end
fprintf(fid, 'parameter_set_count=%d\n', height(sets));

local_plan = readtable(fullfile(out_dir, 'local_search_plan.csv'), 'TextType', 'string');
if any(~contains(local_plan.calibration_status, "not_original_paper"))
    error('Local search candidates must be marked not_original_paper.');
end
fprintf(fid, 'local_search_candidate_count=%d\n', height(local_plan));

score_summary = readtable(fullfile(out_dir, 'pilot', 'calibration_pilot_score_summary.csv'), 'TextType', 'string');
fprintf(fid, 'pilot_parameter_set_count=%d\n', height(score_summary));
if ~ismember('recommendation', score_summary.Properties.VariableNames)
    error('calibration_pilot_score_summary.csv missing recommendation column.');
end

parameter_sets = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scenario_ids = ["concentrated_bus34","distributed_30_39","wind_speed_11_28","wind_speed_12_00", ...
    "penetration_40pct","penetration_60pct","penetration_80pct"];
scenario_required = ["markov_chain_summary.csv","markov_var_metrics.csv", ...
    "markov_var_metrics_weighted.csv","markov_var_metrics_paper_severity.csv"];
for p = 1:numel(parameter_sets)
    for s = 1:numel(scenario_ids)
        base_dir = fullfile(out_dir, 'pilot', parameter_sets(p), scenario_ids(s));
        for r = 1:numel(scenario_required)
            path = fullfile(base_dir, 'tables', scenario_required(r));
            exists_flag = exist(path, 'file') == 2;
            fprintf(fid, 'pilot_file=%s exists=%d\n', path, exists_flag);
            if ~exists_flag
                error('Missing pilot scenario output: %s', path);
            end
        end
        log_exists = exist(fullfile(base_dir, 'logs', 'scenario_run_log.txt'), 'file') == 2;
        fprintf(fid, 'pilot_log=%s exists=%d\n', fullfile(base_dir, 'logs', 'scenario_run_log.txt'), log_exists);
        if ~log_exists
            error('Missing pilot scenario log for %s/%s', parameter_sets(p), scenario_ids(s));
        end
    end
end

forbidden = [
    "results/final_summary/benchmark_calibration_framework_check_log.txt"
    "results/final_summary/tables/calibration_pilot_score_summary.csv"
    ];
for i = 1:numel(forbidden)
    exists_flag = exist(fullfile(project_root, forbidden(i)), 'file') == 2;
    fprintf(fid, 'forbidden_final_summary_file=%s exists=%d\n', forbidden(i), exists_flag);
    if exists_flag
        error('Calibration framework wrote into final_summary.');
    end
end

doc_text = string(fileread(fullfile(project_root, 'docs', 'benchmark_calibration_plan.md')));
if ~contains(doc_text, "not original paper") && ~contains(doc_text, "不是原文参数")
    error('benchmark_calibration_plan.md must explicitly state calibrated parameters are not original paper parameters.');
end
if contains(doc_text, "严格复现")
    fprintf(fid, 'strict_reproduction_phrase_present_for_warning_context=1\n');
end

fprintf(fid, '\ncheck_status=passed\n');
fprintf('benchmark calibration framework check passed: %s\n', log_path);
end
