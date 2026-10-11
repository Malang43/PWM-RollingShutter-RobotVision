clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('');


matlabFile = repository_input(repoPaths,'verification/rowgain_matlab.csv');

pythonFile = repository_input(repoPaths,'verification/rowgain_python.csv');

A = readtable(matlabFile);
B = readtable(pythonFile);

assert(height(A) == height(B), ...
    'Different number of rows.');

assert(all(A.ReadoutMs == B.ReadoutMs), ...
    'Readout order differs.');

assert(all(abs(A.Phase - B.Phase) < 1e-12), ...
    'Phase order differs.');

assert(all(A.RowIndex == B.Row), ...
    'Row order differs.');

d1 = abs( ...
    A.GainFrame1 - ...
    B.GainFrame1);

d2 = abs( ...
    A.GainFrame2 - ...
    B.GainFrame2);

fprintf('\n');
fprintf('MATLAB vs PYTHON ROW-GAIN CHECK\n');
fprintf('================================\n');

fprintf( ...
    'Frame 1 mean abs difference = %.15g\n', ...
    mean(d1));

fprintf( ...
    'Frame 1 max abs difference  = %.15g\n', ...
    max(d1));

fprintf( ...
    'Frame 2 mean abs difference = %.15g\n', ...
    mean(d2));

fprintf( ...
    'Frame 2 max abs difference  = %.15g\n', ...
    max(d2));

fprintf('\n');

fprintf( ...
    'Frame 1 rows > 1e-12 = %d / %d\n', ...
    sum(d1 > 1e-12), ...
    numel(d1));

fprintf( ...
    'Frame 2 rows > 1e-12 = %d / %d\n', ...
    sum(d2 > 1e-12), ...
    numel(d2));

fprintf('\n');

if max([d1; d2]) < 1e-12

    fprintf( ...
        'RESULT: MATLAB and Python row-gain profiles are numerically equivalent.\n');

else

    fprintf( ...
        'RESULT: Differences exist. We need to inspect them.\n');

end