function [angle,vidarr_f,BWui8_f]=imagePreProcAndAngleCorrection(USdata,endframe,params)
%% Function to preprocess the image and produce binarized masks used for fascicle recognition
%Inputs:
%USdata (struct): ultrasound data from running TVD2mat conversion as found
%in video conversion tools on the Ultratrack website (https://sites.google.com/site/ultratracksoftware/file-cabinet)
%endframe (int): the last frame of ultrasound data we are interested in.
%This is usually the last frame of keyframes
%params (struct): parameters struct

%Outputs:
%angle: the angle of the image as entered by the user
%vidarr_f (mxnxframes uint8): the array of ultrasound images after shearing
%to remove anything outside of angled edges
%BWui8_f (mxnxframes uint8): the array of binarized images after shearing
%to remove anything outside of angled edges and outside of user specified
%region where fascicles of interest could ever be. This area should be
%conservative because later the aponeurosis will be used as the bottom
%border
%prox_xi2 (5x1 double): x-coordinates of user selected region where good
%fascicles could ever be
%prox_yi2 (5x1 double): y-coordinates of user selected region where good
%fascicles could ever be



vidarr=USdata.TVDdata.Im(:,:,1:endframe);
angle=-str2double(char(inputdlg('Enter image angle in degrees:')));

B=imwarp(vidarr(:,:,1),affine2d([1 0 0;tand(angle) 1 0;0 0 1]));
[r,~]  = size(vidarr(:,:,1));
imbad=1;
figure(1);
while imbad==1
    
    imshow(B)
    cropit=char(inputdlg('Enter "c" to crop, "a" to enter a new angle, or "y" if image is not angled in this corrected image:'));
    if strcmp(cropit,'c')
        n=round(r*tand(angle))+5; %Add 5 pixels to be safe on edges
        B = B(:,n+1:end-n); %take away area to left and right of image before filtering
    elseif strcmp(cropit,'y')


        %warp
        vidarr_w=imwarp(vidarr,affine2d([1 0 0;tand(angle) 1 0;0 0 1]));
        %crop image
        n=round(r*tand(angle))+5; %Add 5 pixels to be safe on edges
        vidarr_wc = vidarr_w(:,n+1:end-n,:); %take away area to left and right of image before filtering
        
        BW_wc=zeros(size(vidarr_wc));
        
        
        f1 = waitbar(0,'Preprocessing Image');
        
        %CLAHE filter
        for frame=1:size(vidarr_wc,3)
        vidframe=vidarr_wc(:,:,frame);
        vidframe=adapthisteq(vidframe);
        BW_wc(:,:,frame) = imbinarize(fibermetric(vidframe,params.fibermetricThickness,'ObjectPolarity','bright','StructureSensitivity',params.fibermetricStructSensitivity));
        waitbar((frame)/size(vidarr_wc,3),f1,['Preprocessing ' num2str(round((frame)/size(vidarr_wc,3).*100)) '% Complete'],'Notification');
        end

        BWui8_wc=uint8(BW_wc).*255;
        %add padding, then inverse shear transform
        BWui8_w=padarray(BWui8_wc,[0 n],'both');
        vidarr_w=padarray(vidarr_wc,[0 n],'both');
        BWui8_f=imwarp(BWui8_w,affine2d([1 0 0;tand(-angle) 1 0;0 0 1]));
        vidarr_f=imwarp(vidarr_w,affine2d([1 0 0;tand(-angle) 1 0;0 0 1]));
        n=round(r*tand(angle)); %Add 5 pixels to be safe on edges
        BWui8_f = BWui8_f(:,n+1:end-n,:); %take away area to left and right caused by shearing
        vidarr_f = vidarr_f(:,n+1:end-n,:); %take away area to left and right caused by shearing


        if params.additionalROIspecification
        m1=msgbox({'Select Area of Image Where Good Fascicles Will Potentially Be'},'Notification');    
        [proc_mask]=roipoly(vidarr_f(:,:,1));
        delete(m1)
        for frame=1:size(BWui8_f,3)
            BWui8_f(:,:,frame)=BWui8_f(:,:,frame).*uint8(proc_mask);
        end        
        end
        
   
        imbad=0;
        delete(f1)
        close
    elseif strcmp(cropit,'a')
        angle=-str2double(char(inputdlg('Enter image angle in degrees:')));
        B=imwarp(vidarr(:,:,1),affine2d([1 0 0;tand(angle) 1 0;0 0 1]));
    end
    
end


