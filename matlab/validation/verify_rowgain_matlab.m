clc;
clear;

% Repository copy: path handling only; original provenance in MANIFEST.md.
addpath(fileparts(fileparts(mfilename('fullpath'))));
repoPaths = repository_paths('');


H = 480;
Ns = 100;

freqHz = 100;
exposure_s = 0.001;
duty = 0.25;
modDepth = 0.90;

phases = [0, 0.125, 0.25, 0.5, 0.875];
readouts_ms = [5, 10, 15, 20, 25, 30];

rows = [];

for ir = 1:numel(readouts_ms)

    readout_s = readouts_ms(ir) / 1000;
    rowTime = readout_s / H;

    for ip = 1:numel(phases)

        phaseOffset = phases(ip);

        gain1 = zeros(H,1);
        gain2 = zeros(H,1);

        for r = 0:H-1

            exposureOffsets = linspace(0, exposure_s, Ns);

            t1 = r*rowTime + exposureOffsets;
            phi1 = mod(freqHz*t1, 1);

            led1 = phi1 < duty;

            intensity1 = ...
                (1-modDepth) + ...
                modDepth*double(led1);

            gain1(r+1) = mean(intensity1);

            t2 = r*rowTime + exposureOffsets;
            phi2 = mod(freqHz*t2 + phaseOffset, 1);

            led2 = phi2 < duty;

            intensity2 = ...
                (1-modDepth) + ...
                modDepth*double(led2);

            gain2(r+1) = mean(intensity2);

        end

        for r = 1:H

            rows = [rows; ...
                readouts_ms(ir), ...
                phaseOffset, ...
                r-1, ...
                gain1(r), ...
                gain2(r)];

        end

    end
end

T = array2table(rows, ...
    'VariableNames', ...
    {'ReadoutMs','Phase','RowIndex','GainFrame1','GainFrame2'});

writetable(T, ...
    repository_output(repoPaths,'verification/rowgain_matlab.csv'));

fprintf('\nSaved:\n');
fprintf('%s\n',fullfile(repoPaths.outputRoot,'verification','rowgain_matlab.csv'));
fprintf('Rows = %d\n',height(T));