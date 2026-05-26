function X = supply_state(t, orbit_states, T, t_orbit, mu)
% SUPPLY_STATE Return the supply spacecraft state at time t
%
% The supply spacecraft follows the Lyapunov orbit periodically.
% Given time t, maps to the orbit phase and uses DIRECT INTEGRATION
% from the initial state to ensure high precision (10^-6 level).
%
% Inputs:
%   t            - time (TU), scalar or vector
%   orbit_states - [N x 4] Lyapunov orbit states (one period)
%   T            - orbital period (TU)
%   t_orbit      - (unused, kept for backward compatibility)
%   mu           - (optional) CR3BP mass parameter, default from const.params()
%
% Output:
%   X - state [4 x length(t)] or [4 x 1] for scalar t

% Get mu if not provided
if nargin < 5 || isempty(mu)
    p = const.params();
    mu = p.mu;
end

% Initial state of Lyapunov orbit (t=0)
X0 = orbit_states(1, :)';

if isscalar(t)
    % Map t to [0, T)
    t_mod = mod(t, T);

    if t_mod < 1e-12
        % At t=0, return initial state directly
        X = X0;
    else
        % Direct integration from X0 to t_mod
        [~, X_traj] = cr3bp.propagate(X0, [0, t_mod], mu);
        X = X_traj(end, :)';
    end
else
    t = t(:);
    X = zeros(4, length(t));
    for k = 1:length(t)
        t_mod = mod(t(k), T);

        if t_mod < 1e-12
            X(:,k) = X0;
        else
            [~, X_traj] = cr3bp.propagate(X0, [0, t_mod], mu);
            X(:,k) = X_traj(end, :)';
        end
    end
end
end
