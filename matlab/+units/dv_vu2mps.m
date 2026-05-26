function dv_mps = dv_vu2mps(dv_vu, p)
% DV_VU2MPS Convert delta-v from velocity units to m/s
%
% Inputs:
%   dv_vu - delta-v in normalized velocity units (VU)
%   p     - params struct (from const.params)
%
% Output:
%   dv_mps - delta-v in m/s

    dv_mps = dv_vu * p.VU * 1000;  % VU is km/s, multiply by 1000 for m/s
end
