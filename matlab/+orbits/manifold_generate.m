function [traj_u, traj_s, v_u_all, v_s_all, hit_u, hit_s] = manifold_generate(orbit_states, T, mu, p, epsilon, branch_sign, t_max, t_orbit)
% MANIFOLD_GENERATE Generate unstable/stable manifold trajectories with event termination
%
% Inputs:
%   orbit_states - [N x 4] points on Lyapunov orbit [x y vx vy]
%   T            - period (TU)
%   mu           - CR3BP mass parameter
%   p            - params struct (must include r_LEO, r_LLO)
%   epsilon      - perturbation magnitude (~1e-6)
%   branch_sign  - +1 or -1 (choose +/- eigenvector branch)
%   t_max        - max integration time magnitude (TU)
%   t_orbit      - [N x 1] times along orbit (TU)
%
% Outputs:
%   traj_u  - cell{N}: [t, x, y, vx, vy] forward integrated (unstable)
%   traj_s  - cell{N}: [t, x, y, vx, vy] backward integrated (stable)
%   v_u_all - [N x 4] unstable direction at each point
%   v_s_all - [N x 4] stable direction at each point
%   hit_u   - [N x 1] event id for traj_u end: 1 Moon, 2 Earth, 3 Escape, 0 none
%   hit_s   - [N x 1] event id for traj_s end: 1 Moon, 2 Earth, 3 Escape, 0 none

if nargin < 7 || isempty(t_max)
    t_max = 5*T;
end

N = size(orbit_states, 1);

if nargin < 8 || isempty(t_orbit)
    warning('manifold_generate:NoTimeVector', 'No t_orbit provided; assuming uniform spacing.');
    t_orbit = linspace(0, T, N)';
end
t_orbit = t_orbit(:);

traj_u = cell(N, 1);
traj_s = cell(N, 1);
hit_u  = zeros(N, 1);
hit_s  = zeros(N, 1);

% --- Events: stop on first hit of Moon LLO, Earth LEO, or escape (>2 LU) ---
event_fun = @(t, X) manifold_events(t, X, mu, p);

% IMPORTANT: For events to be reliable, don't use too huge MaxStep.
opts = odeset('RelTol', 1e-12, 'AbsTol', 1e-12, ...
              'Events', event_fun, 'MaxStep', 0.01);

%% Step 1: Monodromy at reference point (i=1) via STM
X0_ref = orbit_states(1, :)';
Y0_ref = [X0_ref; reshape(eye(4), 16, 1)];
[~, Y_full] = cr3bp.propagate(Y0_ref, T, mu);
M = reshape(Y_full(end, 5:20), 4, 4);

%% Step 2: Eigendecomposition - robust neutral/stable/unstable identification
[V, D] = eig(M);
lambdas = diag(D);
abs_lam = abs(lambdas);

tol_neutral = 1e-3;
neutral_idx = find(abs(abs_lam - 1) < tol_neutral);

if numel(neutral_idx) < 2
    [~, order] = sort(abs(abs_lam - 1));
    neutral_idx = order(1:2);
elseif numel(neutral_idx) > 2
    [~, order] = sort(abs(abs_lam(neutral_idx) - 1));
    neutral_idx = neutral_idx(order(1:2));
end

remaining_idx = setdiff(1:4, neutral_idx);
if numel(remaining_idx) ~= 2
    error('Eigenvalue classification failed: expected 2 non-neutral modes, got %d', numel(remaining_idx));
end

[~, iu_local] = max(abs_lam(remaining_idx));
[~, is_local] = min(abs_lam(remaining_idx));
idx_u = remaining_idx(iu_local);
idx_s = remaining_idx(is_local);

v_u_ref = real(V(:, idx_u)); v_u_ref = v_u_ref / norm(v_u_ref);
v_s_ref = real(V(:, idx_s)); v_s_ref = v_s_ref / norm(v_s_ref);

%% Step 3: Propagate eigenvectors along orbit using actual t_orbit times
v_u_all = zeros(N, 4);
v_s_all = zeros(N, 4);
v_u_prev = v_u_ref;
v_s_prev = v_s_ref;

for i = 1:N
    X0 = orbit_states(i, :)';
    t_i = t_orbit(i);

    if i == 1
        v_u = v_u_ref;
        v_s = v_s_ref;
    else
        % STM from reference to this point
        Y0_i = [X0_ref; reshape(eye(4), 16, 1)];
        [~, Y_i] = cr3bp.propagate(Y0_i, t_i, mu);
        Phi_i = reshape(Y_i(end, 5:20), 4, 4);

        v_u = Phi_i * v_u_ref; v_u = v_u / norm(v_u);
        v_s = Phi_i * v_s_ref; v_s = v_s / norm(v_s);

        if dot(v_u, v_u_prev) < 0, v_u = -v_u; end
        if dot(v_s, v_s_prev) < 0, v_s = -v_s; end
    end

    v_u_prev = v_u;
    v_s_prev = v_s;
    v_u_all(i, :) = v_u';
    v_s_all(i, :) = v_s';

    % --- Unstable manifold: perturb ONLY velocity and integrate forward (0 -> +t_max) ---
    X_pert_u = X0;

    v_u_vel = v_u(3:4);
    if norm(v_u_vel) < 1e-12
        error('manifold_generate:BadEigenvector', 'Unstable eigenvector has near-zero velocity components.');
    end
    v_u_vel = v_u_vel / norm(v_u_vel);

    % epsilon now means "velocity perturbation magnitude" (VU)
    X_pert_u(3:4) = X0(3:4) + branch_sign * epsilon * v_u_vel;

    [t_u, X_u, te_u, Xe_u, ie_u] = ode113(@(t,X) cr3bp.eom(t,X,mu), [0, t_max], X_pert_u, opts);

    traj_u{i} = [t_u, X_u];

    if ~isempty(ie_u)
        hit_u(i) = ie_u(1); % first event that terminated
    else
        hit_u(i) = 0;
    end

    % --- Stable manifold: perturb ONLY velocity and integrate backward (0 -> -t_max) ---
    X_pert_s = X0;

    v_s_vel = v_s(3:4);
    if norm(v_s_vel) < 1e-12
        error('manifold_generate:BadEigenvector', 'Stable eigenvector has near-zero velocity components.');
    end
    v_s_vel = v_s_vel / norm(v_s_vel);

    % epsilon now means "velocity perturbation magnitude" (VU)
    X_pert_s(3:4) = X0(3:4) + branch_sign * epsilon * v_s_vel;

    [t_s, X_s, te_s, Xe_s, ie_s] = ode113(@(t,X) cr3bp.eom(t,X,mu), [0, -t_max], X_pert_s, opts);

    traj_s{i} = [t_s, X_s];

    if ~isempty(ie_s)
        hit_s(i) = ie_s(1);
    else
        hit_s(i) = 0;
    end
end
end

function [value, isterminal, direction] = manifold_events(~, X, mu, p)
% Stop when:
% 1) reach Moon LLO radius
% 2) reach Earth LEO radius
% 3) escape beyond 2 LU from barycenter
x = X(1); y = X(2);

r2 = sqrt((x - 1 + mu)^2 + y^2);    % distance to Moon
r1 = sqrt((x + mu)^2 + y^2);        % distance to Earth
r0 = sqrt(x^2 + y^2);               % distance to barycenter

value = [
    r2 - p.r_LLO;   % 1: Moon boundary
    r1 - p.r_LEO;   % 2: Earth boundary
    r0 - 2.0        % 3: escape boundary (hit when r0 = 2)
];

isterminal = [1; 1; 1];     % stop integration
direction  = [0; 0; 0];     % detect both in/out crossings (works for backward too)
end