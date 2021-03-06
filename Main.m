%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%         Brainstorm Protocol for Automatic Head Model
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% Scripted leadfield pipeline for Freesurfer anatomy files
% Brainstorm (25-Sep-2019) or higher
%


% Authors
% - Ariosky Areces Gonzalez
% - Deirel Paz Linares
%
%    November 15, 2019


%% Preparing WorkSpace
clc;
close all;
clear all;
disp('-->> Starting process');
restoredefaultpath;

%%
%------------ Preparing properties --------------------
% brainstorm('stop');
addpath(fullfile('app'));
addpath('bst_templates');
addpath(fullfile('config_labels'));
addpath(fullfile('config_MaQC'));
addpath(fullfile('config_protocols'));
addpath(fullfile('config_StP_prop'));
addpath(fullfile('external'));
addpath(genpath(fullfile('functions')));
addpath('guide');
addpath(genpath('plugins'));
addpath(fullfile('templates'));
addpath(fullfile('tools'));

try
    app_properties = jsondecode(fileread(fullfile('app','properties.json')));
catch EM
    fprintf(2,"\n ->> Error: The app/properties file do not have a correct format \n");
    disp("-->> Message error");
    disp(EM.message);
    disp('-->> Process stoped!!!');
    return;
end

%% Printing data information
disp(strcat("-->> Name:",app_properties.generals.name));
disp(strcat("-->> Version:",app_properties.generals.version));
disp(strcat("-->> Version date:",app_properties.generals.version_date));
disp("=================================================================");

%% ------------ Checking MatLab compatibility ----------------
disp('-->> Checking installed matlab version');
if(~check_matlab_version())
    return;
end
%% ------------  Checking updates --------------------------
disp('-->> Checking project laster version');
if(isequal(check_version,'updated'))
    return;
end
%% ------------  Checking app properties --------------------------
properties  = get_properties();
if(isequal(properties,'canceled'))
    return;
end
status      = check_properties(properties);
if(~status)
    fprintf(2,strcat('\nBC-V-->> Error: The current configuration files are wrong \n'));
    disp('Please check the configuration files.');
    return;
end

properties.general_params       = properties.general_params.params;
properties.anatomy_params       = properties.anatomy_params.params;
properties.channel_params       = properties.channel_params.params;
properties.prep_data_params     = properties.prep_data_params.params;
properties.qc_params            = properties.qc_params.params;

if(isfile(properties.general_params.colormap))
    load(properties.general_params.colormap);
else
    load('tools/mycolormap.mat');
end
%%
disp('-->> Preparing BrainStorm properties.');
bst_path        =  properties.general_params.bst_config.bst_path;
bst_db_path     = properties.general_params.bst_database.db_path;
spm_path        = properties.general_params.spm_config.spm_path;
addpath(genpath(bst_path));
addpath(spm_path);

%---------------- Starting BrainStorm-----------------------

brainstorm reset
brainstorm nogui local

disp("-->> Installing external plugins.");
bst_plugin('SetCustomPath','spm', spm_path);
if(isempty(bst_plugin('GetInstalled', 'openmeeg')))
    [isOk, errMsg, PlugDesc] = bst_plugin('Install', 'openmeeg', 0, []);
    if(isOk)
        [isOk, errMsg, PlugDesc] = bst_plugin('Load', 'openmeeg');
    else
        fprintf(2,"\n ->> Error: We can not install tha openmeeg plugin. Please see the fallow error and restart the process. \n");
        disp("-->> Message error");
        disp(errMsg);
        disp('-->> Process stoped!!!');
        return;
    end
end
if(isempty(bst_plugin('GetInstalled', 'mff')))
    [isOk, errMsg, PlugDesc] = bst_plugin('Install', 'mff', 0, []);
    if(isOk)
        [isOk, errMsg, PlugDesc] = bst_plugin('Load', 'mff');
    else
        fprintf(2,"\n ->> Error: We can not install tha mff plugin. Please see the fallow error and restart the process. \n");
        disp("-->> Message error");
        disp(errMsg);
        disp('-->> Process stoped!!!');
        return;
    end
end

if(~isequal(bst_db_path,'local'))
    bst_set('BrainstormDbDir', app_properties.bst_db_path);
end

if(properties.prep_data_params.clean_data.run)
    toolbox = properties.prep_data_params.clean_data.toolbox;
    switch toolbox
        case 'eeglab'
            if(isfile(fullfile(properties.prep_data_params.clean_data.toolbox_path,'eeglab.m')))
                toolbox_path    = properties.prep_data_params.clean_data.toolbox_path;
                addpath(toolbox_path);
                eeglab nogui;
            else
                fprintf(2,'\n ->> Error: The eeglab path is wrong.');
            end
    end
else
end

%% Process selected dataset and compute the leadfield subjects
%%
%% Calling dataset function to analysis
%%
process_error = headmodel_process_interface(properties);

%% Stoping BrainStorm
disp("=================================================================");
brainstorm('stop');
close all;
clear all;




