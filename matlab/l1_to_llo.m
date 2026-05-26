%% L12LLO.m: L1 Lyapunov Orbit to LLO Transfer
%
% Design transfer from L1 Lyapunov orbit to 100 km Low Lunar Orbit (LLO)
% using pre-computed unstable manifold candidates from phase1_manifolds.mat.
%
% Key features:
%   - Uses manifold data directly (no optimization needed)
%   - Ignores dv_seed (~1 mm/s) as natural drift
%   - Computes precise vector delta-v for LLO insertion in synodic frame
%   - Selects optimal candidate (min dv within time budget)
%
% Critical insight for LLO insertion:
%   In the rotating (synodic) frame, a circular orbit around the Moon requires
%   accounting for frame rotation. The synodic velocity for circular motion is:
%     v_syn = v_circ_inertial - omega x r_rel
%   where omega = 1 (normalized) and r_rel is position relative to Moon.

clear; clc; close all;
fprintf('=== L1 to LLO Transfer Design ===\n\n');

%% 1. Load Data
fprintf('--- Loading Data ---\n');

% Load system parameters and Lyapunov orbit
load('phase0_data.mat', 'p', 'orbit_states', 'T_lyap', 't_orbit', 'x_L1');
fprintf('  Lyapunov orbit: T=%.4f TU (%.2f days), %d points\n', ...
    T_lyap, units.time_tu2day(T_lyap, p), size(orbit_states, 1));

% Load manifold candidates
load('phase1_manifolds.mat', 'candidates_B');
fprintf('  Loaded %d B candidates (L1 -> Moon)\n', length(candidates_B));

% Load Phase 1 results (LEO to L1)
load('leo_to_l1_results.mat', 'results');
t_dock = results.t_dock;
M_carry = results.M_carry;
m_dry = results.m_dry;

% Load Phase 4 results to get return dv for fuel calculation
load('llo_to_earth_results.mat', 'results_LLO2Earth');
dv_return_mps = results_LLO2Earth.dv_return_mps;

% Calculate required fuel at L1 to leave exactly 50 kg at Earth
% Target: m_fuel_final = 50 kg
m_fuel_final_target = 50;  % kg
ve = p.ve;

% Step 1: Calculate required fuel at LLO departure
% m_fuel_LLO = (m_fuel_final + m_dry*(1-k_return)) / k_return
k_return = exp(-dv_return_mps / ve);
m_fuel_LLO_required = (m_fuel_final_target + m_dry*(1-k_return)) / k_return;

% Step 2: Will calculate m_fuel_L1 after we know the insertion dv
% For now, use a placeholder that will be updated after candidate selection
m_fuel_start = 15000;  % Will be recalculated after dv_insert is known
M_total = m_dry + m_fuel_start + M_carry;

fprintf('\n  Fuel planning (target: %.0f kg final):\n', m_fuel_final_target);
fprintf('    Return dv: %.1f m/s\n', dv_return_mps);
fprintf('    Required fuel at LLO: %.1f kg\n', m_fuel_LLO_required);

fprintf('\n  Phase 1 results:\n');
fprintf('    Docking time: %.4f TU (%.2f days)\n', t_dock, units.time_tu2day(t_dock, p));
fprintf('    Payload mass: %.1f kg\n', M_carry);
fprintf('    Total mass at L1: %.1f kg\n', M_total);

%% 2. Compute Precise LLO Insertion Delta-v for Each Candidate
fprintf('\n--- Computing Precise LLO Insertion Delta-v ---\n');

n_cand = length(candidates_B);
for i = 1:n_cand
    X_end = candidates_B(i).X_end;  % synodic state [x, y, vx, vy]

    % Position relative to Moon in synodic frame
    r_rel_syn = [X_end(1) - (1-p.mu), X_end(2)];
    r_mag_LU = norm(r_rel_syn);
    r_mag_km = r_mag_LU * p.LU;

    % Keplerian circular velocity
    v_circ_kep_kms = sqrt(p.mu_m / r_mag_km);
    v_circ_kep_VU = v_circ_kep_kms / p.VU;

    % Position unit vector from Moon center (synodic frame)
    r_hat_syn = r_rel_syn / norm(r_rel_syn);

    % In rotating frame, circular orbit velocity requires correction:
    % v_syn = v_inertial_rel - omega x r_rel
    % where omega x r = (-r_y, r_x) for omega = (0,0,1)

    % Prograde direction (counter-clockwise in inertial frame)
    theta_hat_pro = [-r_hat_syn(2); r_hat_syn(1)];
    v_circ_syn_pro = v_circ_kep_VU * theta_hat_pro - [-r_rel_syn(2); r_rel_syn(1)];

    % Retrograde direction (clockwise in inertial frame)
    theta_hat_ret = [r_hat_syn(2); -r_hat_syn(1)];
    v_circ_syn_ret = v_circ_kep_VU * theta_hat_ret - [-r_rel_syn(2); r_rel_syn(1)];

    % Current velocity in synodic frame
    v_arr_syn = X_end(3:4)';

    % Delta-v needed for each direction (synodic frame)
    dv_syn_pro = v_circ_syn_pro - v_arr_syn;
    dv_syn_ret = v_circ_syn_ret - v_arr_syn;

    % Choose direction with smaller delta-v
    if norm(dv_syn_pro) <= norm(dv_syn_ret)
        dv_insert_syn = dv_syn_pro;
        v_circ_syn = v_circ_syn_pro;
        direction = +1;  % Prograde
    else
        dv_insert_syn = dv_syn_ret;
        v_circ_syn = v_circ_syn_ret;
        direction = -1;  % Retrograde
    end

    % Store results
    candidates_B(i).dv_insert_syn = dv_insert_syn;          % Synodic frame dv [2x1] (VU)
    candidates_B(i).dv_insert_mag = norm(dv_insert_syn) * p.VU;  % km/s
    candidates_B(i).direction = direction;
    candidates_B(i).v_circ_syn = v_circ_syn;                % Target circular velocity (synodic)
    candidates_B(i).v_circ_kep_VU = v_circ_kep_VU;          % Keplerian circular velocity
    candidates_B(i).r_rel_syn = r_rel_syn;                  % Position relative to Moon
end

fprintf('  Computed insertion delta-v for all %d candidates\n', n_cand);

%% 3. Phase Alignment and Time Computation
fprintf('\n--- Computing Phase Alignment and Timing ---\n');

for i = 1:n_cand
    i_orbit = candidates_B(i).i_orbit;

    % Phase time of this candidate on the Lyapunov orbit
    t_phase = t_orbit(i_orbit);

    % Current phase at docking time
    phase_dock = mod(t_dock, T_lyap);

    % Wait time to reach correct departure phase
    t_wait = mod(t_phase - phase_dock, T_lyap);

    % Actual departure time from L1
    t_depart = t_dock + t_wait;

    % LLO arrival time
    t_arr = t_depart + candidates_B(i).t_end;

    % Store timing
    candidates_B(i).t_wait = t_wait;
    candidates_B(i).t_depart = t_depart;
    candidates_B(i).t_arr = t_arr;
    candidates_B(i).total_time = t_arr;  % From mission start to LLO arrival
end

fprintf('  Computed timing for all candidates\n');

%% 4. Select Optimal Candidate
fprintf('\n--- Selecting Optimal Candidate ---\n');

% Extract delta-v and arrival times
dv_all = [candidates_B.dv_insert_mag];
time_all = [candidates_B.t_arr];

% Filter: total time < 80 days (reserve 20 days for return)
max_time_TU = units.time_day2tu(80, p);
valid_idx = find(time_all < max_time_TU);

if isempty(valid_idx)
    warning('No candidates within time budget, using shortest time');
    [~, valid_idx] = min(time_all);
end

% Among valid candidates, select minimum delta-v
[~, best_local] = min(dv_all(valid_idx));
best_idx = valid_idx(best_local);

best = candidates_B(best_idx);

% Direction string
if best.direction > 0
    dir_str = 'Prograde';
else
    dir_str = 'Retrograde';
end

fprintf('\nSelected candidate #%d:\n', best_idx);
fprintf('  Lyapunov orbit index: %d\n', best.i_orbit);
fprintf('  Branch sign: %+d\n', best.sign);
fprintf('  Direction: %s\n', dir_str);
fprintf('  Wait time: %.4f TU (%.2f days)\n', best.t_wait, units.time_tu2day(best.t_wait, p));
fprintf('  Manifold TOF: %.4f TU (%.2f days)\n', best.t_end, units.time_tu2day(best.t_end, p));
fprintf('  LLO insertion dv: %.6f km/s\n', best.dv_insert_mag);
fprintf('  LLO arrival time: %.4f TU (%.2f days from mission start)\n', ...
    best.t_arr, units.time_tu2day(best.t_arr, p));

%% 5. Fuel Consumption Calculation (with backward planning)
fprintf('\n--- Fuel Budget Calculation (Target: 50 kg at Earth) ---\n');

% Now we know the insertion dv, calculate the correct fuel at L1
dv_insert_mps = best.dv_insert_mag * 1000;  % m/s

% Backward calculation:
% Step 1: m_fuel_LLO_required already calculated (to leave 50 kg at Earth)
% Step 2: Calculate m_fuel_L1 needed to have m_fuel_LLO_required after insertion
%   m_fuel_after_insert = m_fuel_L1 - (m_dry + m_fuel_L1 + M_carry) * (1 - exp(-dv/ve))
%   m_fuel_LLO = m_fuel_L1*k_insert - (m_dry + M_carry)*(1-k_insert)
%   m_fuel_L1 = (m_fuel_LLO + (m_dry + M_carry)*(1-k_insert)) / k_insert

k_insert = exp(-dv_insert_mps / ve);
m_fuel_L1_required = (m_fuel_LLO_required + (m_dry + M_carry)*(1-k_insert)) / k_insert;

% Check capacity and apply
if m_fuel_L1_required > p.m_fuel_max
    fprintf('  WARNING: Required fuel %.1f kg > max capacity %.0f kg\n', ...
        m_fuel_L1_required, p.m_fuel_max);
    m_fuel_start = p.m_fuel_max;
else
    m_fuel_start = m_fuel_L1_required;
end

fprintf('  Insertion dv: %.1f m/s (k=%.6f)\n', dv_insert_mps, k_insert);
fprintf('  Required fuel at LLO: %.1f kg\n', m_fuel_LLO_required);
fprintf('  Required fuel at L1: %.1f kg\n', m_fuel_L1_required);
fprintf('  Fuel to load at L1: %.1f kg\n', m_fuel_start);

% Forward verification
M_total = m_dry + m_fuel_start + M_carry;
[M_after, dm_insert] = mission.fuel_consumption(M_total, dv_insert_mps, ve);
m_fuel_after = m_fuel_start - dm_insert;

fprintf('\n  Forward verification:\n');
fprintf('    Mass at L1: %.1f kg\n', M_total);
fprintf('    Fuel consumed for insertion: %.1f kg\n', dm_insert);
fprintf('    Fuel after insertion: %.1f kg (target: %.1f kg)\n', m_fuel_after, m_fuel_LLO_required);

% Verify final fuel at Earth
M_LLO_total = m_dry + m_fuel_after;
[~, dm_return] = mission.fuel_consumption(M_LLO_total, dv_return_mps, ve);
m_fuel_final = m_fuel_after - dm_return;
fprintf('    Expected final fuel at Earth: %.1f kg (target: 50 kg)\n', m_fuel_final);

%% 6. Delta-v Details
fprintf('\n--- Delta-v Details (Synodic Frame) ---\n');

dv_insert_syn = best.dv_insert_syn;
fprintf('  LLO insertion dv:\n');
fprintf('    dvx = %.12e VU\n', dv_insert_syn(1));
fprintf('    dvy = %.12e VU\n', dv_insert_syn(2));
fprintf('    |dv| = %.6f km/s\n', norm(dv_insert_syn) * p.VU);

%% 7. Verify LLO Circular Orbit
fprintf('\n--- LLO Verification ---\n');

% Post-insertion state (synodic frame)
X_insert = best.X_end(:);
X_after_insert = X_insert;
X_after_insert(3:4) = X_insert(3:4) + dv_insert_syn(:);

% LLO orbital period (~1.8 hours for 100 km altitude)
T_LLO = 2*pi*sqrt((p.R_m + 100)^3 / p.mu_m) / p.TU;
fprintf('  LLO period: %.4f TU (%.2f hours)\n', T_LLO, T_LLO * p.TU / 3600);

% Propagate for 3 orbits to verify stability
[t_verify, X_verify] = cr3bp.propagate(X_after_insert, [0, 3*T_LLO], p.mu);

% Check altitude stability (distance from Moon center)
r2_verify = sqrt((X_verify(:,1) - (1-p.mu)).^2 + X_verify(:,2).^2);
alt_verify = (r2_verify - p.R_m/p.LU) * p.LU;  % km

fprintf('\n  Orbit verification (3 orbits):\n');
fprintf('    Altitude min: %.2f km\n', min(alt_verify));
fprintf('    Altitude max: %.2f km\n', max(alt_verify));
fprintf('    Altitude variation: %.2f km\n', max(alt_verify) - min(alt_verify));

% Verify altitude is near 100 km
target_alt = 100;  % km
alt_error = abs(mean(alt_verify) - target_alt);
fprintf('    Mean altitude: %.2f km (target: %.0f km)\n', mean(alt_verify), target_alt);
fprintf('    Altitude error: %.2f km\n', alt_error);

%% 8. Save Results
fprintf('\n--- Saving Results ---\n');

results_L12LLO.best_candidate = best;
results_L12LLO.best_idx = best_idx;
results_L12LLO.t_dock = t_dock;
results_L12LLO.t_depart = best.t_depart;
results_L12LLO.t_arr = best.t_arr;
results_L12LLO.t_wait = best.t_wait;
results_L12LLO.t_manifold = best.t_end;
results_L12LLO.dv_insert_syn = dv_insert_syn;
results_L12LLO.dv_insert_mag_kms = best.dv_insert_mag;
results_L12LLO.direction = best.direction;
results_L12LLO.direction_str = dir_str;
results_L12LLO.M_total = M_total;
results_L12LLO.M_after = M_after;
results_L12LLO.dm_insert = dm_insert;
results_L12LLO.m_fuel_L1 = m_fuel_start;  % Fuel loaded at L1
results_L12LLO.m_fuel_after = m_fuel_after;
results_L12LLO.m_fuel_final_target = m_fuel_final_target;  % Target fuel at Earth
results_L12LLO.M_carry = M_carry;
results_L12LLO.traj = best.traj;
results_L12LLO.X_after_insert = X_after_insert;
results_L12LLO.alt_verify = alt_verify;
results_L12LLO.p = p;

save('l1_to_llo_results.mat', 'results_L12LLO');
fprintf('  Results saved to l1_to_llo_results.mat\n');

%% 9. Generate Visualization
fprintf('\n--- Generating Visualization ---\n');

figure('Position', [100, 100, 1400, 500]);

% Subplot 1: Full transfer trajectory
subplot(1, 3, 1);
hold on; axis equal; grid on;

% Plot Lyapunov orbit
plot(orbit_states(:,1), orbit_states(:,2), 'b-', 'LineWidth', 2, 'DisplayName', 'Lyapunov Orbit');

% Plot manifold trajectory
traj = best.traj;
plot(traj(:,2), traj(:,3), 'r-', 'LineWidth', 1.5, 'DisplayName', 'Manifold Transfer');

% Plot Earth and Moon
theta_circle = linspace(0, 2*pi, 100);
r_earth_plot = p.R_e / p.LU * 3;
r_moon_plot = p.R_m / p.LU * 10;  % Exaggerated for visibility
fill(-p.mu + r_earth_plot*cos(theta_circle), r_earth_plot*sin(theta_circle), ...
    'b', 'EdgeColor', 'b', 'FaceAlpha', 0.3, 'DisplayName', 'Earth');
fill(1-p.mu + r_moon_plot*cos(theta_circle), r_moon_plot*sin(theta_circle), ...
    [0.5 0.5 0.5], 'EdgeColor', [0.5 0.5 0.5], 'FaceAlpha', 0.3, 'DisplayName', 'Moon');

% Mark key points
plot(best.X_orbit(1), best.X_orbit(2), 'go', 'MarkerSize', 10, 'MarkerFaceColor', 'g', ...
    'DisplayName', 'Departure');
plot(best.X_end(1), best.X_end(2), 'rs', 'MarkerSize', 10, 'MarkerFaceColor', 'r', ...
    'DisplayName', 'LLO Insertion');
plot(x_L1, 0, 'kx', 'MarkerSize', 12, 'LineWidth', 2, 'DisplayName', 'L1');

xlabel('x (LU)'); ylabel('y (LU)');
title('L1 to LLO Transfer (Full View)');
legend('Location', 'best');
xlim([0.7, 1.1]); ylim([-0.2, 0.2]);

% Subplot 2: Moon-centered view with LLO
subplot(1, 3, 2);
hold on; axis equal; grid on;

% Moon position
moon_x = 1 - p.mu;

% Plot Moon (to scale)
r_moon_km = p.R_m;
r_moon_LU = r_moon_km / p.LU;
fill(moon_x + r_moon_LU*cos(theta_circle), r_moon_LU*sin(theta_circle), ...
    [0.5 0.5 0.5], 'EdgeColor', [0.3 0.3 0.3], 'FaceAlpha', 0.5);

% Plot 100 km LLO circle
r_LLO_LU = (r_moon_km + 100) / p.LU;
plot(moon_x + r_LLO_LU*cos(theta_circle), r_LLO_LU*sin(theta_circle), ...
    'g--', 'LineWidth', 1.5, 'DisplayName', '100 km LLO');

% Plot arrival trajectory (last portion of manifold)
n_last = min(50, size(traj, 1));
plot(traj(end-n_last+1:end, 2), traj(end-n_last+1:end, 3), 'r-', 'LineWidth', 2, ...
    'DisplayName', 'Approach');

% Plot verified LLO orbit
plot(X_verify(:,1), X_verify(:,2), 'b-', 'LineWidth', 1, 'DisplayName', 'LLO (verified)');

% Mark insertion point
plot(best.X_end(1), best.X_end(2), 'rs', 'MarkerSize', 12, 'MarkerFaceColor', 'r', ...
    'DisplayName', 'Insertion');

xlabel('x (LU)'); ylabel('y (LU)');
title('Moon-Centered View');
legend('Location', 'best');

% Set view around Moon
view_range = 0.02;
xlim([moon_x - view_range, moon_x + view_range]);
ylim([-view_range, view_range]);

% Subplot 3: Summary
subplot(1, 3, 3);
axis off;

text_str = {
    'L1 to LLO Transfer Summary'
    '=========================='
    ''
    'Timing:'
    sprintf('  L1 wait time: %.2f days', units.time_tu2day(best.t_wait, p))
    sprintf('  Manifold TOF: %.2f days', units.time_tu2day(best.t_end, p))
    sprintf('  Total to LLO: %.2f days', units.time_tu2day(best.t_arr, p))
    ''
    'Delta-v Budget:'
    sprintf('  LLO insertion: %.3f km/s', best.dv_insert_mag)
    sprintf('  Direction: %s', dir_str)
    ''
    'Mass Budget:'
    sprintf('  Mass at L1: %.0f kg', M_total)
    sprintf('  Fuel consumed: %.0f kg', dm_insert)
    sprintf('  Mass after LLO: %.0f kg', M_after)
    sprintf('  Fuel remaining: %.0f kg', m_fuel_after)
    ''
    'LLO Verification:'
    sprintf('  Target altitude: 100 km')
    sprintf('  Mean altitude: %.1f km', mean(alt_verify))
    sprintf('  Variation: %.1f km', max(alt_verify) - min(alt_verify))
};

text(0.05, 0.95, text_str, 'FontSize', 10, 'VerticalAlignment', 'top', ...
    'FontName', 'FixedWidth');

% Save figure
saveas(gcf, 'figures/l1_to_llo_transfer.png');
fprintf('  Visualization saved to l1_to_llo_transfer.png\n');

%% 10. Verification Summary
fprintf('\n=== Verification Summary ===\n');

% Check all requirements
pass_all = true;

% 1. LLO altitude = 100 +/- 1 km
if abs(mean(alt_verify) - 100) <= 1
    fprintf('  [PASS] LLO altitude = %.1f km (target: 100 +/- 1 km)\n', mean(alt_verify));
else
    fprintf('  [FAIL] LLO altitude = %.1f km (target: 100 +/- 1 km)\n', mean(alt_verify));
    pass_all = false;
end

% 2. Position error (manifold event detection guarantees this)
r_moon_err = abs(best.r_moon - p.r_LLO);
if r_moon_err <= 1e-6
    fprintf('  [PASS] Position error = %.2e LU (requirement: <= 1e-6 LU)\n', r_moon_err);
else
    fprintf('  [FAIL] Position error = %.2e LU (requirement: <= 1e-6 LU)\n', r_moon_err);
    pass_all = false;
end

% 3. Circular orbit stability (altitude variation < 10 km in 3 orbits)
alt_var = max(alt_verify) - min(alt_verify);
if alt_var < 10
    fprintf('  [PASS] Orbit stability: %.1f km variation in 3 orbits (< 10 km)\n', alt_var);
else
    fprintf('  [FAIL] Orbit stability: %.1f km variation in 3 orbits (>= 10 km)\n', alt_var);
    pass_all = false;
end

% 4. Fuel consumption reasonable (expected 3000-10000 kg for ~900 m/s)
if dm_insert >= 2000 && dm_insert <= 12000
    fprintf('  [PASS] Fuel consumption: %.0f kg (reasonable range)\n', dm_insert);
else
    fprintf('  [WARN] Fuel consumption: %.0f kg (may be unusual)\n', dm_insert);
end

% 5. Total time < 80 days
total_days = units.time_tu2day(best.t_arr, p);
if total_days < 80
    fprintf('  [PASS] Total time: %.1f days (< 80 days)\n', total_days);
else
    fprintf('  [FAIL] Total time: %.1f days (>= 80 days)\n', total_days);
    pass_all = false;
end

if pass_all
    fprintf('\n=== All verification checks PASSED ===\n');
else
    fprintf('\n=== Some verification checks FAILED ===\n');
end

fprintf('\n=== L1 to LLO Transfer Design Complete ===\n');
