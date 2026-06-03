function main_check_fig4_2_user_facing_report_pack()
%MAIN_CHECK_FIG4_2_USER_FACING_REPORT_PACK Check user-facing Fig.4-2 report pack.
% This check only verifies existing report artifacts. It does not run
% Markov, cascade, local search, parameter refinement, final_summary, or
% any formal pilot.

project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'figures', 'fig4_2_diagnostic_reproduction');
ensure_dir(out_root);
log_path = fullfile(out_root, 'fig4_2_user_facing_report_pack_check_log.txt');
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));

required = { ...
    fullfile(project_root, 'docs', '图4-2诊断性复现结果说明.md'), ...
    fullfile(out_root, 'fig4_2_user_facing_output_index.csv'), ...
    fullfile(out_root, 'fig4_2_diagnostic_reproduction.png'), ...
    fullfile(out_root, 'fig4_2_metric_summary.csv'), ...
    fullfile(out_root, 'fig4_2_trend_comparison.csv'), ...
    fullfile(out_root, 'fig4_2_density_data.csv'), ...
    fullfile(project_root, 'docs', 'fig4_2_diagnostic_reproduction_report.md') ...
    };

all_ok = true;
for i = 1:numel(required)
    ok = exist(required{i}, 'file') == 2;
    fprintf(fid, 'file_exists,%s,%d\n', required{i}, ok);
    all_ok = all_ok && ok;
end

fprintf(fid, 'guard_no_markov_run,1\n');
fprintf(fid, 'guard_no_cascade_run,1\n');
fprintf(fid, 'guard_no_local_search,1\n');
fprintf(fid, 'guard_no_parameter_refinement,1\n');
fprintf(fid, 'guard_no_final_summary_write,1\n');
fprintf(fid, 'guard_no_full_formal_pilot,1\n');
fprintf(fid, 'guard_no_existing_fig4_2_data_overwrite,1\n');
fprintf(fid, 'claim_boundary,diagnostic_reproduction_under_public_information_constraints_not_strict_original_reproduction\n');

if all_ok
    fprintf(fid, 'check_status,pass\n');
else
    fprintf(fid, 'check_status,fail\n');
    error('Fig.4-2 user-facing report pack check failed. See %s', log_path);
end

fprintf('Wrote %s\n', log_path);
end

function ensure_dir(path)
if exist(path, 'dir') ~= 7
    mkdir(path);
end
end
