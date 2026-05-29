function [p, detail] = compute_line_outage_probability_dispatch(line_loading_pu, branch_row, cfg, varargin)
%COMPUTE_LINE_OUTAGE_PROBABILITY_DISPATCH Dispatch engineering/paper line probability models.
engineering_probability = line_outage_probability(line_loading_pu, cfg);
mode = lower(string(get_cfg(cfg, 'line_outage_probability_model', 'engineering')));

detail = struct();
detail.model = mode;
detail.engineering_probability = engineering_probability;
detail.paper_formula_probability = NaN;
detail.paper_formula_status = "not_evaluated";
detail.paper_formula_missing_parameters = "";
detail.paper_formula_used_fallback = false;

switch mode
    case "engineering"
        p = engineering_probability;
        detail.model = "engineering";

    case "paper_formula"
        [paper_probability, paper_detail] = compute_paper_line_outage_probability( ...
            line_loading_pu, branch_row, cfg, varargin{:}, ...
            'fallback_probability', engineering_probability);
        p = paper_probability;
        detail = merge_paper_detail(detail, paper_detail);
        detail.model = "paper_formula";

    case "paper_formula_diagnostic"
        [paper_probability, paper_detail] = compute_paper_line_outage_probability( ...
            line_loading_pu, branch_row, cfg, varargin{:}, ...
            'fallback_probability', engineering_probability);
        p = engineering_probability;
        detail = merge_paper_detail(detail, paper_detail);
        detail.model = "paper_formula_diagnostic";

    otherwise
        error('Unknown line_outage_probability_model: %s', mode);
end
end

function detail = merge_paper_detail(detail, paper_detail)
detail.paper_formula_probability = paper_detail.p_line;
detail.paper_formula_status = paper_detail.status;
detail.paper_formula_missing_parameters = string(paper_detail.missing_parameters);
detail.paper_formula_used_fallback = logical(paper_detail.used_fallback);
detail.paper_formula_note = string(paper_detail.note);
detail.paper_formula_P_flow = paper_detail.P_flow;
detail.paper_formula_P_hidden_distance = paper_detail.P_hidden_distance;
detail.paper_formula_P_hidden_loading = paper_detail.P_hidden_loading;
detail.paper_formula_P3 = paper_detail.P3;
end

function value = get_cfg(cfg, name, default_value)
if isfield(cfg, name)
    value = cfg.(name);
else
    value = default_value;
end
end
