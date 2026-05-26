function [X0, T, orbit_states, t_orbit] = lyapunov_orbit(x0_guess, mu, Ax_target)
% LYAPUNOV_ORBIT Compute a Lyapunov orbit around L1 using differential correction
%
% Uses x-axis symmetry: initial state [x0, 0, 0, vy0].
% At half-period (y=0 crossing), require vx=0.
% Single-variable correction on vy0 with x0 fixed.
%
% Inputs:
%   x0_guess  - initial x-coordinate guess (should be left of L1)
%   mu        - mass parameter
%   Ax_target - (optional) desired x-amplitude from L1
%
% Outputs:
%   X0           - corrected initial state [x0; 0; 0; vy0]
%   T            - orbital period (TU)
%   orbit_states - [N x 4] states along one full period
%   t_orbit      - [N x 1] corresponding times (from ODE, variable step)

xL1 = orbits.l1_point(mu);

if nargin >= 3 && ~isempty(Ax_target)
    x0 = xL1 - Ax_target;
else
    x0 = x0_guess;
end

% Ensure x0 is left of L1
if x0 >= xL1
    x0 = xL1 - 0.05;
end

% Initial guess for vy0 using linearized dynamics
Ax = abs(x0 - xL1);
r1_L1 = abs(xL1 + mu);
r2_L1 = abs(xL1 - 1 + mu);
Uxx = 1 + 2*(1-mu)/r1_L1^3 + 2*mu/r2_L1^3;

% Characteristic exponent from linearized equations
% lambda^4 + (2 - Uxx)*lambda^2 + ... = 0
% Approximate: lambda ~ sqrt(Uxx - 1) for in-plane Lyapunov
beta = 2 - (Uxx + 2);
disc = beta^2 + 4*(Uxx - 1)*(Uxx + 1);
if disc > 0
    s2 = (-beta + sqrt(disc)) / 2;
    if s2 > 0
        s = sqrt(s2);
    else
        s = 2.0;
    end
else
    s = 2.0;
end

% vy0 estimate: for Lyapunov orbit, vy0 ~ -s * Ax (negative for leftward start)
vy0_guess = -s * Ax;
if abs(vy0_guess) < 0.01
    vy0_guess = -0.2;
end

% Differential correction: find vy0 such that vx=0 at half-period
% Use fzero on scalar function
options = optimset('TolX', 1e-14, 'Display', 'off');

try
    vy0_corr = fzero(@(vy0) half_period_vx(x0, vy0, mu), vy0_guess, options);
catch
    % Try bracketing approach
    vy_range = linspace(vy0_guess*2, vy0_guess*0.1, 50);
    vx_vals = zeros(size(vy_range));
    for i = 1:length(vy_range)
        vx_vals(i) = half_period_vx(x0, vy_range(i), mu);
    end
    % Find sign change
    sign_changes = find(diff(sign(vx_vals)) ~= 0);
    if ~isempty(sign_changes)
        bracket = [vy_range(sign_changes(1)), vy_range(sign_changes(1)+1)];
        vy0_corr = fzero(@(vy0) half_period_vx(x0, vy0, mu), bracket, options);
    else
        error('Could not find Lyapunov orbit');
    end
end

X0 = [x0; 0; 0; vy0_corr];

% Find precise half-period
T_half = find_half_period(X0, mu);
T = 2 * T_half;

% Generate full orbit states with time vector
[t_orbit, orbit_states] = cr3bp.propagate(X0, [0, T], mu);
end

function vx_half = half_period_vx(x0, vy0, mu)
% Integrate to half-period (y=0 crossing) and return vx
% Avoids t=0 event by integrating a small step first, then with events
X0 = [x0; 0; 0; vy0];

% First, integrate a tiny step to move away from y=0
dt_init = 1e-4;
[~, X_init] = ode113(@(t,X) cr3bp.eom(t,X,mu), [0, dt_init], X0, ...
    odeset('RelTol', 1e-13, 'AbsTol', 1e-13));
X_start = X_init(end, :)';

% Now determine the crossing direction
% If vy0 > 0: y went positive, half-period is y crossing zero going down (dir = -1)
% If vy0 < 0: y went negative, half-period is y crossing zero going up (dir = +1)
if vy0 > 0
    dir = -1;
else
    dir = 1;
end

event_opts = odeset('RelTol', 1e-13, 'AbsTol', 1e-13, ...
    'Events', @(t,X) y_cross_dir(t, X, dir));

[~, ~, te, Xe, ~] = ode113(@(t,X) cr3bp.eom(t,X,mu), [0, 30], X_start, event_opts);

if isempty(te)
    vx_half = 1;  % Penalty: no crossing found
else
    vx_half = Xe(1, 3);  % vx at half-period
end
end

function T_half = find_half_period(X0, mu)
% Find precise half-period time
vy0 = X0(4);

% Small initial step to avoid t=0 event
dt_init = 1e-4;
[~, X_init] = ode113(@(t,X) cr3bp.eom(t,X,mu), [0, dt_init], X0, ...
    odeset('RelTol', 1e-13, 'AbsTol', 1e-13));
X_start = X_init(end, :)';

if vy0 > 0
    dir = -1;
else
    dir = 1;
end

event_opts = odeset('RelTol', 1e-13, 'AbsTol', 1e-13, ...
    'Events', @(t,X) y_cross_dir(t, X, dir));

[~, ~, te, ~, ~] = ode113(@(t,X) cr3bp.eom(t,X,mu), [0, 30], X_start, event_opts);

if ~isempty(te)
    T_half = te(1) + dt_init;
else
    T_half = pi;  % Fallback
end
end

function [value, isterminal, direction] = y_cross_dir(~, X, dir)
% Detect y = 0 crossing in specified direction
value = X(2);       % y = 0
isterminal = 1;
direction = dir;
end
