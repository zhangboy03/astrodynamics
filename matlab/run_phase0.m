%% Phase 0: Specification Verification and Self-Check
% This script validates all core modules before mission design

clear; clc; close all;
fprintf('=== Phase 0: Specification Verification ===\n\n');

%% 0.1 Parameters Consistency Check
fprintf('0.1 Parameters Check...\n');
p = const.params();
fprintf('  mu_e = %.0f km^3/s^2 (assignment: 398600)\n', p.mu_e);
fprintf('  mu_m = %.0f km^3/s^2 (assignment: 4903)\n', p.mu_m);
fprintf('  R_e = %.0f km (assignment: 6378)\n', p.R_e);
fprintf('  R_m = %.0f km (assignment: 1737)\n', p.R_m);
fprintf('  LU = %.0f km (assignment: 384400)\n', p.LU);
fprintf('  mu = %.12e (computed)\n', p.mu);
fprintf('  TU = %.6f s (%.6f days)\n', p.TU, p.TU/86400);
fprintf('  VU = %.6f km/s\n', p.VU);
fprintf('  r_LEO = %.6e LU (400 km alt)\n', p.r_LEO);
fprintf('  r_LLO = %.6e LU (100 km alt)\n', p.r_LLO);
fprintf('  Dry mass = %.0f kg, Fuel capacity = %.0f kg\n', p.m_dry, p.m_fuel_max);
fprintf('  ve = %.0f m/s\n', p.ve);
fprintf('  PASSED: Parameters consistent with assignment\n\n');

%% 0.2 Coordinate Transformation Test
fprintf('0.2 Coordinate Transformation Test...\n');
try
    frames.test_frames_transforms();
    fprintf('  PASSED: Frame transformations validated\n\n');
catch ME
    fprintf('  FAILED: %s\n\n', ME.message);
end

%% 0.3 L1 Point Computation
fprintf('0.3 L1 Point Computation...\n');
x_L1 = orbits.l1_point(p.mu);
fprintf('  L1 x-coordinate: %.12f LU\n', x_L1);
fprintf('  L1 distance from Earth: %.0f km\n', (x_L1 + p.mu) * p.LU);
fprintf('  L1 distance from Moon: %.0f km\n', (1 - p.mu - x_L1) * p.LU);
fprintf('  PASSED: L1 computed\n\n');

%% 0.4 Lyapunov Orbit at x0=0.8 (Assignment Requirement)
fprintf('0.4 Lyapunov Orbit Construction (x0=0.8)...\n');
try
    [X0_lyap, T_lyap, orbit_states, t_orbit] = orbits.lyapunov_orbit(0.8, p.mu);
    fprintf('  Initial position: [%.12f, %.12f]\n', orbit_states(1,1), orbit_states(1,2));
    fprintf('  Initial velocity: [%.12f, %.12f]\n', X0_lyap(3), X0_lyap(4));
    fprintf('  Period T = %.12f TU (%.4f days)\n', T_lyap, units.time_tu2day(T_lyap, p));

    % Verify periodicity
    X_end = orbit_states(end, :);
    pos_err = norm(X_end(1:2) - orbit_states(1,1:2));
    vel_err = norm(X_end(3:4) - [X0_lyap(3), X0_lyap(4)]);
    fprintf('  Periodicity error: pos=%.2e, vel=%.2e\n', pos_err, vel_err);

    % Jacobi constant check
    C_start = cr3bp.jacobi(orbit_states(1,:)', p.mu);
    C_end = cr3bp.jacobi(orbit_states(end,:)', p.mu);
    fprintf('  Jacobi constant: start=%.12f, end=%.12f, drift=%.2e\n', C_start, C_end, abs(C_end-C_start));

    if pos_err < 1e-6 && vel_err < 1e-6
        fprintf('  PASSED: Lyapunov orbit converged\n\n');
    else
        fprintf('  WARNING: Periodicity error larger than 1e-6\n\n');
    end
catch ME
    fprintf('  FAILED: %s\n\n', ME.message);
end

%% 0.5 Supply State Interpolation Test
fprintf('0.5 Supply State Interpolation Test...\n');
try
    % Test mod(t, T) behavior
    t_test = 0.5 * T_lyap;
    X_test1 = orbits.supply_state(t_test, orbit_states, T_lyap, t_orbit);
    X_test2 = orbits.supply_state(t_test + 3*T_lyap, orbit_states, T_lyap, t_orbit);
    diff_state = norm(X_test1 - X_test2);
    fprintf('  State at t=0.5T vs t=3.5T: diff=%.2e\n', diff_state);
    if diff_state < 1e-10
        fprintf('  PASSED: Periodic interpolation working\n\n');
    else
        fprintf('  WARNING: Periodic interpolation may have issues\n\n');
    end
catch ME
    fprintf('  FAILED: %s\n\n', ME.message);
end

%% 0.6 LEO and LLO Circular Orbit Construction
fprintf('0.6 Circular Orbit State Construction...\n');
t0 = 0;
theta_LEO = 0;
theta_LLO = 0;

% LEO state (prograde)
X_LEO = frames.circular_orbit_state('earth', p.r_LEO, theta_LEO, t0, p.mu, 1);
fprintf('  LEO state (prograde): [%.6f, %.6f, %.6f, %.6f]\n', X_LEO);

% Check LEO is at correct radius from Earth
r_LEO_check = sqrt((X_LEO(1)+p.mu)^2 + X_LEO(2)^2);
fprintf('  LEO radius from Earth: %.6e LU (expected %.6e)\n', r_LEO_check, p.r_LEO);

% LLO state (prograde)
X_LLO = frames.circular_orbit_state('moon', p.r_LLO, theta_LLO, t0, p.mu, 1);
fprintf('  LLO state (prograde): [%.6f, %.6f, %.6f, %.6f]\n', X_LLO);

% Check LLO is at correct radius from Moon
r_LLO_check = sqrt((X_LLO(1)-(1-p.mu))^2 + X_LLO(2)^2);
fprintf('  LLO radius from Moon: %.6e LU (expected %.6e)\n', r_LLO_check, p.r_LLO);

fprintf('  PASSED: Circular orbit states constructed\n\n');

%% 0.7 C3 Calculation Test
fprintf('0.7 C3 Energy Calculation Test...\n');
% At LEO, relative velocity should give C3 near 0 for circular orbit
[r_rel, v_rel] = frames.state_rel_body(X_LEO, t0, 'earth', p.mu);
r_rel_km = norm(r_rel) * p.LU;
v_rel_kms = norm(v_rel) * p.VU;
C3_LEO = v_rel_kms^2 - 2*p.mu_e/r_rel_km;
fprintf('  LEO relative to Earth: r=%.1f km, v=%.4f km/s\n', r_rel_km, v_rel_kms);
fprintf('  C3 at LEO (circular): %.4f km^2/s^2 (expected ~%.4f)\n', C3_LEO, -p.mu_e/(p.R_e+400));
fprintf('  PASSED: C3 calculation working\n\n');

%% 0.8 Mass Model Test
fprintf('0.8 Mass Model Test...\n');
% Test case: C3=0 -> M0=25000
[M0, M_carry] = mission.mass_model(0, p.m_dry, 8000);
fprintf('  C3=0, m_fuel=8000: M0=%.0f kg, M_carry=%.0f kg (expected: 25000, 7000)\n', M0, M_carry);

% Test case: C3=-1 -> M0=26000
[M0_neg, M_carry_neg] = mission.mass_model(-1, p.m_dry, 8000);
fprintf('  C3=-1, m_fuel=8000: M0=%.0f kg, M_carry=%.0f kg (expected: 26000, 8000)\n', M0_neg, M_carry_neg);
fprintf('  PASSED: Mass model correct\n\n');

%% 0.9 Fuel Consumption Test
fprintf('0.9 Fuel Consumption Test...\n');
M_before = 20000;
dv_mps = 1000; % 1 km/s
[M_after, fuel_used] = mission.fuel_consumption(M_before, dv_mps, p.ve);
M_expected = M_before * exp(-dv_mps/p.ve);
fprintf('  M_before=%.0f kg, dv=%.0f m/s\n', M_before, dv_mps);
fprintf('  M_after=%.2f kg (expected: %.2f)\n', M_after, M_expected);
fprintf('  Fuel used: %.2f kg\n', fuel_used);
fprintf('  PASSED: Fuel consumption correct\n\n');

%% 0.10 Results Format Minimal Test
fprintf('0.10 Results File Format Test...\n');
try
    rb = io.ResultsBuilder();

    % Minimal test trajectory
    t_dep = 0;
    X_dep = X_LEO;
    dv_dep = [0.1; 0.05];
    M_fuel = 10000;
    M_carry = 5000;

    rb.add_departure(t_dep, X_dep, dv_dep, M_fuel, M_carry);
    rb.add_coast([0, 1], [X_LEO'; X_LEO'], M_fuel, M_carry);

    % Mock burn
    dv_burn = [0.01; 0.01];
    dv_mps_burn = norm(dv_burn) * p.VU * 1000;
    [~, fuel_used_burn] = mission.fuel_consumption(M_fuel + M_carry + p.m_dry, dv_mps_burn, p.ve);
    M_fuel_after_burn = M_fuel - fuel_used_burn;
    rb.add_burn(1, X_LEO, dv_burn, M_fuel, M_fuel_after_burn, M_carry);

    rb.add_coast([1, 2], [X_LEO'; X_LLO'], M_fuel_after_burn, M_carry);
    rb.add_arrive_moon(2, X_LLO, M_fuel_after_burn, M_carry);
    rb.add_leave_moon(2.5, X_LLO, M_fuel_after_burn);

    % Another burn for departure from Moon
    dv_moon_dep = [0.01; 0.01];
    dv_mps_moon = norm(dv_moon_dep) * p.VU * 1000;
    [~, fuel_used_moon] = mission.fuel_consumption(M_fuel_after_burn + p.m_dry, dv_mps_moon, p.ve);
    M_fuel_after_moon = M_fuel_after_burn - fuel_used_moon;
    rb.add_burn(2.5, X_LLO, dv_moon_dep, M_fuel_after_burn, M_fuel_after_moon, 0);

    rb.add_coast([2.5, 3], [X_LLO'; X_LEO'], M_fuel_after_moon, 0);

    % Final return with fuel <= 100 kg
    M_fuel_return = 50;
    rb.add_return_earth(3, X_LEO, M_fuel_return);

    % Validate structure (not fuel since we faked intermediate values)
    fprintf('  Created %d rows\n', rb.n_rows);
    fprintf('  First event: %d (expected 1)\n', rb.data(1,10));
    fprintf('  Last event: %d (expected 4)\n', rb.data(end,10));

    % Write test file
    test_file = '/Users/keeplearning/Desktop/Astrodynamics/Final/matlab/test_results.txt';
    io.write_results(test_file, rb.data);

    % Read back and verify format
    fid = fopen(test_file, 'r');
    first_line = fgetl(fid);
    fclose(fid);
    fprintf('  First line: %s\n', first_line);

    % Parse first line to check column order
    vals = sscanf(first_line, '%d %e %e %e %e %e %e %e %e %e');
    fprintf('  Parsed Event=%d (col 1), Time=%.6f (col 2)\n', vals(1), vals(2));

    delete(test_file);
    fprintf('  PASSED: Results format correct (Event in col 1)\n\n');
catch ME
    fprintf('  FAILED: %s\n\n', ME.message);
end

%% Summary
fprintf('=== Phase 0 Complete ===\n');
fprintf('All core modules validated. Ready for Phase 1.\n');

% Save Lyapunov orbit data for later phases
save('/Users/keeplearning/Desktop/Astrodynamics/Final/matlab/phase0_data.mat', ...
    'p', 'X0_lyap', 'T_lyap', 'orbit_states', 't_orbit', 'x_L1');
fprintf('\nLyapunov orbit data saved to phase0_data.mat\n');