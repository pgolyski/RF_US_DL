function [Sub,id,slip_side,slip_timing,iter]=nameParser(file)
%% This script is particular to this study design and will have to be changed depending on how you use keyframes

%% This function generates the fields in the RF_MasterStruct from the filename
%Inputs:
%file (string): the name of the Converted .mat file that was loaded in

%Outputs:
%Sub: subject id
%id: what type of locomotion mode is it?
%slip_side: what side was the perturbation
%slip_timing: what timing was the perturbation?
%iter: what iteration of perturbation was this?


if strcmp(file(1:2),'RF')
    
    Sub=file(1:5);
    
    if strcmp(file(end-2:end),'mat')
    file=file(1:end-4); %crop off .mat extension
        if (contains(file, 'Static'))||(contains(file, 'static')) %This is a static file
            
            id='Static';
            slip_side='none';
            slip_timing='none';
            iter='none';
            
        elseif contains(file, 'W_125ms')%W_125ms
            
            id='W125';
            slip_side='none';
            slip_timing='none';
            iter='none';
            
        elseif contains(file, 'W_2ms')%W_2ms
            
            id='W2';
            slip_side='none';
            slip_timing='none';
            iter='none';
            
        elseif contains(file, 'R_2ms')%R_2ms
            
            id='R2';
            slip_side='none';
            slip_timing='none';
            iter='none';
            
        elseif contains(file, 'R_325ms')%R_325ms
            
            id='R325';
            slip_side='none';
            slip_timing='none';
            iter='none';
            
        else %this is a slip trial
            id='slip';
            iter=['I' file(end-1:end)];
            %Determine side of slip
            if strcmp(file(7),'L')
                slip_side='L';
            elseif strcmp(file(7),'R')
                slip_side='R';
            else
                error('Slip, but L or R not identified')
            end
            
            %Determine desired timing of slip
            if strcmp(file(9:10),'00')
                slip_timing='P00';
            elseif strcmp(file(9:10),'20')
                slip_timing='P20';
            else
                error('Slip, timing not identified')
            end
            
        end
    else
        error('Not .mat file!')
    end
else
    error('Not RF file!')
end
end
