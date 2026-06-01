function main_compare_metric_definition_matrix()
%MAIN_COMPARE_METRIC_DEFINITION_MATRIX Compare paper-required features against engineering variants.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'diagnostics');
ensure_dir(out_dir);

paper_path = fullfile(out_dir, 'paper_metric_definition_table.csv');
if exist(paper_path, 'file') == 2
    paper_defs = readtable(paper_path, 'TextType', 'string');
else
    paper_defs = table();
end

features = ["uses_line_probability"; "uses_state_probability"; "uses_stage_severity"; ...
    "uses_chain_probability"; "uses_initial_outage_probability"; "uses_confidence_level_or_var"; ...
    "uses_percent_scale"; "uses_weighted_CRI"; "uses_all_initial_faults"; ...
    "uses_markov_trial_average"; "uses_topology_scenario_average"];
variants = ["raw_markov_var", "weighted_markov_var", "paper_severity_markov_var", ...
    "chain_summary", "stage_level_risk_preview", "calibration_pilot_used"];
metrics = ["SLLR", "SLFOR", "SNVOR", "CRI"];

metric_name = strings(0,1);
paper_required_feature = strings(0,1);
raw_markov_var = strings(0,1);
weighted_markov_var = strings(0,1);
paper_severity_markov_var = strings(0,1);
chain_summary = strings(0,1);
stage_level_risk_preview = strings(0,1);
calibration_pilot_used = strings(0,1);
match_status = strings(0,1);
gap_description = strings(0,1);
recommended_fix = strings(0,1);

for m = metrics
    paper_missing = is_paper_missing(paper_defs, m);
    for f = features'
        vals = strings(1, numel(variants));
        for i = 1:numel(variants)
            vals(i) = variant_feature_status(variants(i), f);
        end
        metric_name(end+1,1) = m; %#ok<AGROW>
        paper_required_feature(end+1,1) = f; %#ok<AGROW>
        raw_markov_var(end+1,1) = vals(1); %#ok<AGROW>
        weighted_markov_var(end+1,1) = vals(2); %#ok<AGROW>
        paper_severity_markov_var(end+1,1) = vals(3); %#ok<AGROW>
        chain_summary(end+1,1) = vals(4); %#ok<AGROW>
        stage_level_risk_preview(end+1,1) = vals(5); %#ok<AGROW>
        calibration_pilot_used(end+1,1) = vals(6); %#ok<AGROW>
        if paper_missing
            match_status(end+1,1) = "paper_definition_unconfirmed"; %#ok<AGROW>
            gap_description(end+1,1) = "Current paper inputs do not fully specify this required feature."; %#ok<AGROW>
            recommended_fix(end+1,1) = "Ask user to provide original risk metric formula text/screenshots before local search."; %#ok<AGROW>
        elseif any(vals == "yes")
            match_status(end+1,1) = "partially_supported_by_existing_variant"; %#ok<AGROW>
            gap_description(end+1,1) = "At least one engineering variant has this feature, but end-to-end paper equivalence is not confirmed."; %#ok<AGROW>
            recommended_fix(end+1,1) = "Use engineering index plus paper definition table to select a single source before calibration."; %#ok<AGROW>
        else
            match_status(end+1,1) = "missing_in_engineering_variants"; %#ok<AGROW>
            gap_description(end+1,1) = "No existing variant clearly implements this feature."; %#ok<AGROW>
            recommended_fix(end+1,1) = "Build offline paper-consistent preview or update metric pipeline after formula confirmation."; %#ok<AGROW>
        end
    end
end

out = table(metric_name, paper_required_feature, raw_markov_var, weighted_markov_var, ...
    paper_severity_markov_var, chain_summary, stage_level_risk_preview, ...
    calibration_pilot_used, match_status, gap_description, recommended_fix);
writetable(out, fullfile(out_dir, 'metric_definition_gap_matrix.csv'));
fprintf('metric definition gap matrix written: %d rows\n', height(out));
end

function flag = is_paper_missing(paper_defs, metric)
flag = true;
if isempty(paper_defs) || ~ismember('metric_name', paper_defs.Properties.VariableNames)
    return;
end
idx = find(upper(string(paper_defs.metric_name)) == upper(metric), 1);
if isempty(idx)
    return;
end
if ismember('missing_information', paper_defs.Properties.VariableNames)
    flag = strlength(string(paper_defs.missing_information(idx))) > 0;
end
end

function status = variant_feature_status(variant, feature)
status = "no";
switch feature
    case "uses_line_probability"
        if any(variant == ["weighted_markov_var", "paper_severity_markov_var", "stage_level_risk_preview", "calibration_pilot_used"])
            status = "partial";
        end
    case "uses_state_probability"
        if variant == "stage_level_risk_preview"
            status = "yes";
        elseif variant == "paper_severity_markov_var"
            status = "partial_line_only_Pwt_Pge_equal_1";
        end
    case "uses_stage_severity"
        if variant == "stage_level_risk_preview"
            status = "yes";
        elseif variant == "paper_severity_markov_var"
            status = "partial";
        end
    case "uses_chain_probability"
        if any(variant == ["raw_markov_var", "weighted_markov_var", "paper_severity_markov_var", "calibration_pilot_used"])
            status = "yes";
        end
    case "uses_initial_outage_probability"
        if any(variant == ["weighted_markov_var", "paper_severity_markov_var", "calibration_pilot_used"])
            status = "yes";
        end
    case "uses_confidence_level_or_var"
        if any(variant == ["raw_markov_var", "weighted_markov_var", "paper_severity_markov_var", "calibration_pilot_used"])
            status = "yes";
        end
    case "uses_percent_scale"
        status = "no";
    case "uses_weighted_CRI"
        status = "yes";
    case "uses_all_initial_faults"
        if variant ~= "stage_level_risk_preview"
            status = "yes";
        else
            status = "no_smoke_subset_only";
        end
    case "uses_markov_trial_average"
        if variant == "chain_summary"
            status = "not_aggregated";
        elseif variant == "stage_level_risk_preview"
            status = "sum_over_stage_records";
        else
            status = "empirical_distribution";
        end
    case "uses_topology_scenario_average"
        status = "no";
end
end

function ensure_dir(path_value)
if exist(path_value, 'dir') ~= 7
    mkdir(path_value);
end
end
