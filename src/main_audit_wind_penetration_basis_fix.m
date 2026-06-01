function main_audit_wind_penetration_basis_fix()
%MAIN_AUDIT_WIND_PENETRATION_BASIS_FIX Audit paper-aligned wind penetration basis.

out_dir = fullfile('results', 'calibration', 'diagnostics');
snapshot_file = fullfile(out_dir, 'pilot_scenario_config_snapshot.csv');
if ~exist(snapshot_file, 'file')
    error('Missing snapshot file: %s', snapshot_file);
end
S = readtable(snapshot_file, 'TextType', 'string', 'Delimiter', ',');
total_gen = 7500;

scenario_ids = {'concentrated_bus34', 'distributed_30_39', 'wind_speed_11_28', ...
    'wind_speed_12_00', 'penetration_40pct', 'penetration_60pct', 'penetration_80pct'};
rows = {};
for i = 1:numel(scenario_ids)
    sid = scenario_ids{i};
    idx = find(strcmp(S.scenario_id, sid), 1);
    if isempty(idx)
        rows(end + 1, :) = {sid, NaN, 'total_generation_capacity', NaN, '', NaN, NaN, NaN, ...
            'missing_snapshot', 'missing_snapshot', true, true, 'Scenario missing from dry-run snapshot.'}; %#ok<AGROW>
        continue;
    end
    expected_pen = expected_penetration(sid);
    expected_capacity = expected_pen * total_gen;
    actual_capacity = S.wind_capacity_total_mw(idx);
    actual_basis = char(S.wind_penetration_basis(idx));
    paper_pen = S.paper_wind_penetration(idx);
    load_pen = S.load_based_wind_penetration(idx);
    cap_match = abs(actual_capacity - expected_capacity) <= 1e-6 * max(1, abs(expected_capacity));
    basis_match = strcmp(actual_basis, 'total_generation_capacity');
    rows(end + 1, :) = {sid, expected_pen, 'total_generation_capacity', expected_capacity, ...
        actual_basis, actual_capacity, paper_pen, load_pen, status_text(cap_match), ...
        status_text(basis_match), true, ~(cap_match && basis_match), ...
        'Paper-aligned benchmark/calibration uses total_generation_capacity; load-based penetration is retained only as diagnostic.'}; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', {'scenario_id', 'expected_penetration', ...
    'expected_basis', 'expected_capacity_mw', 'actual_basis', 'actual_capacity_mw', ...
    'paper_wind_penetration', 'load_based_wind_penetration', 'capacity_match_status', ...
    'basis_match_status', 'blocking_before', 'blocking_after', 'note'});
writetable(T, fullfile(out_dir, 'wind_penetration_basis_fix_audit.csv'));
fprintf('Wrote %s\n', fullfile(out_dir, 'wind_penetration_basis_fix_audit.csv'));
end

function p = expected_penetration(scenario_id)
switch scenario_id
    case {'concentrated_bus34', 'distributed_30_39', 'wind_speed_11_28', 'wind_speed_12_00', 'penetration_40pct'}
        p = 0.40;
    case 'penetration_60pct'
        p = 0.60;
    case 'penetration_80pct'
        p = 0.80;
    otherwise
        p = NaN;
end
end

function txt = status_text(tf)
if tf
    txt = 'matched';
else
    txt = 'mismatched';
end
end
