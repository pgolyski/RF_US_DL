%% Script to hand-label top and bottom apos for use in training deep neural netpath
%% First script to run in order to generate data for training aponeurosis detection models
%Author: Pawel Golyski

%original directory with raw image files
orgdir='Z:\Dropbox (GaTech)\RF\RF_US_DL\Data\RawImages\';

%target directories - these are the folders that will receive the cropped
%and resized images and masks used for training the models
tardir_top='Z:\Dropbox (GaTech)\RF\RF_US_DL\Data\Resized\Masks\TopApo\';
tardir_bot='Z:\Dropbox (GaTech)\RF\RF_US_DL\Data\Resized\Masks\BotApo\';
tardir_raw='Z:\Dropbox (GaTech)\RF\RF_US_DL\Data\Resized\CroppedResizedImgs\';

listing = dir([orgdir '\*.tif']);

%This part is necessary if for some reason there are borders around your
%images that need to be removed. Here we pass in the indices of the images
%and the coordinates of the good image within the images to crop out the
%borders in the for loops.
%format for crop sizes - [start file index,end file index, x start (leftmost horizontal coordinate in image), x end (rightmost horizontal coordinate in image), y start (topmost vertical coordinate in image), y end (bottommost vertical coordinate in image)]
cropsizes=[1,210,87,886,135,982;
    211,280,87,910,135,955;
    281,350,46,922,135,1156;
    351,420,87,886,135,1156;
    421,490,46,922,135,1156];

%generate array of cropsizes
cropdims=zeros(cropsizes(size(cropsizes,1),2),4);
for i=1:size(cropsizes,1)
        cropdims(cropsizes(i,1):cropsizes(i,2),1:4)=repmat(cropsizes(i,3:6),cropsizes(i,2)-cropsizes(i,1)+1,1);
end

for i =1:size(listing,1)  
    
    cropdim=cropdims(i,:);
    
    %import raw image
    tiffile=importdata([orgdir listing(i).name]);
    %convert to grayscale
    I = rgb2gray(tiffile);    
    %crop the image to remove outer borders
    I_crop=I(cropdim(1):cropdim(2),cropdim(3):cropdim(4));
    
    %resize the cropped raw image
    I_crop_resize=imresize(I_crop,[512,512]);
    %save the cropped, resized raw image
    imwrite(I_crop_resize, [tardir_raw listing(i).name]);
    
    %identify top apo
    figure;
    hold on
    title('Outline Top Apo')
    BW1=roipoly(I_crop);
    close
    BW1=uint8(BW1).*255;
    BW1=imresize(BW1,[512,512]);
    %save the re
    imwrite(BW1, [tardir_top listing(i).name]);
    
    %identify bottom apo
    figure;
    hold on
    title('Outline Bottom Apo')
    BW2=roipoly(I_crop);
    close
    BW2=uint8(BW2).*255;
    BW2=imresize(BW2,[512,512]);
    imwrite(BW2, [tardir_bot listing(i).name]);  
    
end
 

