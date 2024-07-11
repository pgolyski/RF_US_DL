function [StrideMat]=StrideSplitter(data,datatimevec,keyframes)
%% Function to gait normalize time-series ultrasoun data
%Inputs:
%data (double): a vector of timeseries data
%datatimevec (double): a vector of times for that timeseries data
%keyframes (length(keyframes)-1,2 doubles): an array where each row
%represents a gait cycle, with the value in the left column being the start

%Output:
%StrideMat (101 x number of cycles doubles): each column represents a
%cycle, each row represents a percentage of the cycle

UnevenStrideCell={};
for i = 1:size(keyframes,1)
   UnevenStrideCell{i}=data((keyframes(i,1)-keyframes(1,1)+1):(keyframes(i,2)-keyframes(1,1)+1)); 
   UnevenStrideTimeCell{i}=datatimevec((keyframes(i,1)-keyframes(1,1)+1):(keyframes(i,2)-keyframes(1,1)+1));
end

StrideMat=[];
counts=0;
for i=1:(size(UnevenStrideCell,2))
    counts=counts+1; 
    UnevenStrideMat=UnevenStrideCell{i};
    UnevenStrideTimeMat=UnevenStrideTimeCell{i};
    StrideMat(counts,:)=interp1(UnevenStrideTimeMat,UnevenStrideMat',linspace(UnevenStrideTimeMat(1),UnevenStrideTimeMat(end),101));
    
end

StrideMat=StrideMat';

end
