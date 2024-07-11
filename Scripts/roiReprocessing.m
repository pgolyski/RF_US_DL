function [outfile, repfas]=roiReprocessing(endframe,USdata,trackrange,vidarr,BWui8,rois,roifound,params)
%% Function to process fascicle information for a trial based on the ROI data
%Inputs:
%endframe (double): the last frame of the trial to be processed
%USdata (struct): ultrasound data from running TVD2mat conversion as found
%in video conversion tools on the Ultratrack website (https://sites.google.com/site/ultratracksoftware/file-cabinet)
%trackrange (1xkeyframes(end,end)-keyframes(1,1) double): the frames being processed
%vidarr (mxnxframes uint8): the array of all frames to be processed,
%without any preprocessing
%BWui8 (mxnxframes uint8): the array of all frames to be processed after
%having gone through preprocessing to binarize the image
%outfile (struct): struct with stored data about objects identified as snippets of fascicles
%rois (framesx8 double): array of coordinates specifying vertices of top
%and bottom aponeuroses together. For each row, the convention is
%x_bottom_left, x_bottom_right, x_top_right, x_top_left, y_bottom_left, y_bottom_right, y_top_right, y_top_left,
%params (struct): tracker parameters

%Outputs:
%outfile (struct): struct with stored data about objects identified as snippets of fascicles
%repfas_out (length(trackrange)x4 double): used for visualizing representative fascicle



%Generate output structure and if roi already exists, process fascicles
outfile=struct;
repfas=zeros(endframe,4);

if roifound==0
    for i=1:endframe
        outfile(i).repfas_len=NaN;
        outfile(i).repfas_pen=NaN;
        outfile(i).thickness=NaN;
        outfile(i).thickness_noang=NaN;
        outfile(i).bot_ang=NaN;
        outfile(i).top_ang=NaN;
        outfile(i).time=USdata.TVDdata.Time(i);
    end
else
    for i=1:trackrange(1)
        outfile(i).repfas_len=NaN;
        outfile(i).repfas_pen=NaN;
        outfile(i).thickness=NaN;
        outfile(i).thickness_noang=NaN;
        outfile(i).bot_ang=NaN;
        outfile(i).top_ang=NaN;
        outfile(i).time=USdata.TVDdata.Time(i);
    end
    

    [outfile,repfas_trackframes]=FascicleMultiTrack(trackrange,vidarr,BWui8,outfile,rois,USdata,params);
    repfas(trackrange,:)=repfas_trackframes(trackrange,:);
end

end