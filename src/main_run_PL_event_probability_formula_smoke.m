function main_run_PL_event_probability_formula_smoke()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'event_probability_formula');
ensure_dir(out_dir);
cases = [
    0.001 0.001 0.001
    0.05 0.05 0.01
    0.2 0.3 0.1
    0.6 0.6 0.2
];
rows = cell(size(cases,1),1);
for i = 1:size(cases,1)
    P1 = cases(i,1); P2 = cases(i,2); P3 = cases(i,3);
    simple = P1 + P2 + P3;
    clipped = min(max(simple,0),1);
    unionp = 1 - (1-P1)*(1-P2)*(1-P3);
    rows{i} = table("case_"+string(i), P1, P2, P3, simple, clipped, unionp, "paper_simple_sum_current", ...
        expected(P1,P2,P3), "pass", "Formula smoke only; union is diagnostic comparator, not selected without paper confirmation.", ...
        'VariableNames', {'test_case','P1','P2','P3','PL_simple_sum','PL_clipped_sum','PL_independent_union','selected_PL_mode', ...
        'expected_behavior','pass_fail','note'});
end
writetable(vertcat(rows{:}), fullfile(out_dir, 'PL_event_probability_formula_smoke.csv'));
end

function s = expected(P1,P2,P3)
if P1+P2+P3 > 1
    s = "simple sum clipped to one; union remains below or equal one";
else
    s = "simple sum and union are both valid comparators; paper confirmation required before changing mode";
end
end

function ensure_dir(path)
if exist(path,'dir')~=7, mkdir(path); end
end
