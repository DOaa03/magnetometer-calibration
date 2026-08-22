%this script reads and calibrates data from QMC5883L to calculate heading 

clc; clear; close all;

% Connect to Arduino
arduinoObj = arduino();

%connect to Magnetometer
addr = '0x0D';

% Create I2C device object
magnetometer = device(arduinoObj , 'I2CAddress', addr);

% Initialize QMC5883L
write(magnetometer, [0x0B, 0x01]);  % Set control register to Continuous Measurement mode
write(magnetometer, [0x09, 0x1D]);  % Set configuration (Data Rate, Range, Mode)

pause(0.1);  % Small delay for sensor initialization

% Read magnetometernetometer Data
Samples=1000;
readings=[];
for i=1:Samples
    write(magnetometer, 0x00); % Set register pointer to data output

    rawData = read(magnetometer, 6, 'uint8');  % Read 6 bytes of data

    x = typecast(uint8(rawData(1:2)), 'int16');
    y = typecast(uint8(rawData(5:6)), 'int16');
    z = typecast(uint8(rawData(3:4)), 'int16');
    mag=[y,-x,z]; 
    readings=[readings ; mag];
end
%this txt file pf readings will be imported to ClibMag exe programe to get
%A and B
save('matrix.txt', 'readings',"-ascii")

%% after getting A,B
A=[0.968, 0.018, -0.045;
    0.018, 1.015, -0.006;
    -0.045, -0.006, 0.989];
B=[38.3 ,3.7,0.709];
calibrated=zeros(4507,3);
for i=1:4507
    Reading=readings(i,:);
    magcalibrated= CalibrateMag(A,B,Reading);
    calibrated(i,:)=magcalibrated;
end    
%% calculate hading 
headingAngle=zeros(4507,1);
for i=1:4507
    heading=(atan2(calibrated(i,2),calibrated(i,1)))*180/pi;

    %adding magnetic field declination positiv eastward and negative westward
    declination=+4.73;
    heading=heading + declination;

    %convert if the heading is minus
    if heading<0
        heading= heading + 360;
    end
    headingAngle(i,:)=heading;

end



