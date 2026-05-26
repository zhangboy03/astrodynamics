function xL1 = l1_point(mu)
% L1_POINT Compute the x-coordinate of the L1 Lagrange point (normalized)
%
% L1 lies between the primaries: x in (-mu, 1-mu).
% Uses fzero with a bracket for robustness.

% Net x-acceleration equilibrium on x-axis (y=0):
% x - (1-mu)*(x+mu)/|x+mu|^3 - mu*(x-1+mu)/|x-1+mu|^3 = 0
f = @(x) x - (1-mu)*(x+mu)./abs(x+mu).^3 - mu*(x-1+mu)./abs(x-1+mu).^3;

% Bracket strictly inside (-mu, 1-mu) to avoid singularities
a = -mu + 1e-6;
b =  1 - mu - 1e-6;

% Initial guess (optional, not strictly needed when using bracket)
x0 = 1 - mu - (mu/3)^(1/3); %#ok<NASGU>

options = optimset('TolX', 1e-13, 'Display', 'off');

% Use bracket to ensure we converge to the L1 root
xL1 = fzero(f, [a, b], options);
end