clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('xyz');


% ------------------------------------------------------------
% INPUT IMAGE
% ------------------------------------------------------------
rgbDir = fullfile(repoPaths.tumXYZ,'rgb');

files = dir(fullfile(rgbDir,'*.png'));

% Sort by filename
[~,idx] = sort({files.name});
files = files(idx);

imgPath = fullfile(rgbDir,files(100).name);

img = imread(imgPath);

% ------------------------------------------------------------
% MATCHED PWM SETTINGS
% ------------------------------------------------------------
H = size(img,1);
Ns = 100;

freqHz = 100;
exposure_s = 0.001;
duty = 0.25;
modDepth = 0.90;

phaseOffset = 0.25;
readout_ms = 20;

readout_s = readout_ms/1000;
rowTime = readout_s/H;

rowGain = zeros(H,1);

for r = 0:H-1

    exposureOffsets = linspace(0,exposure_s,Ns);

    t = r*rowTime + exposureOffsets;

    phi = mod(freqHz*t + phaseOffset,1);

    ledOn = phi < duty;

    instantaneousGain = ...
        (1-modDepth) + ...
        modDepth*double(ledOn);

    rowGain(r+1) = mean(instantaneousGain);

end

% ------------------------------------------------------------
% APPLY GAIN
% ------------------------------------------------------------
imgDouble = double(img);

perturbed = ...
    imgDouble .* reshape(rowGain,[H 1 1]);

% Match Python behavior:
% round -> clip -> uint8
perturbed = round(perturbed);
perturbed = min(max(perturbed,0),255);
perturbed = uint8(perturbed);

% ------------------------------------------------------------
% SAVE
% ------------------------------------------------------------
outFile = repository_output(repoPaths,'verification/perturbed_matlab.png');

imwrite(perturbed,outFile);

writematrix(rowGain, ...
    repository_output(repoPaths,'verification/rowgain_single_matlab.csv'));

fprintf('Saved:\n%s\n',outFile);
fprintf('Image size: %d x %d x %d\n',size(perturbed));