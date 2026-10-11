function paths = setup_paths_example()
% Repository configuration example. Edit dataset placeholders or copy the
% assignments into an ignored matlab/setup_paths.m script.
% These are repository paths only; no scientific parameters are set here.
paths.repoRoot = fileparts(fileparts(mfilename('fullpath')));
paths.tumXYZ = '';  % Set the extracted TUM fr1/xyz root, outside the repository.
paths.tumDesk = ''; % Set the extracted TUM fr1/desk root, outside the repository.
paths.resultsRoot = fullfile(paths.repoRoot,'results'); % Saved repository inputs.
paths.outputRoot = fullfile(paths.repoRoot,'reproduction_work','results');
paths.figuresRoot = fullfile(paths.repoRoot,'figures');
paths.xyzPWMMatches = '';  % External experiment18I_LightGlue_PWM_matches.csv.
paths.deskPWMMatches = ''; % External fr1_desk_LightGlue_PWM_matches.csv.
end
