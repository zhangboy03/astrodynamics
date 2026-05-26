function t_day = time_tu2day(t_tu, p)
% TIME_TU2DAY Convert time from TU to days
%
% Inputs:
%   t_tu - time in TU
%   p    - params struct (from const.params)
%
% Output:
%   t_day - time in days

    t_day = t_tu * p.TU_day;
end
