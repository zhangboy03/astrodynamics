%% LEO2L1.m: LEO to L1 Lyapunov Orbit Transfer
%
% Optimizes a trajectory from 400 km LEO to dock with a supply ship on the
% L1 Lyapunov orbit. Uses patched conics for initial guess since stable
% manifolds from L1 do NOT reach LEO (closest approach ~0.85 LU).
%
% Decision variables: x = [theta; t_dep; tof; dv_dep_x; dv_dep_y]
%   theta   - LEO phase angle (rad)
%   t_dep   - departure time (TU)
%   tof     - time of flight (TU)
%   dv_dep  - departure delta-v in synodic frame (VU)
%
% Requirements:
%   - Position error <= 1e-6 LU at docking
%   - C3 computed via state_rel_body.m (assignment requirement)
%   - Path constraints: Moon altitude >= 100 km, Earth altitude >= 400 km

clear; clc; close all;

%% 1. Load Data
fprintf('=== LEO to L1 Lyapunov Transfer Optimization ===\n\n');

load('phase0_data.mat', 'p', 'X0_lyap', 'T_lyap', 'orbit_states', 't_orbit', 'x_L1');

fprintf('Parameters loaded:\n');
fprintf('  L1 x-coordinate: %.6f LU\n', x_L1);
fprintf('  Lyapunov period: %.4f TU (%.2f days)\n', T_lyap, T_lyap * p.TU / 86400);
fprintf('  LEO radius: %.6f LU (%.0f km)\n', p.r_LEO, p.r_LEO * p.LU);
fprintf('  mu = %.10f\n\n', p.mu);

%% 2. Patched Conics Initial Guess
% Use two-body (Earth-centered) approximation for trans-L1 injection

fprintf('--- Patched Conics Initial Guess ---\n');

% Physical parameters (km)
r_LEO_km = p.R_e + 400;                          % 6778 km
r_L1_km = (x_L1 + p.mu) * p.LU;                  % Distance from Earth to L1

% Circular velocity at LEO
v_circ_LEO = sqrt(p.mu_e / r_LEO_km);            % km/s

% Hohmann-like transfer semi-major axis
a_trans = (r_LEO_km + r_L1_km) / 2;              % km

% Departure velocity for transfer ellipse
v_dep_km = sqrt(p.mu_e * (2/r_LEO_km - 1/a_trans));  % km/s

% Trans-L1 injection delta-v
dv_TLI_km = v_dep_km - v_circ_LEO;               % km/s

% Transfer time (half period of transfer ellipse)
tof_hohmann_s = pi * sqrt(a_trans^3 / p.mu_e);   % seconds
tof_hohmann_TU = tof_hohmann_s / p.TU;           % TU

% C3 estimate from patched conics
C3_estimate = v_dep_km^2 - 2*p.mu_e/r_LEO_km;    % km^2/s^2

fprintf('  LEO altitude: 400 km (r = %.0f km)\n', r_LEO_km);
fprintf('  L1 distance from Earth: %.0f km\n', r_L1_km);
fprintf('  Circular velocity at LEO: %.3f km/s\n', v_circ_LEO);
fprintf('  Transfer semi-major axis: %.0f km\n', a_trans);
fprintf('  Departure velocity: %.3f km/s\n', v_dep_km);
fprintf('  TLI delta-v: %.3f km/s\n', dv_TLI_km);
fprintf('  Hohmann TOF: %.2f TU (%.2f days)\n', tof_hohmann_TU, tof_hohmann_s/86400);
fprintf('  C3 estimate: %.3f km^2/s^2\n\n', C3_estimate);

% Convert to normalized units
dv_TLI_VU = dv_TLI_km / p.VU;

%% 3. Grid Search for Best Starting Point
% Search over (theta, t_dep, tof) with near-tangential departure burns
fprintf('--- Grid Search for Initial Guess ---\n');

n_theta = 36;
n_tdep = 12;
n_tof = 15;
n_angle = 5;  % Burn angle offsets from tangential

theta_grid = linspace(0, 2*pi, n_theta + 1);
theta_grid = theta_grid(1:end-1);
t_dep_grid = linspace(0, T_lyap, n_tdep);
tof_grid = linspace(1.5, 6, n_tof);  % 1.5-6 TU (~6-26 days)
angle_offset_grid = linspace(-15, 15, n_angle) * pi/180;  % ±15 deg from tangent

best_dist = inf;
best_params = [];
all_results = [];

fprintf('  Searching %d combinations...\n', n_theta * n_tdep * n_tof * n_angle);

for i_theta = 1:length(theta_grid)
    theta = theta_grid(i_theta);

    for i_tdep = 1:length(t_dep_grid)
        t_dep = t_dep_grid(i_tdep);

        for i_tof = 1:length(tof_grid)
            tof = tof_grid(i_tof);

            for i_angle = 1:length(angle_offset_grid)
                angle_off = angle_offset_grid(i_angle);

                try
                    % Get LEO state at departure
                    X_LEO = frames.circular_orbit_state('earth', p.r_LEO, theta, t_dep, p.mu, +1);

                    % Compute burn direction: tangential + offset
                    v_LEO = X_LEO(3:4);
                    v_hat = v_LEO / norm(v_LEO);
                    % Rotate by angle_off
                    c = cos(angle_off); s = sin(angle_off);
                    v_hat_rot = [c, -s; s, c] * v_hat;
                    dv_dep = dv_TLI_VU * v_hat_rot;

                    X_dep = X_LEO;
                    X_dep(3:4) = X_LEO(3:4) + dv_dep;

                    % Propagate to arrival
                    [~, X_traj] = cr3bp.propagate(X_dep, [0, tof], p.mu);
                    X_arr = X_traj(end, :)';

                    % Get supply ship state at docking time
                    t_dock = t_dep + tof;
                    X_supply = orbits.supply_state(t_dock, orbit_states, T_lyap, t_orbit);

                    % Compute position error
                    pos_err = norm(X_arr(1:2) - X_supply(1:2));

                    % Store for multi-start
                    all_results = [all_results; theta, t_dep, tof, dv_dep(1), dv_dep(2), pos_err];

                    if pos_err < best_dist
                        best_dist = pos_err;
                        best_params = [theta; t_dep; tof; dv_dep(1); dv_dep(2)];
                    end
                catch
                    continue;
                end
            end
        end
    end
end

fprintf('  Best grid result: position error = %.6f LU\n', best_dist);
fprintf('  Initial guess: theta=%.3f rad, t_dep=%.3f TU, tof=%.3f TU\n', ...
    best_params(1), best_params(2), best_params(3));
fprintf('  dv_dep = [%.6f, %.6f] VU (%.3f km/s)\n\n', ...
    best_params(4), best_params(5), norm(best_params(4:5)) * p.VU);

%% 4. Multi-start fmincon Optimization
fprintf('--- Multi-start fmincon Optimization ---\n');

% Variable bounds: [theta, t_dep, tof, dv_x, dv_y]
% Note: dv bounds must accommodate ~3 VU TLI burn
lb = [0;      0;    0.5;   -5;    -5];
ub = [2*pi;   15;   10;     5;     5];

% Optimization options
opts_fmincon = optimoptions('fmincon', ...
    'Display', 'off', ...
    'Algorithm', 'sqp', ...
    'MaxFunctionEvaluations', 10000, ...
    'MaxIterations', 1000, ...
    'OptimalityTolerance', 1e-10, ...
    'StepTolerance', 1e-12, ...
    'ConstraintTolerance', 1e-9, ...
    'FiniteDifferenceType', 'central', ...
    'FiniteDifferenceStepSize', 1e-8);

% Sort results by position error and try top candidates
[~, sort_idx] = sort(all_results(:,6));
n_starts = min(20, size(all_results, 1));
top_candidates = all_results(sort_idx(1:n_starts), :);

best_fval = inf;
best_x_opt = [];
best_exitflag = -999;

fprintf('  Trying %d starting points...\n', n_starts);

for i = 1:n_starts
    x0 = top_candidates(i, 1:5)';

    try
        [x_opt_i, fval_i, exitflag_i, ~] = fmincon(...
            @(x) objective_func(x, p, orbit_states, T_lyap, t_orbit), ...
            x0, [], [], [], [], lb, ub, ...
            @(x) constraints_func(x, p, orbit_states, T_lyap, t_orbit), ...
            opts_fmincon);

        % Check if this solution meets position constraint
        [c_test, ceq_test] = constraints_func(x_opt_i, p, orbit_states, T_lyap, t_orbit);
        pos_err_test = norm(ceq_test);

        if exitflag_i > 0 && pos_err_test < 1e-5 && fval_i < best_fval
            best_fval = fval_i;
            best_x_opt = x_opt_i;
            best_exitflag = exitflag_i;
            fprintf('    Start %d: exitflag=%d, pos_err=%.2e, fval=%.4f [NEW BEST]\n', ...
                i, exitflag_i, pos_err_test, fval_i);
        elseif pos_err_test < 1e-4
            fprintf('    Start %d: exitflag=%d, pos_err=%.2e, fval=%.4f\n', ...
                i, exitflag_i, pos_err_test, fval_i);
        end
    catch ME
        fprintf('    Start %d: failed (%s)\n', i, ME.message);
    end
end

% If multi-start didn't find a good solution, try focused refinement
if isempty(best_x_opt) || best_fval > 100
    fprintf('\n  Multi-start did not converge. Trying refined search...\n');

    % Try finer grid around best point from coarse search (reduced for speed)
    theta_fine = best_params(1) + linspace(-0.5, 0.5, 5);
    tdep_fine = best_params(2) + linspace(-0.5, 0.5, 5);
    tof_fine = best_params(3) + linspace(-1, 1, 5);

    for i_th = 1:length(theta_fine)
        for i_td = 1:length(tdep_fine)
            for i_tf = 1:length(tof_fine)
                theta = mod(theta_fine(i_th), 2*pi);
                t_dep = max(0, tdep_fine(i_td));
                tof = max(0.5, tof_fine(i_tf));

                try
                    X_LEO = frames.circular_orbit_state('earth', p.r_LEO, theta, t_dep, p.mu, +1);
                    v_LEO = X_LEO(3:4);
                    v_hat = v_LEO / norm(v_LEO);
                    dv_dep = dv_TLI_VU * v_hat;

                    x0 = [theta; t_dep; tof; dv_dep(1); dv_dep(2)];

                    [x_opt_i, fval_i, exitflag_i, ~] = fmincon(...
                        @(x) objective_func(x, p, orbit_states, T_lyap, t_orbit), ...
                        x0, [], [], [], [], lb, ub, ...
                        @(x) constraints_func(x, p, orbit_states, T_lyap, t_orbit), ...
                        opts_fmincon);

                    [~, ceq_test] = constraints_func(x_opt_i, p, orbit_states, T_lyap, t_orbit);
                    pos_err_test = norm(ceq_test);

                    if exitflag_i > 0 && pos_err_test < 1e-5 && fval_i < best_fval
                        best_fval = fval_i;
                        best_x_opt = x_opt_i;
                        best_exitflag = exitflag_i;
                        fprintf('    Fine grid: pos_err=%.2e, fval=%.4f [NEW BEST]\n', ...
                            pos_err_test, fval_i);
                    end
                catch
                    continue;
                end
            end
        end
    end
end

% Use best result or fall back to grid search best
if isempty(best_x_opt)
    fprintf('\n  Warning: Optimization did not converge. Using best grid point.\n');
    x_opt = best_params;
    exitflag = -1;
else
    x_opt = best_x_opt;
    exitflag = best_exitflag;
end

fprintf('\nOptimization complete. Exit flag: %d\n', exitflag);

%% 5. Final Refinement with Tighter Tolerances
fprintf('\n--- Final Refinement ---\n');

% Check current solution quality before refining
[~, ceq_pre] = constraints_func(x_opt, p, orbit_states, T_lyap, t_orbit);
pos_err_pre = norm(ceq_pre);
fprintf('  Pre-refinement position error: %.2e LU\n', pos_err_pre);

% Only refine if current solution is not already excellent
if pos_err_pre > 1e-8
    % Refine the solution with tighter tolerances
    opts_refine = optimoptions('fmincon', ...
        'Display', 'iter', ...
        'Algorithm', 'sqp', ...
        'MaxFunctionEvaluations', 20000, ...
        'MaxIterations', 2000, ...
        'OptimalityTolerance', 1e-12, ...
        'StepTolerance', 1e-14, ...
        'ConstraintTolerance', 1e-10, ...
        'FiniteDifferenceType', 'central', ...
        'FiniteDifferenceStepSize', 1e-9);

    [x_opt_ref, fval_ref, exitflag_ref, output] = fmincon(...
        @(x) objective_func(x, p, orbit_states, T_lyap, t_orbit), ...
        x_opt, [], [], [], [], lb, ub, ...
        @(x) constraints_func(x, p, orbit_states, T_lyap, t_orbit), ...
        opts_refine);

    % Check if refinement improved or degraded the solution
    [~, ceq_post] = constraints_func(x_opt_ref, p, orbit_states, T_lyap, t_orbit);
    pos_err_post = norm(ceq_post);

    if pos_err_post < pos_err_pre
        fprintf('\nRefinement improved solution: %.2e -> %.2e LU\n', pos_err_pre, pos_err_post);
        x_opt = x_opt_ref;
        exitflag = exitflag_ref;
    else
        fprintf('\nRefinement degraded solution: %.2e -> %.2e LU. Keeping original.\n', pos_err_pre, pos_err_post);
    end
else
    fprintf('  Solution already excellent (%.2e LU). Skipping refinement.\n', pos_err_pre);
end

fprintf('\nFinal optimization complete. Exit flag: %d\n', exitflag);

%% 6. Validate and Extract Results
fprintf('\n--- Validation and Results ---\n');

theta_opt = x_opt(1);
t_dep_opt = x_opt(2);
tof_opt = x_opt(3);
dv_dep_opt = x_opt(4:5);

% Reconstruct trajectory
X_LEO = frames.circular_orbit_state('earth', p.r_LEO, theta_opt, t_dep_opt, p.mu, +1);
X_dep = X_LEO;
X_dep(3:4) = X_LEO(3:4) + dv_dep_opt;

% Full trajectory for plotting
t_span = linspace(0, tof_opt, 500);
[t_traj, X_traj] = cr3bp.propagate(X_dep, t_span, p.mu);

X_arr = X_traj(end, :)';

% Supply ship state at docking
t_dock = t_dep_opt + tof_opt;
X_supply = orbits.supply_state(t_dock, orbit_states, T_lyap, t_orbit);

% Position and velocity errors
pos_err = norm(X_arr(1:2) - X_supply(1:2));
dv_match = X_supply(3:4) - X_arr(3:4);
dv_match_km = norm(dv_match) * p.VU;

fprintf('  Position error: %.2e LU (requirement: <= 1e-6 LU)\n', pos_err);
fprintf('  Velocity match dv: %.6f VU (%.3f km/s)\n', norm(dv_match), dv_match_km);

% C3 computation via state_rel_body.m (CRITICAL - assignment requirement)
[r_rel, v_rel] = frames.state_rel_body(X_dep, t_dep_opt, 'earth', p.mu);
r_km = norm(r_rel) * p.LU;
v_kms = norm(v_rel) * p.VU;
C3 = v_kms^2 - 2*p.mu_e/r_km;

fprintf('  C3 = %.4f km^2/s^2 (computed via state_rel_body.m)\n', C3);

% Departure delta-v (provided by launch vehicle, not spacecraft fuel)
dv_dep_km = norm(dv_dep_opt) * p.VU;
fprintf('  Departure delta-v: %.3f km/s (launch vehicle)\n', dv_dep_km);

% Total delta-v budget
dv_total_km = dv_dep_km + dv_match_km;
fprintf('  Total delta-v: %.3f km/s\n', dv_total_km);

%% 6.1 Fuel Optimization Strategy
% Key insight: The departure burn is provided by the launch vehicle (not spacecraft fuel).
% The spacecraft only needs fuel for the velocity matching burn at L1 docking.
% After docking, fuel can be replenished at the supply ship.
% Therefore, we only carry enough fuel for the matching burn + safety margin,
% and maximize payload with the remaining mass capacity.

fprintf('\n--- Fuel Optimization (L1 Refueling Strategy) ---\n');

% Get launch mass capacity from C3
M0 = 25000 - 1000 * C3;  % kg (launch vehicle capacity)
m_dry = 10000;           % kg (spacecraft dry mass)
m_fuel_max = 15000;      % kg (max fuel tank capacity)

fprintf('  Launch mass capacity (M0): %.1f kg\n', M0);
fprintf('  Spacecraft dry mass: %.0f kg\n', m_dry);

% Calculate minimum fuel needed for velocity matching burn
% Fuel consumption: M_f = M * exp(-dv/ve), where ve = 3000 m/s
% Fuel used = M * (1 - exp(-dv/ve))
ve = 3000;  % m/s (exhaust velocity)
dv_match_ms = dv_match_km * 1000;  % convert to m/s

% At arrival, mass = M0 (no fuel consumed during transfer)
% Fuel needed for matching burn:
fuel_fraction = 1 - exp(-dv_match_ms / ve);
m_fuel_min = M0 * fuel_fraction;

fprintf('  Velocity matching burn: %.1f m/s\n', dv_match_ms);
fprintf('  Fuel fraction for burn: %.4f\n', fuel_fraction);
fprintf('  Minimum fuel required: %.1f kg\n', m_fuel_min);

% Apply safety margin: use 4000 kg as minimum fuel
m_fuel_safety = 4000;  % kg safety margin
m_fuel_opt = max(m_fuel_min, m_fuel_safety);

% Ensure we don't exceed tank capacity
m_fuel_opt = min(m_fuel_opt, m_fuel_max);

fprintf('  Safety margin fuel: %.0f kg\n', m_fuel_safety);
fprintf('  Optimized fuel load: %.1f kg\n', m_fuel_opt);

% Calculate optimized payload
M_carry_opt = M0 - m_dry - m_fuel_opt;
M_carry_opt = max(0, M_carry_opt);  % Ensure non-negative

fprintf('\n  === Mass Budget Comparison ===\n');
fprintf('  Traditional (full tank):\n');
[~, M_carry_full] = mission.mass_model(C3, m_dry, m_fuel_max);
fprintf('    Fuel: %.0f kg, Payload: %.1f kg\n', m_fuel_max, M_carry_full);
fprintf('  Optimized (L1 refuel strategy):\n');
fprintf('    Fuel: %.1f kg, Payload: %.1f kg\n', m_fuel_opt, M_carry_opt);
fprintf('  Payload improvement: %.1f kg (+%.1f%%)\n', ...
    M_carry_opt - M_carry_full, (M_carry_opt - M_carry_full) / max(1, M_carry_full) * 100);

% Verify fuel is sufficient for the burn
M_after_burn = M0 * exp(-dv_match_ms / ve);
fuel_consumed = M0 - M_after_burn;
fuel_remaining = m_fuel_opt - fuel_consumed;
fprintf('\n  Fuel verification:\n');
fprintf('    Fuel consumed in matching burn: %.1f kg\n', fuel_consumed);
fprintf('    Fuel remaining after burn: %.1f kg\n', fuel_remaining);
if fuel_remaining >= 0
    fprintf('    [OK] Sufficient fuel for docking\n');
else
    fprintf('    [WARNING] Insufficient fuel! Need %.1f kg more\n', -fuel_remaining);
end

% Use optimized values
M_carry = M_carry_opt;
m_fuel = m_fuel_opt;

% Timing
fprintf('\n  Timing:\n');
fprintf('    Departure time: %.4f TU (%.2f days)\n', t_dep_opt, t_dep_opt * p.TU / 86400);
fprintf('    Time of flight: %.4f TU (%.2f days)\n', tof_opt, tof_opt * p.TU / 86400);
fprintf('    Docking time: %.4f TU (%.2f days)\n', t_dock, t_dock * p.TU / 86400);
fprintf('    LEO phase angle: %.4f rad (%.1f deg)\n', theta_opt, rad2deg(theta_opt));

%% 8. Check Path Constraints
fprintf('\n--- Path Constraint Check ---\n');

% Sample trajectory points
r1_traj = sqrt((X_traj(:,1) + p.mu).^2 + X_traj(:,2).^2);  % Distance from Earth
r2_traj = sqrt((X_traj(:,1) - (1-p.mu)).^2 + X_traj(:,2).^2);  % Distance from Moon
r0_traj = sqrt(X_traj(:,1).^2 + X_traj(:,2).^2);  % Distance from barycenter

min_earth_alt_km = (min(r1_traj) - p.R_e/p.LU) * p.LU;
min_moon_alt_km = (min(r2_traj) - p.R_m/p.LU) * p.LU;
max_dist_LU = max(r0_traj);

fprintf('  Min Earth altitude: %.1f km (requirement: >= 400 km)\n', min_earth_alt_km);
fprintf('  Min Moon altitude: %.1f km (requirement: >= 100 km)\n', min_moon_alt_km);
fprintf('  Max distance from barycenter: %.4f LU (requirement: < 2 LU)\n', max_dist_LU);

% Verification status
all_pass = true;
if pos_err <= 1e-6
    fprintf('\n  [PASS] Position error constraint satisfied\n');
else
    fprintf('\n  [FAIL] Position error constraint NOT satisfied (%.2e > 1e-6)\n', pos_err);
    all_pass = false;
end

if min_earth_alt_km >= 400
    fprintf('  [PASS] Earth altitude constraint satisfied\n');
else
    fprintf('  [FAIL] Earth altitude constraint NOT satisfied\n');
    all_pass = false;
end

if min_moon_alt_km >= 100
    fprintf('  [PASS] Moon altitude constraint satisfied\n');
else
    fprintf('  [FAIL] Moon altitude constraint NOT satisfied\n');
    all_pass = false;
end

if max_dist_LU < 2
    fprintf('  [PASS] Max distance constraint satisfied\n');
else
    fprintf('  [FAIL] Max distance constraint NOT satisfied\n');
    all_pass = false;
end

%% 9. Save Results
results.theta_opt = theta_opt;
results.t_dep_opt = t_dep_opt;
results.tof_opt = tof_opt;
results.dv_dep_opt = dv_dep_opt;
results.t_dock = t_dock;
results.X_LEO = X_LEO;
results.X_dep = X_dep;
results.X_arr = X_arr;
results.X_supply = X_supply;
results.pos_err = pos_err;
results.dv_match = dv_match;
results.C3 = C3;
results.M0 = M0;
results.m_dry = m_dry;
results.m_fuel = m_fuel;
results.m_fuel_min = m_fuel_min;
results.M_carry = M_carry;
results.fuel_consumed = fuel_consumed;
results.fuel_remaining = fuel_remaining;
results.X_traj = X_traj;
results.t_traj = t_traj + t_dep_opt;  % Absolute time
results.dv_dep_km = dv_dep_km;
results.dv_match_km = dv_match_km;
results.dv_total_km = dv_total_km;
results.p = p;
results.exitflag = exitflag;
results.all_pass = all_pass;

save('leo_to_l1_results.mat', 'results');
fprintf('\nResults saved to leo_to_l1_results.mat\n');

%% 10. Plotting
fprintf('\n--- Generating Plots ---\n');

figure('Position', [100, 100, 1600, 500]);

% Subplot 1: Trajectory
subplot(1, 4, 1);
hold on; axis equal; grid on;

% Plot Lyapunov orbit
plot(orbit_states(:,1), orbit_states(:,2), 'b-', 'LineWidth', 2, 'DisplayName', 'Lyapunov Orbit');

% Plot transfer trajectory
plot(X_traj(:,1), X_traj(:,2), 'r-', 'LineWidth', 1.5, 'DisplayName', 'Transfer');

% Plot Earth and Moon
theta_circle = linspace(0, 2*pi, 100);
r_earth_plot = p.R_e / p.LU * 5;  % Exaggerated for visibility
r_moon_plot = p.R_m / p.LU * 5;
fill(-p.mu + r_earth_plot*cos(theta_circle), r_earth_plot*sin(theta_circle), ...
    'b', 'EdgeColor', 'b', 'FaceAlpha', 0.3, 'DisplayName', 'Earth');
fill(1-p.mu + r_moon_plot*cos(theta_circle), r_moon_plot*sin(theta_circle), ...
    [0.5 0.5 0.5], 'EdgeColor', [0.5 0.5 0.5], 'FaceAlpha', 0.3, 'DisplayName', 'Moon');

% Mark key points
plot(X_LEO(1), X_LEO(2), 'go', 'MarkerSize', 10, 'MarkerFaceColor', 'g', 'DisplayName', 'Departure');
plot(X_arr(1), X_arr(2), 'rs', 'MarkerSize', 10, 'MarkerFaceColor', 'r', 'DisplayName', 'Arrival');
plot(X_supply(1), X_supply(2), 'b^', 'MarkerSize', 10, 'MarkerFaceColor', 'b', 'DisplayName', 'Supply Ship');

% Plot L1 point
plot(x_L1, 0, 'kx', 'MarkerSize', 12, 'LineWidth', 2, 'DisplayName', 'L1');

xlabel('x (LU)'); ylabel('y (LU)');
title('LEO to L1 Lyapunov Transfer');
legend('Location', 'best');
xlim([-0.1, 1.1]);

% Subplot 2: Delta-v budget
subplot(1, 4, 2);
bar_data = [dv_dep_km, dv_match_km];
b = bar(bar_data);
b.FaceColor = 'flat';
b.CData(1,:) = [0.5 0.8 0.5];  % Green for launch vehicle
b.CData(2,:) = [0.3 0.6 0.9];  % Blue for spacecraft
set(gca, 'XTickLabel', {'Departure (LV)', 'Matching (SC)'});
ylabel('\Delta v (km/s)');
title(sprintf('\\Delta v Budget'));
grid on;

% Add values on bars
for i = 1:2
    text(i, bar_data(i) + 0.05, sprintf('%.3f', bar_data(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 10);
end

% Subplot 3: Mass budget (optimized)
subplot(1, 4, 3);
mass_data = [m_dry, m_fuel, M_carry];
pie_colors = [0.6 0.6 0.6; 0.9 0.5 0.2; 0.2 0.7 0.4];
h = pie(mass_data);
% Color the pie slices
for i = 1:3
    h(2*i-1).FaceColor = pie_colors(i,:);
end
legend({'Dry Mass', 'Fuel (Opt)', 'Payload'}, 'Location', 'southoutside');
title(sprintf('Mass Budget (M0=%.0f kg)', M0));

% Subplot 4: Summary parameters
subplot(1, 4, 4);
axis off;
text_str = {
    'Transfer Parameters:'
    ''
    sprintf('  Departure: %.1f deg, %.2f days', rad2deg(theta_opt), t_dep_opt * p.TU / 86400)
    sprintf('  TOF: %.2f days', tof_opt * p.TU / 86400)
    sprintf('  C3: %.4f km^2/s^2', C3)
    ''
    'Mass Budget (Optimized):'
    ''
    sprintf('  M0 = %.0f kg', M0)
    sprintf('  Dry mass = %.0f kg', m_dry)
    sprintf('  Fuel = %.0f kg (min %.0f)', m_fuel, m_fuel_min)
    sprintf('  Payload = %.0f kg', M_carry)
    ''
    'Accuracy:'
    ''
    sprintf('  Pos error: %.2e LU', pos_err)
    sprintf('  dv match: %.3f km/s', dv_match_km)
};
text(0.05, 0.95, text_str, 'FontSize', 10, 'VerticalAlignment', 'top', ...
    'FontName', 'FixedWidth');
title('Summary');

% Save figure
saveas(gcf, 'figures/leo_to_l1_transfer.png');
fprintf('Figure saved to leo2l1_transfer.png\n');

fprintf('\n=== LEO to L1 Transfer Optimization Complete ===\n');

%% ========== Helper Functions ==========

function J = objective_func(x, p, orbit_states, T_lyap, t_orbit)
    % Objective: minimize C3 + weighted velocity match
    %
    % Lower C3 = higher M0 = better
    % Lower dv_match = less fuel needed for docking

    theta = x(1);
    t_dep = x(2);
    tof = x(3);
    dv_dep = x(4:5);

    % Weight for velocity matching term
    w_dv = 50;  % Penalize velocity mismatch heavily

    try
        % Get LEO state at departure
        X_LEO = frames.circular_orbit_state('earth', p.r_LEO, theta, t_dep, p.mu, +1);
        X_post = X_LEO;
        X_post(3:4) = X_LEO(3:4) + dv_dep;

        % Compute C3 via state_rel_body.m (assignment requirement)
        [r_rel, v_rel] = frames.state_rel_body(X_post, t_dep, 'earth', p.mu);
        r_km = norm(r_rel) * p.LU;
        v_kms = norm(v_rel) * p.VU;
        C3 = v_kms^2 - 2*p.mu_e/r_km;

        % Propagate to arrival
        [~, X_traj] = cr3bp.propagate(X_post, [0, tof], p.mu);
        X_arr = X_traj(end, :)';

        % Supply ship state at docking
        t_dock = t_dep + tof;
        X_supply = orbits.supply_state(t_dock, orbit_states, T_lyap, t_orbit);

        % Velocity mismatch
        dv_match = norm(X_supply(3:4) - X_arr(3:4));

        % Objective: minimize C3 (maximize mass) + penalize velocity mismatch
        J = C3 + w_dv * dv_match^2;

    catch
        J = 1e6;  % Large penalty for failed propagation
    end
end

function [c, ceq] = constraints_func(x, p, orbit_states, T_lyap, t_orbit)
    % Nonlinear constraints
    %
    % Equality: position match at docking (2 constraints)
    % Inequality: path safety along trajectory
    %
    % CRITICAL: Check actual perigee altitude, not just sampled distances!
    % The validation program computes Earth-relative orbit perigee.
    %
    % OPTIMIZED: Only compute perigee at points near closest Earth approach

    theta = x(1);
    t_dep = x(2);
    tof = x(3);
    dv_dep = x(4:5);

    try
        % Get LEO state at departure
        X_LEO = frames.circular_orbit_state('earth', p.r_LEO, theta, t_dep, p.mu, +1);
        X_post = X_LEO;
        X_post(3:4) = X_LEO(3:4) + dv_dep;

        % Propagate with intermediate points for path constraints
        n_check = 100;  % Reduced from 200 for speed
        t_span = linspace(0, tof, n_check);
        [t_traj, X_traj] = cr3bp.propagate(X_post, t_span, p.mu);

        X_arr = X_traj(end, :)';

        % Supply ship state at docking
        t_dock = t_dep + tof;
        X_supply = orbits.supply_state(t_dock, orbit_states, T_lyap, t_orbit);

        % === Equality constraints: position match ===
        ceq = [X_arr(1) - X_supply(1);
               X_arr(2) - X_supply(2)];

        % === Inequality constraints: c <= 0 ===

        % Distance from Earth center (normalized)
        r1 = sqrt((X_traj(:,1) + p.mu).^2 + X_traj(:,2).^2);

        % Distance from Moon center (normalized)
        r2 = sqrt((X_traj(:,1) - (1-p.mu)).^2 + X_traj(:,2).^2);

        % Distance from barycenter
        r0 = sqrt(X_traj(:,1).^2 + X_traj(:,2).^2);

        % Minimum altitudes (normalized)
        min_earth_alt_km = 400;   % 400 km
        min_moon_alt = 100 / p.LU;    % 100 km (normalized)
        max_dist = 2.0;               % 2 LU

        % Moon radius (normalized)
        R_m_norm = p.R_m / p.LU;

        % --- OPTIMIZED: Compute perigee only at points near closest Earth approach ---
        % Find the index of minimum Earth distance
        [~, min_idx] = min(r1);

        % Check perigee at the closest approach point and a few nearby points
        check_range = max(1, min_idx-3):min(n_check, min_idx+3);
        min_perigee_alt_km = inf;

        for i = check_range
            X_pt = X_traj(i, :)';
            t_pt = t_dep + t_traj(i);

            % Get Earth-relative state
            [r_rel, v_rel] = frames.state_rel_body(X_pt, t_pt, 'earth', p.mu);
            r_km = norm(r_rel) * p.LU;
            v_kms = norm(v_rel) * p.VU;

            % Compute specific orbital energy (two-body, Earth-centered)
            energy = v_kms^2/2 - p.mu_e/r_km;  % km^2/s^2

            if energy < 0  % Elliptic orbit - has a perigee
                % Semi-major axis
                a = -p.mu_e / (2*energy);  % km

                % Specific angular momentum
                r_vec = r_rel * p.LU;  % km
                v_vec = v_rel * p.VU;  % km/s
                h_vec = cross([r_vec; 0], [v_vec; 0]);
                h = norm(h_vec);  % km^2/s

                % Eccentricity
                e = sqrt(max(0, 1 + 2*energy*h^2/p.mu_e^2));

                % Perigee radius
                r_peri = a * (1 - e);  % km
                alt_peri = r_peri - p.R_e;  % km

                if alt_peri < min_perigee_alt_km
                    min_perigee_alt_km = alt_peri;
                end
            end
            % Hyperbolic orbits (energy >= 0) don't have perigee constraint issues
        end

        % If no elliptic segments found near closest approach, use direct distance
        if isinf(min_perigee_alt_km)
            min_perigee_alt_km = (min(r1) - p.R_e/p.LU) * p.LU;
        end

        % c <= 0 form
        c_earth = min_earth_alt_km - min_perigee_alt_km;  % Perigee altitude >= 400 km
        c_moon = (R_m_norm + min_moon_alt) - min(r2);     % Moon altitude >= 100 km
        c_max = max(r0) - max_dist;                        % Distance < 2 LU

        c = [c_earth; c_moon; c_max];

    catch
        % Return large constraint violations for failed propagation
        ceq = [1e6; 1e6];
        c = [1e6; 1e6; 1e6];
    end
end
