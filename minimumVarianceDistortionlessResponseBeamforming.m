clear;
polars_cell = cell(1,6);
for i = 1:6
    load(sprintf("MatData/polars_average_channel_%d.mat", i));
    polars_cell{i} = polars;
end

f_sound = 1000; % sound frequency for beamforming
r = 0.1; % coordinate unit length
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
s_pos = 10*r*[cos(elevation)*cos(azimuth) cos(elevation)*sin(azimuth) sin(elevation)];

% delay and sum algorithm
dasb_delay = s_pos*m_pos/norm(s_pos)/c; % to compensate the delay aka alignment: times "-" to a "-"
d_dasb = exp(-1j*2*pi*f_sound*dasb_delay)/numel(m_pos(1,:));
w_dasb = d_dasb;

% mvdr algorithm
d_mvdr = d_dasb';
n_mics = 6;
Phi_NN = ones(n_mics, n_mics);
[noise, fs] = audioread("Temporary/noisebelow_mon_2_.wav");
f_res = fs/length(noise);  % Frequency resolution
f_index = round(f_sound/f_res);  % Index of the frequency of interest
for i = 1:n_mics
    for j = i:n_mics  % Symmetric matrix, compute half and mirror
        [cpsd_ij, f] = cpsd(noise(:,i), noise(:,j), [], [], [], fs);
        Phi_NN(i,j) = cpsd_ij(f_index);
        Phi_NN(j,i) = Phi_NN(i,j);  % Mirror since matrix is Hermitian
    end
end
Phi_NN_inv = inv(Phi_NN);  % Compute the inverse of the noise covariance matrix
% After computing Phi_NN_inv
max_val = max(max(abs(Phi_NN_inv)));  % Find the maximum absolute value in the matrix
Phi_NN_inv = Phi_NN_inv / max_val;  % Normalize so the max absolute value is now 1 (0 dB)
w_mvdr = (Phi_NN_inv*d_mvdr/(d_mvdr'*Phi_NN_inv*d_mvdr)).';

% simulation parameters
sound_delay_angles = deg2rad(0:5:360);
sound_delay_positions = [cos(sound_delay_angles')*cos(azimuth) cos(sound_delay_angles')*sin(azimuth) sin(sound_delay_angles')];
sound_delays = -sound_delay_positions*m_pos/c; % to simulate the propagation: with "-"
simulations = w_mvdr*(exp(-1j*2*pi*f_sound*sound_delays).*sys).'; % to simulate signals from all directions: with "-"; do NOT use Hermitian

% simulation polar plot
threshold = -60;
for i = 1:numel(sound_delay_angles)
    if mag2db(abs(simulations(i))) < threshold
        simulations(i) = 10^(threshold/20);
    end
end
polarplot(sound_delay_angles, mag2db(abs(simulations)));
thetalim([0 360]);
thetaticks(0:45:315);
rlim([threshold 0]);
rticks(threshold:5:0);
title(sprintf("azimuth %d°, elevation %d°, frequency %dHz", azimuth_deg, elevation_deg, f_sound));