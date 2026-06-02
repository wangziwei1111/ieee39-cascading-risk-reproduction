function main_audit_severity_component_field_availability()
root=fileparts(fileparts(mfilename('fullpath')));
out_dir=fullfile(root,'results','calibration','severity_formula'); ensure_dir(out_dir);
src_root=fullfile(root,'results','calibration','wind_speed_component_diagnostic_rerun');
psets=["high_hidden_failure","benchmark_calibrated_seed"]; scens=["wind_speed_11_28","wind_speed_12_00"];
req=["basic_LLR","basic_LFOR","basic_NVOR","basic_CRI","total_load_shed_mw","total_load_shed_frac","max_line_loading_pu","max_voltage_deviation_pu","overloaded_branch_count","voltage_violation_bus_count","branch_loading_vector","bus_voltage_vector","total_load_mw","branch_count","bus_count","normalization_base_load","normalization_branch_count","normalization_bus_count"];
rows={};
for p=1:numel(psets)
 for s=1:numel(scens)
  for tbl=["markov_chain_summary","severity_component_trace"]
   path=fullfile(src_root,psets(p),scens(s),'tables',tbl+'.csv');
   names=string.empty;
   if exist(path,'file')==2, T=readtable(path,'TextType','string','Delimiter',','); names=string(T.Properties.VariableNames); end
   for r=1:numel(req)
    avail=ismember(req(r),names);
    fallback=ismember(req(r),["branch_loading_vector","bus_voltage_vector","total_load_mw","branch_count","bus_count","normalization_base_load","normalization_branch_count","normalization_bus_count"]);
    block=ismember(req(r),["basic_LLR","basic_LFOR","basic_NVOR","basic_CRI","total_load_shed_frac","max_line_loading_pu","max_voltage_deviation_pu","overloaded_branch_count","voltage_violation_bus_count"]) && ~avail && tbl=="severity_component_trace";
    rows{end+1,1}=table(psets(p),scens(s),tbl,req(r),avail,needed(req(r)),fallback,block,fix(avail,block), ...
      "Field availability audit for offline severity recompute.", ...
      'VariableNames',{'parameter_set_id','scenario_id','source_table','required_field','field_available','needed_for_metric','fallback_possible','blocking_if_missing','recommended_fix','note'}); %#ok<AGROW>
   end
  end
 end
end
writetable(vertcat(rows{:}),fullfile(out_dir,'severity_component_field_availability.csv'));
end
function s=needed(f)
if contains(f,"LLR")||contains(f,"load"), s="LLR"; elseif contains(f,"LFOR")||contains(f,"line")||contains(f,"branch"), s="LFOR"; elseif contains(f,"NVOR")||contains(f,"voltage")||contains(f,"bus"), s="NVOR"; elseif contains(f,"CRI"), s="CRI"; else, s="diagnostic_context"; end
end
function r=fix(avail,block)
if avail, r="no_fix_required"; elseif block, r="run_severity_component_trace_smoke_if_needed"; else, r="not_required_for_current_recompute"; end
end
function ensure_dir(path), if exist(path,'dir')~=7, mkdir(path); end, end
