function tutorial_neuromag_malaysia(tutorial_dir,ID,name,condition)
% TUTORIAL_NEUROMAG: Script that reproduces the results of the online tutorials "MEG median nerve (Elekta)"
%
% CORRESPONDING ONLINE TUTORIALS:
%     https://neuroimage.usc.edu/brainstorm/Tutorials/TutMindNeuromag
%
% INPUTS: 
%     tutorial_dir: Directory where the sample_neuromag.zip file has been unzipped

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Author: Francois Tadel, 2010-2016
%% Modified from above for global/local object presentation

% ===== FILES TO IMPORT =====
% You have to specify the folder in which the tutorial dataset is unzipped
if (nargin == 0) || isempty(tutorial_dir) || ~file_exist(tutorial_dir)
    error('The first argument must be the full path to the tutorial dataset folder.');
end
% Build the path of the files to import
AnatDir = fullfile(tutorial_dir, 'T1w');
RawFile = fullfile(tutorial_dir, [ID,'_spm'], [name,'_',condition,'_tsss.fif']);
% Check if the folder contains the required files
if ~file_exist(RawFile)
    error(['The folder ' tutorial_dir ' does not contain the folder from the file sample_neuromag.zip.']);
end

% ===== CREATE PROTOCOL =====
% The protocol name has to be a valid folder name (no spaces, no weird characters...)
ProtocolName = 'MalaysiaNeuromag';
% Start brainstorm without the GUI
% if ~brainstorm('status')
%     brainstorm nogui
% end
% Delete existing protocol
gui_brainstorm('DeleteProtocol', ProtocolName);
% Create new protocol
gui_brainstorm('CreateProtocol', ProtocolName, 0, 0);
% Start a new report
bst_report('Start');

% ===== ANATOMY =====
% Subject name
SubjectName = name;
% Process: Import MRI
sFilesRaw = bst_process('CallProcess', 'process_import_mri', [], [], ...
    'subjectname', SubjectName, ...
    'mrifile',     {fullfile(AnatDir,'T1w.nii.gz'), 'ALL-MNI'});

% Process: Generate head surface
bst_process('CallProcess', 'process_generate_head', [], [], ...
    'subjectname', SubjectName, ...
    'nvertices',   10000, ...
    'erodefactor', 3, ...
    'fillfactor',  2);

% Process: Import surfaces
sFilesRaw = bst_process('CallProcess', 'process_import_surfaces', sFilesRaw, [], ...
    'subjectname', SubjectName, ...
    'cortexfile1', {fullfile(AnatDir,'Native','Freesurfer_TestColin27.L.midthickness.native.surf.gii'), 'GII-MNI'}, ...
    'cortexfile2', {fullfile(AnatDir,'Native','Freesurfer_TestColin27.R.midthickness.native.surf.gii'), 'GII-MNI'}, ...
    'nvertcortex', 8000);

SurfFile  = fullfile(bst_get('BrainstormDbDir'),ProtocolName,'anat',SubjectName,'tess_cortex_concat.mat');
LabelFile = {fullfile(AnatDir,'aparc+aseg.nii.gz'),'MRI-MASK-MNI'};
script_import_label(SurfFile,LabelFile);

% ===== LINK CONTINUOUS FILE =====
% Process: Create link to raw file
sFilesRaw = bst_process('CallProcess', 'process_import_data_raw', sFilesRaw, [], ...
    'subjectname',    SubjectName, ...
    'datafile',       {RawFile, 'FIF'}, ...
    'channelreplace', 1, ...
    'channelalign',   0);

% Process: Remove head points
sFilesRaw = bst_process('CallProcess', 'process_headpoints_remove', sFilesRaw, [], ...
    'zlimit', 0);

% Process: Refine registration
sFilesRaw = bst_process('CallProcess', 'process_headpoints_refine', sFilesRaw, []);

% Process: Snapshot: Sensors/MRI registration
bst_process('CallProcess', 'process_snapshot', sFilesRaw, [], ...
    'target',   1, ...  % Sensors/MRI registration
    'modality', 1, ...  % MEG (All)
    'orient',   1, ...  % left
    'comment',  'MEG/MRI Registration');

% Process: Events: Read from channel
sFilesRaw = bst_process('CallProcess', 'process_evt_read', sFilesRaw, [], ...
    'stimchan',  'STI101', ...
    'trackmode', 1, ...  % Value: detect the changes of channel value
    'zero',      0);

% ===== REMOVE 50/100/150/200/250/300/350/400/450/500 Hz =====
% Process: Apply SSP & CTF compensation
sFilesClean = bst_process('CallProcess', 'process_ssp_apply', sFilesRaw, []);

% Process: Notch filter: 60Hz 120Hz 180Hz
sFilesClean = bst_process('CallProcess', 'process_notch', sFilesClean, [], ...
    'freqlist',    [50 100 150 200 250 300 350 400 450 500], ...
    'sensortypes', 'MEG, EEG', ...
    'read_all',    0);

% Process: Power spectrum density (Welch)
sFilesPsd = bst_process('CallProcess', 'process_psd', [sFilesRaw, sFilesClean], [], ...
    'timewindow',  [], ...
    'win_length',  4, ...
    'win_overlap', 50, ...
    'clusters',    {}, ...
    'sensortypes', 'MEG', ...
    'edit', struct(...
         'Comment',         'Power', ...
         'TimeBands',       [], ...
         'Freqs',           [], ...
         'ClusterFuncTime', 'none', ...
         'Measure',         'power', ...
         'Output',          'all', ...
         'SaveKernel',      0));

% Process: Snapshot: Frequency spectrum
bst_process('CallProcess', 'process_snapshot', sFilesPsd, [], ...
    'target',   10, ...  % Frequency spectrum
    'modality', 1, ...   % MEG (All)
    'comment',  'Power spectrum density');


% ===== CORRECT BLINKS AND HEARTBEATS =====
% Process: Detect heartbeats
sFilesClean = bst_process('CallProcess', 'process_evt_detect_ecg', sFilesClean, [], ...
    'channelname', 'EOG063', ...
    'timewindow',  [], ...
    'eventname',   'cardiac');

% Process: Detect eye blinks
sFilesClean = bst_process('CallProcess', 'process_evt_detect_eog', sFilesClean, [], ...
    'channelname', 'EOG062', ...
    'timewindow',  [], ...
    'eventname',   'blink');

% Process: Remove simultaneous
sFilesClean = bst_process('CallProcess', 'process_evt_remove_simult', sFilesClean, [], ...
    'remove', 'cardiac', ...
    'target', 'blink', ...
    'dt',     0.25, ...
    'rename', 0);

% Process: SSP ECG: cardiac (MAG and GRAD)
sFilesClean = bst_process('CallProcess', 'process_ssp_ecg', sFilesClean, [], ...
    'eventname',   'cardiac', ...
    'sensortypes', 'MEG MAG', ...
    'usessp',       1, ...
    'select',       1);   % Force selection of some components
sFilesClean = bst_process('CallProcess', 'process_ssp_ecg', sFilesClean, [], ...
    'eventname',   'cardiac', ...
    'sensortypes', 'MEG GRAD', ...
    'usessp',       1, ...
    'select',       1);   % Force selection of some components

% Process: SSP EOG: blink (MAG and GRAD)
sFilesClean = bst_process('CallProcess', 'process_ssp_eog', sFilesClean, [], ...
    'eventname',   'blink', ...
    'sensortypes', 'MEG MAG', ...
    'usessp',       1, ...
    'select',       1);   % Force selection of some components
sFilesClean = bst_process('CallProcess', 'process_ssp_eog', sFilesClean, [], ...
    'eventname',   'blink', ...
    'sensortypes', 'MEG GRAD', ...
    'usessp',       1, ...
    'select',       1);   % Force selection of some components

% Process: Snapshot: SSP projectors
bst_process('CallProcess', 'process_snapshot', sFilesClean, [], ...
    'target',  2, ...  % SSP projectors
    'comment', 'SSP projectors');


% ===== IMPORT EVENTS =====
% Process: Import MEG/EEG: Events
sFilesEpochs = bst_process('CallProcess', 'process_import_data_event', sFilesClean, [], ...
    'subjectname', SubjectName, ...
    'condition',   '', ...
    'eventname',   '1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15', ...
    'timewindow',  [], ...
    'epochtime',   [-0.1, 0.3], ...
    'createcond',  1, ...
    'ignoreshort', 1, ...
    'usectfcomp',  1, ...
    'usessp',      1, ...
    'freq',        [], ...
    'baseline',    []);

% Process: Average: By condition (subject average)
sFilesAvg = bst_process('CallProcess', 'process_average', sFilesEpochs, [], ...
    'avgtype',    6, ...  % By trial groups (subject average)
    'avg_func',   1, ...  % Arithmetic average: mean(x)
    'keepevents', 0);

% % Process: Cut stimulation artifact: [0ms,4ms]
% sFilesAvg = bst_process('CallProcess', 'process_cutstim', sFilesAvg, [], ...
%     'timewindow',  [0, 0.0039], ...
%     'sensortypes', 'MEG, EEG', ...
%     'overwrite',   1);

% Process: Snapshot: Recordings time series
bst_process('CallProcess', 'process_snapshot', sFilesAvg, [], ...
    'target',   5, ...  % Recordings time series
    'modality', 1, ...  % MEG (All)
    'comment',  'Evoked response');


% ===== SOURCE MODELING =====
% Process: Generate BEM surfaces
bst_process('CallProcess', 'process_generate_bem', [], [], ...
    'subjectname', SubjectName, ...
    'nscalp',      1922, ...
    'nouter',      1922, ...
    'ninner',      1922, ...
    'thickness',   4);

% Process: Compute head model
bst_process('CallProcess', 'process_headmodel', sFilesAvg, [], ...
    'Comment',     '', ...
    'sourcespace', 1, ...  % Cortex surface
    'volumegrid',  struct(...
         'Method',        'adaptive', ...
         'nLayers',       17, ...
         'Reduction',     3, ...
         'nVerticesInit', 4000, ...
         'Resolution',    0.005, ...
         'FileName',      []), ...
    'meg',         4, ...  % OpenMEEG BEM
    'eeg',         1, ...  % 
    'ecog',        1, ...  % 
    'seeg',        1, ...  % 
    'openmeeg',    struct(...
         'BemSelect',    [1, 1, 1], ...
         'BemCond',      [1, 0.0125, 1], ...
         'BemNames',     {{'Scalp', 'Skull', 'Brain'}}, ...
         'BemFiles',     {{}}, ...
         'isAdjoint',    0, ...
         'isAdaptative', 1, ...
         'isSplit',      0, ...
         'SplitLength',  4000));

% Save and display report
ReportFile = bst_report('Save', sFilesAvg);
bst_report('Open', ReportFile);


