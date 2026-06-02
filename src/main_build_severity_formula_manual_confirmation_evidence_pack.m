function main_build_severity_formula_manual_confirmation_evidence_pack()
%MAIN_BUILD_SEVERITY_FORMULA_MANUAL_CONFIRMATION_EVIDENCE_PACK
% Build an offline evidence index for manual confirmation of severity formulas.
% This script does not run Markov/cascade, tune parameters, or modify formulas.

root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'severity_formula');
ensure_dir(out_dir);

rows = {};
source_audit_file = fullfile(out_dir, 'severity_formula_source_audit.csv');
if exist(source_audit_file, 'file') == 2
    S = readtable(source_audit_file, 'TextType', 'string');
    for i = 1:height(S)
        strength = "code_implementation";
        if ismember('formula_status', S.Properties.VariableNames)
            if S.formula_status(i) == "extracted_note"
                strength = "extracted_note";
            elseif S.formula_status(i) == "missing"
                strength = "missing";
            end
        end
        rows{end+1,1} = make_row("SRC-" + string(i), S.source_file(i), S.source_section_or_function(i), ...
            S.severity_item(i), S.severity_item(i), S.formula_text_or_code(i), ...
            S.current_code_formula(i), strength == "code_implementation", strength ~= "code_implementation", ...
            strength, S.missing_information(i), S.note(i));
    end
end

rows = add_current_code_rows(rows, root);
rows = add_keyword_evidence_rows(rows, root);

missing_items = ["LLR","SLLR","LFOR","SLFOR","NVOR","SNVOR","CRI","CRI_weighting", ...
    "severity_stage_or_chain_level","normalization_basis","zero_violation_handling","nonconvergence_handling"];
for i = 1:numel(missing_items)
    if ~has_item(rows, missing_items(i), "original_paper_formula")
        rows{end+1,1} = make_row("MISS-" + string(i), "paper_inputs/docs search", ...
            "manual confirmation required", missing_items(i), missing_items(i), ...
            "missing_original_formula", "No confirmed original-paper formula was found in current filled/validated inputs.", ...
            false, false, "missing", ...
            "Need user to provide paper screenshot or exact formula text.", ...
            "Do not treat current code implementation as original paper formula.");
    end
end

T = vertcat(rows{:});
writetable(T, fullfile(out_dir, 'severity_formula_manual_confirmation_evidence.csv'));
end

function rows = add_current_code_rows(rows, root)
files = {fullfile(root,'src','risk','calc_basic_risk_metrics.m'), fullfile(root,'src','risk','calc_cri.m')};
for f = 1:numel(files)
    if exist(files{f}, 'file') ~= 2
        continue;
    end
    lines = splitlines(string(fileread(files{f})));
    rel = erase(string(files{f}), string(root) + filesep);
    for i = 1:numel(lines)
        txt = strtrim(lines(i));
        if contains(txt, "sllr =")
            rows{end+1,1} = make_row("CODE-LLR", rel, "line " + string(i), "LLR", "SLLR", txt, ...
                "Current code computes total_load_shed_mw / base_load_mw.", true, false, ...
                "code_implementation", "Paper normalization and stage/chain level remain unconfirmed.", "");
        elseif contains(txt, "slfor = line_excess")
            rows{end+1,1} = make_row("CODE-LFOR", rel, "line " + string(i), "LFOR", "SLFOR", txt, ...
                "Current code multiplies max overload excess by max(overloaded_line_count,1).", true, false, ...
                "code_implementation", "Paper overload severity definition remains unconfirmed.", "");
        elseif contains(txt, "snvor = violations.max_voltage_deviation_pu")
            rows{end+1,1} = make_row("CODE-NVOR", rel, "line " + string(i), "NVOR", "SNVOR", txt, ...
                "Current code multiplies max voltage deviation by max(violation_bus_count,1).", true, false, ...
                "code_implementation", "Paper voltage-overrun severity definition remains unconfirmed.", "");
        elseif contains(txt, "cri =")
            rows{end+1,1} = make_row("CODE-CRI", rel, "line " + string(i), "CRI", "CRI", txt, ...
                "Current code uses normalized weights, default 0.6/0.2/0.2.", true, false, ...
                "code_implementation", "Need screenshot confirmation of CRI weights and normalization.", "");
        end
    end
end
end

function rows = add_keyword_evidence_rows(rows, root)
keywords = ["LLR","SLLR","LFOR","SLFOR","NVOR","SNVOR","CRI","severity","risk index", ...
    "load loss","load shedding","line overload","voltage violation","voltage overrun"];
scan_roots = {fullfile(root,'paper_inputs','filled'), fullfile(root,'paper_inputs','validated'), fullfile(root,'docs')};
id = 0;
for r = 1:numel(scan_roots)
    if exist(scan_roots{r}, 'dir') ~= 7
        continue;
    end
    files = dir(fullfile(scan_roots{r}, '**', '*.*'));
    for f = 1:numel(files)
        if files(f).isdir
            continue;
        end
        [~,~,ext] = fileparts(files(f).name);
        if ~ismember(lower(string(ext)), [".csv",".md",".txt",".m"])
            continue;
        end
        path = fullfile(files(f).folder, files(f).name);
        try
            txt = string(fileread(path));
        catch
            continue;
        end
        for k = 1:numel(keywords)
            if contains(lower(txt), lower(keywords(k)))
                id = id + 1;
                rel = erase(string(path), string(root) + filesep);
                item = map_keyword_to_item(keywords(k));
                rows{end+1,1} = make_row("HIT-" + string(id), rel, "keyword:" + keywords(k), item, item, ...
                    "keyword hit: " + keywords(k), "Potential supporting context only; not automatically treated as a formula.", ...
                    false, true, "diagnostic_assumption", ...
                    "Manual reading is required to decide whether this is formula evidence.", ...
                    "Keyword evidence is intentionally weak.");
                break;
            end
        end
    end
end
end

function item = map_keyword_to_item(keyword)
k = upper(string(keyword));
if contains(k, "LLR") || contains(k, "LOAD")
    item = "LLR";
elseif contains(k, "LFOR") || contains(k, "LINE")
    item = "LFOR";
elseif contains(k, "NVOR") || contains(k, "VOLTAGE")
    item = "NVOR";
elseif contains(k, "CRI") || contains(k, "RISK")
    item = "CRI";
else
    item = "severity_stage_or_chain_level";
end
end

function tf = has_item(rows, item, strength)
tf = false;
for i = 1:numel(rows)
    if rows{i}.severity_item == item && rows{i}.evidence_strength == strength
        tf = true;
        return;
    end
end
end

function T = make_row(id, file, section, item, symbol, text, interpretation, supports_code, supports_alt, strength, missing, note)
T = table(string(id), string(file), string(section), string(item), string(symbol), ...
    string(text), string(interpretation), logical(supports_code), logical(supports_alt), ...
    string(strength), string(missing), string(note), ...
    'VariableNames', {'evidence_id','source_file','source_section_or_line','severity_item','formula_symbol', ...
    'formula_text','formula_interpretation','supports_current_code_formula','supports_alternative_formula', ...
    'evidence_strength','missing_information','note'});
end

function ensure_dir(path)
if exist(path, 'dir') ~= 7
    mkdir(path);
end
end
