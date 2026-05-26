function t_tu = time_day2tu(t_day, p)
% TIME_DAY2TU Convert time from days to TU
%
% Inputs:
%   t_day - time in days
%   p     - params struct (from const.params)
%
% Output:
%   t_tu - time in TU

    t_tu = t_day / p.TU_day;
end
