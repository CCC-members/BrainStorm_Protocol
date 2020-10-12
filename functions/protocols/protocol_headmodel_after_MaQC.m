function protocol_headmodel_after_MaQC()
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
% Author: Francois Tadel, 2014-2016
%
%
% Updaters:
% - Ariosky Areces Gonzalez
% - Deirel Paz Linares

%%
%% Preparing selected protocol
%%
load('tools/mycolormap');
app_properties = jsondecode(fileread(strcat('app',filesep,'app_properties.json')));
selected_data_set = jsondecode(fileread(strcat('config_protocols',filesep,app_properties.selected_data_set.file_name)));

new_bst_DB = selected_data_set.bst_db_path;
bst_set('BrainstormDbDir', new_bst_DB);

gui_brainstorm('UpdateProtocolsList');
nProtocols = db_import(new_bst_DB);

%getting existing protocols on DB
ProtocolFiles = dir(fullfile(new_bst_DB,'**','protocol.mat'));

for i=1:length(ProtocolFiles)
    Protocol = load(fullfile(ProtocolFiles(i).folder,ProtocolFiles(i).name));   
    ProtocolName = Protocol.ProtocolInfo.Comment;
    iProtocol = bst_get('Protocol', ProtocolName);
    gui_brainstorm('SetCurrentProtocol', iProtocol);
    ProtocolInfo = bst_get('ProtocolInfo');
    subjects = bst_get('ProtocolSubjects');
    for j=1:length(subjects.Subject)
        sSubject = subjects.Subject(j);     
        subID = sSubject.Name;
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
        %%
        %%
        
        % subjects_list = bst_get('ProtocolSubjects');
        
        %%
        %% Quality control
        %%
        % Get MRI file and surface files
        if(isempty(sSubject) || isempty(sSubject.iAnatomy) || isempty(sSubject.iCortex) || isempty(sSubject.iInnerSkull) || isempty(sSubject.iOuterSkull) || isempty(sSubject.iScalp))
            return;
        end
        % Start a new report
        bst_report('Start',['Protocol for subject:' , subID]);
        bst_report('Info',    '', [], ['Protocol for subject:' , subID]);
        
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
        %% Quality control
        %%
        % Get subject definition and subject files
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
        close(hFigMri4);
        %
        hFigMri5  = script_view_contactsheet( hFigMriSurf, 'volume', 'y','');
        bst_report('Snapshot',hFigMri5,MriFile,'Cortex - MRI registration Coronal view', [200,200,750,475]);
        saveas( hFigMri5,fullfile(subject_report_path,'Cortex - MRI registration Coronal view.fig'));
        close(hFigMri5);
        %
        hFigMri6  = script_view_contactsheet( hFigMriSurf, 'volume', 'z','');
        bst_report('Snapshot',hFigMri6,MriFile,'Cortex - MRI registration Sagital view', [200,200,750,475]);
        saveas( hFigMri6,fullfile(subject_report_path,'Cortex - MRI registration Sagital view.fig'));        
        close([hFigMriSurf hFigMri6]);
        
        %
        hFigMri7 = view_mri(MriFile, ScalpFile);
        bst_report('Snapshot',hFigMri7,MriFile,'Scalp registration', [200,200,750,475]);
        saveas( hFigMri7,fullfile(subject_report_path,'Scalp registration.fig'));
        close(hFigMri7);
        %
        hFigMri8 = view_mri(MriFile, OuterSkullFile);
        bst_report('Snapshot',hFigMri8,MriFile,'Outer Skull - MRI registration', [200,200,750,475]);
        saveas( hFigMri8,fullfile(subject_report_path,'Outer Skull - MRI registration.fig'));
        close(hFigMri8);
        %
        hFigMri9 = view_mri(MriFile, InnerSkullFile);
        bst_report('Snapshot',hFigMri9,MriFile,'Inner Skull - MRI registration', [200,200,750,475]);
        saveas( hFigMri9,fullfile(subject_report_path,'Inner Skull - MRI registration.fig'));        
        % Closing figures
        close(hFigMri9);
        
        %        
        % Top
        hFigSurf10 = view_surface(CortexFile);
        bst_report('Snapshot',hFigSurf10,[],'Cortex mesh 3D top view', [200,200,750,475]);
        saveas( hFigSurf10,fullfile(subject_report_path,'Cortex mesh 3D view.fig'));
        % Bottom
        view(90,270)
        bst_report('Snapshot',hFigSurf10,[],'Cortex mesh 3D bottom view', [200,200,750,475]);
        %Left
        view(1,180)
        bst_report('Snapshot',hFigSurf10,[],'Cortex mesh 3D left hemisphere view', [200,200,750,475]);
        % Right
        view(0,360)
        bst_report('Snapshot',hFigSurf10,[],'Cortex mesh 3D right hemisphere view', [200,200,750,475]);
        % Closing figure
        close(hFigSurf10);
        
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
        % Closing figure
        close(hFigSurf11);
        
        %%
        %% Quality control
        %%
        hFigMri15 = view_mri(MriFile, ScalpFile);
        bst_report('Snapshot',hFigMri15,[],'SPM Scalp Envelope - MRI registration', [200,200,750,475]);
        saveas( hFigMri15,fullfile(subject_report_path,'SPM Scalp Envelope - MRI registration.fig'));
        % Close figures        
        close(hFigMri15);
        
        %%
        %% Quality control
        %%
        % View sources on MRI (3D orthogonal slices)
        iStudies = bst_get('ChannelStudiesWithSubject', j);        
        sStudy = bst_get('Study', iStudies);
        
        BSTChannelsFile = bst_fullfile(ProtocolInfo.STUDIES,sStudy.Channel(1).FileName);
%         BSTChannelsFile = bst_fullfile(ProtocolInfo.STUDIES,subID,'@raw5-Restin_c_rfDC','channel_10-20_19.mat');
                
        hFigMri16      = script_view_mri_3d(MriFile, [], [], [], 'front');
        hFigMri16      = view_channels(BSTChannelsFile, 'EEG', 1, 0, hFigMri16, 1);
        bst_report('Snapshot',hFigMri16,[],'Sensor-MRI registration front view', [200,200,750,475]);
        saveas( hFigMri16,fullfile(subject_report_path,'Sensor-MRI registration view.fig'));
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
        hFigMri20      = script_view_surface(ScalpFile, [], [], [],'front');
        hFigMri20      = view_channels(BSTChannelsFile, 'EEG', 1, 0, hFigMri20, 1);
        bst_report('Snapshot',hFigMri20,[],'Sensor-Scalp registration front view', [200,200,750,475]);
        saveas( hFigMri20,fullfile(subject_report_path,'Sensor-Scalp registration view.fig'));
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
        %% Quality control
        %%
        %%        
        hFigSurf24 = view_surface(CortexFile);
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
        
        % Get subject definition and subject files
        
        %%
        %% Get Protocol information
        %%       
        headmodel_options = struct();
        headmodel_options.Comment = 'OpenMEEG BEM';
        headmodel_options.HeadModelFile = bst_fullfile(ProtocolInfo.STUDIES,sSubject.Name,sStudy.Name);
        headmodel_options.HeadModelType = 'surface';        
        % Uploading Channels        
        BSTChannels = load(BSTChannelsFile);
        headmodel_options.Channel = BSTChannels.Channel;
        headmodel_options.MegRefCoef = [];
        headmodel_options.MEGMethod = '';
        headmodel_options.EEGMethod = 'openmeeg';
        headmodel_options.ECOGMethod = '';
        headmodel_options.SEEGMethod = '';
        headmodel_options.HeadCenter = [];
        headmodel_options.Radii = [0.88,0.93,1];
        headmodel_options.Conductivity = [0.33,0.0042,0.33];
        headmodel_options.SourceSpaceOptions = [];        
        % Uploading cortex        
        headmodel_options.CortexFile = CortexFile;        
        % Uploading head        
        headmodel_options.HeadFile = ScalpFile;        
         % Uploading InnerSkull
        headmodel_options.InnerSkullFile = InnerSkullFile;        
       % Uploading OuterSkull
        headmodel_options.OuterSkullFile =  OuterSkullFile;
        headmodel_options.GridOptions = [];
        headmodel_options.GridLoc  = [];
        headmodel_options.GridOrient  = [];
        headmodel_options.GridAtlas  = [];
        headmodel_options.Interactive  = true;
        headmodel_options.SaveFile  = true;
        
        % BEM params
        BSTScalpFile = bst_fullfile(ProtocolInfo.SUBJECTS, ScalpFile);
        BSTOuterSkullFile = bst_fullfile(ProtocolInfo.SUBJECTS, OuterSkullFile);
        BSTInnerSkullFile = bst_fullfile(ProtocolInfo.SUBJECTS, InnerSkullFile);
        headmodel_options.BemFiles = {BSTScalpFile, BSTOuterSkullFile,BSTInnerSkullFile};
        headmodel_options.BemNames = {'Scalp','Skull','Brain'};
        headmodel_options.BemCond = [1,0.0125,1];
        headmodel_options.iMeg = [];
        headmodel_options.iEeg = 1:length(BSTChannels.Channel);
        headmodel_options.iEcog = [];
        headmodel_options.iSeeg = [];
        headmodel_options.BemSelect = [true,true,true];
        headmodel_options.isAdjoint = false;
        headmodel_options.isAdaptative = true;
        headmodel_options.isSplit = false;
        headmodel_options.SplitLength = 4000;
        
        
        %%
        %% Recomputing Head Model
        %%
        [headmodel_options, errMessage] = bst_headmodeler(headmodel_options);
        
        if(~isempty(headmodel_options))
            sStudy = bst_get('Study', iStudies);
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
            bst_set('Study', iStudies, sStudy);
            db_save();
            
            %%
            %% Quality control
            %%            
            BSTCortexFile = bst_fullfile(ProtocolInfo.SUBJECTS, headmodel_options.CortexFile);
            cortex = load(BSTCortexFile);
            
            head = load(BSTScalpFile);
            
            % Uploading Gain matrix
            BSTHeadModelFile = bst_fullfile(headmodel_options.HeadModelFile);
            BSTHeadModel = load(BSTHeadModelFile);
            Ke = BSTHeadModel.Gain;
            
            % Uploading Channels Loc
            channels = [headmodel_options.Channel.Loc];
            channels = channels';
            
            %%
            %% Checking LF correlation
            %%
            [Ne,Nv]=size(Ke);
            Nv= Nv/3;
            VoxelCoord=cortex.Vertices;
            VertNorms=cortex.VertNormals;
            
            %computing homogeneous lead field
            [Kn,Khom]   = computeNunezLF(Ke,VoxelCoord, channels);
            
            %%
            %% Ploting sensors and sources on the scalp and cortex
            %%
            [hFig25] = view3D_K(Kn,cortex,head,channels,17);
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
            
            
            [hFig26]    = view3D_K(Khom,cortex,head,channels,17);
            bst_report('Snapshot',hFig26,[],'Homogenous field top view', [200,200,750,475]);
            view(0,360)
            saveas( hFig26,fullfile(subject_report_path,'Homogenous field view.fig'));
            
            bst_report('Snapshot',hFig26,[],'Homogenous field right view', [200,200,750,475]);
            view(1,180)
            bst_report('Snapshot',hFig26,[],'Homogenous field left view', [200,200,750,475]);
            view(90,360)
            bst_report('Snapshot',hFig26,[],'Homogenous field front view', [200,200,750,475]);
            view(270,360)
            bst_report('Snapshot',hFig26,[],'Homogenous field back view', [200,200,750,475]);
            % Closing figure
            close(hFig26);
            
            VertNorms   = reshape(VertNorms,[1,Nv,3]);
            VertNorms   = repmat(VertNorms,[Ne,1,1]);
            Kn          = sum(Kn.*VertNorms,3);
            Khom        = sum(Khom.*VertNorms,3);
            
            
            %Homogenous Lead Field vs. Tester Lead Field Plot
            hFig27 = figure;
            scatter(Khom(:),Kn(:));
            title('Homogenous Lead Field vs. Tester Lead Field');
            xlabel('Homogenous Lead Field');
            ylabel('Tester Lead Field');
            bst_report('Snapshot',hFig27,[],'Homogenous Lead Field vs. Tester Lead Field', [200,200,750,475]);
            saveas( hFig27,fullfile(subject_report_path,'Homogenous Lead Field vs. Tester Lead Field.fig'));
            % Closing figure
            close(hFig27);
            
            %computing channel-wise correlation
            for k=1:size(Kn,1)
                corelch(k,1)=corr(Khom(k,:).',Kn(k,:).');
            end
            %plotting channel wise correlation
            hFig28 = figure;
            plot([1:size(Kn,1)],corelch,[1:size(Kn,1)],0.7,'r-');
            xlabel('Channels');
            ylabel('Correlation');
            title('Correlation between both lead fields channel-wise');
            bst_report('Snapshot',hFig28,[],'Correlation between both lead fields channel-wise', [200,200,750,475]);
            saveas( hFig28,fullfile(subject_report_path,'Correlation channel-wise.fig'));
            % Closing figure
            close(hFig28);
            
            zKhom = zscore(Khom')';
            zK = zscore(Kn')';
            %computing voxel-wise correlation
            for k=1:Nv
                corelv(k,1)=corr(zKhom(:,k),zK(:,k));
            end
            corelv(isnan(corelv))=0;
            corr2d = corr2(Khom, Kn);
            %plotting voxel wise correlation
            hFig29 = figure;
            plot([1:Nv],corelv);
            title('Correlation both lead fields Voxel wise');
            bst_report('Snapshot',hFig29,[],'Correlation both lead fields Voxel wise', [200,200,750,475]);
            saveas( hFig29,fullfile(subject_report_path,'Correlation Voxel wise.fig'));
            close(hFig29);
            
                        %%
            %% Finding points of low corelation
            %%     
            low_cor_inds = find(corelv < .3); 
            BSTCortexFile = bst_fullfile(ProtocolInfo.SUBJECTS, headmodel_options.CortexFile);            
            hFig_low_cor = view_surface(BSTCortexFile, [], [], 'NewFigure');         
            hFig_low_cor = view_surface(BSTCortexFile, [], [], hFig_low_cor);           
            % Delete scouts
            delete(findobj(hFig_low_cor, 'Tag', 'ScoutLabel'));
            delete(findobj(hFig_low_cor, 'Tag', 'ScoutMarker'));
            delete(findobj(hFig_low_cor, 'Tag', 'ScoutPatch'));
            delete(findobj(hFig_low_cor, 'Tag', 'ScoutContour'));           
            
            line(cortex.Vertices(low_cor_inds,1), cortex.Vertices(low_cor_inds,2), cortex.Vertices(low_cor_inds,3), 'LineStyle', 'none', 'Marker', 'o',  'MarkerFaceColor', [1 0 0], 'MarkerSize', 6);
            figure_3d('SetStandardView', hFig_low_cor, 'bottom');
            bst_report('Snapshot',hFig_low_cor,[],'Low correlation Voxel', [200,200,750,475]);
            saveas( hFig_low_cor,fullfile(subject_report_path,'Low correlation Voxel.fig'));
            close(hFig_low_cor);
            
            figure_cor = figure;            
            %colormap(gca,cmap);            
            patch('Faces',cortex.Faces,'Vertices',cortex.Vertices,'FaceVertexCData',corelv,'FaceColor','interp','EdgeColor','none','FaceAlpha',.99);
            view(90,270)            
            bst_report('Snapshot',figure_cor,[],'Low correlation map', [200,200,750,475]);
            saveas( figure_cor,fullfile(subject_report_path,'Low correlation Voxel interpolation.fig'));
            close(figure_cor);
           
            %%
            %% Save and display report
            %%
            ReportFile = bst_report('Save', []);
            bst_report('Export',  ReportFile,report_name);
            bst_report('Open', ReportFile);
            bst_report('Close');
            processed = true;
            disp(strcat("-->> Process finished for subject: ", subID));
          
            %%
            %% Export Subject to BC-VARETA
            %%
            if(processed)
                disp(strcat('BC-V -->> Export subject:' , subID, ' to BC-VARETA structure'));
                if(selected_data_set.bcv_config.export)
                    export_subject_BCV_structure(selected_data_set,subID);
                end
            end           
            
            disp(strcat('-->> Subject:' , subID, '. Processing finished.'));
        end
    end
end
