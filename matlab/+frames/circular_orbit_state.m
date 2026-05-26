function X_syn = circular_orbit_state(body, r_orbit, theta, t, mu, direction)
% CIRCULAR_ORBIT_STATE Return synodic-frame state for a circular orbit
%
% Computes the state of a spacecraft on a circular orbit around a body,
% then transforms to the synodic (rotating) frame.
%
% Inputs:
%   body      - 'earth' or 'moon'
%   r_orbit   - orbit radius (normalized, from body center)
%   theta     - phase angle in inertial frame (rad)
%   t         - current time (TU)
%   mu        - mass parameter
%   direction - +1 (prograde) or -1 (retrograde)
%               prograde = same direction as Moon's orbital motion
%
% Output:
%   X_syn - synodic state [x; y; vx; vy]

    if nargin < 6
        direction = 1;  % Default prograde
    end

    p = const.params();

    % Body center in inertial frame
    if strcmp(body, 'earth')
        r_body_I = [-mu*cos(t); -mu*sin(t)];
        v_body_I = [mu*sin(t); -mu*cos(t)];
        mu_body = p.mu_e / (p.mu_e + p.mu_m);  % normalized mu_body
    elseif strcmp(body, 'moon')
        r_body_I = [(1-mu)*cos(t); (1-mu)*sin(t)];
        v_body_I = [-(1-mu)*sin(t); (1-mu)*cos(t)];
        mu_body = p.mu_m / (p.mu_e + p.mu_m);  % normalized mu_body
    else
        error('Body must be ''earth'' or ''moon''');
    end

    % Circular orbit velocity (normalized)
    % v_circ = sqrt(mu_body / r_orbit) in normalized units
    v_circ = sqrt(mu_body / r_orbit);

    % Spacecraft position in inertial frame (relative to body center)
    dr_I = r_orbit * [cos(theta); sin(theta)];

    % Spacecraft velocity in inertial frame (relative to body)
    % Prograde: perpendicular to radius, counterclockwise
    dv_I = direction * v_circ * [-sin(theta); cos(theta)];

    % Absolute inertial state
    r_sc_I = r_body_I + dr_I;
    v_sc_I = v_body_I + dv_I;

    % Convert to synodic frame
    X_I = [r_sc_I; v_sc_I];
    X_syn = frames.inertial2synodic(X_I, t);
end
