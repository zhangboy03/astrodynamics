function X_S = inertial2synodic(X_I, t)
% INERTIAL2SYNODIC Convert state from inertial to rotating (synodic) frame
%
% Convention: omega = 1 (normalized), rotation angle = t
%
% Inputs:
%   X_I - inertial state [x_I; y_I; vx_I; vy_I] or [N x 4]
%   t   - time (TU), scalar or [N x 1]
%
% Output:
%   X_S - synodic state [x; y; vx; vy] or [N x 4]

    row_input = false;
    if size(X_I, 2) == 1
        X_I = X_I';
        row_input = true;
    end

    if isscalar(t)
        t = t * ones(size(X_I, 1), 1);
    end

    x_I  = X_I(:,1);
    y_I  = X_I(:,2);
    vx_I = X_I(:,3);
    vy_I = X_I(:,4);

    ct = cos(t);
    st = sin(t);

    % Position: inverse rotation
    x =  x_I.*ct + y_I.*st;
    y = -x_I.*st + y_I.*ct;

    % Velocity: inverse rotation then remove omega x r
    % v_synodic = R^T * v_inertial - omega x r_synodic
    % In 2D with omega=1: omega x r = [-y; x]
    % So: vx_syn = (R^T * v_I)_x + y,  vy_syn = (R^T * v_I)_y - x
    vx_rot =  vx_I.*ct + vy_I.*st;
    vy_rot = -vx_I.*st + vy_I.*ct;

    vx = vx_rot + y;
    vy = vy_rot - x;

    X_S = [x, y, vx, vy];

    if row_input
        X_S = X_S';
    end
end
