%% Phase 1: Build Manifold Candidate Library (Event-based, using hit flags)
% Generate stable/unstable manifolds from L1 Lyapunov orbit
% Stop propagation on first boundary hit (Moon LLO / Earth LEO / Escape 2LU)
% Classify candidates using hit_* (no tol shell checks)

clear; clc; close all;
fprintf('=== Phase 1: Manifold Candidate Library (Event-based) ===\n\n');

%% Load Phase 0 data
load('phase0_data.mat', 'p', 'X0_lyap', 'T_lyap', 'orbit_states', 't_orbit', 'x_L1');
fprintf('Loaded Lyapunov orbit: T=%.4f TU (%.2f days), %d points\n', ...
    T_lyap, units.time_tu2day(T_lyap, p), size(orbit_states, 1));

%% Generate manifolds for both branch signs
fprintf('\n1.1 Generating Manifolds (with Events)...\n');

% 重要：epsilon 不能太小，否则流形可能来源于积分误差
% 1e-6 VU ≈ 0.001 m/s (太小)
% 1e-3 VU ≈ 1 m/s (合理的量级)
epsilon = 1e-3;          % perturbation magnitude (VU), ~1 m/s
t_max   = 15 * T_lyap;   % max integration time (~200 days)

fprintf('  Manifold epsilon = %.0e VU (%.3f m/s)\n', epsilon, epsilon * p.VU * 1000);

% Branch +1
fprintf('  Generating branch +1 manifolds...\n');
[traj_u_p1, traj_s_p1, v_u_p1, v_s_p1, hit_u_p1, hit_s_p1] = orbits.manifold_generate( ...
    orbit_states, T_lyap, p.mu, p, epsilon, +1, t_max, t_orbit);
fprintf('    Unstable: %d trajectories, Stable: %d trajectories\n', ...
    length(traj_u_p1), length(traj_s_p1));

% Branch -1
fprintf('  Generating branch -1 manifolds...\n');
[traj_u_m1, traj_s_m1, v_u_m1, v_s_m1, hit_u_m1, hit_s_m1] = orbits.manifold_generate( ...
    orbit_states, T_lyap, p.mu, p, epsilon, -1, t_max, t_orbit);
fprintf('    Unstable: %d trajectories, Stable: %d trajectories\n', ...
    length(traj_u_m1), length(traj_s_m1));

% Quick hit statistics
fprintf('\n  Hit stats (Unstable +1): Moon=%d, Earth=%d, Escape=%d, None=%d\n', ...
    sum(hit_u_p1==1), sum(hit_u_p1==2), sum(hit_u_p1==3), sum(hit_u_p1==0));
fprintf('  Hit stats (Unstable -1): Moon=%d, Earth=%d, Escape=%d, None=%d\n', ...
    sum(hit_u_m1==1), sum(hit_u_m1==2), sum(hit_u_m1==3), sum(hit_u_m1==0));
fprintf('  Hit stats (Stable   +1): Moon=%d, Earth=%d, Escape=%d, None=%d\n', ...
    sum(hit_s_p1==1), sum(hit_s_p1==2), sum(hit_s_p1==3), sum(hit_s_p1==0));
fprintf('  Hit stats (Stable   -1): Moon=%d, Earth=%d, Escape=%d, None=%d\n', ...
    sum(hit_s_m1==1), sum(hit_s_m1==2), sum(hit_s_m1==3), sum(hit_s_m1==0));
%% (Optional but recommended) Diagnose Earth-approach: min r1 along trajectories
fprintf('\n1.1b Diagnosing Earth approach (min r1 along each trajectory)...\n');

% helper to compute min Earth distance along one traj
% traj columns: [t, x, y, vx, vy]
min_r1_of_traj = @(traj) min( sqrt( (traj(:,2)+p.mu).^2 + (traj(:,3)).^2 ) );

% collect all unstable + stable trajectories
all_traj_u = [traj_u_p1; traj_u_m1];
all_traj_s = [traj_s_p1; traj_s_m1];

min_r1_u = nan(length(all_traj_u),1);
min_r1_s = nan(length(all_traj_s),1);

for k = 1:length(all_traj_u)
    traj = all_traj_u{k};
    if ~isempty(traj)
        min_r1_u(k) = min_r1_of_traj(traj);
    end
end

for k = 1:length(all_traj_s)
    traj = all_traj_s{k};
    if ~isempty(traj)
        min_r1_s(k) = min_r1_of_traj(traj);
    end
end

% summarize
fprintf('  p.r_LEO = %.6e LU (%.0f km)\n', p.r_LEO, p.r_LEO*p.LU);

% report global minima (LU and km)
fprintf('  Unstable: min(min_r1) = %.6e LU (%.0f km)\n', ...
    min(min_r1_u, [], 'omitnan'), min(min_r1_u, [], 'omitnan')*p.LU);
fprintf('  Stable  : min(min_r1) = %.6e LU (%.0f km)\n', ...
    min(min_r1_s, [], 'omitnan'), min(min_r1_s, [], 'omitnan')*p.LU);

% how many come "near Earth" by some coarse thresholds
thr_list = [0.05, 0.03, 0.02, p.r_LEO];  % LU
for th = thr_list
    cu = sum(min_r1_u < th, 'omitnan');
    cs = sum(min_r1_s < th, 'omitnan');
    fprintf('  Count(min_r1 < %.4f LU = %.0f km): Unstable=%d, Stable=%d\n', ...
        th, th*p.LU, cu, cs);
end

% optional: show a few closest trajectories indices for debugging
[~, idx_u] = sort(min_r1_u, 'ascend', 'MissingPlacement','last');
fprintf('  Closest 5 unstable traj indices (min_r1 LU):\n');
for ii = 1:min(5, sum(~isnan(min_r1_u)))
    fprintf('    #%d: idx=%d, min_r1=%.6e LU (%.0f km)\n', ...
        ii, idx_u(ii), min_r1_u(idx_u(ii)), min_r1_u(idx_u(ii))*p.LU);
end
%% Classify manifold trajectories using hit flags
fprintf('\n1.2 Classifying Manifold Candidates (using hit)...\n');

% Initialize candidate structures
candidates_A = [];  % LEO -> L1 (stable manifold, Earth hit in backward propagation)
candidates_B = [];  % L1 -> Moon (unstable manifold, Moon hit)
candidates_C = [];  % Moon -> L1 (stable manifold, Moon hit in backward propagation)
candidates_D = [];  % L1 -> Earth (unstable manifold, Earth hit)

% Combine both branch signs
all_traj_u   = [traj_u_p1; traj_u_m1];
all_hit_u    = [hit_u_p1;  hit_u_m1];
all_signs_u  = [ +ones(length(traj_u_p1),1); -ones(length(traj_u_m1),1) ];

all_traj_s   = [traj_s_p1; traj_s_m1];
all_hit_s    = [hit_s_p1;  hit_s_m1];
all_signs_s  = [ +ones(length(traj_s_p1),1); -ones(length(traj_s_m1),1) ];

N_orbit = size(orbit_states, 1);

% --- Unstable manifolds -> B (Moon hit) and D (Earth hit)
fprintf('  Processing unstable manifolds...\n');
for j = 1:length(all_traj_u)
    traj = all_traj_u{j};
    hit  = all_hit_u(j);
    if isempty(traj) || hit == 0 || hit == 3
        continue;
    end

    X_end = traj(end, 2:5);  % [x, y, vx, vy]
    t_end = traj(end, 1);

    % Map back to orbit sample index (first N are +1 branch, next N are -1 branch)
    i_orbit = mod(j-1, N_orbit) + 1;
    sign_branch = all_signs_u(j);

    if hit == 1
        % B: L1 -> Moon
        r2 = sqrt((X_end(1) - 1 + p.mu)^2 + X_end(2)^2);
        cand.i_orbit = i_orbit;
        cand.sign = sign_branch;
        cand.epsilon = epsilon;            % 速度扰动幅值（VU）
        cand.t_end = t_end;
        cand.X_end = X_end;
        cand.r_moon = r2;
        cand.traj = traj;

        cand.X_orbit = orbit_states(i_orbit, 1:4);      % 周期轨道点（相位点）
        cand.X0 = traj(1,2:5);                          % 真实seed（周期点+扰动）
        cand.dv_seed = cand.X0(3:4) - cand.X_orbit(3:4);% 注入到不稳定流形所需的速度增量（VU）               
        cand.t0 = traj(1,1);                            % 一般为 0

        candidates_B = [candidates_B; cand];
    elseif hit == 2
        % D: L1 -> Earth
        r1 = sqrt((X_end(1) + p.mu)^2 + X_end(2)^2);
        cand.i_orbit = i_orbit;
        cand.sign = sign_branch;
        cand.t_end = t_end;
        cand.X_end = X_end;
        cand.r_earth = r1;
        cand.traj = traj;
        candidates_D = [candidates_D; cand];
    end
end
fprintf('    B candidates (L1->Moon): %d\n', length(candidates_B));
fprintf('    D candidates (L1->Earth): %d\n', length(candidates_D));

% --- Stable manifolds (backward time) -> A (Earth hit) and C (Moon hit)
fprintf('  Processing stable manifolds...\n');
for j = 1:length(all_traj_s)
    traj = all_traj_s{j};
    hit  = all_hit_s(j);
    if isempty(traj) || hit == 0 || hit == 3
        continue;
    end

    X_end = traj(end, 2:5);
    t_end = traj(end, 1);   % negative time (since integrated backward)

    i_orbit = mod(j-1, N_orbit) + 1;
    sign_branch = all_signs_s(j);

    if hit == 2
        % A: LEO -> L1 (found by backward integrating stable manifold until Earth hit)
        r1 = sqrt((X_end(1) + p.mu)^2 + X_end(2)^2);
        cand.i_orbit = i_orbit;
        cand.sign = sign_branch;
        cand.t_end = t_end;     % negative
        cand.X_end = X_end;
        cand.r_earth = r1;
        cand.traj = traj;
        candidates_A = [candidates_A; cand];
    elseif hit == 1
        % C: Moon -> L1 (backward stable manifold until Moon hit)
        r2 = sqrt((X_end(1) - 1 + p.mu)^2 + X_end(2)^2);
        cand.i_orbit = i_orbit;
        cand.sign = sign_branch;
        cand.t_end = t_end;     % negative
        cand.X_end = X_end;
        cand.r_moon = r2;
        cand.traj = traj;
        cand.X_moon_hit = traj(end,2:5);   % 反向积分末端：命中月球壳层的状态
        cand.t_moon_hit = traj(end,1);     % 负数
        cand.X_L1_start = traj(1,2:5);     % 反向积分起点：L1附近（已扰动）
        candidates_C = [candidates_C; cand];
    end
end
fprintf('    A candidates (LEO->L1): %d\n', length(candidates_A));
fprintf('    C candidates (Moon->L1): %d\n', length(candidates_C));

%% Rank candidates by transfer quality
fprintf('\n1.3 Ranking Candidates...\n');

% B: estimate capture dv at Moon (rough)
if ~isempty(candidates_B)
    for i = 1:length(candidates_B)
        X_end = candidates_B(i).X_end;
        t_end = candidates_B(i).t_end;

        [r_rel, v_rel] = frames.state_rel_body([X_end(1:2), X_end(3:4)]', t_end, 'moon', p.mu);

        r_mag = norm(r_rel) * p.LU;      % km
        v_circ = sqrt(p.mu_m / r_mag);   % km/s
        v_rel_mag = norm(v_rel) * p.VU;  % km/s

        candidates_B(i).v_rel = v_rel_mag;
        candidates_B(i).v_circ = v_circ;
        candidates_B(i).dv_capture_est = abs(v_rel_mag - v_circ);
    end

    [~, idx] = sort([candidates_B.dv_capture_est]);
    candidates_B = candidates_B(idx);

    fprintf('  Top 5 B candidates (lowest capture dv):\n');
    for i = 1:min(5, length(candidates_B))
        fprintf('    #%d: i_orbit=%d, sign=%+d, TOF=%.2f days, dv_cap=%.4f km/s\n', ...
            i, candidates_B(i).i_orbit, candidates_B(i).sign, ...
            units.time_tu2day(candidates_B(i).t_end, p), candidates_B(i).dv_capture_est);
    end
end

% D: Earth return candidates (report v_rel)
if ~isempty(candidates_D)
    for i = 1:length(candidates_D)
        X_end = candidates_D(i).X_end;
        t_end = candidates_D(i).t_end;

        [r_rel, v_rel] = frames.state_rel_body([X_end(1:2), X_end(3:4)]', t_end, 'earth', p.mu);

        candidates_D(i).r_rel = norm(r_rel) * p.LU; % km
        candidates_D(i).v_rel = norm(v_rel) * p.VU; % km/s
    end

    fprintf('  Top 5 D candidates (Earth return):\n');
    for i = 1:min(5, length(candidates_D))
        fprintf('    #%d: i_orbit=%d, sign=%+d, TOF=%.2f days, v_rel=%.4f km/s, r_rel=%.0f km\n', ...
            i, candidates_D(i).i_orbit, candidates_D(i).sign, ...
            units.time_tu2day(candidates_D(i).t_end, p), candidates_D(i).v_rel, candidates_D(i).r_rel);
    end
end

% A: estimate departure C3 at Earth hit point (note: t_end is negative)
if ~isempty(candidates_A)
    for i = 1:length(candidates_A)
        X_end = candidates_A(i).X_end;
        t_end = candidates_A(i).t_end; % negative

        [r_rel, v_rel] = frames.state_rel_body([X_end(1:2), X_end(3:4)]', t_end, 'earth', p.mu);

        r_mag = norm(r_rel) * p.LU;      % km
        v_rel_mag = norm(v_rel) * p.VU;  % km/s

        candidates_A(i).v_rel = v_rel_mag;
        candidates_A(i).r_rel = r_mag;
        candidates_A(i).C3 = v_rel_mag^2 - 2*p.mu_e/r_mag;
    end

    [~, idx] = sort([candidates_A.C3]);
    candidates_A = candidates_A(idx);

    fprintf('  Top 5 A candidates (lowest C3):\n');
    for i = 1:min(5, length(candidates_A))
        fprintf('    #%d: i_orbit=%d, sign=%+d, TOF=%.2f days, C3=%.2f km^2/s^2\n', ...
            i, candidates_A(i).i_orbit, candidates_A(i).sign, ...
            units.time_tu2day(-candidates_A(i).t_end, p), candidates_A(i).C3);
    end
end

% C: estimate Moon departure dv (note: t_end is negative)
if ~isempty(candidates_C)
    for i = 1:length(candidates_C)
        X_end = candidates_C(i).X_end;
        t_end = candidates_C(i).t_end; % negative

        [r_rel, v_rel] = frames.state_rel_body([X_end(1:2), X_end(3:4)]', t_end, 'moon', p.mu);

        r_mag = norm(r_rel) * p.LU;      % km
        v_circ = sqrt(p.mu_m / r_mag);   % km/s
        v_rel_mag = norm(v_rel) * p.VU;  % km/s

        candidates_C(i).v_rel = v_rel_mag;
        candidates_C(i).v_circ = v_circ;
        candidates_C(i).dv_dep_est = abs(v_rel_mag - v_circ);
    end

    [~, idx] = sort([candidates_C.dv_dep_est]);
    candidates_C = candidates_C(idx);

    fprintf('  Top 5 C candidates (lowest Moon departure dv):\n');
    for i = 1:min(5, length(candidates_C))
        fprintf('    #%d: i_orbit=%d, sign=%+d, TOF=%.2f days, dv_dep=%.4f km/s\n', ...
            i, candidates_C(i).i_orbit, candidates_C(i).sign, ...
            units.time_tu2day(-candidates_C(i).t_end, p), candidates_C(i).dv_dep_est);
    end
end

%% Save manifold library (include hit flags)
fprintf('\n1.4 Saving Manifold Library...\n');
save('phase1_manifolds.mat', ...
    'candidates_A','candidates_B','candidates_C','candidates_D', ...
    'traj_u_p1','traj_s_p1','traj_u_m1','traj_s_m1', ...
    'v_u_p1','v_s_p1','v_u_m1','v_s_m1', ...
    'hit_u_p1','hit_s_p1','hit_u_m1','hit_s_m1', ...
    'epsilon','t_max', '-v7.3');
fprintf('Saved to phase1_manifolds.mat\n');

%% Plot manifold overview (no invalid colors)
fprintf('\n1.5 Generating Manifold Visualization...\n');
figure('Position', [100, 100, 1200, 500]);

subplot(1,2,1);
hold on;
plot(orbit_states(:,1), orbit_states(:,2), 'k-', 'LineWidth', 2);

% plot a subset of unstable manifolds
for i = 1:min(50, length(traj_u_p1))
    traj = traj_u_p1{i};
    if ~isempty(traj)
        plot(traj(:,2), traj(:,3), 'r-', 'LineWidth', 0.5);
    end
end
for i = 1:min(50, length(traj_u_m1))
    traj = traj_u_m1{i};
    if ~isempty(traj)
        plot(traj(:,2), traj(:,3), 'b-', 'LineWidth', 0.5);
    end
end

plot(-p.mu, 0, 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'b');                 % Earth
plot(1-p.mu, 0, 'ko', 'MarkerSize', 6,  'MarkerFaceColor', [0.5 0.5 0.5]);     % Moon (gray)
plot(x_L1, 0, 'g^', 'MarkerSize', 8,  'MarkerFaceColor', 'g');                 % L1
xlabel('x (LU)'); ylabel('y (LU)');
title('Unstable Manifolds (red: +1, blue: -1)');
axis equal; grid on;
xlim([-0.5, 1.5]); ylim([-1, 1]);

subplot(1,2,2);
hold on;
plot(orbit_states(:,1), orbit_states(:,2), 'k-', 'LineWidth', 2);

% plot a subset of stable manifolds
for i = 1:min(50, length(traj_s_p1))
    traj = traj_s_p1{i};
    if ~isempty(traj)
        plot(traj(:,2), traj(:,3), 'r-', 'LineWidth', 0.5);
    end
end
for i = 1:min(50, length(traj_s_m1))
    traj = traj_s_m1{i};
    if ~isempty(traj)
        plot(traj(:,2), traj(:,3), 'b-', 'LineWidth', 0.5);
    end
end

plot(-p.mu, 0, 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'b');                 % Earth
plot(1-p.mu, 0, 'ko', 'MarkerSize', 6,  'MarkerFaceColor', [0.5 0.5 0.5]);     % Moon (gray)
plot(x_L1, 0, 'g^', 'MarkerSize', 8,  'MarkerFaceColor', 'g');                 % L1
xlabel('x (LU)'); ylabel('y (LU)');
title('Stable Manifolds (red: +1, blue: -1)');
axis equal; grid on;
xlim([-0.5, 1.5]); ylim([-1, 1]);

saveas(gcf, 'figures/phase1_manifolds.png');
fprintf('Saved visualization to phase1_manifolds.png\n');

%% Summary
fprintf('\n=== Phase 1 Complete ===\n');
fprintf('Manifold Library Summary:\n');
fprintf('  A candidates (LEO->L1): %d\n', length(candidates_A));
fprintf('  B candidates (L1->Moon): %d\n', length(candidates_B));
fprintf('  C candidates (Moon->L1): %d\n', length(candidates_C));
fprintf('  D candidates (L1->Earth): %d\n', length(candidates_D));

if ~isempty(candidates_B)
    fprintf('\nBest B candidate: dv_capture_est = %.4f km/s\n', candidates_B(1).dv_capture_est);
end
if ~isempty(candidates_A)
    fprintf('Best A candidate: C3 = %.2f km^2/s^2\n', candidates_A(1).C3);
end

fprintf('\nReady for Phase 2 (Level 3 direct shooting baseline).\n');