%% llo_to_earth.m: LLO to Earth Return
%
% Phase 3: Design return trajectory from 100 km LLO to Earth
%
% Goals:
%   1. Find trajectory with periapsis altitude = 0 km (at Earth surface)
%   2. Spacecraft is AT the periapsis point (radial velocity = 0)
%   3. Satisfy all mission constraints
%
% Key constraints:
%   - Total mission time: <= 100 days
%   - Lunar surface stay: 3.0 - 10.0 days
%   - Moon altitude: >= 100 km (throughout)
%   - Earth altitude: >= 400 km (before return trajectory)
%   - Distance: < 2 LU
%   - Return fuel: <= 100 kg (handled by adjusting L1 refueling)
%
% Note: Fuel constraint is satisfied by l1_to_llo.m which calculates
%       the required L1 refueling based on this script's return dv.

clear; clc; close all;
fprintf('=== LLO to Earth Return (Periapsis = 0 km) ===\n\n');

%% 1. Load Data
load('phase0_data.mat', 'p');
load('l1_to_llo_results.mat', 'results_L12LLO');

t_arr_LLO = results_L12LLO.t_arr;
m_fuel_after_insert = results_L12LLO.m_fuel_after;

fprintf('LLO arrival time: %.2f days\n', t_arr_LLO * p.TU / 86400);

%% 2. Parameters
r_LLO_km = p.R_m + 100;
r_LLO_LU = r_LLO_km / p.LU;
v_circ_LLO_kms = sqrt(p.mu_m / r_LLO_km);
v_circ_kep_VU = v_circ_LLO_kms / p.VU;

moon_x = 1 - p.mu;

t_stay_min = units.time_day2tu(3.0, p);
t_stay_max = units.time_day2tu(10.0, p);
t_total_max = units.time_day2tu(100, p);
t_return_max = t_total_max - t_arr_LLO - t_stay_min;

fprintf('LLO radius: %.1f km\n', r_LLO_km);
fprintf('LLO circular velocity: %.4f km/s\n', v_circ_LLO_kms);

%% 3. Grid Search - Find candidates close to periapsis=0
fprintf('\n--- Grid Search for Periapsis = 0 km ---\n');

n_theta = 72;
n_stay = 5;
n_dv_mag = 25;
n_dv_dir = 48;

theta_grid = linspace(0, 2*pi, n_theta + 1); theta_grid(end) = [];
stay_grid = linspace(t_stay_min, t_stay_max, n_stay);
dv_mag_grid = linspace(0.8, 1.5, n_dv_mag);  % km/s
dv_dir_grid = linspace(-pi, pi, n_dv_dir);

best_result = struct();
best_result.alt_error = inf;
best_result.found = false;

candidates = [];
n_total = n_theta * n_stay * n_dv_mag * n_dv_dir;
fprintf('Searching %d combinations...\n', n_total);

direction = -1;  % retrograde LLO

for i_stay = 1:n_stay
    t_stay = stay_grid(i_stay);

    for i_theta = 1:n_theta
        theta_LLO = theta_grid(i_theta);

        % LLO departure state
        r_rel = r_LLO_LU * [cos(theta_LLO); sin(theta_LLO)];
        x_dep = moon_x + r_rel(1);
        y_dep = r_rel(2);

        theta_hat_pro = [-sin(theta_LLO); cos(theta_LLO)];
        theta_hat = direction * theta_hat_pro;
        v_circ_syn = v_circ_kep_VU * theta_hat - [-r_rel(2); r_rel(1)];

        for i_dv_mag = 1:n_dv_mag
            dv_mag_kms = dv_mag_grid(i_dv_mag);
            dv_mag_VU = dv_mag_kms / p.VU;

            for i_dv_dir = 1:n_dv_dir
                dv_dir = dv_dir_grid(i_dv_dir);

                % Δv direction
                v_hat = v_circ_syn / norm(v_circ_syn);
                v_perp = [-v_hat(2); v_hat(1)];
                dv_syn = dv_mag_VU * (cos(dv_dir) * v_hat + sin(dv_dir) * v_perp);

                X_dep = [x_dep; y_dep; v_circ_syn(1) + dv_syn(1); v_circ_syn(2) + dv_syn(2)];
                t_dep = t_arr_LLO + t_stay;

                try
                    % Propagate until periapsis passage (rdot = 0, direction +1)
                    opts = odeset('Events', @(t,X) event_periapsis(t,X,p), 'RelTol', 1e-10, 'AbsTol', 1e-12);
                    [t_traj, X_traj, te, Xe, ie] = cr3bp.propagate(X_dep, [0, t_return_max], p.mu, opts);

                    % Check if periapsis event triggered (ie==1)
                    if ~isempty(ie) && ie(end) == 1
                        X_peri = Xe(end, :)';
                        t_flight = te(end);

                        % Compute periapsis altitude (this IS the periapsis point)
                        dx = X_peri(1) + p.mu;
                        dy = X_peri(2);
                        r_peri_km = sqrt(dx^2 + dy^2) * p.LU;
                        alt_peri_km = r_peri_km - p.R_e;

                        % Check path constraints
                        valid = check_path(X_traj, p);
                        t_total = t_arr_LLO + t_stay + t_flight;

                        if valid && t_total < t_total_max && alt_peri_km > -100 && alt_peri_km < 200
                            cand = struct();
                            cand.theta_LLO = theta_LLO;
                            cand.t_stay = t_stay;
                            cand.dv_syn = dv_syn;
                            cand.dv_mag_kms = dv_mag_kms;
                            cand.X_dep = X_dep;
                            cand.t_dep = t_dep;
                            cand.t_flight = t_flight;
                            cand.t_total = t_total;
                            cand.X_peri = X_peri;
                            cand.alt_peri_km = alt_peri_km;
                            cand.traj = [t_traj, X_traj];
                            candidates = [candidates; cand];

                            % Update best (closest to 0 km)
                            alt_error = abs(alt_peri_km);
                            if alt_error < best_result.alt_error
                                best_result = cand;
                                best_result.alt_error = alt_error;
                                best_result.found = true;
                            end
                        end
                    end
                catch
                    continue;
                end
            end
        end
    end
end

fprintf('Found %d candidates\n', length(candidates));

if ~isempty(candidates)
    all_alt = [candidates.alt_peri_km];
    fprintf('Periapsis altitude range: %.1f to %.1f km\n', min(all_alt), max(all_alt));

    % Show top 5 closest to 0 km
    [~, idx] = sort(abs(all_alt));
    fprintf('\nTop 5 closest to 0 km:\n');
    for i = 1:min(5, length(idx))
        c = candidates(idx(i));
        fprintf('  #%d: alt=%.1f km, dv=%.3f km/s, t=%.1f days\n', ...
            i, c.alt_peri_km, c.dv_mag_kms, c.t_flight * p.TU / 86400);
    end
end

%% 4. Refine with fmincon to get exactly 0 km
if best_result.found
    fprintf('\n--- Refining with fmincon ---\n');

    % Initial guess from best grid result
    x0 = [best_result.theta_LLO; best_result.t_stay; best_result.dv_syn];

    % Bounds
    lb = [0; t_stay_min; -2; -2];
    ub = [2*pi; t_stay_max; 2; 2];

    % Objective: minimize |alt_peri - 0|
    obj = @(x) objective_alt_peri(x, t_arr_LLO, t_return_max, p, moon_x, r_LLO_LU, v_circ_kep_VU, direction);

    % High precision options for 1e-6 LU requirement (~0.38 km)
    options = optimoptions('fmincon', 'Display', 'iter', 'MaxIterations', 500, ...
        'OptimalityTolerance', 1e-12, 'StepTolerance', 1e-14, ...
        'ConstraintTolerance', 1e-12, 'FiniteDifferenceStepSize', 1e-10);

    [x_opt, fval, exitflag] = fmincon(obj, x0, [], [], [], [], lb, ub, [], options);

    % Precision requirement: position error <= 1e-6 LU = 0.38 km
    precision_km = 1e-6 * p.LU;  % ~0.38 km

    if exitflag > 0 && fval < 1  % Converged with alt_peri < 1 km
        fprintf('\nOptimization converged! alt_peri error = %.4f km (requirement: < %.3f km)\n', fval, precision_km);

        % Extract optimized trajectory
        theta_opt = x_opt(1);
        t_stay_opt = x_opt(2);
        dv_syn_opt = x_opt(3:4);

        % Recompute final trajectory
        r_rel = r_LLO_LU * [cos(theta_opt); sin(theta_opt)];
        x_dep = moon_x + r_rel(1);
        y_dep = r_rel(2);
        theta_hat = direction * [-sin(theta_opt); cos(theta_opt)];
        v_circ_syn = v_circ_kep_VU * theta_hat - [-r_rel(2); r_rel(1)];

        X_dep_opt = [x_dep; y_dep; v_circ_syn(1) + dv_syn_opt(1); v_circ_syn(2) + dv_syn_opt(2)];
        t_dep_opt = t_arr_LLO + t_stay_opt;

        opts = odeset('Events', @(t,X) event_periapsis(t,X,p), 'RelTol', 1e-12, 'AbsTol', 1e-14);
        [t_traj_opt, X_traj_opt, te_opt, Xe_opt, ~] = cr3bp.propagate(X_dep_opt, [0, t_return_max], p.mu, opts);

        X_peri_opt = Xe_opt(end,:)';
        t_flight_opt = te_opt(end);

        dx = X_peri_opt(1) + p.mu;
        dy = X_peri_opt(2);
        alt_peri_opt = sqrt(dx^2 + dy^2) * p.LU - p.R_e;

        % Update best result
        best_result.theta_LLO = theta_opt;
        best_result.t_stay = t_stay_opt;
        best_result.dv_syn = dv_syn_opt;
        best_result.dv_mag_kms = norm(dv_syn_opt) * p.VU;
        best_result.X_dep = X_dep_opt;
        best_result.t_dep = t_dep_opt;
        best_result.t_flight = t_flight_opt;
        best_result.t_total = t_arr_LLO + t_stay_opt + t_flight_opt;
        best_result.X_peri = X_peri_opt;
        best_result.alt_peri_km = alt_peri_opt;
        best_result.traj = [t_traj_opt, X_traj_opt];

        % Verify Moon altitude constraint for optimized trajectory
        use_fmincon_result = check_path(X_traj_opt, p);

        if ~use_fmincon_result
            fprintf('  Warning: fmincon result violates Moon altitude constraint!\n');
            fprintf('  Reverting to grid search result.\n');
            % Restore the best grid search result
            best_result = candidates(1);
            for ic = 1:length(candidates)
                if abs(candidates(ic).alt_peri_km) < abs(best_result.alt_peri_km)
                    best_result = candidates(ic);
                end
            end
            best_result.alt_error = abs(best_result.alt_peri_km);
            best_result.found = true;
        end

        % Check if precision requirement met (only refine if fmincon was used)
        alt_error_LU = abs(best_result.alt_peri_km) / p.LU;
        if use_fmincon_result && alt_error_LU > 1e-6
            fprintf('  Warning: alt_peri error %.2e LU > 1e-6 LU, trying fsolve refinement...\n', alt_error_LU);

            % Use fsolve to precisely solve alt_peri = 0
            % Only vary dv magnitude while keeping direction
            dv_dir_opt = atan2(dv_syn_opt(2), dv_syn_opt(1));
            dv_mag_init = norm(dv_syn_opt);

            refine_obj = @(dv_mag) refine_periapsis(dv_mag, dv_dir_opt, theta_opt, t_stay_opt, ...
                t_arr_LLO, t_return_max, p, moon_x, r_LLO_LU, v_circ_kep_VU, direction);

            opts_fsolve = optimoptions('fsolve', 'Display', 'iter', ...
                'FunctionTolerance', 1e-14, 'StepTolerance', 1e-14, ...
                'OptimalityTolerance', 1e-14);
            [dv_mag_refined, ~, exitflag_refine] = fsolve(refine_obj, dv_mag_init, opts_fsolve);

            if exitflag_refine > 0
                % Update with refined solution
                dv_syn_refined = dv_mag_refined * [cos(dv_dir_opt); sin(dv_dir_opt)];
                X_dep_refined = [x_dep; y_dep; v_circ_syn(1) + dv_syn_refined(1); v_circ_syn(2) + dv_syn_refined(2)];

                opts_ode = odeset('Events', @(t,X) event_periapsis(t,X,p), 'RelTol', 1e-13, 'AbsTol', 1e-15);
                [t_traj_ref, X_traj_ref, te_ref, Xe_ref, ~] = cr3bp.propagate(X_dep_refined, [0, t_return_max], p.mu, opts_ode);

                % Verify fsolve result also satisfies Moon constraint
                if check_path(X_traj_ref, p)
                    X_peri_ref = Xe_ref(end,:)';
                    dx_ref = X_peri_ref(1) + p.mu;
                    dy_ref = X_peri_ref(2);
                    alt_peri_ref = sqrt(dx_ref^2 + dy_ref^2) * p.LU - p.R_e;

                    fprintf('  fsolve refinement: alt_peri = %.6f km (error: %.2e LU)\n', alt_peri_ref, abs(alt_peri_ref)/p.LU);

                    % Update best result
                    best_result.dv_syn = dv_syn_refined;
                    best_result.dv_mag_kms = norm(dv_syn_refined) * p.VU;
                    best_result.X_dep = X_dep_refined;
                    best_result.X_peri = X_peri_ref;
                    best_result.alt_peri_km = alt_peri_ref;
                    best_result.t_flight = te_ref(end);
                    best_result.t_total = t_arr_LLO + t_stay_opt + te_ref(end);
                    best_result.traj = [t_traj_ref, X_traj_ref];
                else
                    fprintf('  fsolve result violates Moon constraint, keeping fmincon result.\n');
                end
            end
        end
    else
        fprintf('\nOptimization did not converge well. Using grid search result.\n');
    end
end

%% 5. Final Results
if ~best_result.found
    error('No valid trajectory found!');
end

fprintf('\n=== Final Trajectory ===\n');
fprintf('Departure theta: %.1f deg\n', rad2deg(best_result.theta_LLO));
fprintf('Lunar stay: %.2f days\n', best_result.t_stay * p.TU / 86400);
fprintf('Flight time: %.2f days\n', best_result.t_flight * p.TU / 86400);
fprintf('Total mission: %.2f days\n', best_result.t_total * p.TU / 86400);
fprintf('Return Δv: %.4f km/s\n', best_result.dv_mag_kms);
fprintf('Periapsis altitude: %.6f km (target: 0 km, error: %.2e LU)\n', ...
    best_result.alt_peri_km, abs(best_result.alt_peri_km)/p.LU);

% Verify radial velocity at periapsis
X_peri = best_result.X_peri;
dx = X_peri(1) + p.mu;
dy = X_peri(2);
r = sqrt(dx^2 + dy^2);
rdot = (dx*X_peri(3) + dy*X_peri(4)) / r;
fprintf('Radial velocity at periapsis: %.6f VU (should be ~0)\n', rdot);

%% 6. Fuel Analysis
fprintf('\n=== Fuel Analysis ===\n');
dv_return_mps = best_result.dv_mag_kms * 1000;

% With current fuel
M_before = p.m_dry + m_fuel_after_insert;
[M_after, dm] = mission.fuel_consumption(M_before, dv_return_mps, p.ve);
m_fuel_final = m_fuel_after_insert - dm;

fprintf('Current fuel at LLO: %.0f kg\n', m_fuel_after_insert);
fprintf('Fuel consumed: %.0f kg\n', dm);
fprintf('Final fuel: %.0f kg\n', m_fuel_final);

if m_fuel_final > 100
    fprintf('\n*** Final fuel exceeds 100 kg limit ***\n');
    fprintf('Solution: Reduce L1 refueling by %.0f kg\n', m_fuel_final - 100);

    % Calculate required L1 fuel
    % We need m_fuel_final = 100 kg
    % m_fuel_LLO - dm = 100
    % dm = M_before * (1 - exp(-dv/ve))
    % m_fuel_LLO - (m_dry + m_fuel_LLO) * (1 - k) = 100
    % m_fuel_LLO * k - m_dry * (1 - k) = 100
    % m_fuel_LLO = (100 + m_dry * (1 - k)) / k
    k = exp(-dv_return_mps / p.ve);
    m_fuel_LLO_required = (100 + p.m_dry * (1 - k)) / k;
    fprintf('Required fuel at LLO: %.0f kg (to have 100 kg at Earth)\n', m_fuel_LLO_required);
end

%% 7. Calculate Reentry Velocity
fprintf('\n=== Reentry State ===\n');
X_earth = best_result.X_peri;
t_reentry = best_result.t_dep + best_result.t_flight;

% Convert to Earth-relative velocity
[r_rel_E, v_rel_E] = frames.state_rel_body(X_earth, t_reentry, 'earth', p.mu);
v_reentry_kms = norm(v_rel_E) * p.VU;
fprintf('Reentry velocity (relative to Earth): %.2f km/s\n', v_reentry_kms);

%% 8. Verification Summary
fprintf('\n=== Verification Summary ===\n');

pass_all = true;

% 1. Total time < 100 days
if best_result.t_total * p.TU / 86400 < 100
    fprintf('[PASS] Total mission time: %.1f days (< 100 days)\n', best_result.t_total * p.TU / 86400);
else
    fprintf('[FAIL] Total mission time: %.1f days (>= 100 days)\n', best_result.t_total * p.TU / 86400);
    pass_all = false;
end

% 2. Lunar stay 3-10 days
stay_days = best_result.t_stay * p.TU / 86400;
if stay_days >= 3.0 && stay_days <= 10.0
    fprintf('[PASS] Lunar stay: %.2f days (3-10 days)\n', stay_days);
else
    fprintf('[FAIL] Lunar stay: %.2f days (should be 3-10 days)\n', stay_days);
    pass_all = false;
end

% 3. Periapsis altitude = 0 km (position error <= 1e-6 LU)
precision_LU = 1e-6;
precision_km = precision_LU * p.LU;  % ~0.38 km
alt_error_LU = abs(best_result.alt_peri_km) / p.LU;

if alt_error_LU <= precision_LU
    fprintf('[PASS] Periapsis altitude: %.4f km (error: %.2e LU <= 1e-6 LU)\n', ...
        best_result.alt_peri_km, alt_error_LU);
else
    fprintf('[FAIL] Periapsis altitude: %.4f km (error: %.2e LU > 1e-6 LU)\n', ...
        best_result.alt_peri_km, alt_error_LU);
    fprintf('       Need to refine optimization or use tighter tolerance\n');
    pass_all = false;
end

% 4. Final fuel <= 100 kg
if m_fuel_final <= 100
    fprintf('[PASS] Final fuel: %.0f kg (<= 100 kg)\n', m_fuel_final);
else
    fprintf('[WARN] Final fuel: %.0f kg (> 100 kg, will adjust L1 refueling)\n', m_fuel_final);
end

if pass_all
    fprintf('\n=== All verification checks PASSED ===\n');
else
    fprintf('\n=== Some checks need attention ===\n');
end

%% 9. Save Results
fprintf('\n--- Saving Results ---\n');

results_LLO2Earth = struct();
results_LLO2Earth.theta_LLO = best_result.theta_LLO;
results_LLO2Earth.t_stay = best_result.t_stay;
results_LLO2Earth.t_stay_days = best_result.t_stay * p.TU / 86400;
results_LLO2Earth.dv_syn = best_result.dv_syn;
results_LLO2Earth.dv_return_kms = best_result.dv_mag_kms;
results_LLO2Earth.dv_return_mps = best_result.dv_mag_kms * 1000;
results_LLO2Earth.X_dep = best_result.X_dep;
results_LLO2Earth.t_dep = best_result.t_dep;
results_LLO2Earth.t_flight = best_result.t_flight;
results_LLO2Earth.t_flight_days = best_result.t_flight * p.TU / 86400;
results_LLO2Earth.t_total = best_result.t_total;
results_LLO2Earth.t_total_days = best_result.t_total * p.TU / 86400;
results_LLO2Earth.X_earth = best_result.X_peri;  % State at periapsis = Earth return point
results_LLO2Earth.alt_peri_km = best_result.alt_peri_km;
results_LLO2Earth.v_reentry_kms = v_reentry_kms;
results_LLO2Earth.traj = best_result.traj;
results_LLO2Earth.direction = direction;
results_LLO2Earth.m_fuel_final = m_fuel_final;  % Final fuel with current LLO fuel
results_LLO2Earth.p = p;

save('llo_to_earth_results.mat', 'results_LLO2Earth');
fprintf('Results saved to llo_to_earth_results.mat\n');

%% 10. Visualization
figure('Position', [100, 100, 1200, 400]);

traj = best_result.traj;
theta_circle = linspace(0, 2*pi, 100);

% Full trajectory
subplot(1,3,1);
hold on; axis equal; grid on;
plot(traj(:,2), traj(:,3), 'b-', 'LineWidth', 1.5);
fill(-p.mu + 0.02*cos(theta_circle), 0.02*sin(theta_circle), 'b', 'FaceAlpha', 0.5);
fill(moon_x + 0.01*cos(theta_circle), 0.01*sin(theta_circle), [0.5 0.5 0.5], 'FaceAlpha', 0.5);
plot(best_result.X_dep(1), best_result.X_dep(2), 'go', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
plot(best_result.X_peri(1), best_result.X_peri(2), 'rs', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
xlabel('x (LU)'); ylabel('y (LU)');
title('Return Trajectory');
legend('Trajectory', 'Earth', 'Moon', 'Departure', 'Periapsis');

% Earth arrival detail
subplot(1,3,2);
hold on; axis equal; grid on;
r_e_LU = p.R_e / p.LU;
fill(-p.mu + r_e_LU*cos(theta_circle), r_e_LU*sin(theta_circle), 'b', 'FaceAlpha', 0.5);
plot(traj(end-100:end,2), traj(end-100:end,3), 'm-', 'LineWidth', 2);
plot(best_result.X_peri(1), best_result.X_peri(2), 'rs', 'MarkerSize', 12, 'MarkerFaceColor', 'r');
xlim([-p.mu-0.03, -p.mu+0.03]); ylim([-0.03, 0.03]);
xlabel('x (LU)'); ylabel('y (LU)');
title(sprintf('Earth Arrival (alt=%.1f km)', best_result.alt_peri_km));

% Summary
subplot(1,3,3);
axis off;
text_str = {
    'LLO → Earth Return'
    '===================='
    ''
    sprintf('Lunar stay: %.2f days', best_result.t_stay * p.TU / 86400)
    sprintf('Flight time: %.2f days', best_result.t_flight * p.TU / 86400)
    sprintf('Total: %.2f days', best_result.t_total * p.TU / 86400)
    ''
    sprintf('Return Δv: %.3f km/s', best_result.dv_mag_kms)
    sprintf('Periapsis alt: %.1f km', best_result.alt_peri_km)
    ''
    sprintf('Fuel consumed: %.0f kg', dm)
    sprintf('Final fuel: %.0f kg', m_fuel_final)
};
text(0.1, 0.9, text_str, 'FontSize', 11, 'VerticalAlignment', 'top', 'FontName', 'FixedWidth');

saveas(gcf, 'figures/llo_to_earth_transfer.png');
fprintf('Figure saved.\n');

fprintf('\n=== Complete ===\n');

%% Helper Functions

function [value, isterminal, direction] = event_periapsis(~, X, p)
    % Detect Earth periapsis passage (rdot = 0, from negative to positive)
    dx = X(1) + p.mu;
    dy = X(2);
    r = sqrt(dx^2 + dy^2);
    rdot = (dx*X(3) + dy*X(4)) / r;

    % Moon distance check
    r_moon = sqrt((X(1) - 1 + p.mu)^2 + X(2)^2) * p.LU;

    % Events: 1=periapsis, 2=moon collision, 3=too far
    value = [rdot; r_moon - (p.R_m + 100); 2 - sqrt(X(1)^2 + X(2)^2)];
    isterminal = [1; 1; 1];
    direction = [+1; -1; -1];  % periapsis: rdot goes from - to +
end

function valid = check_path(X_traj, p)
    valid = true;

    % Track the minimum Moon altitude throughout the trajectory
    % Skip first few points (starting at LLO, altitude ~100 km)
    for i = 5:size(X_traj, 1)
        % Moon distance in km
        r_moon = sqrt((X_traj(i,1) - 1 + p.mu)^2 + X_traj(i,2)^2) * p.LU;
        alt_moon = r_moon - p.R_m;  % altitude above Moon surface

        % Strict 100 km constraint - don't allow any dip below 100 km
        if alt_moon < 100
            valid = false; return;
        end

        % Distance limit (< 2 LU from barycenter)
        if sqrt(X_traj(i,1)^2 + X_traj(i,2)^2) > 2
            valid = false; return;
        end
    end
end

function f = objective_alt_peri(x, ~, t_return_max, p, moon_x, r_LLO_LU, v_circ_kep_VU, direction)
    theta = x(1);
    % t_stay = x(2);  % Not used in trajectory propagation
    dv_syn = x(3:4);

    % Departure state
    r_rel = r_LLO_LU * [cos(theta); sin(theta)];
    x_dep = moon_x + r_rel(1);
    y_dep = r_rel(2);
    theta_hat = direction * [-sin(theta); cos(theta)];
    v_circ_syn = v_circ_kep_VU * theta_hat - [-r_rel(2); r_rel(1)];

    X_dep = [x_dep; y_dep; v_circ_syn(1) + dv_syn(1); v_circ_syn(2) + dv_syn(2)];

    try
        opts = odeset('Events', @(t,X) event_peri_simple(t,X,p), 'RelTol', 1e-10, 'AbsTol', 1e-12);
        [~, ~, te, Xe, ie] = ode113(@(t,X) cr3bp.eom(t,X,p.mu), [0, t_return_max], X_dep, opts);

        if ~isempty(ie) && ie(end) == 1
            dx = Xe(end,1) + p.mu;
            dy = Xe(end,2);
            alt_peri = sqrt(dx^2 + dy^2) * p.LU - p.R_e;
            f = abs(alt_peri);  % Minimize |altitude - 0|
        else
            f = 1e6;  % No periapsis found
        end
    catch
        f = 1e6;
    end
end

function [value, isterminal, direction] = event_peri_simple(~, X, p)
    dx = X(1) + p.mu;
    dy = X(2);
    r = sqrt(dx^2 + dy^2);
    rdot = (dx*X(3) + dy*X(4)) / r;
    value = rdot;
    isterminal = 1;
    direction = +1;
end

function f = refine_periapsis(dv_mag, dv_dir, theta, ~, ~, t_return_max, p, moon_x, r_LLO_LU, v_circ_kep_VU, orbit_dir)
% REFINE_PERIAPSIS Objective function for fsolve to find exact periapsis = 0
%
% Returns: f = (r_periapsis - R_earth) in LU, should be 0
% Note: t_stay and t_arr_LLO are passed but not used (trajectory independent of absolute time)

    % Compute departure state
    r_rel = r_LLO_LU * [cos(theta); sin(theta)];
    x_dep = moon_x + r_rel(1);
    y_dep = r_rel(2);
    theta_hat = orbit_dir * [-sin(theta); cos(theta)];
    v_circ_syn = v_circ_kep_VU * theta_hat - [-r_rel(2); r_rel(1)];

    dv_syn = dv_mag * [cos(dv_dir); sin(dv_dir)];
    X_dep = [x_dep; y_dep; v_circ_syn(1) + dv_syn(1); v_circ_syn(2) + dv_syn(2)];

    try
        opts = odeset('Events', @(t,X) event_peri_fsolve(t,X,p), 'RelTol', 1e-13, 'AbsTol', 1e-15);
        [~, ~, ~, Xe, ie] = ode113(@(t,X) cr3bp.eom(t,X,p.mu), [0, t_return_max], X_dep, opts);

        if ~isempty(ie) && ie(end) == 1
            dx = Xe(end,1) + p.mu;
            dy = Xe(end,2);
            r_peri_LU = sqrt(dx^2 + dy^2);
            R_e_LU = p.R_e / p.LU;
            f = r_peri_LU - R_e_LU;  % Should be 0 for exact periapsis at Earth surface
        else
            f = 1;  % Large error if no periapsis found
        end
    catch
        f = 1;
    end
end

function [value, isterminal, direction] = event_peri_fsolve(~, X, p)
    dx = X(1) + p.mu;
    dy = X(2);
    r = sqrt(dx^2 + dy^2);
    rdot = (dx*X(3) + dy*X(4)) / r;
    value = rdot;
    isterminal = 1;
    direction = +1;
end
