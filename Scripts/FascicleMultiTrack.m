function [outfile,repfas_out]=FascicleMultiTrack(trackrange,vidarr,BWui8,outfile,rois,data,params)
%% Function to track a single frame of ultrasound as part of the main tracker application
%Inputs:
%trackrange (1xkeyframes(end,end)-keyframes(1,1) double): the frames being processed
%vidarr (mxnxframes uint8): the array of all frames to be processed,
%without any preprocessing
%BWui8 (mxnxframes uint8): the array of all frames to be processed after
%having gone through preprocessing to binarize the image
%outfile (struct): struct with stored data about objects identified as snippets of fascicles
%rois (framesx8 double): array of coordinates specifying vertices of top
%and bottom aponeuroses together. For each row, the convention is
%x_bottom_left, x_bottom_right, x_top_right, x_top_left, y_bottom_left, y_bottom_right, y_top_right, y_top_left,
%USdata (struct): ultrasound data from running TVD2mat conversion as found
%in video conversion tools on the Ultratrack website (https://sites.google.com/site/ultratracksoftware/file-cabinet)
%params (struct): tracker parameters

%Outputs:
%outfile (struct): struct with stored data about objects identified as snippets of fascicles
%repfas_out (length(trackrange)x4 double): used for visualizing representative fascicle

repfas_out=zeros(length(trackrange),4);
prog=0;
wb=waitbar(prog,'Processing fascicles');%Parameters

for v=1:length(trackrange)
    waitbar((v-1)/length(trackrange),wb,['Fascicle Processing ' num2str(round((v-1)/length(trackrange).*100)) '% Complete']);
    frame=trackrange(v);
    [outfile,repfas_out(frame,1:4)]=FascicleSingleTrack(frame,vidarr,BWui8,outfile,rois,data,params);
end

delete(wb)
end