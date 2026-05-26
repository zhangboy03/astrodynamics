function [r_rel, v_rel] = state_rel_body(X_syn, t, body, mu)
% STATE_REL_BODY Compute position and velocity relative to a body in inertial frame
%
% This is the SOLE entry point for C3 calculations and circular orbit matching.
%
% Inputs:
%   X_syn - synodic state [x; y; vx; vy] (normalized)
%   t     - current time (TU)
%   body  - 'earth' or 'moon'
%   mu    - mass parameter
%
% Outputs:
%   r_rel - relative position in inertial frame [2x1] (normalized)
%   v_rel - relative velocity in inertial frame [2x1] (normalized)

    % Convert spacecraft state to inertial frame
    X_I = frames.synodic2inertial(X_syn(:), t);
    r_sc = X_I(1:2);
    v_sc = X_I(3:4);

    % Body positions and velocities in inertial frame
    if strcmp(body, 'earth')
        % Earth at (-mu, 0) in synodic frame
        % Inertial: r_E = [-mu*cos(t); -mu*sin(t)]
        %           v_E = [mu*sin(t); -mu*cos(t)]
        r_body = [-mu*cos(t); -mu*sin(t)];
        v_body = [mu*sin(t); -mu*cos(t)];
    elseif strcmp(body, 'moon')
        % Moon at (1-mu, 0) in synodic frame
        % Inertial: r_M = [(1-mu)*cos(t); (1-mu)*sin(t)]
        %           v_M = [-(1-mu)*sin(t); (1-mu)*cos(t)]
        r_body = [(1-mu)*cos(t); (1-mu)*sin(t)];
        v_body = [-(1-mu)*sin(t); (1-mu)*cos(t)];
    else
        error('Body must be ''earth'' or ''moon''');
    end

    r_rel = r_sc - r_body;
    v_rel = v_sc - v_body;
end
