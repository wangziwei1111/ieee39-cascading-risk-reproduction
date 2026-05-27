function require_matpower(cfg)
%REQUIRE_MATPOWER 检查MATPOWER核心函数是否可用。
% 输入：
%   cfg - 全局配置，包含MATPOWER候选路径。
% 输出：
%   无。若缺失MATPOWER则报错。
% 物理含义：
%   潮流计算必须依赖MATPOWER，不能退化为非MATPOWER实现。

needed = {'case39', 'runpf', 'loadcase', 'mpoption'};

if any(cellfun(@(f) exist(f, 'file') ~= 2, needed)) ...
        && isfield(cfg, 'matpower_candidate_paths')
    for p = 1:numel(cfg.matpower_candidate_paths)
        candidate = cfg.matpower_candidate_paths{p};
        if exist(candidate, 'dir')
            addpath(genpath(candidate));
            if all(cellfun(@(f) exist(f, 'file') == 2, needed))
                fprintf('已自动加入MATPOWER路径：%s\n', candidate);
                break;
            end
        end
    end
end

missing = {};
for k = 1:numel(needed)
    if exist(needed{k}, 'file') ~= 2
        missing{end + 1} = needed{k}; %#ok<AGROW>
    end
end

if ~isempty(missing)
    error(['MATPOWER路径未配置，缺少函数：%s。\n', ...
        '请先在MATLAB中 addpath(genpath(''你的MATPOWER目录'')) 或运行 savepath 后重试。'], ...
        strjoin(missing, ', '));
end
end
