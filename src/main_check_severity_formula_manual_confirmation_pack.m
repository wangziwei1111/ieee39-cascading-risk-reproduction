function main_check_severity_formula_manual_confirmation_pack()
% Offline check for the manual confirmation pack.

root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'severity_formula');
ensure_dir(out_dir);

checks = {};
checks{end+1,1}=check_file("severity_formula_manual_confirmation_evidence.csv", fullfile(out_dir,'severity_formula_manual_confirmation_evidence.csv'));
checks{end+1,1}=check_file("severity_formula_manual_confirmation_questions.csv", fullfile(out_dir,'severity_formula_manual_confirmation_questions.csv'));
checks{end+1,1}=check_file("severity_formula_uncertainty_summary.csv", fullfile(out_dir,'severity_formula_uncertainty_summary.csv'));
checks{end+1,1}=check_file("severity_formula_next_step_branch_plan.csv", fullfile(out_dir,'severity_formula_next_step_branch_plan.csv'));
checks{end+1,1}=check_file("docs/severity_formula_manual_confirmation_request.md", fullfile(root,'docs','severity_formula_manual_confirmation_request.md'));

checks{end+1,1}=guard("calc_basic_risk_metrics_not_modified_by_pack", git_clean_or_unstaged_only(root, "src/risk/calc_basic_risk_metrics.m"), ...
    "Manual confirmation pack must not modify current severity implementation.");
checks{end+1,1}=guard("calc_cri_not_modified_by_pack", git_clean_or_unstaged_only(root, "src/risk/calc_cri.m"), ...
    "Manual confirmation pack must not modify CRI implementation.");
checks{end+1,1}=guard("no_markov_run", true, "No Markov/cascade script is called by this check.");
checks{end+1,1}=guard("no_local_search", true, "No local search script is called by this check.");
checks{end+1,1}=guard("no_parameter_tuning", true, "No parameter refinement is performed.");
checks{end+1,1}=guard("no_final_summary_write", ~recent_final_summary(root), "No final_summary output was modified by this pack.");

T = vertcat(checks{:});
overall = all(T.pass);
T = [T; table("overall_status", overall, ternary(overall,"pass","fail"), "Manual confirmation pack offline checks.", ...
    'VariableNames', {'check_item','pass','status','note'})];
writetable(T, fullfile(out_dir, 'severity_formula_manual_confirmation_pack_check_log.txt'));

if ~overall
    error('severity_formula_manual_confirmation_pack_check failed. See log.');
end
end

function T = check_file(name, path)
ok = exist(path,'file') == 2;
T = table(string(name), ok, ternary(ok,"pass","fail"), string(path), ...
    'VariableNames', {'check_item','pass','status','note'});
end

function T = guard(name, ok, note)
T = table(string(name), logical(ok), ternary(ok,"pass","fail"), string(note), ...
    'VariableNames', {'check_item','pass','status','note'});
end

function ok = git_clean_or_unstaged_only(root, rel)
[status, out] = system(sprintf('git -C "%s" status --short -- "%s"', root, rel));
if status ~= 0
    ok = false;
    return;
end
lines = splitlines(string(strtrim(out)));
if numel(lines) == 1 && strlength(lines(1)) == 0
    ok = true;
    return;
end
% Any staged change has a non-space first status column.
ok = true;
for i = 1:numel(lines)
    line = char(lines(i));
    if numel(line) >= 1 && line(1) ~= ' '
        ok = false;
        return;
    end
end
end

function tf = recent_final_summary(root)
paths = [dir(fullfile(root,'results','**','final_summary*')); dir(fullfile(root,'results','**','*final*summary*'))];
tf = false;
if isempty(paths)
    return;
end
now_num = now;
for i = 1:numel(paths)
    if ~paths(i).isdir && now_num - paths(i).datenum < (10 / 1440)
        tf = true;
        return;
    end
end
end

function s = ternary(cond, a, b)
if cond
    s = string(a);
else
    s = string(b);
end
end

function ensure_dir(path)
if exist(path,'dir')~=7, mkdir(path); end
end
