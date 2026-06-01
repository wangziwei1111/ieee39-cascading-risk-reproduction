function main_build_paper_consistent_metric_preview()
%MAIN_BUILD_PAPER_CONSISTENT_METRIC_PREVIEW Build offline paper-consistent metric candidates.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'diagnostics');
ensure_dir(out_dir);

prob_path = fullfile(project_root, 'results', 'composite', ...
    'unified_state_probability_diagnostic_smoke', 'unified_state_probability_stage_details.csv');
sev_path = fullfile(project_root, 'results', 'composite', ...
    'unified_state_probability_diagnostic_smoke', 'stage_severity_details.csv');
out_path = fullfile(out_dir, 'paper_consistent_metric_preview.csv');

if exist(prob_path, 'file') ~= 2 || exist(sev_path, 'file') ~= 2
    out = empty_preview("missing unified probability or stage severity inputs");
    writetable(out, out_path);
    return;
end

prob = readtable(prob_path, 'TextType', 'string');
sev = readtable(sev_path, 'TextType', 'string');
joined = innerjoin(prob, sev, 'Keys', {'initial_branch', 'trial_id', 'stage_id'});

metrics = ["SLLR", "SLFOR", "SNVOR", "CRI"];
sev_cols = ["severity_LLR", "severity_LFOR", "severity_NVOR", "severity_CRI"];
preview_variants = ["stage_probability_sum", "stage_probability_percent", ...
    "stage_mean_severity", "stage_mean_severity_percent", "chain_probability_proxy"];

preview_variant = strings(0,1);
metric_name = strings(0,1);
preview_value = [];
source_probability = strings(0,1);
source_severity = strings(0,1);
scale_convention = strings(0,1);
aggregation_rule = strings(0,1);
valid_stage_count = [];
missing_probability_count = [];
missing_severity_count = [];
formula_note = strings(0,1);
not_formal_reason = strings(0,1);

for i = 1:numel(metrics)
    sev_values = joined.(sev_cols(i));
    for v = preview_variants
        valid = ~isnan(sev_values);
        if contains(v, "probability")
            valid = valid & ~isnan(joined.P_total_Ek);
        end
        value = NaN;
        src_prob = "none";
        agg = "";
        scale = "per-unit";
        if v == "stage_probability_sum"
            value = sum(joined.P_total_Ek(valid) .* sev_values(valid), 'omitnan');
            src_prob = "P_total_Ek";
            agg = "sum(P_total_Ek * stage_severity)";
        elseif v == "stage_probability_percent"
            value = 100 * sum(joined.P_total_Ek(valid) .* sev_values(valid), 'omitnan');
            src_prob = "P_total_Ek";
            scale = "percent";
            agg = "100 * sum(P_total_Ek * stage_severity)";
        elseif v == "stage_mean_severity"
            value = mean(sev_values(valid), 'omitnan');
            agg = "mean(stage_severity)";
        elseif v == "stage_mean_severity_percent"
            value = 100 * mean(sev_values(valid), 'omitnan');
            scale = "percent";
            agg = "100 * mean(stage_severity)";
        elseif v == "chain_probability_proxy"
            valid(:) = false;
            value = NaN;
            src_prob = "unavailable";
            agg = "chain probability unavailable in unified smoke";
        end
        preview_variant(end+1,1) = v; %#ok<AGROW>
        metric_name(end+1,1) = metrics(i); %#ok<AGROW>
        preview_value(end+1,1) = value; %#ok<AGROW>
        source_probability(end+1,1) = src_prob; %#ok<AGROW>
        source_severity(end+1,1) = "unified stage_severity_details." + sev_cols(i); %#ok<AGROW>
        scale_convention(end+1,1) = scale; %#ok<AGROW>
        aggregation_rule(end+1,1) = agg; %#ok<AGROW>
        valid_stage_count(end+1,1) = sum(valid); %#ok<AGROW>
        missing_probability_count(end+1,1) = sum(isnan(joined.P_total_Ek)); %#ok<AGROW>
        missing_severity_count(end+1,1) = sum(isnan(sev_values)); %#ok<AGROW>
        formula_note(end+1,1) = "Offline candidate preview only; no simulation run and no final_summary update."; %#ok<AGROW>
        not_formal_reason(end+1,1) = "Uses diagnostic P_line/P_wt/P_ge parameter sets and one small unified smoke, not confirmed paper VaR/aggregation rule."; %#ok<AGROW>
    end
end

out = table(preview_variant, metric_name, preview_value, source_probability, ...
    source_severity, scale_convention, aggregation_rule, valid_stage_count, ...
    missing_probability_count, missing_severity_count, formula_note, not_formal_reason);
writetable(out, out_path);
fprintf('paper-consistent metric preview written: %d rows\n', height(out));
end

function out = empty_preview(row_note)
preview_variant = strings(0,1);
metric_name = strings(0,1);
preview_value = [];
source_probability = strings(0,1);
source_severity = strings(0,1);
scale_convention = strings(0,1);
aggregation_rule = strings(0,1);
valid_stage_count = [];
missing_probability_count = [];
missing_severity_count = [];
formula_note = strings(0,1);
not_formal_reason = strings(0,1);
for m = ["SLLR", "SLFOR", "SNVOR", "CRI"]
    preview_variant(end+1,1) = "unavailable"; %#ok<AGROW>
    metric_name(end+1,1) = m; %#ok<AGROW>
    preview_value(end+1,1) = NaN; %#ok<AGROW>
    source_probability(end+1,1) = "missing"; %#ok<AGROW>
    source_severity(end+1,1) = "missing"; %#ok<AGROW>
    scale_convention(end+1,1) = "unknown"; %#ok<AGROW>
    aggregation_rule(end+1,1) = "unavailable"; %#ok<AGROW>
    valid_stage_count(end+1,1) = 0; %#ok<AGROW>
    missing_probability_count(end+1,1) = 0; %#ok<AGROW>
    missing_severity_count(end+1,1) = 0; %#ok<AGROW>
    formula_note(end+1,1) = row_note; %#ok<AGROW>
    not_formal_reason(end+1,1) = "Required diagnostic inputs are missing."; %#ok<AGROW>
end
out = table(preview_variant, metric_name, preview_value, source_probability, ...
    source_severity, scale_convention, aggregation_rule, valid_stage_count, ...
    missing_probability_count, missing_severity_count, formula_note, not_formal_reason);
end

function ensure_dir(path_value)
if exist(path_value, 'dir') ~= 7
    mkdir(path_value);
end
end
