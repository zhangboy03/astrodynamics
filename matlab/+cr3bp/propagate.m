function [t_out, X_out, te, Xe, ie] = propagate(X0, t_span, mu, options_in)
% PROPAGATE High-accuracy CR3BP integration
%
% Inputs:
%   X0      - initial state [4x1] or [20x1] for STM mode
%   t_span  - scalar (final time) or vector [t0, tf] or full time vector
%   mu      - mass parameter
%   options_in - (optional) odeset options (can include events)
%
% Outputs:
%   t_out - time vector
%   X_out - state matrix [N x dim]
%   te    - event times
%   Xe    - event states
%   ie    - event indices

if nargin < 4
    options_in = [];
end

% Determine if STM mode
dim = length(X0);
if dim == 20
    odefun = @(t, Y) cr3bp.eom_stm(t, Y, mu);
else
    odefun = @(t, Y) cr3bp.eom(t, Y, mu);
end

% Set default high-accuracy options
default_opts = odeset('RelTol', 1e-10, 'AbsTol', 1e-10, ...
    'MaxStep', 0.02);

if ~isempty(options_in)
    opts = odeset(default_opts, options_in);
else
    opts = default_opts;
end

% Handle t_span
if isscalar(t_span)
    t_span_vec = [0, t_span];
else
    t_span_vec = t_span;
end

% Integrate
te = []; Xe = []; ie = [];
if ~isempty(opts.Events)
    [t_out, X_out, te, Xe, ie] = ode113(odefun, t_span_vec, X0, opts);
else
    [t_out, X_out] = ode113(odefun, t_span_vec, X0, opts);
end
end
