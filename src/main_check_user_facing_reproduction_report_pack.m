function main_check_user_facing_reproduction_report_pack()
%MAIN_CHECK_USER_FACING_REPRODUCTION_REPORT_PACK Check user-facing report pack only.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'reproduction_status');
ensure_dir(out_dir);

index_path = fullfile(out_dir, 'user_facing_report_index.csv');
docs = [
    "docs/阶段性复现报告_公开信息约束版.md"
    "docs/复现进度简版说明.md"
    "docs/严格复现所需补充资料清单.md"
    "docs/reproduction_status_and_public_information_gap_report.md"
    "docs/additional_paper_data_needed_for_strict_reproduction.md"
    ];
purpose = [
    "中文阶段性主报告"
    "快速阅读版说明"
    "严格复现资料需求表"
    "English/ASCII status gap report"
    "English/ASCII additional data checklist"
    ];
recommended_use = [
    "用于论文/项目阶段性总结"
    "用于快速同步当前进度"
    "用于向用户或作者索要补充资料"
    "用于追踪工程化状态与边界"
    "用于英文资料请求或仓库说明"
    ];
status = repmat("ready", numel(docs), 1);
note = repmat("No simulation was run; report-only artifact.", numel(docs), 1);
T = table(docs, purpose, recommended_use, status, note, ...
    'VariableNames', {'document','purpose','recommended_use','status','note'});
writetable(T, index_path);

log_path = fullfile(out_dir, 'user_facing_reproduction_report_pack_check_log.txt');
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
ok = true;
for k = 1:numel(docs)
    exists = isfile(fullfile(project_root, docs(k)));
    ok = ok && exists;
    fprintf(fid, 'file_exists,%s,%d\n', docs(k), exists);
end
index_exists = isfile(index_path);
ok = ok && index_exists;
fprintf(fid, 'file_exists,results/calibration/reproduction_status/user_facing_report_index.csv,%d\n', index_exists);
fprintf(fid, 'guard_no_markov_run,1\n');
fprintf(fid, 'guard_no_cascade_run,1\n');
fprintf(fid, 'guard_no_local_search,1\n');
fprintf(fid, 'guard_no_parameter_tuning,1\n');
fprintf(fid, 'guard_no_final_summary_write,1\n');
fprintf(fid, 'guard_no_full_7_scenario_formal_pilot,1\n');
if ok
    fprintf(fid, 'check_status,pass\n');
else
    fprintf(fid, 'check_status,fail\n');
    error('User-facing reproduction report pack check failed.');
end
fprintf('Wrote %s\n', log_path);
end

function ensure_dir(pathname)
if ~exist(pathname, 'dir')
    mkdir(pathname);
end
end
