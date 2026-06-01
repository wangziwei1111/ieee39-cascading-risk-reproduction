function main_extract_paper_metric_definition_table()
%MAIN_EXTRACT_PAPER_METRIC_DEFINITION_TABLE Extract currently available paper metric definitions.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'diagnostics');
ensure_dir(out_dir);

paper_path = fullfile(project_root, 'paper_inputs', 'filled', 'paper_risk_metric_formulas.csv');
metrics = ["SLLR"; "SLFOR"; "SNVOR"; "CRI"];

metric_name = metrics;
paper_symbol = ["SLLR"; "SLFOR"; "SNVOR"; "CRI"];
paper_formula = strings(4, 1);
required_inputs = strings(4, 1);
probability_weighting = strings(4, 1);
severity_mapping = strings(4, 1);
aggregation_rule = strings(4, 1);
scale_convention = strings(4, 1);
confidence_or_var_rule = strings(4, 1);
extracted_status = strings(4, 1);
missing_information = strings(4, 1);
note = strings(4, 1);

if exist(paper_path, 'file') == 2
    raw = read_csv(paper_path);
    for i = 1:numel(metrics)
        idx = find_metric_row(raw, metrics(i));
        if ~isnan(idx)
            symbol_value = get_col(raw, idx, ["paper_symbol", "symbol"]);
            if strlength(symbol_value) > 0
                paper_symbol(i) = symbol_value;
            end
            paper_formula(i) = get_col(raw, idx, ["paper_formula", "formula", "formula_text", "description"]);
            required_inputs(i) = get_col(raw, idx, ["required_inputs", "inputs"]);
            probability_weighting(i) = get_col(raw, idx, ["probability_weighting", "probability_rule"]);
            severity_mapping(i) = get_col(raw, idx, ["severity_mapping", "severity_definition"]);
            aggregation_rule(i) = get_col(raw, idx, ["aggregation_rule", "aggregation"]);
            scale_convention(i) = get_col(raw, idx, ["scale_convention", "scale"]);
            confidence_or_var_rule(i) = get_col(raw, idx, ["confidence_or_var_rule", "var_rule"]);
            if metrics(i) == "CRI"
                extracted_status(i) = "weighted_sum_of_var_metrics";
            else
                extracted_status(i) = "VaR_quantile_metric";
            end
            missing_information(i) = missing_items(paper_formula(i), required_inputs(i), ...
                probability_weighting(i), severity_mapping(i), aggregation_rule(i), ...
                scale_convention(i), confidence_or_var_rule(i));
            note(i) = "Extracted from paper_risk_metric_formulas.csv; verify against original text before calibration.";
        else
            [paper_formula(i), required_inputs(i), probability_weighting(i), severity_mapping(i), ...
                aggregation_rule(i), scale_convention(i), confidence_or_var_rule(i), ...
                extracted_status(i), missing_information(i), note(i)] = missing_definition(metrics(i), "metric row missing from paper_risk_metric_formulas.csv");
        end
    end
else
    for i = 1:numel(metrics)
        [paper_formula(i), required_inputs(i), probability_weighting(i), severity_mapping(i), ...
            aggregation_rule(i), scale_convention(i), confidence_or_var_rule(i), ...
            extracted_status(i), missing_information(i), note(i)] = missing_definition(metrics(i), "paper_risk_metric_formulas.csv not found");
    end
end

out = table(metric_name, paper_symbol, paper_formula, required_inputs, probability_weighting, ...
    severity_mapping, aggregation_rule, scale_convention, confidence_or_var_rule, ...
    extracted_status, missing_information, note);
writetable(out, fullfile(out_dir, 'paper_metric_definition_table.csv'));
fprintf('paper metric definition table written: %d rows\n', height(out));
end

function idx = find_metric_row(raw, metric)
idx = NaN;
names = string(raw.Properties.VariableNames);
candidate_cols = ["metric_name", "metric", "paper_symbol", "symbol"];
for c = candidate_cols
    pos = find(strcmpi(names, c), 1);
    if ~isempty(pos)
        vals = upper(string(raw.(names(pos))));
        hit = find(vals == upper(metric), 1);
        if ~isempty(hit)
            idx = hit;
            return;
        end
    end
end
end

function value = get_col(raw, idx, candidates)
value = "";
names = string(raw.Properties.VariableNames);
for c = candidates
    pos = find(strcmpi(names, c), 1);
    if ~isempty(pos)
        value = string(raw.(names(pos))(idx));
        return;
    end
end
end

function text = missing_items(varargin)
labels = ["paper_formula", "required_inputs", "probability_weighting", "severity_mapping", ...
    "aggregation_rule", "scale_convention", "confidence_or_var_rule"];
miss = strings(0, 1);
for i = 1:nargin
    if strlength(string(varargin{i})) == 0 || ismissing(string(varargin{i}))
        miss(end + 1, 1) = labels(i); %#ok<AGROW>
    end
end
if isempty(miss)
    text = "";
else
    text = strjoin(miss, ";");
end
end

function [formula, inputs, prob, sev, agg, scale, var_rule, status, missing, row_note] = missing_definition(metric, why)
formula = "missing_from_current_paper_inputs";
inputs = "missing_from_current_paper_inputs";
prob = "missing_from_current_paper_inputs";
sev = "missing_from_current_paper_inputs";
agg = "missing_from_current_paper_inputs";
scale = "missing_from_current_paper_inputs";
var_rule = "missing_from_current_paper_inputs";
status = "missing_from_current_paper_inputs";
missing = "SLLR/SLFOR/SNVOR/CRI exact formula, probability weighting, percent scale, confidence/VaR rule, and aggregation rule require original paper confirmation";
row_note = "Cannot confirm paper definition for " + metric + ": " + why + ". Do not continue parameter search before metric alignment.";
end

function ensure_dir(path_value)
if exist(path_value, 'dir') ~= 7
    mkdir(path_value);
end
end

function tbl = read_csv(path_value)
opts = detectImportOptions(path_value, 'Delimiter', ',', 'TextType', 'string');
opts.VariableNamingRule = 'preserve';
tbl = readtable(path_value, opts);
end
