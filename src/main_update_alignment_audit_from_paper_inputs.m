function main_update_alignment_audit_from_paper_inputs()
%MAIN_UPDATE_ALIGNMENT_AUDIT_FROM_PAPER_INPUTS 将 paper_inputs 校验状态联动到原文差距审计表。
% 输入：
%   results/final_summary/tables/original_paper_gap_audit.csv
%   paper_inputs/validated/paper_input_validation_summary.csv
% 输出：
%   results/final_summary/tables/original_paper_gap_audit_with_input_status.csv
%   results/final_summary/logs/original_paper_gap_audit_input_status_log.txt
% 物理含义：
%   不覆盖原审计表，仅增加每个缺口对应原文输入是否已可用于实现的状态。

project_root = fileparts(fileparts(mfilename('fullpath')));
audit_path = fullfile(project_root, 'results', 'final_summary', 'tables', 'original_paper_gap_audit.csv');
summary_path = fullfile(project_root, 'paper_inputs', 'validated', 'paper_input_validation_summary.csv');
out_path = fullfile(project_root, 'results', 'final_summary', 'tables', 'original_paper_gap_audit_with_input_status.csv');
log_dir = fullfile(project_root, 'results', 'final_summary', 'logs');
if ~exist(log_dir, 'dir')
    mkdir(log_dir);
end

if ~exist(audit_path, 'file')
    error('缺少原文差距审计表：%s', audit_path);
end
if ~exist(summary_path, 'file')
    error('缺少 paper input 校验汇总：%s', summary_path);
end

audit = readtable(audit_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
validation = readtable(summary_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');

audit.input_status = strings(height(audit), 1);
audit.implementation_readiness = strings(height(audit), 1);
for i = 1:height(audit)
    files = map_module_to_inputs(string(audit.module(i)));
    statuses = strings(0, 1);
    for j = 1:numel(files)
        idx = string(validation.input_file) == files(j);
        if any(idx)
            statuses(end+1) = string(validation.status(find(idx, 1))); %#ok<AGROW>
        else
            statuses(end+1) = "missing"; %#ok<AGROW>
        end
    end
    if isempty(statuses)
        audit.input_status(i) = "not_mapped";
        audit.implementation_readiness(i) = "review_manually";
    elseif all(ismember(statuses, ["complete", "validated"]))
        audit.input_status(i) = strjoin(statuses, "|");
        audit.implementation_readiness(i) = "ready_to_implement";
    elseif any(ismember(statuses, ["complete", "validated"])) && any(ismember(statuses, ["missing", "incomplete", "template_only"]))
        audit.input_status(i) = strjoin(statuses, "|");
        audit.implementation_readiness(i) = "partially_ready";
    else
        audit.input_status(i) = strjoin(statuses, "|");
        audit.implementation_readiness(i) = "need_user_input";
    end
end

writetable(audit, out_path);

log_file = fullfile(log_dir, 'original_paper_gap_audit_input_status_log.txt');
fid = fopen(log_file, 'w', 'n', 'UTF-8');
cleaner = onCleanup(@() fclose(fid));
fprintf(fid, 'Original paper gap audit input status generated.\n');
fprintf(fid, 'audit_rows=%d\n', height(audit));
fprintf(fid, 'ready_to_implement=%d\n', sum(audit.implementation_readiness == "ready_to_implement"));
fprintf(fid, 'partially_ready=%d\n', sum(audit.implementation_readiness == "partially_ready"));
fprintf(fid, 'need_user_input=%d\n', sum(audit.implementation_readiness == "need_user_input"));
fprintf('Original paper gap audit input status generated: %s\n', log_file);
end

function files = map_module_to_inputs(module)
files = strings(0, 1);
if contains(module, ["IEEE39", "case39", "基础数据", "负荷水平"])
    files = [files; "paper_system_summary.csv"; "paper_case39_bus.csv"; "paper_case39_gen.csv"; "paper_case39_branch.csv"];
elseif contains(module, "发电机参数")
    files = [files; "paper_case39_gen.csv"];
elseif contains(module, "线路容量")
    files = [files; "paper_case39_branch.csv"];
elseif contains(module, "表4-1")
    files = [files; "paper_line_initial_outage_probability.csv"];
elseif contains(module, "线路后续")
    files = [files; "paper_line_subsequent_outage_model.csv"];
elseif contains(module, ["P_wt", "新能源机组状态概率", "新能源脱网概率"])
    files = [files; "paper_wind_trip_probability_model.csv"; "paper_state_probability_formula.csv"];
elseif contains(module, ["P_ge", "传统机组"])
    files = [files; "paper_generator_outage_model.csv"; "paper_state_probability_formula.csv"];
elseif contains(module, ["P_line", "连锁故障状态概率"])
    files = [files; "paper_state_probability_formula.csv"];
elseif contains(module, ["LLR", "LFOR", "NVOR", "CRI", "VaR"])
    files = [files; "paper_risk_severity_formula.csv"; "paper_state_probability_formula.csv"];
elseif contains(module, ["切负荷", "失负荷"])
    files = [files; "paper_load_shedding_model.csv"];
elseif contains(module, "风电功率曲线")
    files = [files; "paper_wind_power_curve.csv"];
elseif contains(module, ["接入场景", "渗透率", "风速", "topology_compare", "penetration_scan", "wind_speed_scan", "renewable_trip_record"])
    files = [files; "paper_scenario_definition.csv"];
elseif contains(module, ["结果图表", "第4章结果"])
    files = [files; "paper_result_benchmark.csv"];
end
end
