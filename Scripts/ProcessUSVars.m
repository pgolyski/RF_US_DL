function [MuscleVar_struct,perc_nans]=ProcessUSVars(outfile,keyframes,params)
%% Function to generate whole-trial fascicle information
%Inputs: 
%outfile (struct): struct containing raw fascicle information
%keyframes (length(keyframes)-1,2 doubles): an array where each row
%represents a gait cycle, with the value in the left column being the start
%frame and value in the left being the end frame of that cycle.
%params (struct): struct of processing parameters

%Outputs:
%MuscleVar_struct (struct): struct containing all processed fascicle
%information
%perc_nans (double): percentage of processed data that had to be
%interpolated


MuscleVar_struct=struct;

FL=[outfile.repfas_len];
angle=[outfile.repfas_pen];
%Time here is in s
time=[outfile.time]./1000;


FL_filt=FL(keyframes(1,1):(keyframes(end)));
%Calculate how much data will have to be interpolated as percentage
perc_nans=(length(FL_filt(isnan(FL_filt)))/length(FL)).*100;

nanidxs=find(isnan(FL_filt));

angle_filt=angle(keyframes(1,1):(keyframes(end)));
time=time(keyframes(1,1):(keyframes(end)));


%Interpolate (and/or extrapolate) data using the time information
vq3 = interp1(time,FL_filt,time(nanidxs),'pchip','extrap');
FL_filt(nanidxs)=vq3;

vq3 = interp1(time,angle_filt,time(nanidxs),'pchip','extrap');
angle_filt(nanidxs)=vq3;

sampfreq=1./mean(diff(time));

fs = sampfreq;
[b,a] = butter(6,params.fc/(fs/2));
FL_filt=filtfilt(b,a,FL_filt);
angle_filt=filtfilt(b,a,angle_filt);

ML_filt=FL_filt.*cosd(angle_filt);

%Calculate fascicle and muscle velocity
FV_filt=gradient(FL_filt).*sampfreq;
MV_filt=gradient(ML_filt).*sampfreq;


FL_arr=StrideSplitter(FL_filt,time,keyframes);
FV_arr=StrideSplitter(FV_filt,time,keyframes);
FPen_arr=StrideSplitter(angle_filt,time,keyframes);
ML_arr=StrideSplitter(ML_filt,time,keyframes);
MV_arr=StrideSplitter(MV_filt,time,keyframes);

MuscleVar_struct.US.FL=FL_arr;
MuscleVar_struct.US.FPen=FPen_arr;
MuscleVar_struct.US.ML=ML_arr;
MuscleVar_struct.US.FV=FV_arr;
MuscleVar_struct.US.MV=MV_arr;
 
end
