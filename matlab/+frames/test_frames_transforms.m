function test_frames_transforms()
%TEST_FRAMES_TRANSFORMS
% Zero-cost sanity checks for synodic <-> inertial transforms.
%
% Place this file under: matlab/+frames/test_frames_transforms.m
% (i.e., inside the +frames package folder)
%
% Run from matlab/ directory:
%   frames.test_frames_transforms
%
% Tests:
%  1) Inverse consistency:
%     inertial2synodic(synodic2inertial(XS,t),t) == XS
%  2) Primary-body fixed-point in synodic frame:
%     Earth and Moon are stationary at [-mu,0] and [1-mu,0] with zero velocity.

fprintf('=== frames.test_frames_transforms ===\n');

p = const.params();
mu = p.mu;

tol = 1e-12;
rng(42); % deterministic

%% Test 1: inverse consistency (roundtrip)
fprintf('Test 1: inverse consistency roundtrip... ');

N = 200; % number of random samples
max_err = 0;

for k = 1:N
    % Random time (nondim); not too huge to avoid trig loss of precision
    t = (2*pi) * (10*rand()); % up to 10 revolutions
    
    % Random synodic state (keep magnitudes moderate)
    x  = -0.5 + 1.5*rand();   % roughly within [-0.5, 1.0]
    y  = -0.5 + 1.0*rand();   % roughly within [-0.5, 0.5]
    vx = -1.0 + 2.0*rand();
    vy = -1.0 + 2.0*rand();
    XS = [x; y; vx; vy];
    
    XI = frames.synodic2inertial(XS, t);
    XS2 = frames.inertial2synodic(XI, t);
    
    err = max(abs(XS2(:) - XS(:)));
    if err > max_err
        max_err = err;
    end
end

if max_err < tol
    fprintf('PASSED (max err = %.3e)\n', max_err);
else
    fprintf('FAILED (max err = %.3e, tol = %.1e)\n', max_err, tol);
    error('Inverse consistency test failed.');
end

%% Test 2: primary bodies stationary in synodic frame
fprintf('Test 2: primary bodies stationary in synodic... ');

% Earth and Moon fixed points in synodic frame
XE_syn = [-mu; 0; 0; 0];
XM_syn = [1-mu; 0; 0; 0];

% Check multiple times
times = linspace(0, 20*pi, 41); % many revolutions
max_err_E = 0;
max_err_M = 0;

for t = times
    % Earth
    XE_I = frames.synodic2inertial(XE_syn, t);
    XE_back = frames.inertial2synodic(XE_I, t);
    errE = max(abs(XE_back(:) - XE_syn(:)));
    if errE > max_err_E
        max_err_E = errE;
    end
    
    % Moon
    XM_I = frames.synodic2inertial(XM_syn, t);
    XM_back = frames.inertial2synodic(XM_I, t);
    errM = max(abs(XM_back(:) - XM_syn(:)));
    if errM > max_err_M
        max_err_M = errM;
    end
end

max_err = max(max_err_E, max_err_M);

if max_err < tol
    fprintf('PASSED (Earth max err = %.3e, Moon max err = %.3e)\n', max_err_E, max_err_M);
else
    fprintf('FAILED (Earth max err = %.3e, Moon max err = %.3e, tol = %.1e)\n', max_err_E, max_err_M, tol);
    error('Primary-body fixed-point test failed.');
end

fprintf('All frame transform tests PASSED.\n');
end