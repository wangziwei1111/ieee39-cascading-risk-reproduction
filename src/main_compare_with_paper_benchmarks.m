function main_compare_with_paper_benchmarks()
%MAIN_COMPARE_WITH_PAPER_BENCHMARKS 建立论文 benchmark 与当前复现结果的对照表。
% 输入：
%   paper_inputs/filled/paper_result_benchmark.csv
%   paper_inputs/filled/paper_scenario_definition.csv
%   results/final_summary/tables/*.csv
% 输出：
%   results/paper_alignment/tables/*.csv
%   results/paper_alignment/figures/*.png
% 物理含义：
%   本脚本只做原文 benchmark 与当前 line-only 工程结果的静态对照，不运行任何仿真，
%   不修改 paper_inputs/filled，也不通过缩放强行贴近论文数值。

project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'paper_alignment');
table_dir = fullfile(out_root, 'tables');
fig_dir = fullfile(out_root, 'figures');
log_dir = fullfile(out_root, 'logs');
ensure_dir(table_dir);
ensure_dir(fig_dir);
ensure_dir(log_dir);

paper_path = fullfile(project_root, 'paper_inputs', 'filled', 'paper_result_benchmark.csv');
scenario_path = fullfile(project_root, 'paper_inputs', 'filled', 'paper_scenario_definition.csv');
if ~exist(paper_path, 'file')
    error('缺少论文 benchmark 输入：%s', paper_path);
end
if ~exist(scenario_path, 'file')
    error('缺少论文场景定义输入：%s', scenario_path);
end

paper_tbl = readtable(paper_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
scenario_tbl = readtable(scenario_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve'); %#ok<NASGU>
topology = read_optional_table(fullfile(project_root, 'results', 'final_summary', 'tables', 'final_topology_comparison.csv'));
penetration = read_optional_table(fullfile(project_root, 'results', 'final_summary', 'tables', 'final_penetration_scan.csv'));
wind_speed = read_optional_table(fullfile(project_root, 'results', 'final_summary', 'tables', 'final_wind_speed_scan.csv'));
paper_wind_speed = read_optional_table(fullfile(project_root, 'results', 'scenarios', 'scenario_result_summary_paper_wind_speed_scan.csv'));
trip_record = read_optional_table(fullfile(project_root, 'results', 'final_summary', 'tables', 'final_renewable_trip_record.csv'));
overview = read_optional_table(fullfile(project_root, 'results', 'final_summary', 'tables', 'final_scenario_overview.csv')); %#ok<NASGU>

mapping = build_mapping(paper_tbl);
paper_std = standardize_paper_benchmark(paper_tbl);
repro_std = standardize_reproduction_results(topology, penetration, wind_speed, paper_wind_speed, trip_record);
comparison = build_comparison(paper_std, repro_std, mapping);
table46 = build_table46_comparison(paper_std, paper_wind_speed);
gap_tbl = build_gap_diagnosis();
priority_tbl = build_fix_priority();

writetable(mapping, fullfile(table_dir, 'paper_to_reproduction_scenario_mapping.csv'));
writetable(paper_std, fullfile(table_dir, 'paper_benchmark_standardized.csv'));
writetable(repro_std, fullfile(table_dir, 'reproduction_result_standardized.csv'));
writetable(comparison, fullfile(table_dir, 'paper_vs_reproduction_comparison.csv'));
writetable(table46, fullfile(table_dir, 'table46_wind_speed_paper_vs_reproduction.csv'));
writetable(gap_tbl, fullfile(table_dir, 'paper_alignment_gap_diagnosis.csv'));
writetable(priority_tbl, fullfile(table_dir, 'next_model_fix_priority.csv'));

plot_paper_alignment_figures(table_dir, fig_dir);

log_file = fullfile(log_dir, 'paper_benchmark_comparison_log.txt');
fid = fopen(log_file, 'w', 'n', 'UTF-8');
cleaner = onCleanup(@() fclose(fid));
fprintf(fid, 'Paper benchmark comparison generated.\n');
fprintf(fid, 'paper_rows=%d\n', height(paper_tbl));
fprintf(fid, 'mapping_rows=%d\n', height(mapping));
fprintf(fid, 'comparison_rows=%d\n', height(comparison));
fprintf(fid, 'gap_rows=%d\n', height(gap_tbl));
fprintf('Paper benchmark comparison generated: %s\n', out_root);
end

function ensure_dir(path)
if ~exist(path, 'dir')
    mkdir(path);
end
end

function tbl = read_optional_table(path)
if exist(path, 'file')
    tbl = readtable(path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
else
    tbl = table();
end
end

function mapping = build_mapping(paper_tbl)
paper_tables = string(paper_tbl.paper_figure_or_table);
paper_scenarios = string(paper_tbl.scenario_id);
keys = unique(strcat(paper_tables, "||", paper_scenarios), 'stable');
rows = cell(numel(keys), 6);
for i = 1:numel(keys)
    parts = split(keys(i), "||");
    paper_table = parts(1);
    paper_scenario = parts(2);
    [repro, status, can_compare, note] = map_one_scenario(paper_table, paper_scenario);
    rows(i, :) = {paper_table, paper_scenario, repro, status, note, can_compare};
end
mapping = cell2table(rows, 'VariableNames', {'paper_table','paper_scenario_id','reproduction_scenario_id','mapping_status','mapping_note','can_compare_directly'});
end

function [repro, status, can_compare, note] = map_one_scenario(paper_table, paper_scenario)
repro = "";
status = "not_directly_mapped";
can_compare = false;
note = "no direct engineering result for this paper scenario";
if paper_table == "Table 4-4" && paper_scenario == "distributed_3000mw"
    repro = "distributed_wind_3000mw_base";
    status = "mapped";
    can_compare = true;
    note = "distributed 3000MW scenario maps to current 3000MW distributed baseline";
elseif paper_table == "Table 4-4" && paper_scenario == "centralized_3000mw"
    repro = "centralized_wind_40pct";
    status = "partially_mapped";
    can_compare = false;
    note = "centralized bus is assumed in current engineering case and paper_formula is diagnostic_only";
elseif paper_table == "Table 4-5" && startsWith(paper_scenario, "penetration_")
    token = regexp(paper_scenario, 'penetration_(\d+)pct', 'tokens', 'once');
    repro = "distributed_wind_penetration_" + token{1} + "pct";
    status = "partially_mapped";
    can_compare = false;
    note = "penetration definition uses current wind_capacity/base_load assumption; trend comparison only";
elseif paper_table == "Table 4-6"
    token = regexp(paper_scenario, 'wind_speed_(\d+)_(\d+)mps', 'tokens', 'once');
    if isempty(token)
        repro = "";
    else
        repro = "paper_wind_speed_" + token{1} + "_" + token{2} + "mps";
    end
    status = "mapped_after_paper_wind_speed_batch";
    can_compare = false;
    note = "paper wind speed batch exists, but current result is line-only paper_formula without P_wt/P_ge";
elseif paper_table == "Table 4-2"
    if paper_scenario == "scenario_1_without_renewable_trip"
        repro = "distributed_wind_3000mw_base";
    else
        repro = "distributed_wind_40pct_trip_record_only";
    end
    status = "not_directly_mapped";
    can_compare = false;
    note = "current renewable trip mode is record_only and does not trigger actual renewable outage";
end
end

function paper_std = standardize_paper_benchmark(paper_tbl)
paper_std = table();
paper_std.paper_table = string(paper_tbl.paper_figure_or_table);
paper_std.paper_scenario_id = string(paper_tbl.scenario_id);
paper_std.metric_name = string(paper_tbl.metric_name);
paper_std.confidence_level = paper_tbl.confidence_level;
paper_std.paper_value = paper_tbl.paper_value;
paper_std.paper_unit = string(paper_tbl.unit);
paper_std.paper_value_dimensionless_candidate = paper_tbl.paper_value * 1e-4;
paper_std.source_note = string(paper_tbl.source_note);
end

function repro_std = standardize_reproduction_results(topology, penetration, wind_speed, paper_wind_speed, trip_record)
repro_std = table('Size', [0, 9], ...
    'VariableTypes', {'string','string','string','string','double','double','string','string','string'}, ...
    'VariableNames', {'reproduction_scenario_id','source_final_table','metric_family','metric_name','confidence_level','reproduction_value_raw','reproduction_value_unit_note','paper_result_status','overall_status'});
repro_std = append_result_table(repro_std, topology, "final_topology_comparison.csv");
repro_std = append_result_table(repro_std, penetration, "final_penetration_scan.csv");
repro_std = append_result_table(repro_std, wind_speed, "final_wind_speed_scan.csv");
repro_std = append_result_table(repro_std, paper_wind_speed, "scenario_result_summary_paper_wind_speed_scan.csv");
repro_std = append_result_table(repro_std, trip_record, "final_renewable_trip_record.csv");
if isempty(repro_std)
    repro_std = table();
    return;
end
repro_std.can_use_for_comparison = repmat("true_for_CRI_only", height(repro_std), 1);
repro_std.note = repmat("final_summary contains CRI at sigma=0.95; SLLR/SLFOR/SNVOR are not available in these summary tables", height(repro_std), 1);
end

function out = append_result_table(out, tbl, source_name)
if isempty(tbl) || height(tbl) == 0 || ~ismember('scenario_id', tbl.Properties.VariableNames)
    return;
end
families = ["basic", "weighted", "paper_formula"];
cols = ["basic_CRI_095", "weighted_CRI_095", "paper_CRI_095"];
for i = 1:height(tbl)
    for j = 1:numel(families)
        if ~ismember(cols(j), string(tbl.Properties.VariableNames))
            continue;
        end
        row = {string(tbl.scenario_id(i)), source_name, families(j), "CRI", 0.95, tbl.(cols(j))(i), ...
            "current final_summary raw value; unit alignment with paper 10^-4 pending", get_status(tbl, i), get_overall(tbl, i)};
        out = [out; row]; %#ok<AGROW>
    end
end
end

function status = get_status(tbl, i)
if ismember('paper_result_status', tbl.Properties.VariableNames)
    status = string(tbl.paper_result_status(i));
else
    status = "";
end
end

function status = get_overall(tbl, i)
if ismember('overall_status', tbl.Properties.VariableNames)
    status = string(tbl.overall_status(i));
else
    status = "";
end
end

function comparison = build_comparison(paper_std, repro_std, mapping)
comparison = table('Size', [0, 16], ...
    'VariableTypes', {'string','string','string','string','string','double','double','string','double','double','double','double','double','double','string','string'}, ...
    'VariableNames', {'paper_table','paper_scenario_id','reproduction_scenario_id','metric_name','metric_family','confidence_level','paper_value','paper_unit','paper_value_dimensionless_candidate','reproduction_value_raw','absolute_error_raw','relative_error_raw','absolute_error_vs_dimensionless_candidate','relative_error_vs_dimensionless_candidate','comparison_status','diagnosis_note'});

for i = 1:height(paper_std)
    ptable = string(paper_std.paper_table(i));
    pscene = string(paper_std.paper_scenario_id(i));
    pmetric = string(paper_std.metric_name(i));
    mrow = mapping(string(mapping.paper_table) == ptable & string(mapping.paper_scenario_id) == pscene, :);
    if isempty(mrow)
        mrow = table(ptable, pscene, "", "not_directly_mapped", "no mapping row", false, ...
            'VariableNames', {'paper_table','paper_scenario_id','reproduction_scenario_id','mapping_status','mapping_note','can_compare_directly'});
    end
    repro_id = string(mrow.reproduction_scenario_id(1));
    candidates = repro_std(string(repro_std.reproduction_scenario_id) == repro_id & string(repro_std.metric_name) == pmetric & repro_std.confidence_level == paper_std.confidence_level(i), :);
    if isempty(candidates)
        comparison = [comparison; make_comparison_row(paper_std(i, :), repro_id, "", NaN, status_for_missing(ptable, pmetric, mrow), string(mrow.mapping_note(1)))]; %#ok<AGROW>
    else
        for j = 1:height(candidates)
            status = status_for_candidate(ptable, pscene, pmetric, mrow, candidates(j, :));
            note = diagnosis_for_candidate(status, mrow, candidates(j, :));
            comparison = [comparison; make_comparison_row(paper_std(i, :), repro_id, string(candidates.metric_family(j)), candidates.reproduction_value_raw(j), status, note)]; %#ok<AGROW>
        end
    end
end
end

function status = status_for_missing(paper_table, metric_name, mapping_row)
if paper_table == "Table 4-6"
    status = "not_comparable_missing_reproduction";
elseif paper_table == "Table 4-2"
    status = "not_comparable_model_missing";
elseif metric_name ~= "CRI"
    status = "not_comparable_unit_uncertain";
elseif string(mapping_row.mapping_status(1)) == "missing_reproduction"
    status = "not_comparable_missing_reproduction";
else
    status = "not_comparable_unit_uncertain";
end
end

function status = status_for_candidate(paper_table, paper_scenario, metric_name, mapping_row, candidate)
if paper_table == "Table 4-2"
    status = "not_comparable_model_missing";
elseif string(candidate.paper_result_status(1)) == "diagnostic_only" && string(candidate.metric_family(1)) == "paper_formula"
    status = "not_comparable_diagnostic_only";
elseif metric_name ~= "CRI"
    status = "not_comparable_unit_uncertain";
elseif paper_table == "Table 4-6"
    status = "comparable_with_caution";
elseif paper_table == "Table 4-4" && paper_scenario == "distributed_3000mw"
    status = "comparable_with_caution";
elseif paper_table == "Table 4-5"
    status = "comparable_with_caution";
elseif string(mapping_row.can_compare_directly(1)) == "true"
    status = "comparable";
else
    status = "comparable_with_caution";
end
end

function note = diagnosis_for_candidate(status, mapping_row, candidate)
if status == "not_comparable_diagnostic_only"
    note = "reproduction paper_formula is diagnostic_only; do not treat NaN as zero";
elseif status == "not_comparable_unit_uncertain"
    note = "current final_summary lacks corresponding SLLR/SLFOR/SNVOR or unit alignment is pending";
elseif status == "comparable_with_caution"
    note = "raw comparison only; current line-only paper_formula and engineering parameters differ from paper";
else
    note = string(mapping_row.mapping_note(1));
end
if string(candidate.metric_family(1)) ~= ""
    note = note + "; metric_family=" + string(candidate.metric_family(1));
end
end

function row = make_comparison_row(paper_row, repro_id, family, repro_value, status, note)
paper_value = paper_row.paper_value;
paper_dim = paper_row.paper_value_dimensionless_candidate;
if isnan(repro_value)
    abs_raw = NaN;
    rel_raw = NaN;
    abs_dim = NaN;
    rel_dim = NaN;
else
    abs_raw = abs(repro_value - paper_value);
    rel_raw = safe_relative(abs_raw, paper_value);
    abs_dim = abs(repro_value - paper_dim);
    rel_dim = safe_relative(abs_dim, paper_dim);
end
row = {string(paper_row.paper_table), string(paper_row.paper_scenario_id), repro_id, string(paper_row.metric_name), family, ...
    paper_row.confidence_level, paper_value, string(paper_row.paper_unit), paper_dim, repro_value, abs_raw, rel_raw, abs_dim, rel_dim, status, note};
end

function table46 = build_table46_comparison(paper_std, paper_wind_speed)
%BUILD_TABLE46_COMPARISON 生成论文表4-6风速点专用对照表。
table46 = table('Size', [0, 11], ...
    'VariableTypes', {'double','double','double','double','double','double','double','double','string','string','string'}, ...
    'VariableNames', {'wind_speed_mps','paper_SLLR','paper_SLFOR','paper_SNVOR','paper_CRI','repro_basic_CRI','repro_weighted_CRI','repro_paper_CRI','paper_result_status','comparison_status','diagnosis_note'});
rows = paper_std(string(paper_std.paper_table) == "Table 4-6", :);
if isempty(rows)
    return;
end
scenario_ids = unique(string(rows.paper_scenario_id), 'stable');
for i = 1:numel(scenario_ids)
    sid = scenario_ids(i);
    speed = parse_table46_speed(sid);
    repro_id = "paper_" + sid;
    paper_vals = metric_values_for_scenario(rows, sid);
    basic = NaN; weighted = NaN; paper_cri = NaN; paper_status = "missing_reproduction";
    comparison_status = "not_comparable_missing_reproduction";
    note = "paper wind speed reproduction result is missing";
    if ~isempty(paper_wind_speed) && height(paper_wind_speed) > 0 && any(string(paper_wind_speed.scenario_id) == repro_id)
        r = paper_wind_speed(string(paper_wind_speed.scenario_id) == repro_id, :);
        basic = r.basic_CRI_095(1);
        weighted = r.weighted_CRI_095(1);
        paper_cri = r.paper_CRI_095(1);
        paper_status = string(r.paper_result_status(1));
        if paper_status == "diagnostic_only"
            comparison_status = "not_comparable_diagnostic_only";
            note = "paper_formula is diagnostic_only; keep NaN and do not treat as zero";
        else
            comparison_status = "comparable_with_caution";
            note = "thesis wind-speed point is reproduced, but current model is line-only and unit alignment is pending";
        end
    end
    table46 = [table46; {speed, paper_vals.SLLR, paper_vals.SLFOR, paper_vals.SNVOR, paper_vals.CRI, ...
        basic, weighted, paper_cri, paper_status, comparison_status, note}]; %#ok<AGROW>
end
table46 = sortrows(table46, 'wind_speed_mps');
end

function values = metric_values_for_scenario(rows, scenario_id)
values = struct('SLLR', NaN, 'SLFOR', NaN, 'SNVOR', NaN, 'CRI', NaN);
metrics = ["SLLR", "SLFOR", "SNVOR", "CRI"];
for k = 1:numel(metrics)
    idx = string(rows.paper_scenario_id) == scenario_id & string(rows.metric_name) == metrics(k);
    if any(idx)
        values.(metrics(k)) = rows.paper_value(find(idx, 1));
    end
end
end

function speed = parse_table46_speed(scenario_id)
token = regexp(string(scenario_id), 'wind_speed_(\d+)_(\d+)mps', 'tokens', 'once');
if isempty(token)
    speed = NaN;
else
    speed = str2double(token{1}) + str2double(token{2}) / 100;
end
end

function r = safe_relative(abs_err, base_value)
if isnan(base_value) || base_value == 0
    r = NaN;
else
    r = abs_err / abs(base_value);
end
end

function gap_tbl = build_gap_diagnosis()
rows = {
    "G01","Table 4-2; Table 4-5","renewable trip scenarios","SLLR/SLFOR/SNVOR/CRI","model_missing","P_wt(E_k) is still fixed to 1 and actual renewable trip states are not included.","Renewable trip is record_only and does not create outage state transitions.","Implement actual renewable trip state transition and P_wt(E_k).","P0",false
    "G02","All","all scenarios","SLLR/SLFOR/SNVOR/CRI","model_missing","P_ge(E_k) is still fixed to 1 and conventional generator outage states are not included.","Conventional generator protection and outage probability model is missing.","Record and implement P_G(q) and conventional generator state transitions.","P0",false
    "G03","All","line cascade scenarios","SLFOR/CRI","parameter_gap","Subsequent line outage probability parameters are not calibrated to the thesis.","Current project uses an engineering piecewise outage probability model.","Replace line outage probability with thesis formula and calibrated parameters.","P0",false
    "G04","All","load shedding states","SLLR/CRI","model_simplification","Current load shedding is simplified and does not implement thesis OLS.","simple_load_shedding is not equivalent to the thesis optimal load shedding model.","Implement the optimal load shedding model in equations 3-19 to 3-26.","P0",true
    "G05","Table 4-6","wind speed 11.28/11.52/11.76/12.00","SLLR/SLFOR/SNVOR/CRI","line_only_reproduction_available","The formal Table 4-6 wind speed points have been rerun, but only under the current line-only model.","P_wt/P_ge, OLS, outage probability parameters, unit scaling, and thesis case data are still not fully aligned.","Use the new Table 4-6 batch as cautious comparison and rerun after model calibration.","P1",true
    "G06","Table 4-4","centralized_3000mw","CRI","unknown_need_paper","Centralized access bus is unknown, so current centralized result is unreliable.","Current project uses a calibration assumption and paper_formula is diagnostic_only.","Confirm centralized access bus from the thesis and rerun.","P0",false
    "G07","All","all scenarios","all metrics","unit_uncertain","Units/scales between reproduction and paper benchmark are not aligned yet.","Paper benchmark unit is 10^-4 while reproduction raw values are not finally scaled.","Confirm VaR risk-value unit and scaling definition.","P0",false
    "G08","Table 4-5","penetration scan","all metrics","definition_gap","Renewable penetration definition still needs confirmation.","Current project uses wind_capacity/base_load and the thesis denominator must be checked.","Confirm penetration definition and update scenarios.","P1",false
    "G09","All","IEEE39 case","all metrics","data_gap","Full IEEE39 bus/gen/branch thesis modifications are not confirmed.","Current project keeps MATPOWER case39 reference structure.","Record complete thesis case parameters.","P1",false
    "G10","All","nonconverged stages","LFOR/NVOR/CRI","method_gap","Nonconverged-stage handling is an engineering safety rule and thesis rule is unknown.","The project excludes nonconverged PF/PT/VM from LFOR/NVOR to avoid nonphysical contamination.","Confirm thesis handling for nonconvergence or islanding.","P1",false
    };
gap_tbl = cell2table(rows, 'VariableNames', {'gap_id','paper_table','affected_scenarios','affected_metrics','gap_type','gap_description','likely_cause','required_fix','priority','can_fix_without_more_paper_input'});
end

function priority_tbl = build_fix_priority()
rows = {
    1,"Implement thesis optimal load shedding model OLS","SLLR strongly depends on load-loss consequence modeling.",true,"Equation 3-19 to 3-26 variables, limits, and parameters","Add OPF/OLS solver and keep simple_load_shedding as comparison","OLS load-loss details and SLLR comparison","Implement thesis OLS and keep the simple version as a baseline."
    2,"Implement thesis subsequent line outage probability","Line transition probabilities directly affect Markov chains.",true,"P_L0, L_Rated, L_max, hidden-failure parameters","Replace line_outage_probability and connect paper_inputs","Line outage probability diagnostics","Implement configurable thesis line outage probability from paper_inputs."
    3,"Use Table 4-6 wind speed rerun for cautious comparison","Formal 11.28/11.52/11.76/12.00 mps reproduction now exists under the current line-only model.",false,"Wind speed points and benchmark already recorded","Keep paper_wind_speed_scan isolated from engineering wind_speed_scan","Table 4-6 paper vs reproduction comparison","After model calibration, rerun paper_wind_speed_scan and regenerate alignment tables."
    4,"Implement renewable actual trip transition and P_wt(E_k)","Table 4-2 depends on actual renewable trip modeling.",true,"P_WT(h) probability function and action rules","Upgrade record_only to state transition","Renewable outage path and P_wt details","Implement actual renewable trip state transition."
    5,"Implement conventional generator outage and P_ge(E_k)","Full thesis state probability requires conventional generator term.",true,"P_G(q) parameters and protection thresholds","Add conventional generator transition module","P_ge details and risk comparison","Implement conventional generator outage probability and state transition."
    6,"Align centralized access bus","Table 4-4 centralized result is not directly comparable.",true,"Centralized access bus or equivalent access definition","Update scenario_library and rerun topology","Centralized comparison result","Confirm centralized access bus from the thesis."
    7,"Align complete IEEE39 parameters","Case parameter differences affect all metrics.",true,"Complete bus/gen/branch parameter tables","Update build_case39_base or input layer","Basecase consistency report","Record complete thesis IEEE39 modified case parameters."
    8,"Build final paper benchmark figures","Final calibrated models are needed for final thesis plots.",false,"Completed calibrated reproduction results","Update comparison scripts and figures","Final error tables and paper figures","Regenerate benchmark comparison after model calibration."
    };
priority_tbl = cell2table(rows, 'VariableNames', {'priority_rank','fix_target','why_needed','depends_on_paper_input','required_inputs','expected_code_changes','expected_outputs','recommended_next_codex_task'});
end
