function X_I = synodic2inertial(X_S, t)
% SYNODIC2INERTIAL Convert state from rotating (synodic) to inertial frame
%
% Convention: omega = 1 (normalized), rotation angle = t
%
% Inputs:
%   X_S - synodic state [x; y; vx; vy] or [N x 4]
%   t   - time (TU), scalar or [N x 1]
%
% Output:
%   X_I - inertial state [x_I; y_I; vx_I; vy_I] or [N x 4]

    row_input = false;
    if size(X_S, 2) == 1
        X_S = X_S';
        row_input = true;
    end

    if isscalar(t)
        t = t * ones(size(X_S, 1), 1);
    end

    x  = X_S(:,1);
    y  = X_S(:,2);
    vx = X_S(:,3);
    vy = X_S(:,4);

    ct = cos(t);
    st = sin(t);

    % Position transformation
    x_I = x.*ct - y.*st;
    y_I = x.*st + y.*ct;

    % Velocity transformation (includes omega x r correction)
    vx_I = (vx - y).*ct - (vy + x).*st;
    vy_I = (vx - y).*st + (vy + x).*ct;

    X_I = [x_I, y_I, vx_I, vy_I];

    if row_input
        X_I = X_I';
    end
end
