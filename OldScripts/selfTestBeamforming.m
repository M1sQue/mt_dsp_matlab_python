%% prototype: display as a figure
clear;
polars_cell = cell(1,6);
for i = 1:6
    load(sprintf("MatData/polars_average_channel_%d.mat", i));
    polars_cell{i} = polars;
end

f_sound = 4000; % sound frequency for beamforming
r = 0.057; % coordinate unit length
c = 343.3; % speed of sound

% microphone system parameters definition
m_pos = [r 0 0; r/2 -sqrt(3)/2*r 0; -r/2 -sqrt(3)/2*r 0; -r 0 0; -r/2 sqrt(3)/2*r 0; r/2 sqrt(3)/2*r 0]';
temp = -1;
for i=1:numel(polar_freq)
    if polar_freq(i) == f_sound
        temp = i;
    end
end
if temp == -1
    error("Frequency %dHz is not found in the directivity pattern.", f_sound);
end
sys = [polars_cell{1}(temp, :); polars_cell{2}(temp, :); polars_cell{3}(temp, :); polars_cell{4}(temp, :); polars_cell{5}(temp, :); polars_cell{6}(temp, :)]';
sys = db2mag(sys);

% sound source parameters definition
azimuth_deg = 0;
elevation_deg = -45;
azimuth = deg2rad(azimuth_deg);
elevation = deg2rad(elevation_deg);
s_pos = 50*r*[cos(elevation)*cos(azimuth) cos(elevation)*sin(azimuth) sin(elevation)];

% delay and sum algorithm
dasb_delay = s_pos*m_pos/norm(s_pos)/c; % to compensate the delay aka alignment: times "-" to a "-"
d_dasb = exp(-1j*2*pi*f_sound*dasb_delay)/numel(m_pos(1,:));
w_dasb = d_dasb;

% simulation parameters
sound_delay_angles = deg2rad(0:5:360);
sound_delay_positions = [cos(sound_delay_angles')*cos(azimuth) cos(sound_delay_angles')*sin(azimuth) sin(sound_delay_angles')];
sound_delays = -sound_delay_positions*m_pos/c; % to simulate the propagation: with "-"
simulations = (exp(-1j*2*pi*f_sound*sound_delays).*sys).';
output = w_dasb*simulations; % to simulate signals from all directions: with "-"; do NOT use Hermitian

% simulation polar plot
H_threshold = max(mag2db(abs(output)));
L_threshold = H_threshold - 20;
for i = 1:numel(sound_delay_angles)
    if mag2db(abs(output(i))) < L_threshold
        output(i) = db2mag(L_threshold);
    end
end
polarplot(sound_delay_angles, mag2db(abs(output)));
thetalim([0 360]);
thetaticks(0:45:315);
rlim([L_threshold H_threshold]);
rticks(L_threshold:5:H_threshold);
title(sprintf("azimuth %d°, elevation %d°, frequency %dHz", azimuth_deg, elevation_deg, f_sound));

%% prototype: display as an animation
clear;
% Load microphone array data
polars_cell = cell(1,6);
for i = 1:6
    load(sprintf("MatData/polars_average_channel_%d.mat", i));
    polars_cell{i} = polars;
end

% Sound and system parameters
f_sound = 4000; % sound frequency for beamforming
r = 0.057; % coordinate unit length
c = 343.3; % speed of sound

% Microphone positions
m_pos = [r 0 0; r/2 -sqrt(3)/2*r 0; -r/2 -sqrt(3)/2*r 0; -r 0 0; -r/2 sqrt(3)/2*r 0; r/2 sqrt(3)/2*r 0]';

% Find frequency index
temp = -1;
for i=1:numel(polars_cell{1}(:,1))
    if polar_freq(i) == f_sound
        temp = i;
        break;
    end
end
if temp == -1
    error("Frequency %dHz is not found in the directivity pattern.", f_sound);
end
sys = [polars_cell{1}(temp, :); polars_cell{2}(temp, :); polars_cell{3}(temp, :); polars_cell{4}(temp, :); polars_cell{5}(temp, :); polars_cell{6}(temp, :)]';
sys = db2mag(sys);

elevation_range = -180:1:180; % Range of elevation angles
% Initialize video writer
% v = VideoWriter('polar_animation.avi');
% open(v);

% Animation loop
for elevation_deg = elevation_range
    azimuth_deg = 0;
    azimuth = deg2rad(azimuth_deg);
    elevation = deg2rad(elevation_deg);
    s_pos = 50*r*[cos(elevation)*cos(azimuth) cos(elevation)*sin(azimuth) sin(elevation)];

    % Delay and sum beamforming
    dasb_delay = s_pos*m_pos/norm(s_pos)/c;
    d_dasb = exp(-1j*2*pi*f_sound*dasb_delay)/numel(m_pos(1,:));
    w_dasb = d_dasb;

    % Simulate sound from all directions
    sound_delay_angles = deg2rad(0:5:360);
    sound_delay_positions = [cos(sound_delay_angles')*cos(azimuth) cos(sound_delay_angles')*sin(azimuth) sin(sound_delay_angles')];
    sound_delays = -sound_delay_positions*m_pos/c;
    simulations = (exp(-1j*2*pi*f_sound*sound_delays).*sys).';
    output = w_dasb*simulations;

    % Plotting
    H_threshold = max(mag2db(abs(output)));
    L_threshold = H_threshold - 10;
    for i = 1:numel(sound_delay_angles)
        if mag2db(abs(output(i))) < L_threshold
            output(i) = db2mag(L_threshold);
        end
    end
    steering_direction = L_threshold*ones(1,numel(sound_delay_angles));
    if elevation_deg <= 0
        steering_index = mod(round(elevation_deg/5)+72,73)+1;
    else 
        steering_index = mod(round(elevation_deg/5)+73,73)+1;
    end
    steering_direction(steering_index) = 0; %direction of elevation_deg
    
    polarplot(sound_delay_angles, mag2db(abs(output)), 'LineWidth', 2);
    hold on;
    polarplot(sound_delay_angles, steering_direction, 'LineWidth', 2);
    hold off;
    thetalim([0 360]);
    thetaticks(0:45:315);
    rlim([L_threshold H_threshold]);
    rticks(L_threshold:10:H_threshold);
    title(sprintf("Azimuth %d°, Elevation %d°, Frequency %dHz", azimuth_deg, elevation_deg, f_sound));
    drawnow;

    % Capture the frame
    % frame = getframe(gcf);
    % writeVideo(v, frame);
end

% Close the video file
% close(v);
