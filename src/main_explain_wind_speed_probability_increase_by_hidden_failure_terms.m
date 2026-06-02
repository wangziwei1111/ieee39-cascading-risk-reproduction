function main_explain_wind_speed_probability_increase_by_hidden_failure_terms()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'hidden_failure_formula');
ensure_dir(out_dir);
R = readtable(fullfile(out_dir, 'hidden_failure_component_recompute_audit.csv'), 'TextType','string');
A = readtable(fullfile(out_dir, 'below_Lmax_PHFL_variation_audit.csv'), 'TextType','string');
psets = unique(R.parameter_set_id);
rows = {};
for p = 1:numel(psets)
    R11 = R(R.parameter_set_id == psets(p) & R.scenario_id == "wind_speed_11_28", :);
    R12 = R(R.parameter_set_id == psets(p) & R.scenario_id == "wind_speed_12_00", :);
    branches = intersect(unique(R11.candidate_branch), unique(R12.candidate_branch));
    for b = 1:numel(branches)
        a = R11(R11.candidate_branch == branches(b), :);
        c = R12(R12.candidate_branch == branches(b), :);
        if isempty(a) || isempty(c), continue; end
        dload = mean(c.line_loading_pu, 'omitnan') - mean(a.line_loading_pu, 'omitnan');
        drec_phfl = mean(c.recorded_P_HF_L, 'omitnan') - mean(a.recorded_P_HF_L, 'omitnan');
        drep_phfl = mean(c.recomputed_P_HF_L_paper, 'omitnan') - mean(a.recomputed_P_HF_L_paper, 'omitnan');
        drec_mis = mean(c.recorded_P_mis_r, 'omitnan') - mean(a.recorded_P_mis_r, 'omitnan');
        drep_mis = mean(c.recomputed_P_mis_r_paper, 'omitnan') - mean(a.recomputed_P_mis_r_paper, 'omitnan');
        drec_p2 = mean(c.recorded_P2, 'omitnan') - mean(a.recorded_P2, 'omitnan');
        drep_p2 = mean(c.recomputed_P2_paper, 'omitnan') - mean(a.recomputed_P2_paper, 'omitnan');
        drec_pl = mean(c.recorded_P_L, 'omitnan') - mean(a.recorded_P_L, 'omitnan');
        drep_pl = mean(c.recomputed_P_L_paper, 'omitnan') - mean(a.recomputed_P_L_paper, 'omitnan');
        issue = any(logical(A.issue_confirmed(A.parameter_set_id == psets(p) & A.candidate_branch == branches(b))));
        effect = classify_effect(drec_phfl, drep_phfl, drep_pl, issue);
        rows{end+1,1} = table(psets(p), branches(b), dload, drec_phfl, drep_phfl, drec_mis, drep_mis, drec_p2, drep_p2, ...
            drec_pl, drep_pl, abs(drec_p2) > 1e-10, abs(drep_p2) > 1e-10, issue, effect, recommended(issue), ...
            "Branch-level mean delta between wind_speed_12_00 and wind_speed_11_28 from existing diagnostic traces.", ...
            'VariableNames', {'parameter_set_id','candidate_branch','delta_line_loading','delta_recorded_P_HF_L', ...
            'delta_recomputed_P_HF_L_paper','delta_recorded_P_mis_r','delta_recomputed_P_mis_r_paper', ...
            'delta_recorded_P2','delta_recomputed_P2_paper','delta_recorded_P_L','delta_recomputed_P_L_paper', ...
            'recorded_hidden_failure_driver','paper_recomputed_hidden_failure_driver','below_Lmax_PHFL_issue_confirmed', ...
            'effect_on_wind_speed_trend','recommended_fix','note'}); %#ok<AGROW>
    end
end
writetable(vertcat(rows{:}), fullfile(out_dir, 'wind_speed_hidden_failure_increase_explanation.csv'));
end

function s = classify_effect(drec_phfl, drep_phfl, drep_pl, issue)
if issue && drec_phfl > 0 && abs(drep_phfl) < abs(drec_phfl)
    s = "recorded_formula_artificially_increases_12mps_risk";
elseif drep_pl > 0
    s = "paper_formula_still_increases_12mps_risk";
elseif issue
    s = "formula_fix_likely_reduces_12mps_risk";
else
    s = "no_clear_effect";
end
end

function r = recommended(issue)
if issue
    r = "set_P_HF_L_constant_below_Lmax_for_paper_mode";
else
    r = "no_PHFL_formula_fix_required";
end
end

function ensure_dir(path)
if exist(path,'dir')~=7, mkdir(path); end
end
