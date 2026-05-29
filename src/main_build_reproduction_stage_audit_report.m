function main_build_reproduction_stage_audit_report()
%MAIN_BUILD_REPRODUCTION_STAGE_AUDIT_REPORT Build a read-only reproduction stage audit.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'stage_audit');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

input_status = collect_input_status(project_root);
module_status = build_module_status(project_root);
missing_inputs = build_missing_inputs_register();
available_results = build_available_results_index(project_root);
claims_not_allowed = build_claims_not_allowed();
roadmap = build_next_step_roadmap();

writetable(module_status, fullfile(out_dir, 'reproduction_module_status.csv'));
writetable(missing_inputs, fullfile(out_dir, 'missing_original_inputs_register.csv'));
writetable(available_results, fullfile(out_dir, 'current_available_results_index.csv'));
writetable(claims_not_allowed, fullfile(out_dir, 'claims_not_allowed_yet.csv'));
writetable(roadmap, fullfile(out_dir, 'next_step_roadmap.csv'));
write_markdown_report(project_root, input_status, module_status, missing_inputs, available_results, claims_not_allowed, roadmap);

fprintf('reproduction stage audit report written: %s\n', out_dir);
end

function input_status = collect_input_status(project_root)
paths = [
    "paper_inputs/validated/paper_input_validation_summary.csv"
    "paper_inputs/validated/paper_result_benchmark_summary.csv"
    "results/paper_alignment/tables/paper_vs_reproduction_comparison.csv"
    "results/paper_alignment/tables/paper_alignment_gap_diagnosis.csv"
    "results/loadshedding/ols_benchmark_smoke/tables/ols_formulation_comparison.csv"
    "results/outage/line_probability_parameter_smoke_summary.csv"
    "results/renewable/wind_state_probability_model_check_log.txt"
    "results/generator/generator_state_probability_model_check_log.txt"
    "results/composite/unified_state_probability_diagnostic_check_log.txt"
    "results/composite/unified_stage_level_risk_preview.csv"
    "results/composite/stage_level_vs_chain_summary_risk_preview_comparison.csv"
    ];
exists_flag = false(numel(paths), 1);
status = strings(numel(paths), 1);
for i = 1:numel(paths)
    exists_flag(i) = exist(fullfile(project_root, paths(i)), 'file') == 2;
    if exists_flag(i)
        status(i) = "available";
    else
        status(i) = "missing";
    end
end
input_status = table(paths, exists_flag, status, ...
    'VariableNames', {'relative_path','exists','status'});
end

function module_status = build_module_status(project_root)
rows = {
"paper_inputs","Paper input data layer","implemented_diagnostic","validation summaries available","ready_for_next_calibration_step","paper_inputs/validated/paper_input_validation_summary.csv","filled data still depends on manual paper verification","continue extracting original formulas and parameters";
"paper_benchmark","Paper benchmark tables","benchmark_ready","Table 4-2/4-4/4-5/4-6 benchmark summary available","ready_for_next_calibration_step","paper_inputs/filled/paper_result_benchmark.csv","benchmark values are input targets, not reproduction success","keep immutable and compare cautiously";
"initial_line_outage_probability_table4_1","Initial line outage probability Table 4-1","implemented_but_not_calibrated","46-line table copied and validated","ready_for_next_calibration_step","data/line_initial_outage_probability_paper_table_4_1.csv","must not be assumed to equal all subsequent P_L terms","confirm original intended use";
"topology_compare","Topology comparison scenarios","implemented_engineering","final topology comparison exists","not_ready_for_formal_benchmark","results/final_summary/tables/final_topology_comparison.csv","centralized node remains diagnostic","confirm centralized access node";
"penetration_scan","Penetration scan scenarios","implemented_engineering","40%-80% engineering scan exists","not_ready_for_formal_benchmark","results/final_summary/tables/final_penetration_scan.csv","penetration definition and probability model are not calibrated","confirm penetration definition and capacity scaling";
"wind_speed_scan","Engineering wind speed scan","implemented_engineering","8/10/12/14/16 mps engineering scan exists","not_ready_for_formal_benchmark","results/final_summary/tables/final_wind_speed_scan.csv","not the paper Table 4-6 wind points","keep separate from paper Table 4-6";
"paper_table46_wind_speed_scan","Paper Table 4-6 wind speed smoke","implemented_diagnostic","11.28/11.52/11.76/12.00 mps run and compared","not_ready_for_formal_benchmark","results/paper_alignment/tables/table46_wind_speed_paper_vs_reproduction.csv","line-only and diagnostic probability assumptions remain","rerun after original P_L/P_wt/P_ge calibration";
"OLS_load_shedding","Optimal load shedding OLS","implemented_diagnostic","multiple AC/DC/dispatchable diagnostic variants tested","not_ready_for_formal_benchmark","results/loadshedding/ols_benchmark_smoke/tables/ols_formulation_comparison.csv","AC-OLS variants remain too unstable for formal benchmark","ask for paper AC/DC/solver settings before formalization";
"line_subsequent_outage_probability_P_L","Line subsequent outage probability P_L","implemented_but_not_calibrated","paper_formula interface and sensitivity diagnostics completed","missing_original_parameters","results/outage/line_probability_parameter_smoke_summary.csv","P_L0/Lmax/hidden-failure parameters missing","extract original parameters or define calibration workflow";
"wind_trip_probability_P_wt","Wind trip probability P_wt","implemented_diagnostic","P_WT/P_wt diagnostic and stress tests completed","missing_original_parameters","results/renewable/wind_state_probability_model_check_log.txt","paper probability function and actual trip transition missing","extract P_WT function and state transition rule";
"generator_outage_probability_P_ge","Generator outage probability P_ge","implemented_diagnostic","P_G/P_ge diagnostic and stress tests completed","missing_original_parameters","results/generator/generator_state_probability_model_check_log.txt","paper thresholds/probability and dynamic frequency missing","extract P_G parameters and transition rule";
"composite_state_probability","Composite state probability","implemented_diagnostic","offline and unified P_line*P_wt*P_ge diagnostics completed","not_ready_for_formal_benchmark","results/composite/unified_state_probability_diagnostic_check_log.txt","component parameters are diagnostic and P_wt/P_ge are inactive in current smoke","use unified smoke after calibration";
"stage_level_severity","Stage-level severity","implemented_diagnostic","same-stage severity and probability x severity preview completed","not_ready_for_formal_benchmark","results/composite/unified_stage_level_risk_preview.csv","diagnostic risk preview, not formal VaR","upgrade after calibrated probabilities and paper severity confirmation";
"paper_benchmark_alignment","Paper benchmark alignment","implemented_diagnostic","paper vs reproduction comparison and gap diagnosis exist","not_ready_for_formal_benchmark","results/paper_alignment/tables/paper_vs_reproduction_comparison.csv","unit/model/parameter basis not aligned","maintain caution labels and rerun after calibration"
};
module_status = cell2table(rows, 'VariableNames', {'module_id','module_name','implementation_status', ...
    'validation_status','formal_reproduction_status','key_outputs','main_limitation','recommended_next_step'});
for i = 1:height(module_status)
    if exist(fullfile(project_root, module_status.key_outputs{i}), 'file') ~= 2
        module_status.key_outputs{i} = [module_status.key_outputs{i} ' (missing or optional)'];
    end
end
end

function tbl = build_missing_inputs_register()
rows = {
"L01","line_P_L","P_L0 是否应等于表4-1或另有基础概率","P_L","missing","table4_1_P_L0_only diagnostic assumption","sets base flow-related outage probability","paper Section 3.1.1 or ask user","P0";
"L02","line_P_L","L_Rated","P_L","missing","rateA factor diagnostic assumption","defines first breakpoint of flow probability","paper Section 3.1.1","P0";
"L03","line_P_L","L_max","P_L","missing","1.2*rateA diagnostic assumption","defines overload probability saturation","paper Section 3.1.1","P0";
"L04","line_P_L","P_W_D","P_L distance hidden failure","missing","distance hidden failure disabled","needed for distance protection hidden failure","paper Section 3.1.1 equation 3-4","P0";
"L05","line_P_L","Z_III","P_L distance hidden failure","missing","no impedance parameter used","needed for distance hidden failure","paper Section 3.1.1","P0";
"L06","line_P_L","P_L_D","P_L loading hidden failure","missing","low/medium diagnostic assumptions only","needed for overload protection hidden failure","paper Section 3.1.1","P0";
"L07","line_P_L","P_L_r","P_L loading hidden failure","missing","low/medium diagnostic assumptions only","needed for severe overload hidden failure","paper Section 3.1.1","P0";
"L08","line_P_L","P3","P_L total probability","missing_or_zero_assumption","P3=0 diagnostic placeholder","other outage factor in P_L=P1+P2+P3","paper Section 3.1.1","P1";
"W01","wind_P_wt","P_WT(h) 完整概率函数","P_wt","missing","diagnostic linear voltage probability","required to compute paper wind state probability","paper Section 3.1.3","P0";
"W02","wind_P_wt","LVRT/HVRT 持续时间到概率的映射","P_wt","missing","threshold record only","connects ride-through curve to trip probability","paper Section 2.2/3.1.3","P0";
"W03","wind_P_wt","FRT 频率区间持续时间到概率的映射","P_wt","missing","frequency thresholds recorded but no probability mapping","needed for frequency trip probability","paper Section 3.1.3","P0";
"W04","wind_P_wt","实际风机脱网状态转移抽样规则","wind actual trip","missing","record_only diagnostic","needed to reproduce Table 4-2 with trip states","paper Chapter 3 cascade algorithm","P0";
"G01","generator_P_ge","P_G_f0","P_ge","missing","diagnostic voltage/frequency probability","normal frequency base outage probability","paper Section 3.1.2","P0";
"G02","generator_P_ge","P_G_U0","P_ge","missing","diagnostic voltage/frequency probability","normal voltage base outage probability","paper Section 3.1.2","P0";
"G03","generator_P_ge","频率阈值","P_ge","missing","48.5/49.5/50.5/51.5 diagnostic thresholds","defines generator frequency protection regions","paper Section 3.1.2","P0";
"G04","generator_P_ge","电压阈值","P_ge","missing","0.7/0.9/1.1/1.3 diagnostic thresholds","defines generator voltage protection regions","paper Section 3.1.2","P0";
"G05","generator_P_ge","分段线性概率参数","P_ge","missing","diagnostic linear assumptions","needed for paper P_G(q) values","paper Section 3.1.2","P0";
"G06","generator_P_ge","传统机组实际停运状态转移抽样规则","generator actual trip","missing","record_only diagnostic","needed for actual generator outage states","paper cascade state transition description","P0";
"O01","OLS","原文使用 AC-OLS 还是 DC-OLS","OLS","unknown","multiple diagnostic variants tested","determines load shedding model class","paper Section 3.2.3 or implementation appendix","P1";
"O02","OLS","OPF 求解器设置","OLS","unknown","MATPOWER OPF diagnostic variants","needed for reproducible convergence","paper implementation details","P1";
"O03","OLS","是否在所有越限 stage 触发 OLS","OLS","unknown","nonconverged_or_violation diagnostic only","determines when OLS is applied","paper cascade algorithm","P1";
"O04","OLS","是否允许软约束","OLS","unknown","strict and relaxed diagnostics only","affects feasibility and risk","paper solver settings","P1";
"O05","OLS","线路容量/电压边界设置","OLS/severity","partial","RATE_A and 0.9/1.1 approximations","needed for OLS constraints and severity","paper Chapter 4 case settings","P1";
"S01","scenario","集中式接入节点","topology/Table 4-4","missing","current centralized node diagnostic assumption","needed for centralized benchmark","paper Chapter 4 scenario definition","P0";
"S02","scenario","渗透率定义","penetration/Table 4-5","uncertain","engineering wind capacity/base load definition","needed for scenario capacity scaling","paper Chapter 4.4","P0";
"S03","scenario","原文样本数或蒙特卡洛抽样次数","all benchmarks","missing","20-trial engineering setting and 5x3 diagnostics","needed for Monte Carlo comparability","paper Chapter 4 simulation settings","P0";
"S04","scenario","是否使用相同随机种子","all benchmarks","missing","engineering seed only","needed if paper uses seeded Monte Carlo","paper implementation details","P2";
"S05","scenario","原始 IEEE39 修改数据","all benchmarks","partial","MATPOWER case39 reference","needed for strict numerical reproduction","paper appendix or user-provided tables","P0";
"S06","scenario","风电容量分配方式","wind/penetration/table46","partial","distributed engineering allocation","needed for exact wind dispatch","paper Chapter 4 scenario definition","P0"
};
tbl = cell2table(rows, 'VariableNames', {'input_id','category','parameter_or_information', ...
    'needed_for_module','current_status','current_fallback_or_diagnostic_assumption', ...
    'why_needed','where_to_find_or_ask_user','priority'});
end

function tbl = build_available_results_index(project_root)
rows = {
"paper_inputs","paper_inputs/filled/paper_result_benchmark.csv","Original paper benchmark values entered from paper","paper benchmark comparison","manual final verification still required";
"paper_alignment","results/paper_alignment/tables/paper_vs_reproduction_comparison.csv","paper vs current reproduction comparison","gap diagnosis and cautious comparison","not strict numeric reproduction";
"paper_alignment","results/paper_alignment/tables/table46_wind_speed_paper_vs_reproduction.csv","Table 4-6 wind-speed comparison","paper Table 4-6 diagnostic comparison","line-only and uncalibrated";
"OLS","results/loadshedding/ols_benchmark_smoke/tables/ols_benchmark_smoke_summary.csv","simple vs OLS smoke summary","OLS directionality study","5-trial smoke only, high failure rates";
"OLS","docs/ols_stage_conclusion.md","OLS staged conclusion","methodology write-up","OLS not ready for formal benchmark";
"line_P_L","results/outage/line_probability_parameter_smoke_summary.csv","P_L diagnostic parameter-set smoke summary","sensitivity analysis","diagnostic assumptions only";
"wind_P_wt","results/renewable/wind_state_probability_effect_summary.csv","P_wt effect summary","wind probability diagnostic","current Markov smoke has P_wt=1";
"generator_P_ge","results/generator/generator_state_probability_effect_summary.csv","P_ge effect summary","generator probability diagnostic","static frequency and P_ge=1 in smoke";
"composite","results/composite/unified_state_probability_diagnostic_smoke/unified_state_probability_stage_details.csv","same-run P_line/P_wt/P_ge/P_total stage table","primary composite diagnostic","diagnostic only";
"stage_severity","results/composite/unified_state_probability_diagnostic_smoke/stage_severity_details.csv","same-run stage severity detail","stage-level risk preview","not formal VaR";
"stage_severity","results/composite/unified_stage_level_risk_preview.csv","P_total times stage severity preview","diagnostic risk preview","not final benchmark"
};
tbl = cell2table(rows, 'VariableNames', {'result_group','file_path','description','can_be_used_for','caveat'});
for i = 1:height(tbl)
    if exist(fullfile(project_root, tbl.file_path{i}), 'file') ~= 2
        tbl.caveat{i} = [tbl.caveat{i} '; file currently missing'];
    end
end
end

function tbl = build_claims_not_allowed()
rows = {
"已经严格复现论文表4-2/4-4/4-5/4-6","current results use engineering/diagnostic parameters and incomplete state transitions","original parameters and formal benchmark reruns";
"OLS 已经替代 simple_load_shedding","OLS remains diagnostic and unstable for formal benchmark","confirmed AC/DC OLS settings and acceptable failure rate";
"P_L 已按原文参数校准","P_L parameter sets are diagnostic-only","paper-extracted or calibrated original P_L parameters";
"P_wt 已按原文概率函数实现","P_WT full probability function is missing","paper P_WT function and transition rule";
"P_ge 已按原文概率函数实现","P_G thresholds/probabilities and dynamic frequency are missing","paper P_G parameters and transition rule";
"综合状态概率已经进入正式 paper_formula","composite probability is offline/unified diagnostic only","formal integration after all component calibration";
"当前结果可直接作为论文数值对照","unit/model/parameter bases are not aligned","calibrated reruns and unit alignment";
"当前静态潮流频率可代表真实动态频率","static power flow uses nominal 50 Hz only","dynamic frequency model or paper-defined frequency approximation";
"diagnostic 参数集就是论文原文参数","diagnostic assumptions are placeholders","user-confirmed original parameters"
};
tbl = cell2table(rows, 'VariableNames', {'claim','reason_not_allowed','required_before_claim'});
end

function tbl = build_next_step_roadmap()
rows = {
1,"向用户索要或从 PDF 精读提取第3.1.1、3.1.2、3.1.3完整参数","all core probability modules are blocked by missing original parameters",true,"P_L, P_WT, P_G formula parameters and transition rules","update paper_inputs only","complete original input register","parameters are readable and mapped to template fields";
2,"建立 original_paper_extracted 参数集","diagnostic sets cannot support formal reproduction",true,"confirmed original parameter values","add original_paper_extracted rows and validators","validated paper parameter sets","all P0 probability parameters resolved";
3,"用 original_paper_extracted 参数集重跑 unified diagnostic smoke","single-run component integration is ready",true,"validated parameter sets","run 5x3 unified diagnostic only","updated unified probability and stage-level risk tables","fallback/missing count is zero or explicitly justified";
4,"选择一个最小正式 benchmark 场景做 20-trial diagnostic rerun","test calibrated pipeline before broad sweeps",false,"none if parameters are ready","add isolated diagnostic batch, not final_summary","20-trial diagnostic comparison table","stable and interpretable against paper benchmark";
5,"扩展到 Table 4-6 风速点","Table 4-6 already has scenario definitions and benchmark",false,"confirmed wind model and scenario settings","rerun paper wind speed batch with calibrated probabilities","Table 4-6 calibrated diagnostic comparison","errors explainable and no diagnostic_only status";
6,"扩展到 Table 4-5 渗透率扫描","penetration risk is sensitive and should follow smaller validation",true,"penetration definition and capacity allocation","rerun calibrated penetration diagnostic","Table 4-5 calibrated diagnostic comparison","definition matches paper and parameters calibrated";
7,"最后才考虑 OLS 正式化","OLS remains solver/model unstable",true,"AC/DC choice, solver settings, trigger rules","possibly refactor OLS formulation","OLS-ready benchmark variant","failure rate acceptable and paper settings confirmed";
8,"如仍无法获得参数，转向“复现骨架 + 敏感性分析”写法","prevents unsupported numeric claims",false,"none","documentation and sensitivity framing","thesis-ready limitations section","all diagnostic assumptions clearly labeled"
};
tbl = cell2table(rows, 'VariableNames', {'priority_rank','next_task','why_this_next', ...
    'depends_on_user_input','required_user_input','expected_code_work','expected_outputs','go_no_go_criteria'});
end

function write_markdown_report(project_root, input_status, module_status, missing_inputs, available_results, claims_not_allowed, roadmap)
doc_path = fullfile(project_root, 'docs', 'reproduction_stage_audit_report.md');
fid = fopen(doc_path, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '# 复现阶段性总审计报告\n\n');
fprintf(fid, '## 1. 当前复现阶段结论\n\n');
fprintf(fid, '当前工程已经形成论文复现骨架：paper inputs、paper benchmark、scenario comparison、P_L/P_wt/P_ge diagnostic、unified composite probability、stage-level severity 均已建立。\n\n');
fprintf(fid, '明确结论：不能声称严格复现。当前结果适合用于复现流程骨架、差距审计、敏感性分析和后续校准准备；不适合作为论文表4-2/4-4/4-5/4-6的严格数值复现。\n\n');

fprintf(fid, '## 2. 已完成内容\n\n');
write_bullets(fid, string(module_status.module_name) + ": " + string(module_status.implementation_status));

fprintf(fid, '\n## 3. benchmark 录入情况\n\n');
fprintf(fid, 'Table 4-2、Table 4-4、Table 4-5、Table 4-6 benchmark 已录入并用于对照。它们是论文原文 benchmark 输入，不是当前工程复现成功的证据。\n\n');

fprintf(fid, '## 4. 当前工程结果与论文 benchmark 的关系\n\n');
fprintf(fid, '当前 benchmark alignment 只能作为谨慎对照。模型中仍包含 engineering 或 diagnostic 假设，单位尺度、概率模型、状态转移和若干场景参数尚未完全统一。\n\n');

fprintf(fid, '## 5. OLS 诊断结论\n\n');
fprintf(fid, 'OLS 已测试 positive-injection free_q、fixed_zero_q、dispatchable_load、DC preshed + AC polish 等变体。当前不建议用 OLS 替代 simple_load_shedding 进行正式 20-trial benchmark，除非获得原文 AC/DC 选择、求解器设置、约束边界和触发规则，并显著降低失败率。\n\n');

fprintf(fid, '## 6. P_L/P_wt/P_ge/composite probability 诊断结论\n\n');
fprintf(fid, 'P_L、P_wt、P_ge 均已形成 diagnostic 框架。P_L 参数敏感性说明线路概率对结果影响显著；P_wt/P_ge 应激测试说明计算链路有效；unified composite smoke 已能在同一次 Markov stage 记录 P_line、P_wt、P_ge、P_total。\n\n');
fprintf(fid, '当前 unified smoke 中 P_wt=1 且 P_ge=1，因此 P_total 退化为 P_line。这是因为当前小样本未触发风机或传统机组风险区，不代表这些分量在原文模型中无影响。\n\n');

fprintf(fid, '## 7. stage-level severity 结论\n\n');
fprintf(fid, 'stage-level severity 已接入 unified smoke，并生成 P_total × severity 的 diagnostic risk preview。该 preview 比旧 chain-summary repeated 版本更严谨，但仍不是正式 VaR，也没有进入 final_summary。\n\n');

fprintf(fid, '## 8. 当前不能声称的内容\n\n');
for i = 1:height(claims_not_allowed)
    fprintf(fid, '- %s：%s。需要：%s。\n', claims_not_allowed.claim{i}, claims_not_allowed.reason_not_allowed{i}, claims_not_allowed.required_before_claim{i});
end

fprintf(fid, '\n## 9. 仍缺原文输入\n\n');
fprintf(fid, '需要用户提供的原文参数清单包括：\n\n');
important = missing_inputs(string(missing_inputs.priority) == "P0", :);
for i = 1:height(important)
    fprintf(fid, '- %s：%s。\n', important.category{i}, important.parameter_or_information{i});
end

fprintf(fid, '\n## 10. 推荐下一步路线\n\n');
for i = 1:height(roadmap)
    fprintf(fid, '%d. %s。Go/No-Go：%s。\n', roadmap.priority_rank(i), roadmap.next_task{i}, roadmap.go_no_go_criteria{i});
end

fprintf(fid, '\n## 11. 给用户的明确问题清单\n\n');
fprintf(fid, '请用户优先提供或确认：\n\n');
fprintf(fid, '- 论文第3.1.1节线路停运概率模型中各参数数值；\n');
fprintf(fid, '- 论文第3.1.2节传统机组频率/电压保护概率参数；\n');
fprintf(fid, '- 论文第3.1.3节新能源机组脱网概率函数；\n');
fprintf(fid, '- 集中式接入节点；\n');
fprintf(fid, '- 原文样本数或蒙特卡洛抽样次数；\n');
fprintf(fid, '- 原始 IEEE39 数据是否为 MATPOWER case39 或经过修改；\n');
fprintf(fid, '- OLS 是 AC 还是 DC，以及求解器约束设置。\n\n');

fprintf(fid, '## 输入文件可用性\n\n');
for i = 1:height(input_status)
    fprintf(fid, '- `%s`: %s\n', input_status.relative_path(i), input_status.status(i));
end

fprintf(fid, '\n## 当前可用结果索引\n\n');
for i = 1:height(available_results)
    fprintf(fid, '- `%s`: %s。用途：%s。注意：%s。\n', available_results.file_path{i}, available_results.description{i}, available_results.can_be_used_for{i}, available_results.caveat{i});
end
end

function write_bullets(fid, lines)
for i = 1:numel(lines)
    fprintf(fid, '- %s\n', lines(i));
end
end
