function anat_error = process_import_anat(properties, type, iSubject, subID)
% === ANATOMY ===
anat_error = [];

%%
%% Surfaces resolution
%%
nVertHead       = properties.anatomy_params.surfaces_resolution.nverthead;
nVertCortex     = properties.anatomy_params.surfaces_resolution.nvertcortex;
nVertSkull      = properties.anatomy_params.surfaces_resolution.nvertskull;

if(isequal(type,'template') || isequal(type,'template_raw') || isequal(type,'individual'))
    non_brain_surfaces  = properties.anatomy_params.non_brain_surfaces;
    if(isequal(type,'template') || isequal(type,'template_raw'))
        anatomy_type        = properties.anatomy_params.anatomy_type.type_list{2};
        temp_sub_ID         = anatomy_type.template_name;
        % MRI File
        base_path           = strrep(anatomy_type.base_path, 'SubID', '');
        base_path           = strrep(base_path, anatomy_type.template_name, '');
        filepath            = strrep(anatomy_type.file_location, 'SubID', temp_sub_ID);
        T1w_file            = fullfile(base_path, temp_sub_ID, filepath);
        % Cortex Surfaces
        filepath            = strrep(anatomy_type.L_surface_location,'SubID',temp_sub_ID);
        L_surface_file      = fullfile(base_path, temp_sub_ID, filepath);
        filepath            = strrep(anatomy_type.R_surface_location,'SubID',temp_sub_ID);
        R_surface_file      = fullfile(base_path, temp_sub_ID, filepath);
        % Non-Brain surface files
        base_path           = strrep(non_brain_surfaces.base_path,'SubID','');
        base_path           = strrep(base_path, temp_sub_ID, '');
        filepath            = strrep(non_brain_surfaces.head_file_location,'SubID',temp_sub_ID);
        head_file           = fullfile(base_path, temp_sub_ID, filepath);
        filepath            = strrep(non_brain_surfaces.outerfile_file_location,'SubID',temp_sub_ID);
        outerskull_file     = fullfile(base_path, temp_sub_ID, filepath);
        filepath            = strrep(non_brain_surfaces.innerfile_file_location,'SubID',temp_sub_ID);
        innerskull_file     = fullfile(base_path, anatomy_type.template_name, filepath);
    else
        anatomy_type    = properties.anatomy_params.anatomy_type.type_list{3};
        % MRI File
        base_path           = strrep(anatomy_type.base_path,'SubID',subID);
        filepath            = strrep(anatomy_type.file_location,'SubID',subID);
        T1w_file            = fullfile(base_path,filepath);
        % Cortex Surfaces
        filepath            = strrep(anatomy_type.L_surface_location,'SubID',subID);
        L_surface_file      = fullfile(base_path,filepath);
        filepath            = strrep(anatomy_type.R_surface_location,'SubID',subID);
        R_surface_file      = fullfile(base_path,filepath);
        % Non-Brain surface files
        base_path           = strrep(non_brain_surfaces.base_path,'SubID',subID);
        filepath            = strrep(non_brain_surfaces.head_file_location,'SubID',subID);
        head_file           = fullfile(base_path,filepath);
        filepath            = strrep(non_brain_surfaces.outerfile_file_location,'SubID',subID);
        outerskull_file     = fullfile(base_path,filepath);
        filepath            = strrep(non_brain_surfaces.innerfile_file_location,'SubID',subID);
        innerskull_file     = fullfile(base_path,filepath);
    end
    if(~isfile(T1w_file) || ~isfile(L_surface_file) || ~isfile(R_surface_file))
        fprintf(2,strcat('\n -->> Error: The Tw1 or Cortex surfaces: \n'));
        disp(string(T1w_file));
        disp(string(L_surface_file));
        disp(string(R_surface_file));
        fprintf(2,strcat('\n -->> Do not exist. \n'));
        fprintf(2,strcat('\n -->> Jumping to an other subject. \n'));
        return;
    end
    if(~isfile(head_file) || ~isfile(outerskull_file) || ~isfile(innerskull_file))
        fprintf(2,strcat('\n -->> Error: One or more non-brain surfaces: \n'));
        disp(string(head_file));
        disp(string(outerskull_file));
        disp(string(innerskull_file));
        fprintf(2,strcat('\n -->> Do not exist. \n'));
        fprintf(2,strcat('\n -->> Jumping to an other subject. \n'));
        return;
    end
end
switch type
    case 'default'
        anatomy_type    = properties.anatomy_params.anatomy_type.type_list{1};
        sTemplates      = bst_get('AnatomyDefaults');
        Name            = anatomy_type.template_name;
        sTemplate       = sTemplates(find(strcmpi(Name, {sTemplates.Name}),1));
        if(isempty(sTemplate))
            fprintf(2,'\n ->> Error: The selected anatomy template is not downloaded.');
            disp(Name);
            disp("Please, open brainstorm and download the anatomy template");
            disp("The process will be stoped!!!");
            return;
        end
        db_set_template( iSubject, sTemplate, false );
        % Get subject definition and subject files
        sSubject        = bst_get('Subject', iSubject);
        MriFile         = sSubject.Anatomy(sSubject.iAnatomy).FileName;
        OldCortexFile   = sSubject.Surface(sSubject.iCortex).FileName;
        OldInnerFile    = sSubject.Surface(sSubject.iInnerSkull).FileName;
        OldOuterFile    = sSubject.Surface(sSubject.iOuterSkull).FileName;
        OldHeadFile     = sSubject.Surface(sSubject.iScalp).FileName;
        % Downsample
        NewHeadFile     = tess_downsize(OldHeadFile, nVertHead, 'reducepatch');
        % Delete intial file
        if ~file_compare(OldHeadFile, NewHeadFile)
            file_delete(file_fullpath(OldHeadFile), 1);
            NewHeadFile = file_fullpath(NewHeadFile);
        end
        % Update Comment field
        HeadMat.Comment = 'Head';
        bst_save(file_fullpath(NewHeadFile), HeadMat, 'v7', 1);
        % Downsample
        NewInnerFile    = tess_downsize(OldInnerFile, nVertSkull, 'reducepatch');
        % Update Comment field
        InnerMat.Comment = 'Inner skull';
        bst_save(file_fullpath(NewInnerFile), InnerMat, 'v7', 1);
        % Downsample
        NewOuterFile    = tess_downsize(OldOuterFile, nVertSkull, 'reducepatch');
        % Update Comment field
        OuterMat.Comment = 'Outer skull';
        bst_save(file_fullpath(NewOuterFile), OuterMat, 'v7', 1);
        % Downsample
        CortexFile      = tess_downsize(OldCortexFile, nVertCortex, 'reducepatch');
        % Update Comment field for Head file
        CortexMat.Comment = 'Cortex';
        db_reload_subjects(iSubject);
    case 'template'
        %%
        %% Process: Import MRI
        %%
        sFiles = bst_process('CallProcess', 'process_import_mri', [], [], ...
            'subjectname', subID, ...
            'mrifile',     {T1w_file, 'ALL-MNI'});
        
        %%
        %% Process: Import surfaces
        %%
        sFiles = bst_process('CallProcess', 'process_import_surfaces', sFiles, [], ...
            'subjectname', subID, ...
            'headfile',    {head_file, 'MRI-MASK-MNI'}, ...
            'cortexfile1', {L_surface_file, 'GII-MNI'}, ...
            'cortexfile2', {R_surface_file, 'GII-MNI'}, ...
            'innerfile',   {innerskull_file, 'MRI-MASK-MNI'}, ...
            'outerfile',   {outerskull_file, 'MRI-MASK-MNI'}, ...
            'nverthead',   nVertHead, ...
            'nvertcortex', nVertCortex, ...
            'nvertskull',  nVertSkull);
    case 'template_raw'
        if(properties.anatomy_params.mri_transformation.use_transformation)
            [BstMriFile, sMri] = import_mri(iSubject, T1w_file, 'ALL-MNI', 0);
            
            %%
            %% Read Transformation
            %%
            base_path = strrep(properties.anatomy_params.mri_transformation.base_path,'SubID',subID);
            transformation_ref = strrep(properties.anatomy_params.mri_transformation.file_location,'SubID',subID);
            transformation_file = fullfile(base_path,transformation_ref);
            if(isfile(transformation_file))
                bst_progress('start', 'Import HCP MEG/anatomy folder', 'Reading transformations...');
                % Read file
                fid = fopen(transformation_file, 'rt');
                strFid = fread(fid, [1 Inf], '*char');
                fclose(fid);
                % Evaluate the file (.m file syntax)
                eval(strFid);
                
                %%
                %% MRI=>MNI Tranformation
                %%
                % Convert transformations from "Brainstorm MRI" to "FieldTrip voxel"
                Tbst2ft = [diag([-1, 1, 1] ./ sMri.Voxsize), [size(sMri.Cube,1); 0; 0]; 0 0 0 1];
                % Set the MNI=>SCS transformation in the MRI
                Tmni = transform.vox07mm2spm * Tbst2ft;
                sMri.NCS.R = Tmni(1:3,1:3);
                sMri.NCS.T = Tmni(1:3,4);
                % Compute default fiducials positions based on MNI coordinates
                sMri = mri_set_default_fid(sMri);
                
                %%
                %% MRI=>SCS TRANSFORMATION =====
                %%
                
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
        else
            sFiles = bst_process('CallProcess', 'process_import_mri', [], [], ...
                'subjectname', subID, ...
                'mrifile',     {T1w_file, 'ALL-MNI'});
        end
        
        %%
        %% Process: Import surfaces
        %%
        sFiles = bst_process('CallProcess', 'process_import_surfaces', [], [], ...
            'subjectname', subID, ...
            'headfile',    {head_file, 'MRI-MASK-MNI'}, ...
            'cortexfile1', {L_surface_file, 'GII-MNI'}, ...
            'cortexfile2', {R_surface_file, 'GII-MNI'}, ...
            'innerfile',   {innerskull_file, 'MRI-MASK-MNI'}, ...
            'outerfile',   {outerskull_file, 'MRI-MASK-MNI'}, ...
            'nverthead',   nVertHead, ...
            'nvertcortex', nVertCortex, ...
            'nvertskull',  nVertSkull);
    case 'individual'
        %%
        %% Process: Import MRI
        %%
        if(properties.anatomy_params.mri_transformation.use_transformation)
            [BstMriFile, sMri] = import_mri(iSubject, T1w_file, 'ALL-MNI', 0);
            
            %%
            %% Read Transformation
            %%
            base_path = strrep(properties.anatomy_params.mri_transformation.base_path,'SubID',subID);
            transformation_ref = strrep(properties.anatomy_params.mri_transformation.file_location,'SubID',subID);
            transformation_file = fullfile(base_path,transformation_ref);
            if(isfile(transformation_file))
                bst_progress('start', 'Import HCP MEG/anatomy folder', 'Reading transformations...');
                % Read file
                fid = fopen(transformation_file, 'rt');
                strFid = fread(fid, [1 Inf], '*char');
                fclose(fid);
                % Evaluate the file (.m file syntax)
                eval(strFid);
                
                %%
                %% MRI=>MNI Tranformation
                %%
                % Convert transformations from "Brainstorm MRI" to "FieldTrip voxel"
                Tbst2ft = [diag([-1, 1, 1] ./ sMri.Voxsize), [size(sMri.Cube,1); 0; 0]; 0 0 0 1];
                % Set the MNI=>SCS transformation in the MRI
                Tmni = transform.vox07mm2spm * Tbst2ft;
                sMri.NCS.R = Tmni(1:3,1:3);
                sMri.NCS.T = Tmni(1:3,4);
                % Compute default fiducials positions based on MNI coordinates
                sMri = mri_set_default_fid(sMri);
                
                %%
                %% MRI=>SCS TRANSFORMATION =====
                %%
                
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
        else
            sFiles = bst_process('CallProcess', 'process_import_mri', [], [], ...
                'subjectname', subID, ...
                'mrifile',     {T1w_file, 'ALL-MNI'});
        end
        
        %%
        %% Process: Import surfaces
        %%
        sFiles = bst_process('CallProcess', 'process_import_surfaces', [], [], ...
            'subjectname', subID, ...
            'headfile',    {head_file, 'MRI-MASK-MNI'}, ...
            'cortexfile1', {L_surface_file, 'GII-MNI'}, ...
            'cortexfile2', {R_surface_file, 'GII-MNI'}, ...
            'innerfile',   {innerskull_file, 'MRI-MASK-MNI'}, ...
            'outerfile',   {outerskull_file, 'MRI-MASK-MNI'}, ...
            'nverthead',   nVertHead, ...
            'nvertcortex', nVertCortex, ...
            'nvertskull',  nVertSkull);
end
if(isequal(type,'template') || isequal(type,'individual'))
    %%
    %% ===== IMPORT SURFACES 32K =====
    %%
    [sSubject, iSubject]                = bst_get('Subject', subID);
    % Left pial
    [iLh, BstTessLhFile, nVertOrigL]    = import_surfaces(iSubject, L_surface_file, 'GII-MNI', 0);
    BstTessLhFile                       = BstTessLhFile{1};
    % Right pial
    [iRh, BstTessRhFile, nVertOrigR]    = import_surfaces(iSubject, R_surface_file, 'GII-MNI', 0);
    BstTessRhFile                       = BstTessRhFile{1};
    % Merge surfaces
    [TessFile32K, iSurface]             = tess_concatenate({BstTessLhFile, BstTessRhFile}, sprintf('cortex_%dV', nVertOrigL + nVertOrigR), 'Cortex');
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
end
end