function dYdt = eom_stm(~, Y, mu)
% EOM_STM CR3BP equations with State Transition Matrix (20-dimensional)
%
% State: Y = [x, y, vx, vy, Phi(1:16)]
% where Phi is the 4x4 STM stored column-major
%
% Inputs:
%   ~  - time (unused)
%   Y  - extended state [4 state + 16 STM elements]
%   mu - mass parameter
%
% Output:
%   dYdt - derivative of extended state

    x  = Y(1);
    y  = Y(2);
    vx = Y(3);
    vy = Y(4);

    % Distances
    r1 = sqrt((x + mu)^2 + y^2);
    r2 = sqrt((x - 1 + mu)^2 + y^2);
    r1_3 = r1^3; r1_5 = r1^5;
    r2_3 = r2^3; r2_5 = r2^5;

    % State derivatives (same as eom.m)
    ax = 2*vy + x - (1-mu)*(x+mu)/r1_3 - mu*(x-1+mu)/r2_3;
    ay = -2*vx + y - (1-mu)*y/r1_3 - mu*y/r2_3;

    % Jacobian of the vector field (A matrix)
    % Second partial derivatives of Omega
    Uxx = 1 - (1-mu)/r1_3 - mu/r2_3 ...
         + 3*(1-mu)*(x+mu)^2/r1_5 + 3*mu*(x-1+mu)^2/r2_5;
    Uyy = 1 - (1-mu)/r1_3 - mu/r2_3 ...
         + 3*(1-mu)*y^2/r1_5 + 3*mu*y^2/r2_5;
    Uxy = 3*(1-mu)*(x+mu)*y/r1_5 + 3*mu*(x-1+mu)*y/r2_5;

    % A = [0   0   1  0 ]
    %     [0   0   0  1 ]
    %     [Uxx Uxy 0  2 ]
    %     [Uxy Uyy -2 0 ]
    A = [0, 0, 1, 0;
         0, 0, 0, 1;
         Uxx, Uxy, 0, 2;
         Uxy, Uyy, -2, 0];

    % STM derivative: dPhi/dt = A * Phi
    Phi = reshape(Y(5:20), 4, 4);
    dPhi = A * Phi;

    dYdt = [vx; vy; ax; ay; dPhi(:)];
end
