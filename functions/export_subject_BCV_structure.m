function [] = export_subject_BCV_structure(selected_data_set,subID)

%%
%% Get Protocol information
%%
% try
ProtocolInfo = bst_get('ProtocolInfo');
% Get subject directory
sSubject = bst_get('Subject', subID);
[sStudies, iStudies] = bst_get('StudyWithSubject', sSubject.FileName);
if(~isempty(iStudies))
else
    [sStudies, iStudies] = bst_get('StudyWithSubject', sSubject.FileName, 'intra_subject');
end
sStudy = bst_get('Study', iStudies);
if(isempty(sSubject) || isempty(sSubject.iAnatomy) || isempty(sSubject.iCortex) || isempty(sSubject.iInnerSkull) || isempty(sSubject.iOuterSkull) || isempty(sSubject.iScalp))
    return;
end
bcv_path = selected_data_set.bcv_config.export_path;
if(~isfolder(bcv_path))
    mkdir(bcv_path);
end

%% Uploding Subject file into BrainStorm Protocol
disp('BST-P ->> Uploading Subject file into BrainStorm Protocol.');

% process_waitbar = waitbar(0,strcat('Importing data subject: ' , subject_name ));
%%
%% Genering leadfield file
%%

disp ("-->> Genering leadfield file");
HeadModels = struct;
for h=1: length(sStudy.HeadModel)
    HeadModelFile = fullfile(ProtocolInfo.STUDIES,sStudy.HeadModel(h).FileName);
    HeadModel = load(HeadModelFile);
    
    HeadModels(h).Comment = sStudy.HeadModel(h).Comment;
    HeadModels(h).Ke = HeadModel.Gain;
    HeadModels(h).GridOrient = HeadModel.GridOrient;
    HeadModels(h).GridAtlas = HeadModel.GridAtlas;
end

%%
%% Genering surf file
%%
disp ("-->> Genering surf file");
% Loadding FSAve templates
FSAve_64k               = load('templates/FSAve_cortex_64k.mat');
fsave_inds_template     = load('templates/FSAve_64k_8k_coregister_inds.mat');

% Loadding subject surfaces
CortexFile64K           = sSubject.Surface(1).FileName;
BSTCortexFile64K        = bst_fullfile(ProtocolInfo.SUBJECTS, CortexFile64K);
Sc64k                   = load(BSTCortexFile64K);
CortexFile8K            = sSubject.Surface(2).FileName;
BSTCortexFile8K         = bst_fullfile(ProtocolInfo.SUBJECTS, CortexFile8K);
Sc8k                    = load(BSTCortexFile8K);
% CortexFile              = sSubject.Surface(sSubject.iCortex).FileName;
% BSTCortexFile           = bst_fullfile(ProtocolInfo.SUBJECTS, CortexFile);
% Sc                      = load(BSTCortexFile);

% Finding near FSAve vertices on subject surface
sub_to_FSAve = find_interpolation_vertices(Sc64k,Sc8k, fsave_inds_template);

%%
%% Genering Channels file
%%
disp ("-->> Genering channels file");
BSTChannelsFile = bst_fullfile(ProtocolInfo.STUDIES,sStudy.Channel(sStudy.iChannel).FileName);
Cdata = load(BSTChannelsFile);

%%
%% Genering scalp file
%%
disp ("-->> Genering scalp file");
ScalpFile      = sSubject.Surface(sSubject.iScalp).FileName;
BSTScalpFile = bst_fullfile(ProtocolInfo.SUBJECTS, ScalpFile);
Sh = load(BSTScalpFile);

%%
%% Genering inner skull file
%%
disp ("-->> Genering inner skull file");
InnerSkullFile = sSubject.Surface(sSubject.iInnerSkull).FileName;
BSTInnerSkullFile = bst_fullfile(ProtocolInfo.SUBJECTS, InnerSkullFile);
Sinn = load(BSTInnerSkullFile);

%%
%% Genering outer skull file
%%
disp ("-->> Genering outer skull file");
OuterSkullFile = sSubject.Surface(sSubject.iOuterSkull).FileName;
BSTOuterSkullFile = bst_fullfile(ProtocolInfo.SUBJECTS, OuterSkullFile);
Sout = load(BSTOuterSkullFile);

%% Creating subject folder structure
disp(strcat("-->> Saving BC-VARETA structure. Subject: ",sSubject.Name));
[output_subject_dir] = create_data_structure(bcv_path,sSubject.Name,selected_data_set.modality);
subject_info = struct;

if(isfolder(output_subject_dir))
    leadfield_dir = struct;
    for h=1:length(HeadModels)
        HeadModel = HeadModels(h);
        if(isequal(HeadModel.Comment,'Overlapping spheres'))
            dir = replace(fullfile('leadfield','os_leadfield.mat'),'\','/');
            leadfield_dir(h).path = dir;
        end
        if(isequal(HeadModel.Comment,'Single sphere'))
            dir = replace(fullfile('leadfield','ss_leadfield.mat'),'\','/');
            leadfield_dir(h).path = dir;
        end
        if(isequal(HeadModel.Comment,'OpenMEEG BEM'))
            dir = replace(fullfile('leadfield','om_leadfield.mat'),'\','/');
            leadfield_dir(h).path = dir;
        end
    end
    subject_info.leadfield_dir = leadfield_dir;
    dir = replace(fullfile('surf','surf.mat'),'\','/');
    subject_info.surf_dir = dir;
    dir = replace(fullfile('scalp','scalp.mat'),'\','/');
    subject_info.scalp_dir = dir;
    dir = replace(fullfile('scalp','innerskull.mat'),'\','/');
    subject_info.innerskull_dir = dir;
    dir = replace(fullfile('scalp','outerskull.mat'),'\','/');
    subject_info.outerskull_dir = dir;
    subject_info.modality = selected_data_set.modality;
    subject_info.name = sSubject.Name;
end

%%
%% Genering eeg file
%%
if(isfield(selected_data_set, 'preprocessed_eeg'))
    if(~isequal(selected_data_set.preprocessed_eeg.base_path,'none'))
        filepath = strrep(selected_data_set.preprocessed_eeg.file_location,'SubID',subID);
        base_path =  strrep(selected_data_set.preprocessed_eeg.base_path,'SubID',subID);
        eeg_file = fullfile(base_path,filepath);
        if(isfile(eeg_file))
            disp ("-->> Genering eeg file");
            [hdr, data] = import_eeg_format(eeg_file,selected_data_set.preprocessed_eeg.format); 
            if(~isequal(selected_data_set.process_import_channel.channel_label_file,"none"))
                user_labels = jsondecode(fileread(selected_data_set.process_import_channel.channel_label_file));
                disp ("-->> Cleanning EEG bad Channels by user labels");
                [data,hdr]  = remove_eeg_channels_by_labels(user_labels,data,hdr);
            end
            labels = hdr.label;
            labels = strrep(labels,'REF','');            
            for h=1:length(HeadModels)
                HeadModel = HeadModels(h);
                disp ("-->> Removing Channels  by preprocessed EEG");
                [Cdata_r,Ke] = remove_channels_and_leadfield_from_layout(labels,Cdata,HeadModel.Ke);
                disp ("-->> Sorting Channels and LeadField by preprocessed EEG");
                [Cdata_s,Ke] = sort_channels_and_leadfield_by_labels(labels,Cdata_r,Ke);
                HeadModels(h).Ke = Ke;
            end
            Cdata = Cdata_s;
            dir = replace(fullfile('eeg','eeg.mat'),'\','/');
            subject_info.eeg_dir = dir;
            dir = replace(fullfile('eeg','eeg_info.mat'),'\','/');
            subject_info.eeg_info_dir = dir;
            disp ("-->> Saving eeg_info file");
            save(fullfile(output_subject_dir,'eeg','eeg_info.mat'),'hdr');
            disp ("-->> Saving eeg file");
            save(fullfile(output_subject_dir,'eeg','eeg.mat'),'data');
        end
    end
end
if(isfield(selected_data_set, 'preprocessed_meg'))
    if(~isequal(selected_data_set.preprocessed_meg.base_path,'none'))
        filepath = strrep(selected_data_set.preprocessed_meg.file_location,'SubID',subID);
        base_path =  strrep(selected_data_set.preprocessed_meg.base_path,'SubID',subID);
        meg_file = fullfile(base_path,filepath);
        if(isfile(meg_file))
            disp ("-->> Genering meg file");
            meg = load(meg_file);
            hdr = meg.data.hdr;
            fsample = meg.data.fsample;
            trialinfo = meg.data.trialinfo;
            grad = meg.data.grad;
            time = meg.data.time;
            label = meg.data.label;
            cfg = meg.data.cfg;
            %                 labels = strrep(labels,'REF','');
            for h=1:length(HeadModels)
                HeadModel = HeadModels(h);
                disp ("-->> Removing Channels  by preprocessed MEG");
                [Cdata_r,Ke] = remove_channels_and_leadfield_from_layout(label,Cdata,HeadModel.Ke);
                disp ("-->> Sorting Channels and LeadField by preprocessed MEG");
                [Cdata_s,Ke] = sort_channels_and_leadfield_by_labels(label,Cdata_r,Ke);
                HeadModels(h).Ke = Ke;
            end
            Cdata = Cdata_s;
            
            data = [meg.data.trial];
            trials = meg.data.trial;
            
            dir = replace(fullfile('meg','meg.mat'),'\','/');
            subject_info.meg_dir = dir;
            dir = replace(fullfile('meg','meg_info.mat'),'\','/');
            subject_info.meg_info_dir = dir;
            dir = replace(fullfile('meg','trials.mat'),'\','/');
            subject_info.trials_dir = dir;
            disp ("-->> Saving meg_info file");
            save(fullfile(output_subject_dir,'meg','meg_info.mat'),'hdr','fsample','trialinfo','grad','time','label','cfg');
            disp ("-->> Saving meg file");
            save(fullfile(output_subject_dir,'meg','meg.mat'),'data');
            disp ("-->> Saving meg trials file");
            save(fullfile(output_subject_dir,'meg','trials.mat'),'trials');
        end
    end
end

for h=1:length(HeadModels)
    Comment     = HeadModels(h).Comment;
    Ke          = HeadModels(h).Ke;
    GridOrient  = HeadModels(h).GridOrient;
    GridAtlas   = HeadModels(h).GridAtlas;
    disp ("-->> Saving leadfield file");
    if(isequal(Comment,'Overlapping spheres'))
        save(fullfile(output_subject_dir,'leadfield','os_leadfield.mat'),'Comment','Ke','GridOrient','GridAtlas');
    end
    if(isequal(Comment,'Single sphere'))
        save(fullfile(output_subject_dir,'leadfield','ss_leadfield.mat'),'Comment','Ke','GridOrient','GridAtlas');
    end
    if(isequal(HeadModel.Comment,'OpenMEEG BEM'))
        save(fullfile(output_subject_dir,'leadfield','om_leadfield.mat'),'Comment','Ke','GridOrient','GridAtlas');
    end
end
disp ("-->> Saving surf file");
save(fullfile(output_subject_dir,'surf','surf.mat'),'Sc64k','Sc8k','sub_to_FSAve');
disp ("-->> Saving scalp file");
save(fullfile(output_subject_dir,'scalp','scalp.mat'),'Cdata','Sh');
disp ("-->> Saving inner skull file");
save(fullfile(output_subject_dir,'scalp','innerskull.mat'),'Sinn');
disp ("-->> Saving outer skull file");
save(fullfile(output_subject_dir,'scalp','outerskull.mat'),'Sout');
disp ("-->> Saving subject file");
save(fullfile(output_subject_dir,'subject.mat'),'subject_info');

% waitbar(0.25,process_waitbar,strcat('Genering eeg file for: ' , subject_name ));
% waitbar(0.5,process_waitbar,strcat('Genering leadfield file for: ' , subject_name ));
%  -------- Genering scalp file -------------------------------
%delete(process_waitbar);
% catch exception
%     brainstorm stop;
%     fprintf(2,strcat("\n -->> Protocol stoped \n"));
%     msgText = getReport(exception);
%     fprintf(2,strcat("\n -->> ", string(msgText), "\n"));
% end


end

