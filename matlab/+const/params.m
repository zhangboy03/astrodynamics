function p = params()
% PARAMS Return all physical constants and non-dimensionalization parameters
%
% Output:
%   p - struct with fields for physical constants, normalized values,
%       spacecraft parameters

    % Gravitational parameters (km^3/s^2)
    p.mu_e = 398600;
    p.mu_m = 4903;

    % Body radii (km)
    p.R_e = 6378;
    p.R_m = 1737;

    % Earth-Moon distance (km)
    p.LU = 384400;

    % CR3BP mass parameter
    p.mu = p.mu_m / (p.mu_e + p.mu_m);

    % Time unit (s)
    p.TU = sqrt(p.LU^3 / (p.mu_e + p.mu_m));

    % Velocity unit (km/s)
    p.VU = p.LU / p.TU;

    % TU in days
    p.TU_day = p.TU / 86400;

    % Normalized orbit radii
    p.r_LEO = (p.R_e + 400) / p.LU;   % LEO (400 km altitude)
    p.r_LLO = (p.R_m + 100) / p.LU;   % LLO (100 km altitude)

    % Spacecraft parameters
    p.m_dry = 10000;        % kg, dry mass
    p.m_fuel_max = 15000;   % kg, max fuel
    p.ve = 3000;            % m/s, equivalent exhaust velocity

    % Note: mass formula M_f = M*exp(-dv/ve), dv must be in m/s
    % CR3BP dv is in VU, convert: dv_mps = dv_VU * VU * 1000
end
