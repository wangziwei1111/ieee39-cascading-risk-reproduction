function main_check_reproduction_stage_audit_report()
%MAIN_CHECK_REPRODUCTION_STAGE_AUDIT_REPORT Validate stage audit outputs.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'stage_audit');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

log_path = fullfile(out_dir, 'reproduction_stage_audit_check_log.txt');
fid = fopen(log_path, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'reproduction_stage_audit_check_log\n');
fprintf(fid, 'generated_at=%s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

required_files = [
    "results/stage_audit/reproduction_module_status.csv"
    "results/stage_audit/missing_original_inputs_register.csv"
    "results/stage_audit/current_available_results_index.csv"
    "results/stage_audit/claims_not_allowed_yet.csv"
    "results/stage_audit/next_step_roadmap.csv"
    "docs/reproduction_stage_audit_report.md"
    ];

all_ok = true;
for i = 1:numel(required_files)
    full_path = fullfile(project_root, required_files(i));
    exists_flag = exist(full_path, 'file') == 2;
    fprintf(fid, 'required_file=%s exists=%d\n', required_files(i), exists_flag);
    if ~exists_flag
        all_ok = false;
    end
end

if ~all_ok
    error('Stage audit check failed: one or more required files are missing. See %s', log_path);
end

module_status = readtable(fullfile(out_dir, 'reproduction_module_status.csv'), 'TextType', 'string');
required_modules = [
    "paper_inputs"
    "paper_benchmark"
    "initial_line_outage_probability_table4_1"
    "topology_compare"
    "penetration_scan"
    "wind_speed_scan"
    "paper_table46_wind_speed_scan"
    "OLS_load_shedding"
    "line_subsequent_outage_probability_P_L"
    "wind_trip_probability_P_wt"
    "generator_outage_probability_P_ge"
    "composite_state_probability"
    "stage_level_severity"
    "paper_benchmark_alignment"
    ];
for i = 1:numel(required_modules)
    present = any(module_status.module_id == required_modules(i));
    fprintf(fid, 'module=%s present=%d\n', required_modules(i), present);
    if ~present
        error('Stage audit check failed: missing module row %s', required_modules(i));
    end
end

doc_path = fullfile(project_root, 'docs', 'reproduction_stage_audit_report.md');
doc_text = string(fileread(doc_path));
has_strict_claim_warning = contains(doc_text, "不能声称严格复现");
has_user_input_list = contains(doc_text, "需要用户提供的原文参数清单");
fprintf(fid, '\ncontains_strict_reproduction_warning=%d\n', has_strict_claim_warning);
fprintf(fid, 'contains_user_parameter_list=%d\n', has_user_input_list);
if ~has_strict_claim_warning
    error('Stage audit report must contain "不能声称严格复现".');
end
if ~has_user_input_list
    error('Stage audit report must contain "需要用户提供的原文参数清单".');
end

forbidden_final_summary_paths = [
    "results/final_summary/reproduction_stage_audit_check_log.txt"
    "results/final_summary/tables/reproduction_module_status.csv"
    "results/final_summary/tables/missing_original_inputs_register.csv"
    ];
for i = 1:numel(forbidden_final_summary_paths)
    forbidden_exists = exist(fullfile(project_root, forbidden_final_summary_paths(i)), 'file') == 2;
    fprintf(fid, 'forbidden_final_summary_file=%s exists=%d\n', forbidden_final_summary_paths(i), forbidden_exists);
    if forbidden_exists
        error('Stage audit check failed: audit output was written under final_summary.');
    end
end

claims = readtable(fullfile(out_dir, 'claims_not_allowed_yet.csv'), 'TextType', 'string');
if height(claims) < 9
    error('Stage audit check failed: claims_not_allowed_yet.csv has too few rows.');
end
fprintf(fid, '\nclaims_not_allowed_count=%d\n', height(claims));

missing_inputs = readtable(fullfile(out_dir, 'missing_original_inputs_register.csv'), 'TextType', 'string');
if ~any(missing_inputs.category == "line_P_L") || ~any(missing_inputs.category == "wind_P_wt") || ~any(missing_inputs.category == "generator_P_ge")
    error('Stage audit check failed: missing input register lacks one or more core probability categories.');
end
fprintf(fid, 'missing_original_inputs_count=%d\n', height(missing_inputs));

fprintf(fid, '\ncheck_status=passed\n');
fprintf('reproduction stage audit check passed: %s\n', log_path);
end
