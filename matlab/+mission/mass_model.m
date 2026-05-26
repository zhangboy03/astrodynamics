function [M0, M_carry] = mass_model(C3_km2s2, m_dry, m_fuel)
% MASS_MODEL Compute initial mass from C3 and payload capacity
%
% Assignment formula:
%   M0 = 25000 - 1000*C3   (kg), C3 in km^2/s^2
%
% This implementation ALLOWS negative C3 (bound orbits),
% which increases M0 per the given linear model.
%
% Inputs:
%   C3_km2s2 - C3 in km^2/s^2
%   m_dry    - dry mass (kg), default 10000
%   m_fuel   - initial fuel mass (kg), default 15000 (caller may set <=15000)
%
% Outputs:
%   M0      - initial total mass at departure (kg)
%   M_carry - payload mass (kg), max(0, M0 - m_dry - m_fuel)

if nargin < 2
    m_dry = 10000;
end
if nargin < 3
    m_fuel = 15000;
end

% Launch vehicle capacity model (no truncation at C3<=0)
M0 = max(0, 25000 - 1000 * C3_km2s2);

% Payload = total mass - structure - fuel
M_carry = max(0, M0 - m_dry - m_fuel);
end