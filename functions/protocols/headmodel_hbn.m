function [processed] = headmodel_hbn()
% TUTORIAL_PHILIPS_MFF: Script that reproduces the results of the online tutorials "Yokogawa recordings".
%
%
% @=============================================================================
%
% Authors:
% - Ariosky Areces Gonzalez
% - Deirel Paz Linares


%%
%% Preparing selected protocol
%%
app_properties = jsondecode(fileread(strcat('app',filesep,'properties.json')));
selected_dataset = jsondecode(fileread(strcat('config_protocols',filesep,app_properties.selected_data_set.file_name)));
modality = selected_dataset.modality;

% Copying the new file channel
colin_channel_path              = fullfile(app_properties.bst_path,'defaults','eeg','Colin27');
channel_GSN_129                 = strcat('templates',filesep,'channel_GSN_129.mat');
channel_GSN_HydroCel_129_E001   = strcat('templates',filesep,'channel_GSN_HydroCel_129_E001.mat');
copyfile( channel_GSN_129 , colin_channel_path);
copyfile( channel_GSN_HydroCel_129_E001, colin_channel_path);

disp(strcat('-->> Data Source:  ', selected_dataset.hcp_data_path.base_path ));
ProtocolName = selected_dataset.protocol_name;
[base_path,name,ext] = fileparts(selected_dataset.hcp_data_path.base_path);
subjects = dir(base_path);
subjects(ismember( {subjects.name}, {'.', '..'})) = [];  %remove . and ..
subjects_process_error = [];
subjects_processed =[];
Protocol_count = 0;
for j=1:length(subjects)
    subject_name = subjects(j).name;
    subID = subject_name;
    if(~isequal(selected_dataset.sub_prefix,'none') && ~isempty(selected_dataset.sub_prefix))
        subID = strrep(subject_name,selected_dataset.sub_prefix,'');
    end
    disp(strcat('-->> Processing subject: ', subID));
    
    %%
    %% Preparing Subject files
    %%
    [subject_environment, files_checked] = get_subject_files(selected_dataset,subID,'hbn',ProtocolName);
    if(~files_checked)
        continue;
    end
    T1w_file            = subject_environment.T1w_file;
    L_surface_file      = subject_environment.L_surface_file;
    R_surface_file      = subject_environment.R_surface_file;
    Atlas_seg_location  = subject_environment.Atlas_seg_location;
    head_file           = subject_environment.head_file;
    outerskull_file     = subject_environment.outerskull_file;
    innerskull_file     = subject_environment.innerskull_file;
    raw_data            = subject_environment.raw_data;
    subject_report_path = subject_environment.subject_report_path;
    report_name         = subject_environment.report_name;
    
    %%
    %%  Checking protocol
    %%
    if( mod(Protocol_count,selected_dataset.protocol_subjet_count) == 0  )
        ProtocolName_R = strcat(ProtocolName,'_',char(num2str(Protocol_count)));
        
        if(selected_dataset.protocol_reset)
            gui_brainstorm('DeleteProtocol',ProtocolName_R);
            bst_db_path = bst_get('BrainstormDbDir');
            if(isfolder(fullfile(bst_db_path,ProtocolName_R)))
                protocol_folder = fullfile(bst_db_path,ProtocolName_R);
                rmdir(protocol_folder, 's');
            end
            gui_brainstorm('CreateProtocol',ProtocolName_R ,selected_dataset.use_default_anatomy, selected_dataset.use_default_channel);
        else
            %                 gui_brainstorm('UpdateProtocolsList');
            iProtocol = bst_get('Protocol', ProtocolName_R);
            gui_brainstorm('SetCurrentProtocol', iProtocol);
            subjects = bst_get('ProtocolSubjects');
            if(j <= length(subjects.Subject))
                db_delete_subjects( j );
            end
        end
    end
    
    try
        %%
        %% Creating subject in Protocol
        %%
        db_add_subject(subID);
        
        %%
        %% Start a new report
        %%
        bst_report('Start',['Protocol for subject:' , subID]);
        bst_report('Info',    '', [], ['Protocol for subject:' , subID])
        
        %%
        %% ===== IMPORT ANATOMY =====
        %%
        % Process: Import MRI
        sFiles = bst_process('CallProcess', 'process_import_mri', [], [], ...
            'subjectname', subID, ...
            'mrifile',     {T1w_file, 'ALL-MNI'});
        
        %%
        %% Quality control
        %%
        % Get subject definition
        sSubject = bst_get('Subject', subID);
        % Get MRI file and surface files
        MriFile    = sSubject.Anatomy(sSubject.iAnatomy).FileName;
        hFigMri1 = view_mri_slices(MriFile, 'x', 20);
        bst_report('Snapshot',hFigMri1,MriFile,'MRI Axial view', [200,200,750,475]);
        saveas( hFigMri1,fullfile(subject_report_path,'MRI Axial view.fig'));
        
        hFigMri2 = view_mri_slices(MriFile, 'y', 20);
        bst_report('Snapshot',hFigMri2,MriFile,'MRI Coronal view', [200,200,750,475]);
        saveas( hFigMri2,fullfile(subject_report_path,'MRI Coronal view.fig'));
        
        hFigMri3 = view_mri_slices(MriFile, 'z', 20);
        bst_report('Snapshot',hFigMri3,MriFile,'MRI Sagital view', [200,200,750,475]);
        saveas( hFigMri3,fullfile(subject_report_path,'MRI Sagital view.fig'));
        
        close([hFigMri1 hFigMri2 hFigMri3]);
        
        %%
        %% Process: Import surfaces
        %%
        nverthead = selected_dataset.process_import_surfaces.nverthead;
        nvertcortex = selected_dataset.process_import_surfaces.nvertcortex;
        nvertskull = selected_dataset.process_import_surfaces.nvertskull;
        
        sFiles = bst_process('CallProcess', 'script_process_import_surfaces', sFiles, [], ...
            'subjectname', subID, ...
            'headfile',    {head_file, 'MRI-MASK-MNI'}, ...
            'cortexfile1', {L_surface_file, 'GII-MNI'}, ...
            'cortexfile2', {R_surface_file, 'GII-MNI'}, ...
            'innerfile',   {innerskull_file, 'MRI-MASK-MNI'}, ...
            'outerfile',   {outerskull_file, 'MRI-MASK-MNI'}, ...
            'nverthead',   nverthead, ...
            'nvertcortex', nvertcortex, ...
            'nvertskull',  nvertskull);
        
        %%
        %% ===== IMPORT SURFACES 32K =====
        %%
        [sSubject, iSubject] = bst_get('Subject', subID);
        % Left pial
        [iLh, BstTessLhFile, nVertOrigL] = import_surfaces(iSubject, L_surface_file, 'GII-MNI', 0);
        BstTessLhFile = BstTessLhFile{1};
        % Right pial
        [iRh, BstTessRhFile, nVertOrigR] = import_surfaces(iSubject, R_surface_file, 'GII-MNI', 0);
        BstTessRhFile = BstTessRhFile{1};
        
        %%
        %% ===== MERGE SURFACES =====
        %%
        % Merge surfaces
        % Merge surfaces
        [TessFile32K, iSurface] = tess_concatenate({BstTessLhFile, BstTessRhFile}, sprintf('cortex_%dV', nVertOrigL + nVertOrigR), 'Cortex');
        % Delete original files
        file_delete(file_fullpath({BstTessLhFile, BstTessRhFile}), 1);
        % Compute missing fields
        in_tess_bst( TessFile32K, 1);
        % Reload subject
        db_reload_subjects(iSubject);
        % Set file type
        db_surface_type(TessFile32K, 'Cortex');
        % Set default cortex
        db_surface_default(iSubject, 'Cortex', 2);
        
        %%
        %% Quality control
        %%
        % Get subject definition and subject files
        sSubject       = bst_get('Subject', subID);
        MriFile        = sSubject.Anatomy(sSubject.iAnatomy).FileName;
        CortexFile     = sSubject.Surface(sSubject.iCortex).FileName;
        InnerSkullFile = sSubject.Surface(sSubject.iInnerSkull).FileName;
        OuterSkullFile = sSubject.Surface(sSubject.iOuterSkull).FileName;
        ScalpFile      = sSubject.Surface(sSubject.iScalp).FileName;
        
        %
        hFigMriSurf = view_mri(MriFile, CortexFile);
        
        %
        hFigMri4  = script_view_contactsheet( hFigMriSurf, 'volume', 'x','');
        bst_report('Snapshot',hFigMri4,MriFile,'Cortex - MRI registration Axial view', [200,200,750,475]);
        saveas( hFigMri4,fullfile(subject_report_path,'Cortex - MRI registration Axial view.fig'));
        %
        hFigMri5  = script_view_contactsheet( hFigMriSurf, 'volume', 'y','');
        bst_report('Snapshot',hFigMri5,MriFile,'Cortex - MRI registration Coronal view', [200,200,750,475]);
        saveas( hFigMri5,fullfile(subject_report_path,'Cortex - MRI registration Coronal view.fig'));
        %
        hFigMri6  = script_view_contactsheet( hFigMriSurf, 'volume', 'z','');
        bst_report('Snapshot',hFigMri6,MriFile,'Cortex - MRI registration Sagital view', [200,200,750,475]);
        saveas( hFigMri6,fullfile(subject_report_path,'Cortex - MRI registration Sagital view.fig'));
        % Closing figures
        close([hFigMriSurf hFigMri4 hFigMri5 hFigMri6]);
        
        %
        hFigMri7 = view_mri(MriFile, ScalpFile);
        bst_report('Snapshot',hFigMri7,MriFile,'Scalp registration', [200,200,750,475]);
        saveas( hFigMri7,fullfile(subject_report_path,'Scalp registration.fig'));
        %
        hFigMri8 = view_mri(MriFile, OuterSkullFile);
        bst_report('Snapshot',hFigMri8,MriFile,'Outer Skull - MRI registration', [200,200,750,475]);
        saveas( hFigMri8,fullfile(subject_report_path,'Outer Skull - MRI registration.fig'));
        %
        hFigMri9 = view_mri(MriFile, InnerSkullFile);
        bst_report('Snapshot',hFigMri9,MriFile,'Inner Skull - MRI registration', [200,200,750,475]);
        saveas( hFigMri9,fullfile(subject_report_path,'Inner Skull - MRI registration.fig'));
        
        % Closing figures
        close([hFigMri7 hFigMri8 hFigMri9]);
        
        %
        hFigSurf10 = view_surface(CortexFile);
        bst_report('Snapshot',hFigSurf10,[],'Cortex mesh 3D top view', [200,200,750,475]);
        saveas( hFigSurf10,fullfile(subject_report_path,'Cortex mesh 3D view.fig'));
        % Bottom
        view(90,270)
        bst_report('Snapshot',hFigSurf10,[],'Cortex mesh 3D bottom view', [200,200,750,475]);
        %Left
        view(1,180)
        bst_report('Snapshot',hFigSurf10,[],'Cortex mesh 3D left hemisphere view', [200,200,750,475]);
        % Rigth
        view(0,360)
        bst_report('Snapshot',hFigSurf10,[],'Cortex mesh 3D right hemisphere view', [200,200,750,475]);
        
        % Closing figure
        close(hFigSurf10);
        
        %%
        %% Process: Generate BEM surfaces
        %%
        bst_process('CallProcess', 'process_generate_bem', [], [], ...
            'subjectname', subID, ...
            'nscalp',      3242, ...
            'nouter',      3242, ...
            'ninner',      3242, ...
            'thickness',   4);
        
        %%
        %% Get subject definition and subject files
        %%
        sSubject       = bst_get('Subject', subID);
        CortexFile     = sSubject.Surface(sSubject.iCortex).FileName;
        InnerSkullFile = sSubject.Surface(sSubject.iInnerSkull).FileName;
        
        %%
        %% Forcing dipoles inside innerskull
        %%
        script_tess_force_envelope(CortexFile, InnerSkullFile);
        
        %%
        %% Get subject definition and subject files
        %%
        sSubject       = bst_get('Subject', subID);
        MriFile        = sSubject.Anatomy(sSubject.iAnatomy).FileName;
        CortexFile     = sSubject.Surface(sSubject.iCortex).FileName;
        InnerSkullFile = sSubject.Surface(sSubject.iInnerSkull).FileName;
        OuterSkullFile = sSubject.Surface(sSubject.iOuterSkull).FileName;
        ScalpFile      = sSubject.Surface(sSubject.iScalp).FileName;
        iCortex        = sSubject.iCortex;
        iAnatomy       = sSubject.iAnatomy;
        iInnerSkull    = sSubject.iInnerSkull;
        iOuterSkull    = sSubject.iOuterSkull;
        iScalp         = sSubject.iScalp;
        
        %%
        %% Quality Control
        %%
        hFigSurf11 = script_view_surface(CortexFile, [], [], [],'top');
        hFigSurf11 = script_view_surface(InnerSkullFile, [], [], hFigSurf11);
        hFigSurf11 = script_view_surface(OuterSkullFile, [], [], hFigSurf11);
        hFigSurf11 = script_view_surface(ScalpFile, [], [], hFigSurf11);
        bst_report('Snapshot',hFigSurf11,[],'BEM surfaces registration top view', [200,200,750,475]);
        saveas( hFigSurf11,fullfile(subject_report_path,'BEM surfaces registration view.fig'));
        % Left
        view(1,180)
        bst_report('Snapshot',hFigSurf11,[],'BEM surfaces registration left view', [200,200,750,475]);
        % Right
        view(0,360)
        bst_report('Snapshot',hFigSurf11,[],'BEM surfaces registration right view', [200,200,750,475]);
        % Front
        view(90,360)
        bst_report('Snapshot',hFigSurf11,[],'BEM surfaces registration front view', [200,200,750,475]);
        % Back
        view(270,360)
        bst_report('Snapshot',hFigSurf11,[],'BEM surfaces registration back view', [200,200,750,475]);
        
        close(hFigSurf11);
        
        %%
        %% Process: Generate SPM canonical surfaces
        %%
        sFiles = bst_process('CallProcess', 'process_generate_canonical', sFiles, [], ...
            'subjectname', subID, ...
            'resolution',  2);  % 8196
        
        %%
        %% Quality control
        %%
        % Get subject definition and subject files
        sSubject       = bst_get('Subject', subID);
        ScalpFile      = sSubject.Surface(sSubject.iScalp).FileName;
        
        %
        hFigMri15 = view_mri(MriFile, ScalpFile);
        bst_report('Snapshot',hFigMri15,[],'SPM Scalp Envelope - MRI registration', [200,200,750,475]);
        saveas( hFigMri15,fullfile(subject_report_path,'SPM Scalp Envelope - MRI registration.fig'));
        % Close figures
        close(hFigMri15);
        
        %%
        %% ===== ACCESS RECORDINGS =====
        %%
        % Process: Create link to raw file
        sFiles = bst_process('CallProcess', 'process_import_data_raw', sFiles, [], ...
            'subjectname',    subID, ...
            'datafile',       {raw_data, 'EEG-EGI-MFF'}, ...
            'channelreplace', 0, ...
            'channelalign',   1);
        
        if(isempty(sFiles))
            if(isfield(selected_dataset.eeg_raw_data_path,'template_data_path') && isfolder(selected_dataset.eeg_raw_data_path.template_data_path))
                tmp_path = selected_dataset.tmp_path;
                if(isequal(tmp_path,'local'))
                    tmp_path = pwd;
                end
                mff_template_dir = selected_dataset.eeg_raw_data_path.template_data_path;
                filepath = strrep(selected_dataset.eeg_raw_data_path.file_location,'SubID',subID);
                temp_mff_folder = fullfile(tmp_path,'tmp',subID,filepath);
                mkdir(temp_mff_folder);
                copyfile( [mff_template_dir,filesep,'*'] , temp_mff_folder);
                bst_report('Info',    '', [], 'The error above was bypassed and does not constitute a factor to be consider in the Quality Control. Keep looking in the protocol for other possible issues or errors.');
                bst_report('Info',    '', [], ['Protocol for subject:' , subID, ', will use MFF Tameplate Raw Data.']);
                sFiles = bst_process('CallProcess', 'process_import_data_raw', sFiles, [], ...
                    'subjectname',    subID, ...
                    'datafile',       {temp_mff_folder, 'EEG-EGI-MFF'}, ...
                    'channelreplace', 0, ...
                    'channelalign',   1);
                try
                    rmdir(fullfile(tmp_path,'tmp'),'s');
                catch
                end
            else
                fprintf(2,strcat('\n -->> Error: The ',selected_dataset.eeg_raw_data_path.data_format ,' Raw data do not have a correct format\n'));
                fprintf(2,strcat('Do not have a correct format\n'));
                disp("OR");
                fprintf(2,strcat('The folder is empty..\n'));
                fprintf(2,strcat('-->> Jumping to an other subject. \n'));
                ReportFile = bst_report('Save', sFiles);
                bst_report('Export',  ReportFile,report_name);
                bst_report('Open', ReportFile);
                bst_report('Close');
                processed = false;
                continue;
            end
        end
        
        %%
        %% Process: Set channel file%
        %%
        sFiles = bst_process('CallProcess', 'process_import_channel', sFiles, [], ...
            'usedefault',   26, ...  % NotAligned: GSN HydroCel 129 E001 (32) / GSN 129 (26)
            'channelalign', 1, ...
            'fixunits',     1, ...
            'vox2ras',      1);
        
        %%
        %% Process: Set BEM Surfaces
        %%
        [sSubject, iSubject] = bst_get('Subject', subID);
        db_surface_default(iSubject, 'Scalp', iScalp);
        db_surface_default(iSubject, 'OuterSkull', iOuterSkull);
        db_surface_default(iSubject, 'InnerSkull', iInnerSkull);
        db_surface_default(iSubject, 'Cortex', iCortex);
        
        %%
        %% Process: Project electrodes on scalp
        %%
        sFiles = bst_process('CallProcess', 'process_channel_project', sFiles, []);
        
        %%
        %% Quality control
        %%
        % View sources on MRI (3D orthogonal slices)
        [sSubject, iSubject] = bst_get('Subject', subID);
        MriFile        = sSubject.Anatomy(sSubject.iAnatomy).FileName;
        
        hFigMri16      = script_view_mri_3d(MriFile, [], [], [], 'front');
        hFigMri16      = view_channels(sFiles.ChannelFile, 'EEG', 1, 0, hFigMri16, 1);
        bst_report('Snapshot',hFigMri16,[],'Sensor-MRI registration front view', [200,200,750,475]);
        saveas( hFigMri16,fullfile(subject_report_path,'Sensor-MRI registration front view.fig'));
        %Left
        view(1,180)
        bst_report('Snapshot',hFigMri16,[],'Sensor-MRI registration left view', [200,200,750,475]);
        % Right
        view(0,360)
        bst_report('Snapshot',hFigMri16,[],'Sensor-MRI registration right view', [200,200,750,475]);
        % Back
        view(90,360)
        bst_report('Snapshot',hFigMri16,[],'Sensor-MRI registration back view', [200,200,750,475]);
        % Close figures
        close(hFigMri16);
        
        % View sources on Scalp
        [sSubject, iSubject] = bst_get('Subject', subID);
        MriFile        = sSubject.Anatomy(sSubject.iAnatomy).FileName;
        ScalpFile      = sSubject.Surface(sSubject.iScalp).FileName;
        
        hFigMri20      = script_view_surface(ScalpFile, [], [], [],'front');
        hFigMri20      = view_channels(sFiles.ChannelFile, 'EEG', 1, 0, hFigMri20, 1);
        bst_report('Snapshot',hFigMri20,[],'Sensor-Scalp registration front view', [200,200,750,475]);
        saveas( hFigMri20,fullfile(subject_report_path,'Sensor-Scalp registration front view.fig'));
        %Left
        view(1,180)
        bst_report('Snapshot',hFigMri20,[],'Sensor-Scalp registration left view', [200,200,750,475]);
        % Right
        view(0,360)
        bst_report('Snapshot',hFigMri20,[],'Sensor-Scalp registration right view', [200,200,750,475]);
        % Back
        view(90,360)
        bst_report('Snapshot',hFigMri20,[],'Sensor-Scalp registration back view', [200,200,750,475]);
        % Close figures
        close(hFigMri20);
        
        %%
        %% Process: Import Atlas
        %%
        
        [sSubject, iSubject] = bst_get('Subject', subID);
        
        LabelFile = {Atlas_seg_location,'MRI-MASK-MNI'};
        script_import_label(sSubject.Surface(sSubject.iCortex).FileName,LabelFile,0);
        
        %%
        %% Quality control
        %%
        %
        hFigSurf24 = view_surface(CortexFile);
        % Deleting the Atlas Labels and Countour from Cortex
        delete(findobj(hFigSurf24, 'Tag', 'ScoutLabel'));
        delete(findobj(hFigSurf24, 'Tag', 'ScoutMarker'));
        delete(findobj(hFigSurf24, 'Tag', 'ScoutContour'));
        
        bst_report('Snapshot',hFigSurf24,[],'surface view', [200,200,750,475]);
        saveas( hFigSurf24,fullfile(subject_report_path,'Surface view.fig'));
        %Left
        view(1,180)
        bst_report('Snapshot',hFigSurf24,[],'Surface left view', [200,200,750,475]);
        % Bottom
        view(90,270)
        bst_report('Snapshot',hFigSurf24,[],'Surface bottom view', [200,200,750,475]);
        % Rigth
        view(0,360)
        bst_report('Snapshot',hFigSurf24,[],'Surface right view', [200,200,750,475]);
        % Closing figure
        close(hFigSurf24)
        
        %%
        %% Getting Headmodeler options
        %%
        ProtocolInfo = bst_get('ProtocolInfo');
        [sStudy iStudy] = bst_get('Study');
        headmodel_options = get_headmodeler_options(modality, subID, iStudy);
        
        %%
        %% Process Head Model
        %%
        [headmodel_options, errMessage] = bst_headmodeler(headmodel_options);
        
        if(~isempty(headmodel_options))
            % Get subject directory
            [sSubject] = bst_get('Subject', subID);
            
            % If a new head model is available
            sHeadModel = db_template('headmodel');
            sHeadModel.FileName      = file_short(headmodel_options.HeadModelFile);
            sHeadModel.Comment       = headmodel_options.Comment;
            sHeadModel.HeadModelType = headmodel_options.HeadModelType;
            % Update Study structure
            iHeadModel = length(sStudy.HeadModel) + 1;
            sStudy.HeadModel(iHeadModel) = sHeadModel;
            sStudy.iHeadModel = iHeadModel;
            sStudy.iChannel = length(sStudy.Channel);
            % Update DataBase
            bst_set('Study', ProtocolInfo.iStudy, sStudy);
            db_save();
            
            %%
            %% Quality control of Head model
            %%
            qc_headmodel(headmodel_options,modality,subject_report_path);
            
            %%
            %% Save and display report
            %%
            ReportFile = bst_report('Save', sFiles);
            bst_report('Export',  ReportFile,report_name);
            bst_report('Open', ReportFile);
            bst_report('Close');
            processed = true;
            disp(strcat("-->> Process finished for subject: ", subID));
            
            Protocol_count = Protocol_count+1;
        else
            subjects_process_error = [subjects_process_error; subID];
            continue;
        end
    catch
        subjects_process_error = [subjects_process_error; subID];
        [~, iSubject] = bst_get('Subject', subID);
        db_delete_subjects( iSubject );
        processed = false;
        continue;
    end
    %%
    %% Export Subject to BC-VARETA
    %%
    if(processed)
        disp(strcat('BC-V -->> Export subject:' , subID, ' to BC-VARETA structure'));
        if(selected_dataset.bcv_config.export)
            export_subject_BCV_structure(selected_dataset,subID);
        end
    end
    %%
    Protocol_count = Protocol_count + 1;
    if( mod(Protocol_count,selected_dataset.protocol_subjet_count) == 0  || j == size(subjects,1))
        % Genering Manual QC file (need to check)
        %                     generate_MaQC_file();
    end
    disp(strcat('-->> Subject:' , subID, '. Processing finished.'));
    
end
disp(strcat('-->> Process finished....'));
disp('=================================================================');
disp('=================================================================');
save report.mat subjects_processed subjects_process_error;

end
