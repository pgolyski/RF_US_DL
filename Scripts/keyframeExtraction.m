function [trackrange,keyframes,endframe]=keyframeExtraction(file,KeyframeStruct)
%% This script is particular to this study design and will have to be changed depending on how you use keyframes

%% Function that pulls keyframes of an ultrasound file from USMasterStruct
%Inputs: file (string): the name of the .mat of ultrasound data being
%processed
%KeyframeStruct (struct): the struct containing keyframes to be parsed

%Outputs: trackrange (1xkeyframes(2)-keyframes(1) double): a vector of all
%the frames to be processed

[Sub,id,slip_side,slip_timing,iter]=nameParser(file); %Detects trials conditions from trial name


if strcmp(id,'slip')%for slips, track from 5 frames before first contralateral footstrike to end of ips stride +2
    trackrange=(KeyframeStruct.(Sub).(id).(slip_side).(slip_timing).(iter).Footstrikes.FS_C_sel_US(1)-5):KeyframeStruct.(Sub).(id).(slip_side).(slip_timing).(iter).Footstrikes.FS_I_sel_US(5);
    keyframes=keyframeRestructure(KeyframeStruct.(Sub).(id).(slip_side).(slip_timing).(iter).Footstrikes.FS_I_sel_US(1:5),id);
else %for walking/running, track from first right footstrike
    trackrange=(KeyframeStruct.(Sub).(id).(slip_side).(slip_timing).(iter).Footstrikes.FS_R_sel_US(1,1)):KeyframeStruct.(Sub).(id).(slip_side).(slip_timing).(iter).Footstrikes.FS_R_sel_US(end,2);
    keyframes=keyframeRestructure(KeyframeStruct.(Sub).(id).(slip_side).(slip_timing).(iter).Footstrikes.FS_R_sel_US,id);
end


endframe=keyframes(end);

end