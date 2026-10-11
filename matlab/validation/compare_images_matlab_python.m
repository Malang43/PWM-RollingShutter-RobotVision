clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('');


A = imread( ...
    repository_input(repoPaths,'verification/perturbed_matlab.png'));

B = imread( ...
    repository_input(repoPaths,'verification/perturbed_python.png'));

assert(isequal(size(A),size(B)), ...
    'Image sizes differ.');

D = abs(double(A)-double(B));

fprintf('\n');
fprintf('MATLAB vs PYTHON PIXEL CHECK\n');
fprintf('============================\n');

fprintf('Mean absolute pixel difference = %.12g\n', ...
    mean(D(:)));

fprintf('Maximum pixel difference = %.12g\n', ...
    max(D(:)));

fprintf('Pixels with any difference = %d / %d\n', ...
    sum(D(:) > 0), ...
    numel(D));

fprintf('Pixels with difference > 1 = %d / %d\n', ...
    sum(D(:) > 1), ...
    numel(D));

if max(D(:)) == 0

    fprintf('\nRESULT: PIXEL-IDENTICAL IMAGES.\n');

else

    fprintf('\nRESULT: SMALL PIXEL DIFFERENCES EXIST.\n');

end