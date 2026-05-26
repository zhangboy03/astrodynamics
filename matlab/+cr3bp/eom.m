function dXdt = eom(~, X, mu)
% EOM CR3BP equations of motion (planar, 4-dimensional)
%
% Derived from potential: Omega = 0.5*(x^2+y^2) + (1-mu)/r1 + mu/r2
%
% Inputs:
%   ~  - time (unused, autonomous system)
%   X  - state [x; y; vx; vy] (normalized)
%   mu - mass parameter
%
% Output:
%   dXdt - state derivative [vx; vy; ax; ay]

x  = X(1);
y  = X(2);
vx = X(3);
vy = X(4);

% Distances: Earth at (-mu, 0), Moon at (1-mu, 0)
r1 = sqrt((x + mu)^2 + y^2);       % distance to Earth
r2 = sqrt((x - 1 + mu)^2 + y^2);   % distance to Moon

% Accelerations from dOmega/dx, dOmega/dy
ax = 2*vy + x - (1-mu)*(x+mu)/r1^3 - mu*(x-1+mu)/r2^3;
ay = -2*vx + y - (1-mu)*y/r1^3 - mu*y/r2^3;

dXdt = [vx; vy; ax; ay];
end
