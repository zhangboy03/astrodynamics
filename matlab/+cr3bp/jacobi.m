function C = jacobi(X, mu)
% JACOBI Compute Jacobi constant for CR3BP state
%
% Inputs:
%   X  - state [x, y, vx, vy] or [N x 4] matrix
%   mu - mass parameter
%
% Output:
%   C  - Jacobi constant (scalar or vector)

    if size(X, 2) == 1
        X = X';
    end

    x  = X(:,1);
    y  = X(:,2);
    vx = X(:,3);
    vy = X(:,4);

    r1 = sqrt((x + mu).^2 + y.^2);
    r2 = sqrt((x - 1 + mu).^2 + y.^2);

    % Pseudo-potential
    Omega = 0.5*(x.^2 + y.^2) + (1-mu)./r1 + mu./r2;

    % Jacobi constant: C = 2*Omega - v^2
    v2 = vx.^2 + vy.^2;
    C = 2*Omega - v2;
end
