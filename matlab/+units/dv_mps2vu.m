function dv_vu = dv_mps2vu(dv_mps, p)
% DV_MPS2VU Convert delta-v from m/s to velocity units
%
% Inputs:
%   dv_mps - delta-v in m/s
%   p      - params struct (from const.params)
%
% Output:
%   dv_vu - delta-v in normalized velocity units (VU)

    dv_vu = dv_mps / (p.VU * 1000);
end
