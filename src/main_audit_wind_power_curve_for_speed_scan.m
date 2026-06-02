function main_audit_wind_power_curve_for_speed_scan()
%MAIN_AUDIT_WIND_POWER_CURVE_FOR_SPEED_SCAN Compare paper and engineering curves.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(project_root, 'src')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
speeds = [11.28, 12.00];
capacities = [3000, 4500, 6000];
rows = table();
for cap = capacities
    for v = speeds
        paper = paper_curve(v, cap);
        eng = wind_power_curve(v, cap, 3, 12, 25);
        diff_mw = eng - paper;
        diff_ratio = diff_mw / max(cap, eps);
        if abs(diff_mw) <= 1e-6
            status = "match";
            note = "Engineering wind_power_curve matches the paper formula at this point.";
        else
            status = "blocking_formula_mismatch";
            note = "Engineering scenario default uses cut-in/cut-out 3/25, while the requested paper audit formula uses 2/20.";
        end
        rows = [rows; table(v, cap, paper, paper/cap, eng, eng/cap, diff_mw, diff_ratio, status, note, ...
            'VariableNames', {'wind_speed_mps','rated_wind_capacity_mw','paper_formula_power_mw', ...
            'paper_formula_power_ratio','engineering_function_power_mw','engineering_function_power_ratio', ...
            'difference_mw','difference_ratio','match_status','note'})]; %#ok<AGROW>
    end
end
writetable(rows, fullfile(out_root, 'wind_power_curve_speed_scan_audit.csv'));
end

function p = paper_curve(v, rated)
if v < 2 || v > 20
    p = 0;
elseif v <= 12
    p = rated * (v^3 - 8) / 1720;
else
    p = rated;
end
end
