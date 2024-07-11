function FascicleSingleTrack_Visualize(frame,vidarr,BWui8,rois,params)
%% Function to track a single frame of ultrasound as part of the main tracker application
%Inputs:
%Frame (int): the frame number being processed
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
%repfas_out (1x4 double): used for visualizing representative fascicle

%Parameters
mm2pix=params.mm2pix;

%Calculates image size based on first frame
[r,c]  = size(vidarr(:,:,1));

%use rois from converted or hand tracked
[bw, xi2, yi2] = roipoly(vidarr(:,:,frame),rois(frame,1:4),rois(frame,5:8)); %verticies of ROI polygon

%polyfit of deep aponeurosis
p_bottom=polyfit([xi2(1) xi2(2)],[yi2(1) yi2(2)],1);

bot_ang=-atand(p_bottom(1)); %counterclockwise angle between horizontal and bottom aponeurosis

%
pix2 = BWui8(:,:,frame) .* (im2uint8(bw) ./ 255);
pix2 = reshape(pix2,r,c);


%Get snippet information using regionprops
cc = bwconncomp(pix2);
stats=regionprops(cc,'Orientation','MajorAxisLength','Area');

%Find indices of objects that fall within selected pennation range
idx = find(-[stats.Orientation]+bot_ang > params.pennationRange(1) & -[stats.Orientation]+bot_ang < params.pennationRange(2) & [stats.Area]./[stats.MajorAxisLength] < params.areaLengthRatio & [stats.MajorAxisLength] > params.minLength);


if isempty(idx) %All w are 0 when objects fulfilling criteria were recognized
disp('No snippets identified on this test frame')
else

    
stats=stats(idx);

% Can use this to plot selected objects
labelscc=labelmatrix(cc);
imageOut=zeros(size(labelscc));
for p=1:size(imageOut,1)
    for pp=1:size(imageOut,2)
        if ismember(labelscc(p,pp),idx)
            imageOut(p,pp)=1;
        end
    end
end
figure;
hold on
B=imoverlay(pix2,imageOut,'red');
imshow(B);


end
end



