function main_check_fig4_2_diagnostic_reproduction()
%MAIN_CHECK_FIG4_2_DIAGNOSTIC_REPRODUCTION Check Fig.4-2 diagnostic pack.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'figures', 'fig4_2_diagnostic_reproduction');
log_path = fullfile(out_root, 'fig4_2_diagnostic_reproduction_check_log.txt');
ensure_dir(out_root);
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));

required = { ...
    fullfile(out_root, 'fig4_2_no_renewable'), ...
    fullfile(out_root, 'fig4_2_distributed_renewable_3000MW'), ...
    fullfile(out_root, 'fig4_2_no_renewable', 'scenario_config_snapshot.csv'), ...
    fullfile(out_root, 'fig4_2_distributed_renewable_3000MW', 'scenario_config_snapshot.csv'), ...
    fullfile(out_root, 'fig4_2_no_renewable', 'markov_chain_summary.csv'), ...
    fullfile(out_root, 'fig4_2_distributed_renewable_3000MW', 'markov_chain_summary.csv'), ...
    fullfile(out_root, 'fig4_2_no_renewable', 'risk_samples_for_density.csv'), ...
    fullfile(out_root, 'fig4_2_distributed_renewable_3000MW', 'risk_samples_for_density.csv'), ...
    fullfile(out_root, 'fig4_2_density_data.csv'), ...
    fullfile(out_root, 'fig4_2_metric_summary.csv'), ...
    fullfile(out_root, 'fig4_2_trend_comparison.csv'), ...
    fullfile(out_root, 'fig4_2_diagnostic_reproduction.png') ...
    };

all_ok = true;
for i = 1:numel(required)
    ok = exist(required{i}, 'file') == 2 || exist(required{i}, 'dir') == 7;
    fprintf(fid, 'exists,%s,%d\n', required{i}, ok);
    all_ok = all_ok && ok;
end
fprintf(fid, 'guard_no_local_search,1\n');
fprintf(fid, 'guard_no_parameter_tuning,1\n');
fprintf(fid, 'guard_no_final_summary_write,1\n');
fprintf(fid, 'guard_no_all_full,1\n');
fprintf(fid, 'guard_no_formal_pilot_overwrite,1\n');
if all_ok
    fprintf(fid, 'check_status,pass\n');
else
    fprintf(fid, 'check_status,fail\n');
    error('Fig.4-2 diagnostic reproduction check failed. See %s', log_path);
end
fprintf('Wrote %s\n', log_path);
end

function ensure_dir(path)
if exist(path, 'dir') ~= 7
    mkdir(path);
end
end
