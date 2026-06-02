function main_run_wind_speed_only_diagnostic_after_severity_formula_fix()
% Build after-fix wind-speed diagnostic outputs by reusing existing 30-trial chains.
% This is a severity-only diagnostic rerun from existing traces; no Markov/local search.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(root, 'src')));
out_root = fullfile(root, 'results', 'calibration', 'severity_formula', 'wind_speed_after_severity_fix_diagnostic_rerun');
ensure_dir(out_root);
main_recompute_wind_speed_paper_confirmed_severity_from_existing_trace();
R = readtable(fullfile(root,'results','calibration','severity_formula','wind_speed_paper_confirmed_severity_recompute_from_existing_trace.csv'), 'TextType','string', 'Delimiter', ',');
src_root = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun');
psets = unique(R.parameter_set_id, 'stable');
for p = 1:numel(psets)
    scens = unique(R.scenario_id(R.parameter_set_id == psets(p)), 'stable');
    for s = 1:numel(scens)
        src_tables = fullfile(src_root, psets(p), scens(s), 'tables');
        out_dir = fullfile(out_root, psets(p), scens(s));
        ensure_dir(fullfile(out_dir, 'tables'));
        ensure_dir(fullfile(out_dir, 'logs'));
        if exist(fullfile(src_tables,'markov_chain_summary.csv'),'file') == 2
            copyfile(fullfile(src_tables,'markov_chain_summary.csv'), fullfile(out_dir,'tables','markov_chain_summary.csv'));
        end
        sub = R(R.parameter_set_id == psets(p) & R.scenario_id == scens(s), :);
        V = table(sub.parameter_set_id, sub.scenario_id, sub.initial_branch, sub.trial_id, sub.stage_id, ...
            sub.LLR_paper_recomputed, sub.LFOR_paper_recomputed, sub.NVOR_paper_recomputed, sub.CRI_stage_reference_paper, ...
            sub.normalization_status, sub.proxy_status, sub.missing_fields, sub.note, ...
            'VariableNames', {'parameter_set_id','scenario_id','initial_branch','trial_id','stage_id', ...
            'LLR_paper','LFOR_paper','NVOR_paper','CRI_stage_reference_paper', ...
            'normalization_status','proxy_status','missing_fields','note'});
        writetable(V, fullfile(out_dir,'tables','severity_vector_trace.csv'));
        snapshot = table(psets(p), scens(s), 30, "paper_confirmed_exponential_sum", ...
            "reused_existing_wind_speed_component_diagnostic_chains", ...
            "No Markov rerun; severity-only diagnostic recompute from existing vectors.", ...
            'VariableNames', {'parameter_set_id','scenario_id','markov_trials_per_initial_fault','severity_formula_mode','source','note'});
        writetable(snapshot, fullfile(out_dir, 'scenario_config_snapshot.csv'));
        writelines(["wind-speed after severity formula fix diagnostic"; "severity-only recompute from existing 30-trial chains"; ...
            "No local search, no parameter tuning, no final_summary."], fullfile(out_dir,'logs','scenario_run_log.txt'));
    end
end
end

function ensure_dir(p)
if exist(p,'dir')~=7, mkdir(p); end
end
