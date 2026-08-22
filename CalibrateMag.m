%%THIS function takes the value of soft iron A and hard iron B correction
%%and only one eading of magnetometer each time

function magcalibrated= CalibrateMag(A,B,Magreading)
         magcalibrated=A*[Magreading(1)-B(1),
                          Magreading(2)-B(2),
                          Magreading(3)-B(3)];

end         