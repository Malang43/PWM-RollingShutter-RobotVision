function filename = repository_input(paths,relativePath)
% Prefer a regenerated file; otherwise read the original saved repository input.
generated = fullfile(paths.outputRoot,relativePath);
saved = fullfile(paths.resultsRoot,relativePath);
if isfile(generated)
    filename = generated;
elseif isfile(saved)
    filename = saved;
elseif strcmp(relativePath,'raw_correspondences/xyz/experiment18I_LightGlue_PWM_matches.csv') ...
        && ~isempty(paths.xyzPWMMatches)
    filename = paths.xyzPWMMatches;
elseif strcmp(relativePath,'raw_correspondences/desk/fr1_desk_LightGlue_PWM_matches.csv') ...
        && ~isempty(paths.deskPWMMatches)
    filename = paths.deskPWMMatches;
else
    filename = saved; % Existing script assertions report missing input.
end
end
