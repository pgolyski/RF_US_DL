function keyframesOut=keyframeRestructure(keyframesIn,id)
%% This script is particular to this study design and will have to be changed depending on how you use keyframes


%% Function that converts a vector of keyframes into an array with each row being a start and end frame for that cycle
%Inputs:
%keyframesIn (1xlength(keyframes) double): a vector of keyframes, such as
%the ultrasound frame numbers that correspond to heelstrikes
%id (string): an identifier of whether or not it was a slip trial

%Outputs:
%keyframesOut (length(keyframes)-1,2 doubles): an array where each row
%represents a gait cycle, with the value in the left column being the start
%frame and value in the left being the end frame of that cycle.

keyframesOut=zeros(length(keyframesIn)-1,2);

if strcmp(id,'slip')
for i=1:length(keyframesIn)-1
keyframesOut(i,:)=[keyframesIn(i) keyframesIn(i+1)];
end

else
keyframesOut=keyframesIn;    
    
    
end
