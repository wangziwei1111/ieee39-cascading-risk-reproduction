function main_audit_wind_power_curve_for_speed_scan()
%MAIN_AUDIT_WIND_POWER_CURVE_FOR_SPEED_SCAN Compare paper and engineering curves.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
speeds = [11.28, 12.00];
capacities = [3000, 4500, 6000];
rows = table();
cfg = base_config();
paper_cfg = cfg;
paper_cfg.wind_power_curve_profile = 'paper_2_12_20';
engineering_cfg = cfg;
engineering_cfg.wind_power_curve_profile = 'engineering_3_12_25';
for cap = capacities
    for v = speeds
        [paper, paper_detail] = compute_paper_wind_power_curve(v, cap, paper_cfg);
        [eng, eng_detail] = compute_paper_wind_power_curve(v, cap, engineering_cfg);
        active = paper;
        diff_mw = active - paper;
        diff_ratio = diff_mw / max(cap, eps);
        if abs(diff_mw) <= 1e-6
            status = "match";
            note = "Active paper-aligned profile matches the requested paper formula; legacy engineering profile is retained only as comparison.";
        else
            status = "blocking_formula_mismatch";
            note = "Active profile does not match requested paper 2/12/20 formula.";
        end
        rows = [rows; table(v, cap, string(paper_detail.curve_profile), string(eng_detail.curve_profile), ...
            paper, paper/cap, active, active/cap, eng, eng/cap, diff_mw, diff_ratio, status, note, ...
            'VariableNames', {'wind_speed_mps','rated_wind_capacity_mw','curve_profile','comparison_profile', ...
            'paper_formula_power_mw','paper_formula_power_ratio','engineering_function_power_mw','engineering_function_power_ratio', ...
            'legacy_engineering_power_mw','legacy_engineering_power_ratio','difference_mw','difference_ratio','match_status','note'})]; %#ok<AGROW>
    end
end
writetable(rows, fullfile(out_root, 'wind_power_curve_speed_scan_audit.csv'));
end
