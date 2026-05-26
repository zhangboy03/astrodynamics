%% generate_results_v2.m: 生成 results.txt 文件
%
% 严格按照 assignment.md 的格式要求生成结果文件
%
% 事件代码:
%   -1: 飞船施加机动
%    0: 无机动轨道递推段
%    1: 从地球初始轨道出发
%    2: 到达目标环月轨道
%    3: 离开目标环月轨道
%    4: 返回地球
%    5: 与补给飞船交会对接

clear; clc;
fprintf('=== 生成 results.txt ===\n\n');

%% 1. 加载所有数据
load('phase0_data.mat', 'p', 'orbit_states', 'T_lyap', 't_orbit');
load('leo_to_l1_results.mat', 'results');
load('l1_to_llo_results.mat', 'results_L12LLO');
load('llo_to_earth_results.mat', 'results_LLO2Earth');

% 常数
ve = p.ve;
m_dry = p.m_dry;

%% 2. 提取关键数据

% Phase 1: LEO 出发
t_dep_LEO = results.t_dep_opt;
X_LEO = results.X_LEO(:);
dv_dep = results.dv_dep_opt(:);
m_fuel_LEO = results.m_fuel;
M_carry = results.M_carry;

% LEO 到 L1 对接
t_dock = results.t_dock;
X_arr_L1 = results.X_arr(:);
X_supply = results.X_supply(:);
dv_match = X_supply(3:4) - X_arr_L1(3:4);  % 速度匹配机动

% Phase 2: L1 到 LLO
t_depart_L1 = results_L12LLO.t_depart;
t_arr_LLO = results_L12LLO.t_arr;
m_fuel_L1 = results_L12LLO.m_fuel_L1;
dv_insert = results_L12LLO.dv_insert_syn(:);
m_fuel_after_insert = results_L12LLO.m_fuel_after;
X_after_insert = results_L12LLO.X_after_insert(:);

best = results_L12LLO.best_candidate;
X_orbit_L1 = best.X_orbit(:);  % Lyapunov轨道上的相位点（流形注入前）
X0_manifold = best.X0(:);      % 流形真实起点（扰动后的状态）
dv_seed = best.dv_seed(:);     % 注入不稳定流形所需的速度增量
X_end_manifold = best.X_end(:);  % 流形终点 (LLO 入轨前)

fprintf('流形注入 dv_seed: [%.6e, %.6e] VU (%.3f m/s)\n', ...
    dv_seed(1), dv_seed(2), norm(dv_seed) * p.VU * 1000);

% Phase 3: LLO 到 Earth
t_stay = results_LLO2Earth.t_stay;
t_dep_LLO = results_LLO2Earth.t_dep;
t_flight_return = results_LLO2Earth.t_flight;
X_dep_LLO = results_LLO2Earth.X_dep(:);
dv_return = results_LLO2Earth.dv_syn(:);
X_earth = results_LLO2Earth.X_earth(:);
t_total = results_LLO2Earth.t_total;

% 计算 LLO 出发前的圆轨道速度 (机动前速度)
v_before_return = X_dep_LLO(3:4) - dv_return;
X_LLO_before_return = [X_dep_LLO(1:2); v_before_return];

%% 3. 燃料计算

% L1 对接机动消耗燃料
dv_match_mps = norm(dv_match) * p.VU * 1000;
M_total_arr = m_dry + m_fuel_LEO + M_carry;
k_match = exp(-dv_match_mps / ve);
dm_match = M_total_arr * (1 - k_match);
m_fuel_after_match = m_fuel_LEO - dm_match;

fprintf('L1对接机动: dv = %.1f m/s, 消耗燃料 = %.1f kg\n', dv_match_mps, dm_match);
fprintf('对接后剩余燃料: %.1f kg (应该接近0)\n', m_fuel_after_match);

% LLO 入轨消耗燃料
dv_insert_mps = norm(dv_insert) * p.VU * 1000;
M_total_L1 = m_dry + m_fuel_L1 + M_carry;
k_insert = exp(-dv_insert_mps / ve);
dm_insert = M_total_L1 * (1 - k_insert);
m_fuel_calc_after_insert = m_fuel_L1 - dm_insert;

fprintf('LLO入轨机动: dv = %.1f m/s, 消耗燃料 = %.1f kg\n', dv_insert_mps, dm_insert);
fprintf('入轨后剩余燃料: %.1f kg\n', m_fuel_calc_after_insert);

% 返回地球消耗燃料
dv_return_mps = norm(dv_return) * p.VU * 1000;
M_total_LLO = m_dry + m_fuel_after_insert;  % 载荷已卸载
k_return = exp(-dv_return_mps / ve);
dm_return = M_total_LLO * (1 - k_return);
m_fuel_final = m_fuel_after_insert - dm_return;

fprintf('返回机动: dv = %.1f m/s, 消耗燃料 = %.1f kg\n', dv_return_mps, dm_return);
fprintf('最终剩余燃料: %.1f kg\n', m_fuel_final);

%% 4. 构建 results 数据

% 格式: [Event, Time, x, y, vx, vy, dvx, dvy, M_fuel, M_carry]
data = [];

% ========================================
% Event 1: LEO 出发 (两行: 机动前, 机动后)
% ========================================
% 机动前
data = [data; 1, t_dep_LEO, X_LEO(1), X_LEO(2), X_LEO(3), X_LEO(4), 0, 0, m_fuel_LEO, M_carry];
% 机动后 (火箭提供 Δv, 燃料不变)
X_after_dep = X_LEO;
X_after_dep(3:4) = X_LEO(3:4) + dv_dep;
data = [data; 1, t_dep_LEO, X_after_dep(1), X_after_dep(2), X_after_dep(3), X_after_dep(4), dv_dep(1), dv_dep(2), m_fuel_LEO, M_carry];

% ========================================
% Event 0: LEO 到 L1 滑行段
% ========================================
% 起点 (与上一行相同位置和速度)
data = [data; 0, t_dep_LEO, X_after_dep(1), X_after_dep(2), X_after_dep(3), X_after_dep(4), 0, 0, m_fuel_LEO, M_carry];
% 终点 (到达 L1 附近)
data = [data; 0, t_dock, X_arr_L1(1), X_arr_L1(2), X_arr_L1(3), X_arr_L1(4), 0, 0, m_fuel_LEO, M_carry];

% ========================================
% Event -1: L1 对接机动 (速度匹配)
% ========================================
% 机动前
data = [data; -1, t_dock, X_arr_L1(1), X_arr_L1(2), X_arr_L1(3), X_arr_L1(4), 0, 0, m_fuel_LEO, M_carry];
% 机动后 (消耗燃料)
X_after_match = X_arr_L1;
X_after_match(3:4) = X_supply(3:4);
data = [data; -1, t_dock, X_after_match(1), X_after_match(2), X_after_match(3), X_after_match(4), dv_match(1), dv_match(2), m_fuel_after_match, M_carry];

% ========================================
% Event 5: 与补给飞船对接 (加注燃料)
% ========================================
% 对接前
data = [data; 5, t_dock, X_supply(1), X_supply(2), X_supply(3), X_supply(4), 0, 0, m_fuel_after_match, M_carry];
% 对接后 (加注燃料)
data = [data; 5, t_dock, X_supply(1), X_supply(2), X_supply(3), X_supply(4), 0, 0, m_fuel_L1, M_carry];

% ========================================
% Event 0: L1 Lyapunov 轨道等待段
% ========================================
% 起点 (对接点)
data = [data; 0, t_dock, X_supply(1), X_supply(2), X_supply(3), X_supply(4), 0, 0, m_fuel_L1, M_carry];
% 终点 (到达流形注入点，即 Lyapunov 轨道上的相位点)
data = [data; 0, t_depart_L1, X_orbit_L1(1), X_orbit_L1(2), X_orbit_L1(3), X_orbit_L1(4), 0, 0, m_fuel_L1, M_carry];

% ========================================
% Event -1: 流形注入机动 (施加 dv_seed 进入不稳定流形)
% ========================================
% 计算流形注入消耗的燃料
dv_seed_mps = norm(dv_seed) * p.VU * 1000;  % m/s
M_before_seed = m_dry + m_fuel_L1 + M_carry;
k_seed = exp(-dv_seed_mps / ve);
dm_seed = M_before_seed * (1 - k_seed);
m_fuel_after_seed = m_fuel_L1 - dm_seed;

fprintf('流形注入机动: dv = %.3f m/s, 消耗燃料 = %.3f kg\n', dv_seed_mps, dm_seed);

% 机动前 (在 Lyapunov 轨道相位点)
data = [data; -1, t_depart_L1, X_orbit_L1(1), X_orbit_L1(2), X_orbit_L1(3), X_orbit_L1(4), 0, 0, m_fuel_L1, M_carry];
% 机动后 (进入流形，速度增加 dv_seed)
data = [data; -1, t_depart_L1, X0_manifold(1), X0_manifold(2), X0_manifold(3), X0_manifold(4), dv_seed(1), dv_seed(2), m_fuel_after_seed, M_carry];

% ========================================
% Event 0: 流形转移段 (从流形起点到 LLO 附近)
% ========================================
% 起点 (流形真实起点，扰动后状态)
data = [data; 0, t_depart_L1, X0_manifold(1), X0_manifold(2), X0_manifold(3), X0_manifold(4), 0, 0, m_fuel_after_seed, M_carry];
% 终点 (到达 LLO 附近)
data = [data; 0, t_arr_LLO, X_end_manifold(1), X_end_manifold(2), X_end_manifold(3), X_end_manifold(4), 0, 0, m_fuel_after_seed, M_carry];

% ========================================
% Event -1: LLO 入轨机动
% ========================================
% 重新计算 LLO 入轨后的燃料（考虑流形注入已消耗的燃料）
M_before_insert = m_dry + m_fuel_after_seed + M_carry;
k_insert_new = exp(-dv_insert_mps / ve);
dm_insert_new = M_before_insert * (1 - k_insert_new);
m_fuel_after_insert_new = m_fuel_after_seed - dm_insert_new;

fprintf('LLO入轨机动（修正后）: 消耗燃料 = %.1f kg, 剩余 = %.1f kg\n', dm_insert_new, m_fuel_after_insert_new);

% 机动前
data = [data; -1, t_arr_LLO, X_end_manifold(1), X_end_manifold(2), X_end_manifold(3), X_end_manifold(4), 0, 0, m_fuel_after_seed, M_carry];
% 机动后 (消耗燃料)
data = [data; -1, t_arr_LLO, X_after_insert(1), X_after_insert(2), X_after_insert(3), X_after_insert(4), dv_insert(1), dv_insert(2), m_fuel_after_insert_new, M_carry];

% ========================================
% Event 2: 到达 LLO (载荷变为0)
% ========================================
data = [data; 2, t_arr_LLO, X_after_insert(1), X_after_insert(2), X_after_insert(3), X_after_insert(4), 0, 0, m_fuel_after_insert_new, 0];

% ========================================
% Event 3: 离开 LLO (紧接 Event 2)
% ========================================
% 使用机动前的状态 (圆轨道速度)
data = [data; 3, t_dep_LLO, X_LLO_before_return(1), X_LLO_before_return(2), X_LLO_before_return(3), X_LLO_before_return(4), 0, 0, m_fuel_after_insert_new, 0];

% ========================================
% Event -1: 返回机动
% ========================================
% 重新计算返回后的燃料
M_before_return = m_dry + m_fuel_after_insert_new;  % 载荷已卸载
k_return_new = exp(-dv_return_mps / ve);
dm_return_new = M_before_return * (1 - k_return_new);
m_fuel_final_new = m_fuel_after_insert_new - dm_return_new;

fprintf('返回机动（修正后）: 消耗燃料 = %.1f kg, 最终剩余 = %.1f kg\n', dm_return_new, m_fuel_final_new);

% 机动前
data = [data; -1, t_dep_LLO, X_LLO_before_return(1), X_LLO_before_return(2), X_LLO_before_return(3), X_LLO_before_return(4), 0, 0, m_fuel_after_insert_new, 0];
% 机动后 (消耗燃料)
data = [data; -1, t_dep_LLO, X_dep_LLO(1), X_dep_LLO(2), X_dep_LLO(3), X_dep_LLO(4), dv_return(1), dv_return(2), m_fuel_final_new, 0];

% ========================================
% Event 0: 返回地球滑行段
% ========================================
% 起点
data = [data; 0, t_dep_LLO, X_dep_LLO(1), X_dep_LLO(2), X_dep_LLO(3), X_dep_LLO(4), 0, 0, m_fuel_final_new, 0];
% 终点
t_earth = t_dep_LLO + t_flight_return;
data = [data; 0, t_earth, X_earth(1), X_earth(2), X_earth(3), X_earth(4), 0, 0, m_fuel_final_new, 0];

% ========================================
% Event 4: 返回地球 (最后一行)
% ========================================
data = [data; 4, t_earth, X_earth(1), X_earth(2), X_earth(3), X_earth(4), 0, 0, m_fuel_final_new, 0];

%% 5. 写入文件
fprintf('\n--- 写入 results.txt ---\n');

fid = fopen('results.txt', 'w');

for i = 1:size(data, 1)
    event = data(i, 1);
    t = data(i, 2);
    x = data(i, 3);
    y = data(i, 4);
    vx = data(i, 5);
    vy = data(i, 6);
    dvx = data(i, 7);
    dvy = data(i, 8);
    m_fuel = data(i, 9);
    m_carry = data(i, 10);

    % 格式: Event 为整数, 其他为 12 位有效数字科学计数法
    fprintf(fid, '%d\t%.12e\t%.12e\t%.12e\t%.12e\t%.12e\t%.12e\t%.12e\t%.12e\t%.12e\n', ...
        event, t, x, y, vx, vy, dvx, dvy, m_fuel, m_carry);
end

fclose(fid);

fprintf('results.txt 已生成, 共 %d 行\n', size(data, 1));

%% 6. 验证输出
fprintf('\n--- 验证 ---\n');
fprintf('事件序列:\n');
events = data(:, 1);
for i = 1:length(events)
    switch events(i)
        case 1
            fprintf('  %2d: Event 1 - LEO 出发\n', i);
        case 0
            fprintf('  %2d: Event 0 - 滑行段\n', i);
        case -1
            fprintf('  %2d: Event -1 - 机动\n', i);
        case 5
            fprintf('  %2d: Event 5 - 对接\n', i);
        case 2
            fprintf('  %2d: Event 2 - 到达 LLO\n', i);
        case 3
            fprintf('  %2d: Event 3 - 离开 LLO\n', i);
        case 4
            fprintf('  %2d: Event 4 - 返回地球\n', i);
    end
end

fprintf('\n最后一行事件: %d (应为 4)\n', events(end));
fprintf('总时间: %.2f 天\n', data(end, 2) * p.TU / 86400);
fprintf('最终燃料: %.1f kg (修正后)\n', m_fuel_final_new);

% 燃料消耗汇总
fprintf('\n--- 燃料消耗汇总 ---\n');
fprintf('  L1对接机动: %.1f kg\n', dm_match);
fprintf('  流形注入机动: %.3f kg\n', dm_seed);
fprintf('  LLO入轨机动: %.1f kg\n', dm_insert_new);
fprintf('  返回机动: %.1f kg\n', dm_return_new);
fprintf('  总消耗: %.1f kg\n', dm_match + dm_seed + dm_insert_new + dm_return_new);

fprintf('\n=== 完成 ===\n');
