%% This script loads in converted US images, and given an image angle, calculates the ROI for fascicle calculation with the primary tracker for 1 participant with the same ultrasound image angle across all images.
%In general, this script is set up to run such that you have a "Converted"
%folder with .mat files of US images that have been converted from .tvd
%files. It will generate a parallel folder callsed ROI_DL which contains
%the vertices denoting the top and bottom aponeuroses
%Author: Pawel Golyski

clear
close all

addpath(genpath('Z:\Dropbox (GaTech)\RF\RF_US_DL'))

%%

%Angle of ultrasound image
angle=-10;

%Select files you want to process
[files2process,dir2process] = uigetfile('MultiSelect','on');

%Load in trained networks
load('Z:\Dropbox (GaTech)\RF\RF_US_DL\TrainedModels\BottomNet.mat')
load('Z:\Dropbox (GaTech)\RF\RF_US_DL\TrainedModels\TopNet.mat')

%Progress bars to know how far through your trials you are, and how far
%through the current trial you are. Position of the waitbar is based on your monitor, so
%adjust if things don't look right
f1 = waitbar(0,'Trials Processed','Position',[585.0000  376.8750  270.0000   56.2500]);
f2 = waitbar(0,'Current Trial Processing','Position',[584.2500  462.7500  270.0000   56.2500]);

%Iterate through your trials
for TrialNum=1:size(files2process,2)
    
    file=files2process{TrialNum};
    
    %Load in the ultrasound .mat file for processing
    data=load([dir2process files2process{TrialNum}]);

    %This section parses the name of the trial to extract keyframes and depends on how you want to organize your data analysis. To
    %decrease processing time, I just generate ROIs in the range of
    %keyframes. Those keyframes are stored in the "RF_MasterStruct"
    load('Z:\Dropbox (GaTech)\RF\RF_US_DL\TrainedModels\RF_MasterStruct_09.mat')
    [trackrange,keyframes,endframe]=keyframeExtraction(file,RF_MasterStruct);
         
    %% For each frame in trackrange, get top and bottom apo mask predictions, identify apos, get polyfit of each, and calculate intersection points with sides of image
    
    %Load in ultrasound .mat file
    I_fullsize=data.TVDdata.Im;
    I_full_size=size(I_fullsize);
    
    %Resize .mat to 512x512 for applying model
    I_resize=imresize(I_fullsize,[512,512]);
    
    r_resize=512;
    c_resize=512;
    
    if angle<0
        sideslope=tan(pi/2+deg2rad(angle));
        rightint=-sideslope*c_resize+r_resize;
        leftint=r_resize;
        
        %%For visualizing lateral borders of image to make sure angle is
        %%correct. Red line should hug left edge, green line should hug
        %%right edge
%             figure;
%             hold on
%             imshow(I_resize(:,:,2))
%             line([r_resize/sideslope,0],[0,r_resize],'Color','red')
%             line([c_resize,-rightint/sideslope],[0,r_resize],'Color','green')
        
    else
        
%             figure;
%             hold on
%             imshow(I_resize(:,:,2))
%             line([0,0],[0,r_resize],'Color','red')
%             line([c_resize,c_resize],[0,r_resize],'Color','green')
    end
    
    close all
    
    %% Initialize roi storage variables
    roistruct=struct;
    roistruct.roi=zeros(trackrange(end),8);
    roistruct.name=file;
    roistruct.percnan=0;
    C_bot=zeros(size(I_resize,1),size(I_resize,2),size(I_resize,3));
    C_top=zeros(size(I_resize,1),size(I_resize,2),size(I_resize,3));     
    

    %Iterate through trackrange
    for i=trackrange
        
        %Generate masks for top and bottom aponeuroses
        [C_bot,~] = semanticseg(I_resize(:,:,i),BottomNet);
        [C_top,~] = semanticseg(I_resize(:,:,i),TopNet);
        
        
        %% Top aponeurosis fitting
        
        BW_top = C_top == 'apo';
        
        %identify largest object in predicted top apo mask
        cc = bwconncomp(BW_top);
        stats=regionprops(cc,'Area','Orientation','Centroid');
        [~,idx] = max([stats.Area]);
        
        if isempty(idx) %if no apo detected, use previous frame
            %fit poly to top
            [C_top,~] = semanticseg(I_resize(:,:,i-1),TopNet);
            BW_top = C_top == 'apo';
            
            %identify largest object
            cc = bwconncomp(BW_top);
            stats=regionprops(cc,'Area','Orientation','Centroid');
            [~,idx] = max([stats.Area]);
        end
        
        %Get slope and centroid of largest object
        slope=-tand([stats(idx).Orientation]);
        Centroid=stats(idx).Centroid;
        
        %calculate intersection of image with top apo polyfit
        %If image angle is not 0
        if angle~=0
            %left side polyfit
            a=-sideslope;
            c=leftint;
            
            %top apo polyfit
            b=slope;
            d=-slope*Centroid(1)+Centroid(2);
            
            x_left_top=(d-c)/(a-b);
            y_left_top=a*((d-c)/(a-b))+c;
            
            c=sideslope*c_resize;
            
            x_right_top=(d-c)/(a-b);
            y_right_top=a*((d-c)/(a-b))+c;
            
            %%Use this to visualize the top apo polyfit, included in yellow
%             figure;
%             hold on
%             imshow(I_resize(:,:,i))
%             line([r_resize/sideslope,0],[0,r_resize],'Color','red')
%             line([c_resize,-rightint/sideslope],[0,r_resize],'Color','green')
%             line([x_left_top,x_right_top],[y_left_top,y_right_top],'Color','yellow','LineWidth',3);
        
        else %image angle is 0
            
            x_left_top=0;
            x_right_top=512;
            
            y_left_top=-slope*Centroid(1)+Centroid(2);
            y_right_top=slope*512-slope*Centroid(1)+Centroid(2);
            
            %%Use this to visualize the top apo polyfit, included in yellow            
%             figure;
%             hold on
%             imshow(I_resize(:,:,i))
%             line([0,0],[0,r_resize],'Color','red')
%             line([c_resize,c_resize],[0,r_resize],'Color','green')
%             line([0,c_resize],[y_left_top,y_right_top],'Color','yellow','LineWidth',3);
        end
        
        %% Bottom aponeurosis fitting
        
        BW_bot = C_bot == 'apo';
        
        %identify largest object in predicted bottom apo mask
        cc = bwconncomp(BW_bot);
        stats=regionprops(cc,'Area','Orientation','Centroid');
        [~,idx] = max([stats.Area]);
        
        
        if isempty(idx) %if no apo detected, use previous frame
            %fit poly to bottom apo
            [C_bot,~] = semanticseg(I_resize(:,:,i-1),BottomNet);
            BW_bot = C_bot == 'apo';
            
            %identify largest object
            cc = bwconncomp(BW_bot);
            stats=regionprops(cc,'Area','Orientation','Centroid');
            [~,idx] = max([stats.Area]);
        end
        
        %Calculate slope and centroid of largest object
        slope=-tand([stats(idx).Orientation]);
        Centroid=stats(idx).Centroid;
        
        %calculate intersection of left side of image with bottom apo polyfit
        %When angle is not zero
        if angle~=0
            %left side polyfit
            a=-sideslope;
            c=leftint;
            
            %top apo polyfit
            b=slope;
            d=-slope*Centroid(1)+Centroid(2);
            
            x_left_bot=(d-c)/(a-b);
            y_left_bot=a*((d-c)/(a-b))+c;
            
            c=sideslope*c_resize;
            
            x_right_bot=(d-c)/(a-b);
            y_right_bot=a*((d-c)/(a-b))+c;
            
            
            %%Use this to visualize the bottom apo polyfit, included in
            %%cyan
%             figure;
%             hold on
%             imshow(I_resize(:,:,i))
%             line([r_resize/sideslope,0],[0,r_resize],'Color','red')
%             line([c_resize,-rightint/sideslope],[0,r_resize],'Color','green')
%             line([x_left_bot,x_right_bot],[y_left_bot,y_right_bot],'Color','cyan','LineWidth',3);
            
        else %image angle is 0
            
            x_left_bot=0;
            x_right_bot=512;
            
            y_left_bot=-slope*Centroid(1)+Centroid(2);
            y_right_bot=slope*512-slope*Centroid(1)+Centroid(2);
            
            %%Use this to visualize the bottom apo polyfit, included in
            %%cyan
%             figure;
%             hold on
%             imshow(I_resize(:,:,i))
%             line([0,0],[0,r_resize],'Color','red')
%             line([c_resize,c_resize],[0,r_resize],'Color','green')
%             line([0,c_resize],[y_left_bot,y_right_bot],'Color','cyan','LineWidth',3);
        end
        
                
        %scale coordinates back to original image size
        roistruct.roi(i,:)=[x_left_bot.*(I_full_size(2)./c_resize),x_right_bot.*(I_full_size(2)./c_resize),x_right_top.*(I_full_size(2)./c_resize),x_left_top.*(I_full_size(2)./c_resize),y_left_bot.*(I_full_size(1)./r_resize),y_right_bot.*(I_full_size(1)./r_resize),y_right_top.*(I_full_size(1)./r_resize),y_left_top.*(I_full_size(1)./r_resize)];
        
        %%Use this to visualize vertices of ROIs on the image
%         figure;
%         hold on
%         imshow(I_fullsize(:,:,i));
%         hold on
%         plot(roistruct.roi(i,1),roistruct.roi(i,5),'ro');
%         plot(roistruct.roi(i,2),roistruct.roi(i,6),'go');
%         plot(roistruct.roi(i,3),roistruct.roi(i,7),'bo');
%         plot(roistruct.roi(i,4),roistruct.roi(i,8),'ko');
        
        waitbar((i-trackrange(1))/length(trackrange),f2,['Current Trial ' num2str(round((i-trackrange(1))/length(trackrange).*100)) '% Complete']);
        
    end
    
    %% Visualize a random frame to make sure your aponeuroses make sense. Blue is top apo, red is bottom apo
%     figure;
%     hold on
%     frame=trackrange(1)+500;
%     imshow(I_fullsize(:,:,frame))
%     line(roistruct.roi(frame,1:2),roistruct.roi(frame,5:6),'Color','red','LineWidth',3);
%     line(roistruct.roi(frame,3:4),roistruct.roi(frame,7:8),'Color','blue','LineWidth',3);
    
    
    %% Saving roistruct to file
    mkdir(strrep(dir2process,'Converted','ROI_DL'))
    save(strrep([dir2process file],'Converted','ROI_DL'),'roistruct')
   
    
    waitbar((TrialNum/size(files2process,2)),f1,[num2str(TrialNum) ' of ' num2str(size(files2process,2)) ' Trials Completed']);    
end

close(f1)
close(f2)
