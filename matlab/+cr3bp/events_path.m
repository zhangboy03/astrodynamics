function [value, isterminal, direction] = events_path(t, X, mu, phase)
% EVENTS_PATH Path constraint event function for CR3BP propagation
%
% Monitors safety constraints during propagation. Terminates integration
% when constraints are violated.
%
% Inputs:
%   t     - current time (TU)
%   X     - current state [x; y; vx; vy]
%   mu    - mass parameter
%   phase - 'transfer' or 'return_coast'
%
% Outputs:
%   value      - event function values
%   isterminal - 1 = stop integration
%   direction  - -1 = detect decreasing zero-crossings

p = const.params();

x = X(1); y = X(2); vx = X(3); vy = X(4);

% Distances (normalized)
r1 = sqrt((x + mu)^2 + y^2);       % to Earth
r2 = sqrt((x - 1 + mu)^2 + y^2);   % to Moon

% Physical distances (km)
r1_phys = r1 * p.LU;
r2_phys = r2 * p.LU;

% Event 1: Moon altitude > 100 km
value(1) = r2_phys - (p.R_m + 100);

% Event 2: Earth altitude > 400 km (only in 'transfer' phase)
if strcmp(phase, 'transfer')
    value(2) = r1_phys - (p.R_e + 400);
else
    value(2) = 1;  % Always positive, never triggers
end

% Event 3: Distance from barycenter < 2 LU
value(3) = 2 - sqrt(x^2 + y^2);

% Event 4: Periapsis detection (only 'return_coast')
if strcmp(phase, 'return_coast')
    % True inertial-frame radial velocity relative to Earth
    % Periapsis = when radial velocity crosses zero from negative to positive
    [r_rel, v_rel] = frames.state_rel_body([x; y; vx; vy], t, 'earth', mu);
    value(4) = dot(r_rel, v_rel);  % True radial velocity in inertial frame
else
    value(4) = 1;  % Never triggers
end

isterminal = [1; 1; 1; 1];
direction  = [-1; -1; -1; 1];  % Event 4: direction=+1 for periapsis (approaching→departing)

% Make column vectors
value = value(:);
end
