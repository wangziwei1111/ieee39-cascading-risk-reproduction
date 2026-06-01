function main_compare_paper_consistent_preview_to_targets()
%MAIN_COMPARE_PAPER_CONSISTENT_PREVIEW_TO_TARGETS Compare preview candidates with target group means.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'diagnostics');
ensure_dir(out_dir);

preview_path = fullfile(out_dir, 'paper_consistent_metric_preview.csv');
target_path = fullfile(project_root, 'paper_inputs', 'filled', 'calibration_target_benchmark.csv');
out_path = fullfile(out_dir, 'paper_consistent_preview_gap.csv');

if exist(preview_path, 'file') ~= 2 || exist(target_path, 'file') ~= 2
    out = table(strings(0,1), strings(0,1), strings(0,1), [], [], [], [], [], strings(0,1), ...
        'VariableNames', {'preview_variant', 'metric_name', 'paper_reference_group', ...
        'paper_reference_mean', 'preview_value', 'ratio_paper_to_preview', ...
        'absolute_gap', 'relative_gap', 'interpretation'});
    writetable(out, out_path);
    return;
end

preview = readtable(preview_path, 'TextType', 'string');
target = readtable(target_path, 'TextType', 'string');
groups = unique(string(target.target_group));

preview_variant = strings(0,1);
metric_name = strings(0,1);
paper_reference_group = strings(0,1);
paper_reference_mean = [];
preview_value = [];
ratio_paper_to_preview = [];
absolute_gap = [];
relative_gap = [];
interpretation = strings(0,1);

for i = 1:height(preview)
    for g = groups'
        mask = string(target.target_group) == g & string(target.metric_name) == string(preview.metric_name(i));
        paper_mean = mean(target.paper_value(mask), 'omitnan');
        val = preview.preview_value(i);
        ratio = NaN;
        rel = NaN;
        gap = NaN;
        interp = "Compared to paper target group mean because unified stage-level smoke is not scenario-aligned to all calibration targets.";
        if ~isnan(paper_mean) && ~isnan(val)
            gap = val - paper_mean;
            if abs(val) > 1e-12
                ratio = paper_mean / val;
            end
            if abs(paper_mean) > 1e-12
                rel = gap / abs(paper_mean);
            end
            if abs(ratio) >= 10 || isnan(ratio)
                interp = interp + " Large scale gap remains; not suitable for calibration target replacement yet.";
            else
                interp = interp + " Candidate is closer in scale, but paper aggregation rule is still unconfirmed.";
            end
        else
            interp = "Missing preview value or target mean; no forced zero fill.";
        end
        preview_variant(end+1,1) = preview.preview_variant(i); %#ok<AGROW>
        metric_name(end+1,1) = preview.metric_name(i); %#ok<AGROW>
        paper_reference_group(end+1,1) = g; %#ok<AGROW>
        paper_reference_mean(end+1,1) = paper_mean; %#ok<AGROW>
        preview_value(end+1,1) = val; %#ok<AGROW>
        ratio_paper_to_preview(end+1,1) = ratio; %#ok<AGROW>
        absolute_gap(end+1,1) = gap; %#ok<AGROW>
        relative_gap(end+1,1) = rel; %#ok<AGROW>
        interpretation(end+1,1) = interp; %#ok<AGROW>
    end
end

out = table(preview_variant, metric_name, paper_reference_group, paper_reference_mean, ...
    preview_value, ratio_paper_to_preview, absolute_gap, relative_gap, interpretation);
writetable(out, out_path);
fprintf('paper-consistent preview gap written: %d rows\n', height(out));
end

function ensure_dir(path_value)
if exist(path_value, 'dir') ~= 7
    mkdir(path_value);
end
end
