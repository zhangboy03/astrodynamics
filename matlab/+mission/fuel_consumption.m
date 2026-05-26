function [M_after, dm] = fuel_consumption(M_before, dv_mps, ve)
% FUEL_CONSUMPTION Compute fuel consumed for a single impulse
%
% Uses Tsiolkovsky rocket equation: M_after = M_before * exp(-|dv|/ve)
% Note: dv must be in m/s, ve is exhaust velocity in m/s
%
% Inputs:
%   M_before - mass before burn (kg)
%   dv_mps   - delta-v magnitude in m/s
%   ve       - exhaust velocity (m/s), default 3000
%
% Outputs:
%   M_after - mass after burn (kg)
%   dm      - fuel consumed (kg)

    if nargin < 3
        ve = 3000;
    end

    M_after = M_before * exp(-abs(dv_mps) / ve);
    dm = M_before - M_after;
end
