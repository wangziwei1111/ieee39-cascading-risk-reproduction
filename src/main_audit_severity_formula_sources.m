function main_audit_severity_formula_sources()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root,'results','calibration','severity_formula');
ensure_dir(out_dir);
rows = {};
rows{end+1,1}=row('src/risk/calc_basic_risk_metrics.m','calc_basic_risk_metrics','LLR','sllr = shed.total_load_shed_mw / base_load_mw',false,'SLLR = total_load_shed_mw/base_load_mw','code_implementation_only','base_load_mw','Need paper screenshot for exact normalization.','need_manual_paper_confirmation','Basic code formula.');
rows{end+1,1}=row('src/risk/calc_basic_risk_metrics.m','calc_basic_risk_metrics','LFOR','line_excess=max(max_line_loading_pu-1,0); SLFOR=line_excess*max(num_overloaded_lines,1)',false,'max overload excess times overloaded-line count','code_implementation_only','max loading and overloaded count','Need paper formula for line overload risk.','need_manual_paper_confirmation','Not proven original formula.');
rows{end+1,1}=row('src/risk/calc_basic_risk_metrics.m','calc_basic_risk_metrics','NVOR','SNVOR=max_voltage_deviation_pu*max(num_voltage_violations,1)',false,'max voltage deviation times violation-bus count','code_implementation_only','max deviation and violated bus count','Need paper formula for node voltage overlimit risk.','need_manual_paper_confirmation','Not proven original formula.');
rows{end+1,1}=row('src/risk/calc_cri.m','calc_cri','CRI','CRI=weights(1)*SLLR+weights(2)*SLFOR+weights(3)*SNVOR',true,'weighted sum using cfg.risk_weights','extracted_note','weights normalized to sum one','Need confirmation if paper weights differ.','verify_weights','Default 0.6/0.2/0.2.');
rows{end+1,1}=row('config/base_config.m','base_config','CRI_weighting','cfg.risk_weights=[0.6,0.2,0.2]',true,'0.6,0.2,0.2','extracted_note','weight vector','Need paper screenshot if challenged.','no_fix_required','Current configured weights.');
rows{end+1,1}=row('results/calibration/wind_speed_component_diagnostic_rerun','severity_component_trace','severity_clipping','No explicit clipping in basic severity traces except nonconverged lower bound in calc_basic_risk_metrics.',false,'diagnostic current behavior','code_implementation_only','none','Need paper handling for clipping/zero/nonconvergence.','manual_confirmation','');
rows{end+1,1}=row('results/calibration/wind_speed_component_diagnostic_rerun','severity_component_trace','severity_zero_handling','zero violations can still use max(count,1), so magnitude term controls zero.',false,'code implementation','code_implementation_only','max(count,1)','Need paper zero handling.','manual_confirmation','');
writetable(vertcat(rows{:}), fullfile(out_dir,'severity_formula_source_audit.csv'));
end

function T=row(file,func,item,text,paper,current,status,norm,missing,fix,note)
T=table(string(file),string(func),string(item),string(text),logical(paper),string(current),string(status),string(norm),string(missing),string(fix),string(note), ...
    'VariableNames', {'source_file','source_section_or_function','severity_item','formula_text_or_code','paper_formula_available','current_code_formula','formula_status','normalization_basis','missing_information','recommended_fix','note'});
end
function ensure_dir(path)
if exist(path,'dir')~=7, mkdir(path); end
end
