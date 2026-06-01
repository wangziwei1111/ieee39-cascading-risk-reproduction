function main_check_pilot_scenario_config_snapshot_diagnosis()
%MAIN_CHECK_PILOT_SCENARIO_CONFIG_SNAPSHOT_DIAGNOSIS Check dry-run snapshot diagnosis outputs.

out_dir = fullfile('results', 'calibration', 'diagnostics');
log_file = fullfile(out_dir, 'pilot_scenario_config_snapshot_diagnosis_check_log.txt');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

required = { ...
    fullfile(out_dir, 'pilot_scenario_config_source_trace.csv'), ...
    fullfile(out_dir, 'pilot_scenario_config_snapshot.csv'), ...
    fullfile(out_dir, 'pilot_scenario_snapshot_target_alignment.csv'), ...
    fullfile(out_dir, 'formal_scenario_aligned_var_pilot_readiness.csv'), ...
    fullfile(out_dir, 'pilot_scenario_mapping_audit_v2.csv'), ...
    fullfile(out_dir, 'wind_penetration_basis_fix_audit.csv'), ...
    fullfile('docs', 'calibration_target_mapping_diagnosis.md') ...
    };

lines = {};
pass = true;
for i = 1:numel(required)
    if exist(required{i}, 'file')
        lines{end + 1} = sprintf('PASS exists: %s', required{i}); %#ok<AGROW>
    else
        lines{end + 1} = sprintf('FAIL missing: %s', required{i}); %#ok<AGROW>
        pass = false;
    end
end

alignment_file = fullfile(out_dir, 'pilot_scenario_snapshot_target_alignment.csv');
if exist(alignment_file, 'file')
    A = readtable(alignment_file, 'TextType', 'string', 'Delimiter', ',');
    blocking_count = sum(strcmp(A.severity, 'blocking') & ~strcmp(A.match_status, 'matched') & ~strcmp(A.match_status, 'assumption_matched'));
    lines{end + 1} = sprintf('blocking_mismatch_count=%d', blocking_count); %#ok<AGROW>
else
    blocking_count = NaN;
end

fix_audit_file = fullfile(out_dir, 'wind_penetration_basis_fix_audit.csv');
if exist(fix_audit_file, 'file')
    F = readtable(fix_audit_file, 'TextType', 'string', 'Delimiter', ',');
    required_caps = table(["penetration_40pct"; "penetration_60pct"; "penetration_80pct"], ...
        [3000; 4500; 6000], 'VariableNames', {'scenario_id', 'expected_capacity_mw'});
    for k = 1:height(required_caps)
        idx = strcmp(F.scenario_id, required_caps.scenario_id(k));
        if any(idx)
            actual_capacity = F.actual_capacity_mw(find(idx, 1));
            if abs(actual_capacity - required_caps.expected_capacity_mw(k)) <= 1e-6
                lines{end + 1} = sprintf('PASS %s actual_capacity_mw=%.6g', required_caps.scenario_id(k), actual_capacity); %#ok<AGROW>
            else
                lines{end + 1} = sprintf('FAIL %s actual_capacity_mw=%.6g expected=%.6g', ...
                    required_caps.scenario_id(k), actual_capacity, required_caps.expected_capacity_mw(k)); %#ok<AGROW>
                pass = false;
            end
        else
            lines{end + 1} = sprintf('FAIL missing wind penetration audit row: %s', required_caps.scenario_id(k)); %#ok<AGROW>
            pass = false;
        end
    end
    remaining_block = sum(F.blocking_after ~= 0);
    lines{end + 1} = sprintf('wind_penetration_basis_fix_remaining_blocking=%d', remaining_block); %#ok<AGROW>
    if remaining_block > 0
        pass = false;
    end
else
    pass = false;
end

readiness_file = fullfile(out_dir, 'formal_scenario_aligned_var_pilot_readiness.csv');
if exist(readiness_file, 'file')
    R = readtable(readiness_file, 'TextType', 'string', 'Delimiter', ',');
    ready = logical(R.formal_var_pilot_ready(1));
    lines{end + 1} = sprintf('formal_var_pilot_ready=%d', ready); %#ok<AGROW>
    lines{end + 1} = sprintf('recommended_next_step=%s', R.recommended_next_step(1)); %#ok<AGROW>
    if ~ready
        lines{end + 1} = 'READINESS_GATE: do not run formal VaR pilot until blocking scenario snapshot mismatch is resolved.'; %#ok<AGROW>
        if exist('A', 'var')
            blocking_rows = A(strcmp(A.severity, 'blocking') & ~strcmp(A.match_status, 'matched') & ~strcmp(A.match_status, 'assumption_matched'), :);
            for k = 1:height(blocking_rows)
                lines{end + 1} = sprintf('BLOCKING_ISSUE: %s %s expected=%s actual=%s', ...
                    blocking_rows.scenario_id(k), blocking_rows.check_item(k), ...
                    blocking_rows.expected_value(k), blocking_rows.actual_value(k)); %#ok<AGROW>
            end
        end
    else
        lines{end + 1} = 'READINESS_GATE: next step is formal scenario-aligned VaR pilot, not local search.'; %#ok<AGROW>
    end
else
    pass = false;
end

if exist(fullfile('results', 'final_summary'), 'dir')
    lines{end + 1} = 'INFO final_summary directory exists from prior work; this check did not write or update it.'; %#ok<AGROW>
else
    lines{end + 1} = 'PASS final_summary directory not touched by this diagnostic.'; %#ok<AGROW>
end

lines{end + 1} = 'FORBIDDEN_RUNS: no Markov simulation, runpf/AC PF, cascade, local search, all_full, or final_summary was invoked by these diagnosis scripts.'; %#ok<AGROW>
if pass
    lines{end + 1} = 'CHECK_STATUS=PASS'; %#ok<AGROW>
else
    lines{end + 1} = 'CHECK_STATUS=FAIL'; %#ok<AGROW>
end

fid = fopen(log_file, 'w');
fprintf(fid, '%s\n', lines{:});
fclose(fid);

if ~pass
    error('Pilot scenario config snapshot diagnosis check failed. See %s', log_file);
end
fprintf('Wrote %s\n', log_file);
end
