function main_update_pilot_scenario_mapping_audit_from_snapshots()
%MAIN_UPDATE_PILOT_SCENARIO_MAPPING_AUDIT_FROM_SNAPSHOTS Update pilot mapping audit with snapshot evidence.

out_dir = fullfile('results', 'calibration', 'diagnostics');
old_file = fullfile(out_dir, 'pilot_scenario_mapping_audit.csv');
snapshot_file = fullfile(out_dir, 'pilot_scenario_config_snapshot.csv');
alignment_file = fullfile(out_dir, 'pilot_scenario_snapshot_target_alignment.csv');
if ~exist(old_file, 'file') || ~exist(snapshot_file, 'file') || ~exist(alignment_file, 'file')
    error('Missing required input audit/snapshot/alignment file.');
end

Old = readtable(old_file, 'TextType', 'string', 'Delimiter', ',');
S = readtable(snapshot_file, 'TextType', 'string', 'Delimiter', ',');
A = readtable(alignment_file, 'TextType', 'string', 'Delimiter', ',');

snapshot_status = strings(height(Old), 1);
snapshot_match_status = strings(height(Old), 1);
blocking_issue_count = zeros(height(Old), 1);
mapping_confidence = strings(height(Old), 1);
updated_mapping_status = strings(height(Old), 1);
updated_recommended_fix = strings(height(Old), 1);

for i = 1:height(Old)
    sid = Old.pilot_scenario_id(i);
    sidx = strcmp(S.scenario_id, sid);
    aidx = strcmp(A.scenario_id, sid);
    if any(sidx)
        snapshot_status(i) = S.snapshot_status(find(sidx, 1));
    else
        snapshot_status(i) = "missing_snapshot";
    end
    block_count = sum(aidx & strcmp(A.severity, 'blocking') & ~strcmp(A.match_status, 'matched') & ~strcmp(A.match_status, 'assumption_matched'));
    warn_count = sum(aidx & strcmp(A.severity, 'warning') & ~strcmp(A.match_status, 'matched') & ~strcmp(A.match_status, 'assumption_matched'));
    blocking_issue_count(i) = block_count;
    if block_count > 0
        snapshot_match_status(i) = "blocking_mismatch";
        mapping_confidence(i) = "medium_with_blocking_config_issue";
        updated_mapping_status(i) = "partially_confirmed_by_config_snapshot";
        updated_recommended_fix(i) = "fix penetration/scenario builder basis before formal VaR pilot";
    elseif warn_count > 0
        snapshot_match_status(i) = "matched_with_warning";
        mapping_confidence(i) = "medium";
        updated_mapping_status(i) = "partially_confirmed_by_config_snapshot";
        updated_recommended_fix(i) = "review warning assumptions before formal VaR pilot";
    else
        snapshot_match_status(i) = "matched";
        mapping_confidence(i) = "high";
        updated_mapping_status(i) = "confirmed_by_config_snapshot";
        updated_recommended_fix(i) = "scenario mapping confirmed by dry-run snapshot; next gate is formal VaR pilot readiness";
    end
end

Old.snapshot_status = snapshot_status;
Old.snapshot_match_status = snapshot_match_status;
Old.blocking_issue_count = blocking_issue_count;
Old.mapping_confidence = mapping_confidence;
Old.mapping_status_v2 = updated_mapping_status;
Old.updated_recommended_fix = updated_recommended_fix;
writetable(Old, fullfile(out_dir, 'pilot_scenario_mapping_audit_v2.csv'));
fprintf('Wrote %s\n', fullfile(out_dir, 'pilot_scenario_mapping_audit_v2.csv'));
end
