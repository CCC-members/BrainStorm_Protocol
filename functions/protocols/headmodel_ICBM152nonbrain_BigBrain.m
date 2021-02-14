function [processed] = headmodel_ICBM152nonbrain_BigBrain()
% Description here
%
%
%
% Author:
% - Ariosky Areces Gonzalez
% - Deirel Paz Linares
%%

%%
%% Preparing selected protocol
%%
app_properties = jsondecode(fileread(strcat('app',filesep,'properties.json')));
selected_data_set = jsondecode(fileread(strcat('config_protocols',filesep,app_properties.selected_data_set.file_name)));
modality = selected_data_set.modality;

%%
%% Preparing Subject files
%%
% MRI File
base_path           = selected_data_set.hcp_data.base_path;
filepath            = selected_data_set.hcp_data.file_location;
T1w_file            = fullfile(base_path,filepath);

% Cortex Surfaces
filepath            = selected_data_set.hcp_data.L_surface_location;
L_surface_file      = fullfile(base_path,filepath);

filepath            = selected_data_set.hcp_data.R_surface_location;
R_surface_file      = fullfile(base_path,filepath);

filepath            = selected_data_set.hcp_data.Atlas_seg_location;
Atlas_seg_location  = fullfile(base_path,filepath);

if(~isfile(T1w_file) || ~isfile(L_surface_file) || ~isfile(R_surface_file) || ~isfile(Atlas_seg_location))
    if(isfile(T1w_file) && ~isfile(L_surface_file) && ~isfile(R_surface_file))
        if(isfield(selected_data_set, 'brain_external_surface_path'))
            base_path =  strrep(selected_data_set.brain_external_surface_path.base_path,'SubID',subID);
            filepath = strrep(selected_data_set.brain_external_surface_path.L_surface_location,'SubID',subID);
            L_surface_file = fullfile(base_path,filepath);
            
            filepath = strrep(selected_data_set.brain_external_surface_path.R_surface_location,'SubID',subID);
            R_surface_file = fullfile(base_path,filepath);
            if(~isfile(L_surface_file) || ~isfile(R_surface_file))
                fprintf(2,strcat('\n -->> Error: The Tw1 or Cortex surfaces: \n'));
                disp(string(L_surface_file));
                disp(string(R_surface_file));
                fprintf(2,strcat('\n -->> Do not exist. \n'));
                fprintf(2,strcat('-->> Jumping to an other subject. \n'));
                processed = false;
                return;
            end
        else
            fprintf(2,strcat('\n -->> Error: You need to configure the cortex surfaces in at least one of follows field\n'));
            disp(string(T1w_file));
            disp("hcp_data");
            disp("OR");
            disp("brain_external_surface_path");
            fprintf(2,strcat('-->> Jumping to an other subject. \n'));
            processed = false;
            return;
        end
    else
        fprintf(2,strcat('\n -->> Error: The Tw1 or Cortex surfaces: \n'));
        disp(string(T1w_file));
        disp(string(L_surface_file));
        disp(string(R_surface_file));
        disp(string(Atlas_seg_location));
        fprintf(2,strcat('\n -->> Do not exist. \n'));
        fprintf(2,strcat('-->> Jumping to an other subject. \n'));
        processed = false;
        return;
    end
end

% Non-Brain surface files
base_path       = selected_data_set.non_brain_data.base_path;
filepath        = selected_data_set.non_brain_data.head_file_location;
head_file       = fullfile(base_path,filepath);

filepath        = selected_data_set.non_brain_data.outerfile_file_location;
outerskull_file = fullfile(base_path,filepath);

filepath        = selected_data_set.non_brain_data.innerfile_file_location;
innerskull_file = fullfile(base_path,filepath);

if(~isfile(head_file) || ~isfile(outerskull_file) || ~isfile(innerskull_file))
    fprintf(2,strcat('\n -->> Error: The Non-brain surfaces: \n'));
    disp(string(T1w_file));
    disp(string(L_surface_file));
    disp(string(R_surface_file));
    fprintf(2,strcat('\n -->> Do not exist. \n'));
    fprintf(2,strcat('-->> Jumping to an other subject. \n'));
    processed = false;
    return;
end

ProtocolName            = selected_data_set.protocol_name;
subjects_process_error  = [];
subjects_processed      = [];
Protocol_count          = 0;

[base_path,name,ext]    = fileparts(selected_data_set.raw_data.base_path);
subjects                =  dir(base_path);
subjects(ismember( {subjects.name}, {'.', '..'})) = [];  %remove . and ..
if(isempty(subjects))
    [base_path,name,ext]    = fileparts(selected_data_set.preprocessed_data.base_path);
    subjects                =  dir(base_path);
    subjects(ismember( {subjects.name}, {'.', '..'})) = [];  %remove . and ..
    if(isempty(subjects))
        fprintf(2,strcat('\n -->> Error: We can not find any subject data: \n'));
        fprintf(2,strcat('-->> Do not exist the Raw data Or the Preprocessed data. \n'));
        fprintf(2,strcat('-->> Please configure the properties file correctly. \n'));
        return;
    end
end
for i=1:length(subjects)
    subject = subjects(i);
    subID   = subject.name;
    
    %%
    %% Preparing Subject files
    %%
    % Transformation file
    base_path =  strrep(selected_data_set.mri_transformation.base_path,'SubID',subID);
    filepath = strrep(selected_data_set.mri_transformation.file_location,'SubID',subID);
    MRI_transformation_file = fullfile(base_path,filepath);
    if(~isfile(MRI_transformation_file) && ~isequal(base_path,'none'))
        fprintf(2,strcat('\n -->> Error: The MEG tranformation file: \n'));
        disp(string(MRI_transformation_file));
        fprintf(2,strcat('\n -->> Do not exist. \n'));
        fprintf(2,strcat('\n -->> Jumping to an other subject. \n'));
        processed = false;
        continue;
    end
    if(isequal(base_path,'none'))
        MRI_transformation_file = 'none';
    end
    
    base_path =  strrep(selected_data_set.raw_data.base_path,'SubID',subID);
    % Raw data
    filepath = strrep(selected_data_set.raw_data.file_location,'SubID',subID);
    raw_data = fullfile(base_path,filepath);
    
    %%
    %%  Checking protocol
    %%
    if( mod(Protocol_count,selected_data_set.protocol_subjet_count) == 0  )
        ProtocolName_R = strcat(ProtocolName,'_',char(num2str(Protocol_count)));
        if(selected_data_set.protocol_reset)
            gui_brainstorm('DeleteProtocol',ProtocolName_R);
            bst_db_path = bst_get('BrainstormDbDir');
            if(isfolder(fullfile(bst_db_path,ProtocolName_R)))
                protocol_folder = fullfile(bst_db_path,ProtocolName_R);
                rmdir(protocol_folder, 's');
            end
            gui_brainstorm('CreateProtocol',ProtocolName_R ,selected_data_set.use_default_anatomy, selected_data_set.use_default_channel);
        else
            %                 gui_brainstorm('UpdateProtocolsList');
            iProtocol = bst_get('Protocol', ProtocolName_R);
            gui_brainstorm('SetCurrentProtocol', iProtocol);
            subjects = bst_get('ProtocolSubjects');
            if(i <= length(subjects.Subject))
                db_delete_subjects( i );
            end
        end
    end
    if(~isequal(selected_data_set.sub_prefix,'none') && ~isempty(selected_data_set.sub_prefix))
        subID = strrep(subject_name,selected_data_set.sub_prefix,'');
    end
    disp(strcat('-->> Processing subject: ', subID));
%     try
        %%
        %% Creating subject in Protocol
        %%
        db_add_subject(subID);
        
        %%
        %% Checking the report output structure
        %%
        if(selected_data_set.report_output_path == "local")
            report_output_path = pwd;
        else
            report_output_path = selected_data_set.report_output_path ;
        end
        if(~isfolder(report_output_path))
            mkdir(report_output_path);
        end
        if(~isfolder(fullfile(report_output_path,'Reports')))
            mkdir(fullfile(report_output_path,'Reports'));
        end
        if(~isfolder(fullfile(report_output_path,'Reports',ProtocolName)))
            mkdir(fullfile(report_output_path,'Reports',ProtocolName));
        end
        if(~isfolder(fullfile(report_output_path,'Reports',ProtocolName,subID)))
            mkdir(fullfile(report_output_path,'Reports',ProtocolName,subID));
        end
        subject_report_path = fullfile(report_output_path,'Reports',ProtocolName,subID);
        report_name = fullfile(subject_report_path,[subID,'.html']);
        iter = 2;
        while(isfile(report_name))
            report_name = fullfile(subject_report_path,[subID,'_Iter_', num2str(iter),'.html']);
            iter = iter + 1;
        end
        
        %%
        %% Start a new report
        %%
        bst_report('Start',['Protocol for subject:' , subID]);
        bst_report('Info',    '', [], ['Protocol for subject:' , subID])
        
        %%
        %% Import Anatomy
        %%
        % Build the path of the files to import
        [sSubject, iSubject] = bst_get('Subject', subID);
        % Process: Import MRI
        [BstMriFile, sMri] = import_mri(iSubject, T1w_file, 'ALL-MNI', 0);
           
        %%
        %% Read Transformation
        %%
        if(~isequal(MRI_transformation_file,'none'))
            bst_progress('start', 'Import HCP MEG/anatomy folder', 'Reading transformations...');
            % Read file
            fid = fopen(MRI_transformation_file, 'rt');
            strFid = fread(fid, [1 Inf], '*char');
            fclose(fid);
            % Evaluate the file (.m file syntax)
            eval(strFid);
        end
        %%
        %% MRI=>MNI Tranformation
        %%
        if(~isequal(MRI_transformation_file,'none'))
            % Convert transformations from "Brainstorm MRI" to "FieldTrip voxel"
            Tbst2ft = [diag([-1, 1, 1] ./ sMri.Voxsize), [size(sMri.Cube,1); 0; 0]; 0 0 0 1];
            % Set the MNI=>SCS transformation in the MRI
            Tmni = transform.vox07mm2spm * Tbst2ft;
            sMri.NCS.R = Tmni(1:3,1:3);
            sMri.NCS.T = Tmni(1:3,4);
            % Compute default fiducials positions based on MNI coordinates
            sMri = mri_set_default_fid(sMri);
        end
        %%
        %% MRI=>SCS TRANSFORMATION =====
        %%
        if(~isequal(MRI_transformation_file,'none'))
            % Set the MRI=>SCS transformation in the MRI
            Tscs = transform.vox07mm2bti * Tbst2ft;
            sMri.SCS.R = Tscs(1:3,1:3);
            sMri.SCS.T = Tscs(1:3,4);
            % Standard positions for the SCS fiducials
            NAS = [90,   0, 0] ./ 1000;
            LPA = [ 0,  75, 0] ./ 1000;
            RPA = [ 0, -75, 0] ./ 1000;
            Origin = [0, 0, 0];
            % Convert: SCS (meters) => MRI (millimeters)
            sMri.SCS.NAS    = cs_convert(sMri, 'scs', 'mri', NAS) .* 1000;
            sMri.SCS.LPA    = cs_convert(sMri, 'scs', 'mri', LPA) .* 1000;
            sMri.SCS.RPA    = cs_convert(sMri, 'scs', 'mri', RPA) .* 1000;
            sMri.SCS.Origin = cs_convert(sMri, 'scs', 'mri', Origin) .* 1000;
            % Save MRI structure (with fiducials)
            bst_save(BstMriFile, sMri, 'v7');
        end
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
        nverthead = selected_data_set.process_import_surfaces.nverthead;
        nvertcortex = selected_data_set.process_import_surfaces.nvertcortex;
        nvertskull = selected_data_set.process_import_surfaces.nvertskull;
        
        sFiles = bst_process('CallProcess', 'script_process_import_surfaces', [], [], ...
            'subjectname', subID, ...
            'headfile',    {head_file, 'MRI-MASK-MNI'}, ...
            'cortexfile1', {L_surface_file, 'GII-MNI'}, ...
            'cortexfile2', {R_surface_file, 'GII-MNI'}, ...
            'innerfile',   {innerskull_file, 'MRI-MASK-MNI'}, ...
            'outerfile',   {outerskull_file, 'MRI-MASK-MNI'}, ...
            'nverthead',   nverthead, ...
            'nvertcortex', nvertcortex, ...
            'nvertskull',  nvertskull);
        %         'innerfile',   {innerskull_file, 'MRI-MASK-MNI'}, ...
        %             'outerfile',   {outerskull_file, 'MRI-MASK-MNI'}, ...
        
        %% ===== IMPORT SURFACES 32K =====
        [sSubject, iSubject] = bst_get('Subject', subID);
        % Left pial
        [iLh, BstTessLhFile, nVertOrigL] = import_surfaces(iSubject, L_surface_file, 'GII-MNI', 0);
        BstTessLhFile = BstTessLhFile{1};
        % Right pial
        [iRh, BstTessRhFile, nVertOrigR] = import_surfaces(iSubject, R_surface_file, 'GII-MNI', 0);
        BstTessRhFile = BstTessRhFile{1};
        
        %% ===== MERGE SURFACES =====
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
        % Closing figures
        close(hFigMri4);
        %
        hFigMri5  = script_view_contactsheet( hFigMriSurf, 'volume', 'y','');
        bst_report('Snapshot',hFigMri5,MriFile,'Cortex - MRI registration Coronal view', [200,200,750,475]);
        saveas( hFigMri5,fullfile(subject_report_path,'Cortex - MRI registration Coronal view.fig'));
        % Closing figures
        close(hFigMri5);
        %
        hFigMri6  = script_view_contactsheet( hFigMriSurf, 'volume', 'z','');
        bst_report('Snapshot',hFigMri6,MriFile,'Cortex - MRI registration Sagital view', [200,200,750,475]);
        saveas( hFigMri6,fullfile(subject_report_path,'Cortex - MRI registration Sagital view.fig'));
        % Closing figures
        close([hFigMriSurf hFigMri6]);
        
        %
        hFigMri7 = view_mri(MriFile, ScalpFile);
        bst_report('Snapshot',hFigMri7,MriFile,'Scalp registration', [200,200,750,475]);
        saveas( hFigMri7,fullfile(subject_report_path,'Scalp registration.fig'));
        % Closing figures
        close(hFigMri7);
        %
        hFigMri8 = view_mri(MriFile, OuterSkullFile);
        bst_report('Snapshot',hFigMri8,MriFile,'Outer Skull - MRI registration', [200,200,750,475]);
        saveas( hFigMri8,fullfile(subject_report_path,'Outer Skull - MRI registration.fig'));
        % Closing figures
        close(hFigMri8);
        %
        hFigMri9 = view_mri(MriFile, InnerSkullFile);
        bst_report('Snapshot',hFigMri9,MriFile,'Inner Skull - MRI registration', [200,200,750,475]);
        saveas( hFigMri9,fullfile(subject_report_path,'Inner Skull - MRI registration.fig'));
        % Closing figures
        close(hFigMri9);
        
        %
        hFigSurf10 = view_surface(CortexFile);
        bst_report('Snapshot',hFigSurf10,[],'Cortex mesh 3D top view', [200,200,750,475]);
        saveas( hFigSurf10,fullfile(subject_report_path,'Cortex mesh 3D top view.fig'));
        %
        figure_3d('SetStandardView', hFigSurf10, 'left');
        bst_report('Snapshot',hFigSurf10,[],'Cortex mesh 3D left hemisphere view', [200,200,750,475]);
        
        %
        figure_3d('SetStandardView', hFigSurf10, 'bottom');
        bst_report('Snapshot',hFigSurf10,[],'Cortex mesh 3D bottom view', [200,200,750,475]);
        
        %
        figure_3d('SetStandardView', hFigSurf10, 'right');
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
        
        %Left
        view(1,180)
        bst_report('Snapshot',hFigSurf11,[],'BEM surfaces registration left view', [200,200,750,475]);
        
        % Right
        view(0,360)
        bst_report('Snapshot',hFigSurf11,[],'BEM surfaces registration right view', [200,200,750,475]);
        
        % Back
        view(90,360)
        bst_report('Snapshot',hFigSurf11,[],'BEM surfaces registration back view', [200,200,750,475]);
        
        close(hFigSurf11);
        
        %%
        %% Process: Generate SPM canonical surfaces
        %%
        sFiles = bst_process('CallProcess', 'process_generate_canonical', [], [], ...
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
            'datafile',       {raw_data, '4D'}, ...
            'channelreplace', 0, ...
            'channelalign',   1);
        
        %%
        %% Process: Set BEM Surfaces
        %%
        [sSubject, iSubject] = bst_get('Subject', subID);
        db_surface_default(iSubject, 'Scalp', iScalp);
        db_surface_default(iSubject, 'OuterSkull', iOuterSkull);
        db_surface_default(iSubject, 'InnerSkull', iInnerSkull);
        db_surface_default(iSubject, 'Cortex', iCortex);
        %%
        %% Quality control
        %%
        % View sources on MRI (3D orthogonal slices)
        [sSubject, iSubject] = bst_get('Subject', subID);
        ScalpFile      = sSubject.Surface(sSubject.iScalp).FileName;
        
        hFigScalp16      = script_view_surface(ScalpFile, [], [], [], 'front');
        [hFigScalp16, iDS, iFig] = view_helmet(sFiles.ChannelFile, hFigScalp16);
        bst_report('Snapshot',hFigScalp16,[],'Sensor-Helmet registration front view', [200,200,750,475]);
        saveas( hFigScalp16,fullfile(subject_report_path,'Sensor-Helmet registration front view.fig'));
        %Left
        view(1,180)
        bst_report('Snapshot',hFigScalp16,[],'Sensor-MRI registration left view', [200,200,750,475]);
        % Right
        view(0,360)
        bst_report('Snapshot',hFigScalp16,[],'Sensor-MRI registration right view', [200,200,750,475]);
        % Back
        view(90,360)
        bst_report('Snapshot',hFigScalp16,[],'Sensor-MRI registration back view', [200,200,750,475]);
        % Close figures
        close(hFigScalp16);
        
        % View 4D coils on Scalp
        [hFigScalp20, iDS, iFig] = view_channels_3d(sFiles.ChannelFile,'4D', 'scalp', 0, 0);
        view(90,360)
        bst_report('Snapshot',hFigScalp20,[],'4D coils-Scalp registration front view', [200,200,750,475]);
        saveas( hFigScalp20,fullfile(subject_report_path,'Sensor-Scalp registration front view.fig'));
        
        view(180,360)
        bst_report('Snapshot',hFigScalp20,[],'4D coils-Scalp registration left view', [200,200,750,475]);
        
        view(0,360)
        bst_report('Snapshot',hFigScalp20,[],'4D coils-Scalp registration right view', [200,200,750,475]);
        
        view(270,360)
        bst_report('Snapshot',hFigScalp20,[],'4D coils-Scalp registration back view', [200,200,750,475]);
        
        % Close figures
        close(hFigScalp20);
        
        
        % View 4D coils on Scalp
        [hFigScalp21, iDS, iFig] = view_channels_3d(sFiles.ChannelFile,'MEG', 'scalp');
        view(90,360)
        bst_report('Snapshot',hFigScalp21,[],'4D coils-Scalp registration front view', [200,200,750,475]);
        saveas( hFigScalp21,fullfile(subject_report_path,'4D coils-Scalp registration front view.fig'));
        
        view(180,360)
        bst_report('Snapshot',hFigScalp21,[],'4D coils-Scalp registration left view', [200,200,750,475]);
        
        view(0,360)
        bst_report('Snapshot',hFigScalp21,[],'4D coils-Scalp registration right view', [200,200,750,475]);
        
        view(270,360)
        bst_report('Snapshot',hFigScalp21,[],'4D coils-Scalp registration back view', [200,200,750,475]);
        
        % Close figures
        close(hFigScalp21);
        
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
        CortexFile = sSubject.Surface(sSubject.iCortex).FileName;
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
        iStudy = ProtocolInfo.iStudy;
        headmodel_options = get_headmodeler_options(modality, subID, iStudy);

        %%
        %% Process Head Model
        %%
        [headmodel_options, errMessage] = bst_headmodeler(headmodel_options);
        
        if(~isempty(headmodel_options))           
            
            sStudy = bst_get('Study', iStudy);
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
            bst_set('Study', iStudy, sStudy);
            db_save();
            
            %%
            %% Quality control
            %%
            ProtocolInfo    = bst_get('ProtocolInfo');
            
            BSTCortexFile   = bst_fullfile(ProtocolInfo.SUBJECTS, headmodel_options.CortexFile);
            cortex          = load(BSTCortexFile);
            
            
            BSTScalpFile    = bst_fullfile(ProtocolInfo.SUBJECTS, headmodel_options.HeadFile);
            head            = load(BSTScalpFile);
            
            %%
            %% Uploading Gain matrix
            %%
            BSTHeadModelFile = bst_fullfile(headmodel_options.HeadModelFile);
            BSTHeadModel = load(BSTHeadModelFile);
            Ke = BSTHeadModel.Gain;
            
            %%
            %% Uploading Channels Loc
            %%
            BSTChannelsFile = bst_fullfile(ProtocolInfo.STUDIES,sStudy.Channel.FileName);
            BSTChannels = load(BSTChannelsFile);
            
            [BSTChannels,Ke] = remove_channels_and_leadfield_from_layout([],BSTChannels,Ke,true);
            
            channels = [];
            for j = 1: length(BSTChannels.Channel)
                Loc = BSTChannels.Channel(j).Loc;
                center = mean(Loc,2);
                channels = [channels; center(1),center(2),center(3) ];
            end
            
            %% Change the Homogenius LeadField for MEG
            %                 %%
            %                 %% Checking LF correlation
            %                 %%
            [Ne,Nv]     = size(Ke);
            Nv          = Nv/3;
            Kn          = reshape(Ke,Ne,3,Nv);
            Kn          = permute(Kn,[1,3,2]);
            %                 VoxelCoord  = cortex.Vertices;
            %                 VertNorms   = cortex.VertNormals;
            %
            %                 %computing homogeneous lead field
            %                 [Kn,Khom]   = computeNunezLF(Ke,VoxelCoord, channels);
            %
            %%
            %% Ploting sensors and sources on the scalp and cortex
            %%
            [hFig25] = view3D_K(Kn,cortex,head,channels,200);
            bst_report('Snapshot',hFig25,[],'Field top view', [200,200,750,475]);
            view(0,360)
            saveas( hFig25,fullfile(subject_report_path,'Field view.fig'));
            
            bst_report('Snapshot',hFig25,[],'Field right view', [200,200,750,475]);
            view(1,180)
            bst_report('Snapshot',hFig25,[],'Field left view', [200,200,750,475]);
            view(90,360)
            bst_report('Snapshot',hFig25,[],'Field front view', [200,200,750,475]);
            view(270,360)
            bst_report('Snapshot',hFig25,[],'Field back view', [200,200,750,475]);
            % Closing figure
            close(hFig25);
            %
            %
            %                 [hFig26]    = view3D_K(Khom,cortex,head,channels,17);
            %                 bst_report('Snapshot',hFig26,[],'Homogenous field top view', [200,200,750,475]);
            %                 view(0,360)
            %                 saveas( hFig26,fullfile(subject_report_path,'Homogenous field view.fig'));
            %
            %                 bst_report('Snapshot',hFig26,[],'Homogenous field right view', [200,200,750,475]);
            %                 view(1,180)
            %                 bst_report('Snapshot',hFig26,[],'Homogenous field left view', [200,200,750,475]);
            %                 view(90,360)
            %                 bst_report('Snapshot',hFig26,[],'Homogenous field front view', [200,200,750,475]);
            %                 view(270,360)
            %                 bst_report('Snapshot',hFig26,[],'Homogenous field back view', [200,200,750,475]);
            %                 % Closing figure
            %                 close(hFig26);
            %
            %                 VertNorms   = reshape(VertNorms,[1,Nv,3]);
            %                 VertNorms   = repmat(VertNorms,[Ne,1,1]);
            %                 Kn          = sum(Kn.*VertNorms,3);
            %                 Khom        = sum(Khom.*VertNorms,3);
            %
            %
            %                 %Homogenous Lead Field vs. Tester Lead Field Plot
            %                 hFig27 = figure;
            %                 scatter(Khom(:),Kn(:));
            %                 title('Homogenous Lead Field vs. Tester Lead Field');
            %                 xlabel('Homogenous Lead Field');
            %                 ylabel('Tester Lead Field');
            %                 bst_report('Snapshot',hFig27,[],'Homogenous Lead Field vs. Tester Lead Field', [200,200,750,475]);
            %                 saveas( hFig27,fullfile(subject_report_path,'Homogenous Lead Field vs. Tester Lead Field.fig'));
            %                 % Closing figure
            %                 close(hFig27);
            %
            %                 %computing channel-wise correlation
            %                 for k=1:size(Kn,1)
            %                     corelch(k,1)=corr(Khom(k,:).',Kn(k,:).');
            %                 end
            %                 %plotting channel wise correlation
            %                 hFig28 = figure;
            %                 plot([1:size(Kn,1)],corelch,[1:size(Kn,1)],0.7,'r-');
            %                 xlabel('Channels');
            %                 ylabel('Correlation');
            %                 title('Correlation between both lead fields channel-wise');
            %                 bst_report('Snapshot',hFig28,[],'Correlation between both lead fields channel-wise', [200,200,750,475]);
            %                 saveas( hFig28,fullfile(subject_report_path,'Correlation channel-wise.fig'));
            %                 % Closing figure
            %                 close(hFig28);
            %
            %                 zKhom = zscore(Khom')';
            %                 zK = zscore(Kn')';
            %                 %computing voxel-wise correlation
            %                 for k=1:Nv
            %                     corelv(k,1)=corr(zKhom(:,k),zK(:,k));
            %                 end
            %                 corelv(isnan(corelv))=0;
            %                 corr2d = corr2(Khom, Kn);
            %                 %plotting voxel wise correlation
            %                 hFig29 = figure;
            %                 plot([1:Nv],corelv);
            %                 title('Correlation both lead fields Voxel wise');
            %                 bst_report('Snapshot',hFig29,[],'Correlation both lead fields Voxel wise', [200,200,750,475]);
            %                 saveas( hFig29,fullfile(subject_report_path,'Correlation Voxel wise.fig'));
            %                 close(hFig29);
            %
            %                 %%
            %                 %% Finding points of low corelation
            %                 %%
            %                 low_cor_inds = find(corelv < .3);
            %                 BSTCortexFile = bst_fullfile(ProtocolInfo.SUBJECTS, headmodel_options.CortexFile);
            %                 hFig_low_cor = view_surface(BSTCortexFile, [], [], 'NewFigure');
            %                 hFig_low_cor = view_surface(BSTCortexFile, [], [], hFig_low_cor);
            %                 % Delete scouts
            %                 delete(findobj(hFig_low_cor, 'Tag', 'ScoutLabel'));
            %                 delete(findobj(hFig_low_cor, 'Tag', 'ScoutMarker'));
            %                 delete(findobj(hFig_low_cor, 'Tag', 'ScoutPatch'));
            %                 delete(findobj(hFig_low_cor, 'Tag', 'ScoutContour'));
            %
            %                 line(cortex.Vertices(low_cor_inds,1), cortex.Vertices(low_cor_inds,2), cortex.Vertices(low_cor_inds,3), 'LineStyle', 'none', 'Marker', 'o',  'MarkerFaceColor', [1 0 0], 'MarkerSize', 6);
            %                 figure_3d('SetStandardView', hFig_low_cor, 'bottom');
            %                 bst_report('Snapshot',hFig_low_cor,[],'Low correlation Voxel', [200,200,750,475]);
            %                 saveas( hFig_low_cor,fullfile(subject_report_path,'Low correlation Voxel.fig'));
            %                 close(hFig_low_cor);
            %
            %                 figure_cor = figure;
            %                 %colormap(gca,cmap);
            %                 patch('Faces',cortex.Faces,'Vertices',cortex.Vertices,'FaceVertexCData',corelv,'FaceColor','interp','EdgeColor','none','FaceAlpha',.99);
            %                 view(90,270)
            %                 bst_report('Snapshot',figure_cor,[],'Low correlation map', [200,200,750,475]);
            %                 saveas( figure_cor,fullfile(subject_report_path,'Low correlation Voxel interpolation.fig'));
            %                 close(figure_cor);
            
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
%     catch
%         subjects_process_error = [subjects_process_error; subID];
%         [~, iSubject] = bst_get('Subject', subID);
%         db_delete_subjects( iSubject );
%         processed = false;
%         continue;
%     end
    %%
    %% Export Subject to BC-VARETA
    %%
    if(processed)
        disp(strcat('BC-V -->> Export subject:' , subID, ' to BC-VARETA structure'));
        if(selected_data_set.bcv_config.export)
            export_subject_BCV_structure(selected_data_set,subID);
        end
    end
    %%
    if( mod(Protocol_count,selected_data_set.protocol_subjet_count) == 0  || i == size(subjects,1))
        % Genering Manual QC file (need to check)
        %                     generate_MaQC_file();
    end
    disp(strcat('-->> Subject:' , subID, '. Processing finished.'));
    
    disp(strcat('-->> Process finished....'));
    disp('=================================================================');
    disp('=================================================================');
    save report.mat subjects_processed subjects_process_error;
end
end
