function [outfile,repfas_out]=FascicleSingleTrack(frame,vidarr,BWui8,outfile,rois,USdata,params)
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

outfile(frame).maskedImage=pix2;

if isempty(idx) %All w are 0 when objects fulfilling criteria were recognized
    outfile(frame).repfas_len=NaN;
    outfile(frame).repfas_pen=NaN;
    outfile(frame).thickness=NaN;   
    outfile(frame).thickness_noang=NaN;   
    outfile(frame).bot_ang=NaN;
    outfile(frame).top_ang=NaN;
    outfile(frame).time=USdata.TVDdata.Time(frame);
    repfas_out=[NaN NaN NaN NaN];
else

    
stats=stats(idx);

%Can use this to plot selected objects
% labelscc=labelmatrix(cc);
% imageOut=zeros(size(labelscc));
% for p=1:size(imageOut,1)
%     for pp=1:size(imageOut,2)
%         if ismember(labelscc(p,pp),idx)
%             imageOut(p,pp)=1;
%         end
%     end
% end
% figure;
% hold on
% B=imoverlay(pix2,imageOut,'red');
% imshow(B);

%Identify snippet angles that fulfill pennation criteria
snippet_angles=-[stats.Orientation]+bot_ang;
snippet_lengths=[stats.MajorAxisLength];

%Weight those pennation angles by their lengths
w= snippet_lengths./sum(snippet_lengths);

%Calculate representative fascicle pennation angle as weighted average by
%snippet length. Use circular statistics because average of angles are
%non-euclidean

repfas_pen = rad2deg(angle(sum(w.*exp(1i*deg2rad(snippet_angles)),2)));
% repfas_pen = w*snippet_angles';



%% Calculate thickness of muscle

%get x coordinate of midpoint of image
xint_mid=round(c/2);

%get vertices defining superficial and deep aponeuroses
xs=rois(frame,1:4);
ys=rois(frame,5:8);

%Generate polyfits of superficial and deep aponeuroses
p_bottom=polyfit([xs(1) xs(2)],[ys(1) ys(2)],1);%polyfit of bottom apo
p_top=polyfit([xs(3) xs(4)],[ys(3) ys(4)],1); %polyfit of top apo

bot_ang=-atand(p_bottom(1)); %counterclockwise angle between horizontal and bottom aponeurosis
top_ang=-atand(p_top(1)); %counterclockwise angle between horizontal and top aponeurosis

xint=xint_mid;
yint=p_bottom(1)*xint_mid+p_bottom(2);%y coordinate of intersection point of thickness line and bottom aponeurosis

yint_topapo=p_top(1)*xint_mid+p_top(2);%y coordinate of middle of top apo


%calculate polyfit of thickness line - this runs perpendicular from
%deep aponeurosis
p_thick(1)=-1/p_bottom(1);
p_thick(2)=-(-1/p_bottom(1))*xint+yint;

%calculate intersection point between thickness polyfit and
%top apo polyfit
xint_top=(p_top(2)-p_thick(2))/(p_thick(1)-p_top(1));
yint_top=p_thick(1)*xint_top+p_thick(2);

%This will plot the thickness lines. Can overlay over an actual image
% line([xint xint_top],[yint yint_top]);

%Thickness of muscle in pixels
thickness_px=sqrt((xint_top-xint)^2+(yint_top-yint)^2);

%Thickness of muscle in mm
thickness=thickness_px.*mm2pix;

%Thickness at midpoint of image - not based on deep apo angle
thickness_noang=abs(yint_topapo-yint).*mm2pix;


%% Output info for frame
%Representative fascicle length calculated as thickness/sin(pennation) as
%in van der Zee et al. 2022
repfas_len=thickness./sind(repfas_pen);

%% Saving outputs and generating outputs for visualizing fascicle

outfile(frame).repfas_len=repfas_len;
outfile(frame).repfas_pen=repfas_pen;
outfile(frame).thickness=thickness;
outfile(frame).thickness_noang=thickness_noang;
outfile(frame).bot_ang=bot_ang;
outfile(frame).top_ang=top_ang;
outfile(frame).time=USdata.TVDdata.Time(frame);

mid_xint=xint_mid;
mid_yint_bot=p_bottom(1)*mid_xint+p_bottom(2);
mid_yint_top=p_top(1)*mid_xint+p_top(2);
mid_yint=mean([mid_yint_bot mid_yint_top]);

%For plotting the representative fascicle
%Go from pennation to absolute angle
repfas_angle=-(repfas_pen-bot_ang);
repfas_slope=-tand(repfas_angle); %Negate because y is downward for image

cr=-repfas_slope*mid_xint+mid_yint;

%Generate line that uses repfas slope and crosses through middle of
%image
repfas_out=[0,c,cr,repfas_slope*600+cr];
%     line([0,c],[cr,repfas_slope*600+cr],'LineWidth',5)
end
end



