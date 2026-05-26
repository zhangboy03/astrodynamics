function [feasible, violations] = check_constraints(trajectory, events, p)
% CHECK_CONSTRAINTS Check all mission constraints (with uniform resampling)
%
% Inputs:
%   trajectory - struct with fields:
%       .t, .X, .t_dep, .t_arr, .t_leave, .t_ret, .M_fuel_final
%       .segments: cell array of {t, X, phase} for each segment
%       .checkpoints (optional): struct array with fields:
%           .name, .t, .X_actual (1x4 or 4x1), .X_target (1x4 or 4x1),
%           .tol_pos (default 1e-6), .tol_vel (default 1e-6)
%   events   - (unused unless you want) can hold checkpoint info too
%   p        - params struct
%
% Outputs:
%   feasible, violations

violations = {};
mu = p.mu;

%% (a) Total mission time <= 100 days
total_time_days = (trajectory.t_ret - trajectory.t_dep) * p.TU_day;
if total_time_days > 100
    violations{end+1} = sprintf('Total time %.2f days > 100 days', total_time_days);
end

%% (b) Moon stay time 3-10 days
stay_days = (trajectory.t_leave - trajectory.t_arr) * p.TU_day;
if stay_days < 3 || stay_days > 10
    violations{end+1} = sprintf('Moon stay %.2f days not in [3,10]', stay_days);
end

%% (c) Return perigee = 0 km
% Typically enforced by event/shooting. If you want, add a checkpoint for it.

%% (d) Path constraints with uniform resampling
% Use a sampling step in TU. 0.01 TU is ~ (0.01 * TU_day) days.
dt_sample = 0.01;

if isfield(trajectory, 'segments')
    for s = 1:numel(trajectory.segments)
        seg = trajectory.segments{s};
        t_seg = seg{1}(:);
        X_seg = seg{2};
        phase = seg{3}; %#ok<NASGU>
        
        if numel(t_seg) < 2 || size(X_seg,1) < 2
            continue;
        end
        
        t0 = t_seg(1);
        tf = t_seg(end);
        
        % Build uniform time grid; ensure tf included
        tq = (t0:dt_sample:tf)';
        if tq(end) < tf
            tq = [tq; tf];
        end
        
        % Resample state (use shape-preserving cubic; switch to 'linear' if needed)
        Xq = zeros(numel(tq), 4);
        for j = 1:4
            Xq(:,j) = interp1(t_seg, X_seg(:,j), tq, 'pchip');
        end
        
        % Check constraints at resampled points
        for k = 1:size(Xq, 1)
            x = Xq(k,1); y = Xq(k,2);
            r1 = sqrt((x + mu)^2 + y^2);         % Earth distance in LU
            r2 = sqrt((x - 1 + mu)^2 + y^2);     % Moon distance in LU
            
            r1_km = r1 * p.LU;
            r2_km = r2 * p.LU;
            
            dist = sqrt(x^2 + y^2); % distance from barycenter in LU
            
            % Moon altitude >= 100 km (always)
            alt_moon = r2_km - p.R_m;
            if alt_moon < 100
                violations{end+1} = sprintf('Moon altitude %.2f km < 100 km at t=%.6f TU', ...
                    alt_moon, tq(k));
                break;
            end
            
            % Earth altitude >= 400 km BEFORE return-entry burn time
            % trajectory.t_return_entry must be set to the time you start the Earth-return descent
            if isfield(trajectory, 't_return_entry')
                t_gate = trajectory.t_return_entry;
            else
                % fallback: use t_ret (legacy), but this is overly strict
                t_gate = trajectory.t_ret;
            end
            
            alt_earth = r1_km - p.R_e;
            if tq(k) < t_gate && alt_earth < 400
                violations{end+1} = sprintf('Earth altitude %.2f km < 400 km at t=%.6f TU (pre-return-entry)', ...
                    alt_earth, tq(k));
                break;
            end
            
            % Distance constraint: within 2 LU from barycenter
            if dist > 2
                violations{end+1} = sprintf('Distance %.6f LU > 2 LU at t=%.6f TU', ...
                    dist, tq(k));
                break;
            end
        end
    end
end

%% (e) Return fuel <= 100 kg
if trajectory.M_fuel_final > 100
    violations{end+1} = sprintf('Return fuel %.2f kg > 100 kg', trajectory.M_fuel_final);
end

%% (f) Checkpoint matching constraints (dock/patch points)
if isfield(trajectory, 'checkpoints') && ~isempty(trajectory.checkpoints)
    cps = trajectory.checkpoints;
    for i = 1:numel(cps)
        cp = cps(i);
        
        Xa = cp.X_actual(:);
        Xt = cp.X_target(:);
        
        tol_pos = 1e-6; tol_vel = 1e-6;
        if isfield(cp, 'tol_pos'), tol_pos = cp.tol_pos; end
        if isfield(cp, 'tol_vel'), tol_vel = cp.tol_vel; end
        
        epos = norm(Xa(1:2) - Xt(1:2));
        evel = norm(Xa(3:4) - Xt(3:4));
        
        if epos > tol_pos || evel > tol_vel
            violations{end+1} = sprintf('Checkpoint %s mismatch: pos=%.3e (tol %.1e), vel=%.3e (tol %.1e)', ...
                cp.name, epos, tol_pos, evel, tol_vel);
        end
    end
end

feasible = isempty(violations);
end