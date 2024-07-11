function [frame]=loadedROICheck(roistruct,trackrange,roifound)
%% Check if loaded ROIs cover the whole range of tracked ROIs
%Inputs:
%roistruct (struct): consists of rois denoting the vertices of top and
%bottom aponeuroses
%trackrange (1xkeyframes(end,end)-keyframes(1,1) double): the frames being processed
%roifound (1 or 0): denotes whether a previously generated ROI file was
%found and loaded in

%Outputs:
%frame (double): the frame the tracker should load when it opens the GUI.

frame=0;
if roifound==1
    %Check for untracked frames within keyframe range
    for i=trackrange
        if mean(roistruct.roi(i,8))==0
            frame=i;
            break
        end
    end
    
    if frame~=0 %ROI found, and there are untracked frames within keyframe range
        frame=i;
    else %ROI found, and there are no untracked frames within keyframe range
        frame=trackrange(1);
    end
    
else %ROI was not found
    frame=trackrange(1);
end


end