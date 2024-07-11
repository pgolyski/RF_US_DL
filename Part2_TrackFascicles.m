%% App to track ROI by hand and have fascicles automatically detected
%Notes: This was run on Matlab 2022a, need Matlab Signal Processing and
%Image Processing toolboxes
%Author: Pawel Golyski

clear
close all

%Add path to Scripts folder
addpath('Z:\Dropbox (GaTech)\RF\RF_US_DL\Scripts')

%Parameters
params=struct;

%Fibermetric parameters
params.fibermetricThickness=7; %Thickness in pixels of objects to be recognized as fascicles
params.fibermetricStructSensitivity=100; %Sensitivity of fibermetric to identifying objects as fascicles relative to background. This can range between 1 and 255.
%Minimum angle of a snippet, relative to lower aponeurosis - took (mean - 2
%std) from Blazevich 2006, who took images of leg 45 degree knee flexion
%and relaxed and supine. From middle of RF - mean = 13.4 +/- 2*3.6 = 6.2 to
%20.6 degrees
%degrees
params.pennationRange=[6,20];
params.mm2pix=65/580;%mm to pixel ratio to convert from pixels to distance. This is obtained by dividing the image depth from the ultrasound software by the number of rows in the ultrasound images and is dependent on computer resolution.
params.minLength=round(4./params.mm2pix); %Adjusted from Marzilger since pixel to cm ratio is different - and also allowed anything greater than Marzilger's 4 cm threshold
params.areaLengthRatio=12; %Marzilger 2018 was 8.5, but that was missing largest fascicles. Also, I use major axis length, not tip to tip length like Marzilger;
params.fc=6; %Lowpass cutoff frequency for fascicle information (Hz)
params.additionalROIspecification=false; %if you want to manually specify an area of the image from which to extract fascicle information, of which the area between the aponeuroses will automatically be a subset, set this to true. Otherwise uses whole image. 
params.showFilteredBinarizedImage=true; %if you would like to visualize what your fibermetric parameters result in, change this to true and the program will show you a sample image and not run all the way through.
params.showFascicleSelection=false; %if you would like to see what parts of an image are being used for fascicle estimation, set this to true;
params.selectFascicleSelectionFrame=false; %Set this to false if want to visualize first frame within trackrange. Otherwise, you can specify a frame to visualize. The script will throw an error if this is outside the range. Check the command window for the frames that have aponeuroses identified and can be visualized
params.flipImage=false; %if fascicles are not running from top left to bottom right, change this to true

%Load in converted .mat file. The generated ROI file will be saved in an ROI folder at the same level as the Converted folder which holds the .mat files generated from .tvd files.
%Will try to load a previously hand tracked ROI file. Will start tracking at first frame that hasn't been hand tracked but is in range of keyframes
[file,path] = uigetfile('*.mat','Select a Converted US File');
USdata=load([path file]);

%Flip images if set in params
if params.flipImage==true
USdata.TVDdata.Im=fliplr(USdata.TVDdata.Im);
end

%% This section pulls keyframes from an external struct file. Edit as necessary so you can load in keyframes automatically

%This function detects trials conditions from trial name
[Sub,id,slip_side,slip_timing,iter]=nameParser(file);

%Loads in RF_MasterStruct for selected sub
addpath('Z:\Dropbox (GaTech)\RF\RF_US_DL\KeyFrameFiles')
load(['Z:\Dropbox (GaTech)\RF\RF_US_DL\KeyFrameFiles\RF_MasterStruct_' Sub(4:5) '.mat'])


try
    if strcmp(id,'slip')%for slips, track from 5 frames before first contralateral footstrike to end of ips stride +2
        trackrange=(RF_MasterStruct.(Sub).(id).(slip_side).(slip_timing).(iter).Footstrikes.FS_C_sel_US(1)-5):RF_MasterStruct.(Sub).(id).(slip_side).(slip_timing).(iter).Footstrikes.FS_I_sel_US(5);
        keyframes=keyframeRestructure(RF_MasterStruct.(Sub).(id).(slip_side).(slip_timing).(iter).Footstrikes.FS_I_sel_US(1:5),id);
    else %for walking/running, track from first right footstrike
        trackrange=(RF_MasterStruct.(Sub).(id).(slip_side).(slip_timing).(iter).Footstrikes.FS_R_sel_US(1,1)):RF_MasterStruct.(Sub).(id).(slip_side).(slip_timing).(iter).Footstrikes.FS_R_sel_US(end,2);
        keyframes=keyframeRestructure(RF_MasterStruct.(Sub).(id).(slip_side).(slip_timing).(iter).Footstrikes.FS_R_sel_US,id);
    end
catch
    m0=msgbox({'Error loading in keyframes'},'Error');
end

endframe=keyframes(end);

%% Try and load in a previously generated ROI file (which consists of vertices denoting top and bottom aponeuroses). If one is not found, make a blank one

try
    load([strrep(path,'Converted','ROI_DL') file]);
    m1=msgbox({'ROI file found and uploaded'},'Notification');
    roifound=1;
    rois=roistruct.roi;

catch
    m1=msgbox({'ROI file not found'},'Notification');
    roistruct=struct;
    rois=zeros(endframe,8);
    roifound=0;

end

%Process binary masks with adaptive image filter
[angle,vidarr,BWui8]=imagePreProcAndAngleCorrection(USdata,endframe,params);

%Showing a sample frame to ensure fibermetric parameters result in good
%binarization of the image
if params.showFilteredBinarizedImage==true
    imshow(BWui8(:,:,endframe))
    delete(m1)
    error('Evaluate if binarization of image was successful. If it looks good, set params.filttestshow=false')
end

%Calculates image size based on first frame
[r,c]  = size(vidarr(:,:,1));
%Get times of frames of interest
vidtime=USdata.TVDdata.Time(1:endframe);

%Establish what frame tracking should start at by evaluating keyframes
[frame]=loadedROICheck(roistruct,trackrange,roifound);
delete(m1);

%Showing a sample frame to demonstrate what structures are being used to
%generate representative fascicle information
if params.showFascicleSelection
    if params.selectFascicleSelectionFrame
        FascicleSingleTrack_Visualize(frame,vidarr,BWui8,rois,params)
        error('Evaluate if red snippets of fascicles are acceptable for representative fascicle calculation. If so, set params.showFascicleSelection=false')
    else
        FrameToVisualize=inputdlg(['Enter frame you want to visualize. Frames available for visualization are ' num2str(trackrange(1)) ' through ' num2str(trackrange(end))]);
        if str2double(FrameToVisualize{1})<trackrange(1) || str2double(FrameToVisualize{1})>trackrange(end)
            error('Frame for visualizing snippets used for representative fascicle is outside of time range with aponeuroses')
        else
            FascicleSingleTrack_Visualize(str2double(FrameToVisualize{1}),vidarr,BWui8,rois,params)
            error('Evaluate if red snippets of fascicles are acceptable for representative fascicle calculation. If so, set params.showFascicleSelection=false')            
        end
    end
end

%Generate output structure and if roi already exists, process fascicles -
[outfile, repfas]=roiReprocessing(endframe,USdata,trackrange,vidarr,BWui8,rois,roifound,params);

%Message box describing how to use tracker
f = msgbox({'a = go back a frame';'e = calculate fascicle for frame';'w = make new bottom edge of ROI. Make sure you double click the second point!';'d = advance to next frame';'q = interpolate ROI';'g = enter frame you would like to go to in matlab command window';'p = process all frames based off of gait cycle you select';'n = make whole new ROI';'esc = end tracking';'r = process fascicles for all tracked ROI frames';' ';'Tracking will automatically end when get to last frame + 1';'Ensemble averages will be presented when tracking ends'},'Tracking Controls');

%Figure showing fascicle lengths
f1=figure(1);
hold on
xlim([1,keyframes(end)]);
xlabel('Frame')
ylabel('Fascicle Length (mm)')
for ii=(reshape(keyframes,1,[]))
    xline(ii);
end
title('Vertical lines are Keyframes')
x1=1:endframe;
y1=[outfile.repfas_len];
h1=plot(x1,y1,'-ok','LineWidth',1);
set(h1, 'XDataSource', 'x1', 'YDataSource', 'y1')
h2=xline(frame,'Color','red','LineWidth',2);
set(h2, 'Value', frame)

%Figure showing ultrasound image
f3=figure(3);
hold on
hImage=imshow(vidarr(:,:,frame));
Ax=get(hImage,'Parent');
xlim([0 c]);
ylim([0 r]);
title(num2str(frame))
apox=[rois(frame,1) rois(frame,3);rois(frame,2) rois(frame,4)];
apoxt=[rois(frame,1) rois(frame,2)];
apoxb=[rois(frame,3) rois(frame,4)];
apoy=[rois(frame,5) rois(frame,7);rois(frame,6) rois(frame,8)];
apoyt=[rois(frame,5) rois(frame,6)];
apoyb=[rois(frame,7) rois(frame,8)];
hold on
apos=plot(apox,apoy,'LineWidth',3,'LineStyle','-');
set(apos,{'XData'},{apoxt;apoxb},{'YData'},{apoyt;apoyb},{'ZData'},{[2 2];[2 2]},{'color'},{[1 1 0];[0 1 0]},{'LineStyle'},{'-'});
rfx=repfas(frame,1:2);
rfy=repfas(frame,3:4);
hold on
rf=plot(rfx,rfy,'Color','blue','LineWidth',3);
set(rf,  'XData',rfx, 'YData',rfy);

%In case of accidentally erroring out the tracker, this will save your ROI
%tracking progress
try

    while frame<(endframe+1)

        w = waitforbuttonpress;
        if w==1

            key = get(gcf,'currentcharacter');
            switch key

                case 114 % 114 is "r" key
                    %reprocess all frames based on ROIs

                    %Calculate which frames have tracked ROIs
                    framerange=keyframes(1,1):endframe;
                    roicol=rois(framerange,1);
                    roiinds=roicol~=0;
                    roiinds=framerange(roiinds);
                    clear roicol

                    [outfile,repfas_roiinds]=FascicleMultiTrack(roiinds,vidarr,BWui8,outfile,rois,USdata,params);
                    repfas(roiinds,:)=repfas_roiinds(roiinds,:);
                    clear repfas_roiinds

                    figure(1)
                    hold on
                    y1=[outfile.repfas_len];
                    set(h1, 'XData', x1, 'YData', y1)
                    drawnow

                    figure(3)
                    hold on
                    title(num2str(frame))
                    set(hImage,'CData',vidarr(:,:,frame));
                    apoxt=[rois(frame,1) rois(frame,2)];
                    apoxb=[rois(frame,3) rois(frame,4)];
                    apoyt=[rois(frame,5) rois(frame,6)];
                    apoyb=[rois(frame,7) rois(frame,8)];
                    set(apos,{'XData'},{apoxt;apoxb},{'YData'},{apoyt;apoyb},{'ZData'},{[2 2];[2 2]},{'color'},{[1 1 0];[0 1 0]},{'LineStyle'},{'-'});
                    rfx=repfas(frame,1:2);
                    rfy=repfas(frame,3:4);
                    set(rf,  'XData',rfx, 'YData',rfy,'ZData',[2 2],'LineStyle','-');
                    drawnow


                case 97 % 97 is "a" key
                    %go back a frame
                    frame=frame-1;

                    if isnan(outfile(frame).repfas_len)
                        [outfile,repfas(frame,:)]=FascicleSingleTrack(frame,vidarr,BWui8,outfile,rois,USdata,params);
                    end

                    figure(1)
                    hold on
                    set(h2, 'Value', frame)
                    drawnow

                    figure(3)
                    hold on
                    title(num2str(frame))
                    set(hImage,'CData',vidarr(:,:,frame));
                    apoxt=[rois(frame,1) rois(frame,2)];
                    apoxb=[rois(frame,3) rois(frame,4)];
                    apoyt=[rois(frame,5) rois(frame,6)];
                    apoyb=[rois(frame,7) rois(frame,8)];
                    set(apos,{'XData'},{apoxt;apoxb},{'YData'},{apoyt;apoyb},{'ZData'},{[2 2];[2 2]},{'color'},{[1 1 0];[0 1 0]},{'LineStyle'},{'-'});
                    rfx=repfas(frame,1:2);
                    rfy=repfas(frame,3:4);
                    set(rf,  'XData',rfx, 'YData',rfy,'ZData',[2 2],'LineStyle','-');
                    drawnow


                case 119 % 119 is "w" key
                    %Correct bottom edge of roi
                    roiline=drawpolyline(Ax,'Color','red');
                    line_vertices=roiline.Position;
                    delete(Ax.Children(1))

                    if rois(frame,1)~=0 %if roi exists, edit bottom edge
                        rois(frame,:)=rois(frame,1:8);
                        rois(frame,1)=line_vertices(1,1);
                        rois(frame,5)=line_vertices(1,2);
                        rois(frame,2)=line_vertices(2,1);
                        rois(frame,6)=line_vertices(2,2);
                    else % if roi doesn't exist, carry over top from previous frame
                        rois(frame,:)=rois(frame-1,1:8);
                        rois(frame,1)=line_vertices(1,1);
                        rois(frame,5)=line_vertices(1,2);
                        rois(frame,2)=line_vertices(2,1);
                        rois(frame,6)=line_vertices(2,2);
                    end

                    title(num2str(frame))

                    [outfile,repfas(frame,:)]=FascicleSingleTrack(frame,vidarr,BWui8,outfile,rois,USdata,params);

                    figure(1)
                    hold on
                    y1=[outfile.repfas_len];
                    set(h1, 'XData', x1, 'YData', y1)
                    drawnow

                    figure(f3);
                    hold on
                    title(num2str(frame))
                    set(hImage,'CData',vidarr(:,:,frame));
                    apoxt=[rois(frame,1) rois(frame,2)];
                    apoxb=[rois(frame,3) rois(frame,4)];
                    apoyt=[rois(frame,5) rois(frame,6)];
                    apoyb=[rois(frame,7) rois(frame,8)];
                    set(apos,{'XData'},{apoxt;apoxb},{'YData'},{apoyt;apoyb},{'ZData'},{[2 2];[2 2]},{'color'},{[1 1 0];[0 1 0]},{'LineStyle'},{'-'});
                    rfx=repfas(frame,1:2);
                    rfy=repfas(frame,3:4);
                    set(rf,  'XData',rfx, 'YData',rfy,'LineStyle','-');
                    drawnow

                case 117 % 119 is "u" key
                    %Correct top edge of roi
                    roiline=drawpolyline(Ax,'Color','red');
                    line_vertices=roiline.Position;
                    delete(Ax.Children(1))

                    if rois(frame,1)~=0 %if roi exists, edit top edge
                        rois(frame,:)=rois(frame,1:8);
                        rois(frame,4)=line_vertices(1,1);
                        rois(frame,8)=line_vertices(1,2);
                        rois(frame,3)=line_vertices(2,1);
                        rois(frame,7)=line_vertices(2,2);
                    else % if roi doesn't exist, carry over bottom from previous frame
                        rois(frame,:)=rois(frame-1,1:8);
                        rois(frame,4)=line_vertices(1,1);
                        rois(frame,8)=line_vertices(1,2);
                        rois(frame,3)=line_vertices(2,1);
                        rois(frame,7)=line_vertices(2,2);
                    end

                    title(num2str(frame))

                    [outfile,repfas(frame,:)]=FascicleSingleTrack(frame,vidarr,BWui8,outfile,rois,USdata,params);

                    figure(1)
                    hold on
                    y1=[outfile.repfas_len];
                    set(h1, 'XData', x1, 'YData', y1)
                    drawnow

                    figure(f3);
                    hold on
                    title(num2str(frame))
                    set(hImage,'CData',vidarr(:,:,frame));
                    apoxt=[rois(frame,1) rois(frame,2)];
                    apoxb=[rois(frame,3) rois(frame,4)];
                    apoyt=[rois(frame,5) rois(frame,6)];
                    apoyb=[rois(frame,7) rois(frame,8)];
                    set(apos,{'XData'},{apoxt;apoxb},{'YData'},{apoyt;apoyb},{'ZData'},{[2 2];[2 2]},{'color'},{[1 1 0];[0 1 0]},{'LineStyle'},{'-'});
                    rfx=repfas(frame,1:2);
                    rfy=repfas(frame,3:4);
                    set(rf,  'XData',rfx, 'YData',rfy,'LineStyle','-');
                    drawnow

                case 110 % 119 is "n" key
                    %Make new ROI
                    pol=drawpolygon(Ax,'Color','red','FaceAlpha',0);
                    pol_vertices=pol.Position;
                    delete(Ax.Children(1))
                    xi2=pol_vertices(:,1);
                    yi2=pol_vertices(:,2);

                    title(num2str(frame))
                    rois(frame,1)=xi2(2);
                    rois(frame,2)=xi2(3);
                    rois(frame,3)=xi2(4);
                    rois(frame,4)=xi2(1);

                    rois(frame,5)=yi2(2);
                    rois(frame,6)=yi2(3);
                    rois(frame,7)=yi2(4);
                    rois(frame,8)=yi2(1);

                    [outfile,repfas(frame,:)]=FascicleSingleTrack(frame,vidarr,BWui8,outfile,rois,USdata,params);

                    figure(1)
                    hold on
                    y1=[outfile.repfas_len];
                    set(h1, 'XData', x1, 'YData', y1)
                    drawnow

                    figure(f3);
                    hold on
                    title(num2str(frame))
                    set(hImage,'CData',vidarr(:,:,frame));
                    apoxt=[rois(frame,1) rois(frame,2)];
                    apoxb=[rois(frame,3) rois(frame,4)];
                    apoyt=[rois(frame,5) rois(frame,6)];
                    apoyb=[rois(frame,7) rois(frame,8)];
                    set(apos,{'XData'},{apoxt;apoxb},{'YData'},{apoyt;apoyb},{'ZData'},{[2 2];[2 2]},{'color'},{[1 1 0];[0 1 0]},{'LineStyle'},{'-'});
                    rfx=repfas(frame,1:2);
                    rfy=repfas(frame,3:4);
                    set(rf,  'XData',rfx, 'YData',rfy,'LineStyle','-');
                    drawnow



                case 101 %101 is the "e" key
                    %Keep roi the same
                    if isnan(outfile(frame).repfas_len)
                        rois(frame,:)=rois(frame-1,1:8);
                    end
                    [outfile,repfas(frame,:)]=FascicleSingleTrack(frame,vidarr,BWui8,outfile,rois,USdata,params);

                    figure(1)
                    hold on
                    y1=[outfile.repfas_len];
                    set(h1, 'XData', x1, 'YData', y1)
                    drawnow

                    figure(3)
                    hold on
                    title(num2str(frame))
                    set(hImage,'CData',vidarr(:,:,frame));
                    apoxt=[rois(frame,1) rois(frame,2)];
                    apoxb=[rois(frame,3) rois(frame,4)];
                    apoyt=[rois(frame,5) rois(frame,6)];
                    apoyb=[rois(frame,7) rois(frame,8)];
                    set(apos,{'XData'},{apoxt;apoxb},{'YData'},{apoyt;apoyb},{'ZData'},{[2 2];[2 2]},{'color'},{[1 1 0];[0 1 0]},{'LineStyle'},{'-'});
                    rfx=repfas(frame,1:2);
                    rfy=repfas(frame,3:4);
                    set(rf,  'XData',rfx, 'YData',rfy,'ZData',[2 2],'LineStyle','-');
                    drawnow


                case 100 %100 is "d" key
                    %advance to next frame

                    frame=frame+1;
                    if frame>endframe
                        break
                    end

                    figure(1)
                    hold on
                    set(h2, 'Value', frame)
                    drawnow


                    if isnan(outfile(frame).repfas_len)
                        figure(3);
                        hold on
                        title(num2str(frame))
                        set(hImage,'CData',vidarr(:,:,frame));
                        apoxt=[rois(frame-1,1) rois(frame-1,2)];
                        apoxb=[rois(frame-1,3) rois(frame-1,4)];
                        apoyt=[rois(frame-1,5) rois(frame-1,6)];
                        apoyb=[rois(frame-1,7) rois(frame-1,8)];
                        set(apos,{'XData'},{apoxt;apoxb},{'YData'},{apoyt;apoyb},{'ZData'},{[2 2];[2 2]},{'color'},{[1 1 0];[0 1 0]},{'LineStyle'},{'--'});
                        set(rf,'LineStyle','none');
                        drawnow
                    else
                        figure(3)
                        hold on
                        title(num2str(frame))
                        set(hImage,'CData',vidarr(:,:,frame));
                        apoxt=[rois(frame,1) rois(frame,2)];
                        apoxb=[rois(frame,3) rois(frame,4)];
                        apoyt=[rois(frame,5) rois(frame,6)];
                        apoyb=[rois(frame,7) rois(frame,8)];
                        set(apos,{'XData'},{apoxt;apoxb},{'YData'},{apoyt;apoyb},{'ZData'},{[2 2];[2 2]},{'color'},{[1 1 0];[0 1 0]},{'LineStyle'},{'-'});
                        rfx=repfas(frame,1:2);
                        rfy=repfas(frame,3:4);
                        set(rf,  'XData',rfx, 'YData',rfy,'ZData',[2 2],'LineStyle','-');
                        drawnow

                    end


                case 113 %113 is "q" key
                    %Interpolate ROI
                    rois(frame,:)=[NaN NaN NaN NaN NaN NaN NaN NaN];


                case 103 %103 is the "g" key
                    %Enter go-to frame mode
                    frame=str2double(char(inputdlg('Enter frame number you would like to go to:')));

                    if frame>endframe
                        break
                    end

                    figure(1)
                    hold on
                    set(h2, 'Value', frame)
                    drawnow

                    if ~isnan(rois(frame,1)) && rois(frame,1)~=0
                        figure(3)
                        hold on
                        title(num2str(frame))
                        set(hImage,'CData',vidarr(:,:,frame));
                        apoxt=[rois(frame,1) rois(frame,2)];
                        apoxb=[rois(frame,3) rois(frame,4)];
                        apoyt=[rois(frame,5) rois(frame,6)];
                        apoyb=[rois(frame,7) rois(frame,8)];
                        set(apos,{'XData'},{apoxt;apoxb},{'YData'},{apoyt;apoyb},{'ZData'},{[2 2];[2 2]},{'color'},{[1 1 0];[0 1 0]},{'LineStyle'},{'-'});
                        rfx=repfas(frame,1:2);
                        rfy=repfas(frame,3:4);
                        set(rf,  'XData',rfx, 'YData',rfy,'ZData',[2 2],'LineStyle','-');
                        drawnow

                    else

                        figure(3)
                        title(num2str(frame))
                        set(hImage,'CData',vidarr(:,:,frame));
                        drawnow
                    end

                case 27  %27 is escape key
                    %end while loop
                    frame=endframe+1;

                case 112 %112 is the "p" key
                    %When p is pressed, will interpolate ROI positions based on
                    %the selected gait cycle

                    rois(:,1:8)=repmat(round(rois(frame,:)),endframe,1);
                    trackframes=1:endframe;
                    [outfile,repfas_trackframes]=FascicleMultiTrack(trackframes,vidarr,BWui8,outfile,rois,USdata,params);
                    repfas(trackframes,:)=repfas_trackframes(trackframes,:);


                    figure(1)
                    hold on
                    y1=[outfile.repfas_len];
                    set(h1, 'XData', x1, 'YData', y1)

                    figure(3)
                    hold on
                    title(num2str(frame))
                    set(hImage,'CData',vidarr(:,:,frame));
                    apoxt=[rois(frame,1) rois(frame,2)];
                    apoxb=[rois(frame,3) rois(frame,4)];
                    apoyt=[rois(frame,5) rois(frame,6)];
                    apoyb=[rois(frame,7) rois(frame,8)];
                    set(apos,{'XData'},{apoxt;apoxb},{'YData'},{apoyt;apoyb},{'ZData'},{[2 2];[2 2]},{'color'},{[1 1 0];[0 1 0]},{'LineStyle'},{'-'});
                    rfx=repfas(frame,1:2);
                    rfy=repfas(frame,3:4);
                    set(rf,  'XData',rfx, 'YData',rfy,'ZData',[2 2],'LineStyle','-');
                    drawnow

            end

        end
    end

    figure(1)
    close

    figure(3)
    close


catch
    %Saves generated ROI data to a file in the ROI folder.
    mkdir(strrep(path,'Converted','ROI_DL'))
    save(strrep([path file],'Converted','ROI_DL'),'roistruct')

    msgbox({'Error in tracker input. ROI data has been saved and will be automatically reloaded on next run of tracker.'},'Error');
    error('Error in tracker input. ROI data has been saved and will be automatically reloaded on next run of tracker.')
end


%Determining what percentage of frames had to be interpolated
roisample=rois(:,1);
roisample=roisample(1:endframe,:);
perc_nans=(length(roisample(isnan(roisample)))/length(roisample)).*100;

roistruct.roi=rois;
roistruct.name=file;
roistruct.percnan=perc_nans;

%Saves generated ROI data to a file in the ROI folder.
mkdir(strrep(path,'Converted','ROI_DL'))
save(strrep([path file],'Converted','ROI_DL'),'roistruct')

%% Filtering data, normalize to gait cycle and generating output data structure
[MuscleVar_struct,percnans]=ProcessUSVars(outfile,keyframes,params);

FL_arr=MuscleVar_struct.US.FL;
FPen_arr=MuscleVar_struct.US.FPen;

US_MasterStruct.FL=MuscleVar_struct.US.FL;
US_MasterStruct.FPen=MuscleVar_struct.US.FPen;
US_MasterStruct.ML=MuscleVar_struct.US.ML;
US_MasterStruct.FV=MuscleVar_struct.US.FV;
US_MasterStruct.MV=MuscleVar_struct.US.MV;
US_MasterStruct.NaNPerc=percnans;
US_MasterStruct.AutotrackerData=outfile;
US_MasterStruct.AutotrackerKeyframes=keyframes;


%% Plotting filtered fascicle lengths and angles
%Plotting Fascicle Length
figure;
subplot(2,1,1)
hold on
x=(1:101)';
xfill = [x; flipud(x)];
y_val=mean(FL_arr,2);
yfill2 = [y_val-std(FL_arr,0,2); flipud(y_val+std(FL_arr,0,2))];
fill(xfill,yfill2,[1 0 0],'LineStyle','none');
plot(x,y_val,'--red','LineWidth',3);
alpha(0.1);
hold off
xlabel('Gait Cycle (%)')
ylabel('Fascicle Length (mm)')
xlim([0,100])
hold off

%Plotting pennation angle relative to deep aponeurosis
subplot(2,1,2)
hold on
x=(1:101)';
xfill = [x; flipud(x)];
y_val=mean(FPen_arr,2);
xfill2 = [x; flipud(x)];
yfill2 = [y_val-std(FPen_arr,0,2); flipud(y_val+std(FPen_arr,0,2))];
fill(xfill,yfill2,[1 0 0],'LineStyle','none');
plot(x,y_val,'--red','LineWidth',3);
alpha(0.1);
hold off
xlabel('Gait Cycle (%)')
ylabel('Pennation Angle (degrees)')
xlim([0,100])
legend('1 STD Auto','Auto','Location','southoutside');
hold off

%Saving output file
saveit=char(inputdlg('Enter "y" if want to save:'));
if strcmp(saveit,'y')
    mkdir(strrep(path,'Converted','Output'))
    save(strrep([path file],'Converted','Output'),'US_MasterStruct')
end
delete(f)
