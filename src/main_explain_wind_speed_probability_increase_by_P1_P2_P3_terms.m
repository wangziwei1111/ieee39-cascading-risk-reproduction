function main_explain_wind_speed_probability_increase_by_P1_P2_P3_terms()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'event_probability_formula');
R = readtable(fullfile(out_dir, 'PL_event_component_recompute_audit.csv'), 'TextType','string');
U = readtable(fullfile(out_dir, 'PL_sum_vs_union_difference_audit.csv'), 'TextType','string');
psets = unique(R.parameter_set_id);
rows = {};
for p = 1:numel(psets)
    R11 = R(R.parameter_set_id==psets(p)&R.scenario_id=="wind_speed_11_28",:);
    R12 = R(R.parameter_set_id==psets(p)&R.scenario_id=="wind_speed_12_00",:);
    branches = intersect(unique(R11.candidate_branch), unique(R12.candidate_branch));
    for b = 1:numel(branches)
        a = R11(R11.candidate_branch==branches(b),:);
        c = R12(R12.candidate_branch==branches(b),:);
        d1 = mean(c.recorded_P1,'omitnan') - mean(a.recorded_P1,'omitnan');
        d2 = mean(c.recorded_P2,'omitnan') - mean(a.recorded_P2,'omitnan');
        d3 = mean(c.recorded_P3,'omitnan') - mean(a.recorded_P3,'omitnan');
        dpl = mean(c.recorded_P_L,'omitnan') - mean(a.recorded_P_L,'omitnan');
        du = mean(c.recomputed_PL_independent_union,'omitnan') - mean(a.recomputed_PL_independent_union,'omitnan');
        mat = any(logical(U.difference_material(U.parameter_set_id==psets(p)&U.candidate_branch==branches(b))));
        rows{end+1,1} = table(psets(p), branches(b), mean(c.line_loading_pu,'omitnan')-mean(a.line_loading_pu,'omitnan'), ...
            d1, d2, d3, dpl, du, dominant(d1,d2,d3), aggregation_effect(mat, dpl, du), trend_effect(dpl,du), recommended(mat), ...
            "Branch-level mean contribution delta from existing traces; no formula change applied.", ...
            'VariableNames', {'parameter_set_id','candidate_branch','delta_line_loading','delta_P1','delta_P2','delta_P3', ...
            'delta_PL_recorded','delta_PL_union_proxy','dominant_probability_term','PL_aggregation_effect','effect_on_wind_speed_trend', ...
            'recommended_fix','note'}); %#ok<AGROW>
    end
end
writetable(vertcat(rows{:}), fullfile(out_dir, 'wind_speed_P1_P2_P3_increase_explanation.csv'));
end

function s = dominant(d1,d2,d3)
[~,idx] = max(abs([d1,d2,d3]));
if max(abs([d1,d2,d3])) < 1e-12, s = "no_clear_term"; return; end
names = ["P1_dominant","P2_dominant","P3_dominant"]; s = names(idx);
end

function s = aggregation_effect(material, dpl, du)
if ~material, s = "simple_sum_ok";
elseif sign(dpl) ~= sign(du), s = "union_would_reduce_risk";
else, s = "union_would_not_change_direction";
end
end

function s = trend_effect(dpl, du)
if dpl > 0 && du > 0, s = "paper_formula_still_increases_12mps_risk";
elseif dpl > 0 && du <= 0, s = "union_proxy_could_change_direction";
else, s = "no_clear_effect";
end
end

function r = recommended(material)
if material, r = "need_manual_paper_confirmation"; else, r = "no_PL_aggregation_fix_required"; end
end
