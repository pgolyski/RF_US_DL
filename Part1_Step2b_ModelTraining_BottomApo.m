%% Training new neural network based on Cronin 2020 approach
%Author: Pawel Golyski
clear all

%Note that everything coming into this model training("raw" images and
%aponeurosis labels) models should be 512x512 pixels

% Load in Cronin 2020 model edited to have a pixel classification layer for
% use in Matlab
lgraph2=importdata('Z:\Dropbox (GaTech)\RF\RF_US_DL\BaseModel\Cronin2020_Update.mat');

%Load in cropped, resized images
imds = imageDatastore('Z:\Dropbox (GaTech)\RF\RF_US_DL\Data\Resized\CroppedResizedImgs','FileExtensions',{'.tif'});

%Establish what pixel values correspond to each feature
classNames = ["apo","background"];
labelIDs   = [255 0];

%Load in bottom aponeuroses that have also been cropped and resized
pxds = pixelLabelDatastore('Z:\Dropbox (GaTech)\RF\RF_US_DL\Data\Resized\Masks\BotApo\*.tif',classNames,labelIDs);
pximds = pixelLabelImageDatastore(imds,pxds);

%Shuffle the set of raw and labeled data so training/testing is robust
pximds2 = shuffle(pximds);

numberImgs=size(pxds.Files,1); %490 images in this case

% 80%/20% Training/Testing breakdown
train_test_index=numberImgs*0.8;
pximds_train = partitionByIndex(pximds2,1:train_test_index);
pximds_test = partitionByIndex(pximds2,(train_test_index+1):numberImgs);

%Set model training options
options=trainingOptions('adam',...
    'InitialLearnRate',0.001,... %default of Adam optimizer in tensorflow
    'MaxEpochs',60,... %Cronin
    'MiniBatchSize',2,... %Cronin
    'ValidationPatience',8,... %Cronin
    'ValidationFrequency',196,...%I set to be about once per epoch, Cronin did not specify
    'LearnRateDropFactor',0.1,... %Cronin
    'LearnRateDropPeriod',10,...%Cronin
    'LearnRateSchedule','piecewise',...
    'Plots','training-progress',...
    'ValidationData',pximds_test,...
    'Epsilon',1e-7,...%Default of tensorflow adam optimizer
    'GradientDecayFactor',0.9,...%Default of tensorflow adam optimizer
    'SquaredGradientDecayFactor',0.999,...%Default of tensorflow adam optimizer
    'Shuffle','every-epoch'); 


BottomNet = trainNetwork(pximds_train,lgraph2,options);

%% Save trained network
save('Z:\Dropbox (GaTech)\RF\RF_US_DL\TrainedModels\BottomNet.mat','BottomNet')

%% Save train and test set objects for any future re-evaluations
save('Z:\Dropbox (GaTech)\RF\RF_US_DL\TrainedModels\BottomNet_trainset.mat','pximds_train')
save('Z:\Dropbox (GaTech)\RF\RF_US_DL\TrainedModels\BottomNet_testset.mat','pximds_test')

%% Testing how well the trained network did

%Select any image from testing set. Here there were 0.2*490 = 98 images in
%that set, so randomly selected the 45th image;
Imgnum=45;

%Load in the test image
I = imread(pximds_test.Images{Imgnum,1});

%Visualize the model performance
[C,scores] = semanticseg(I,BottomNet);
B = labeloverlay(I, C);
figure
imshow(B)
figure
imagesc(scores)
axis square
colorbar

BW = C == 'apo';
figure
imshow(BW)

%% Evaluate the overall performance of model on the test set
%Select images of test set
imdsTest = imageDatastore(pximds_test.Images);

%Generate "ground truth" based on test set 
classNames = ["apo","background"];
labelIDs   = [255 0];
pxdsTruth = pixelLabelDatastore(pximds_test.PixelLabelData,classNames,labelIDs);

%Run semantic segmentation on test set
pxdsResults = semanticseg(imdsTest,BottomNet,'MiniBatchSize',2,"WriteLocation",tempdir);
%Get pixel-wise evaluation metrics from test set
% metrics = evaluateSemanticSegmentation(pxdsResults,pxdsTruth);
% 
% 
%     GlobalAccuracy    MeanAccuracy    MeanIoU    WeightedIoU    MeanBFScore
%     ______________    ____________    _______    ___________    ___________
% 
%        0.99707          0.94167       0.90551      0.99437        0.98707  
