# معايرة مستشعر المجال المغناطيسي (Magnetometer Calibration & Heading Calculation)

يقدم هذا المستودع دليلاً شاملاً وكود MATLAB لجمع البيانات، معايرتها، وحساب زاوية الاتجاه (Heading) باستخدام مستشعر المجال المغناطيسي **QMC5883L** المربوط بلوحة Arduino.

---

## 📌 مقدمة أسباب وأنواع المعايرة

يتأثر مستشعر المجال المغناطيسي بالبيئة المحيطة به، مما يتطلب إجراء عملية معايرة لحساب القيم الصحيحة. تنقسم مصادر الخطأ إلى ثلاثة أنواع رئيسية:

1. **تأثير الحديد الصلب (Hard Iron Effect):**
   * **السبب:** وجود مواد مغناطيسية دائمة بالقرب من المستشعر (مثل المغناطيس حتى لو كان مجاله ضعيفاً).
   * **التأثير:** تسبب إزاحة وتحول لمركز المجال المغناطيسي للمستشعر وحيوده عن نقطة الأصل $(0,0,0)$.

2. **تأثير الحديد اللين (Soft Iron Effect):**
   * **السبب:** وجود معادن قابلة للمغنطة بالقرب من المستشعر تغير مسار خطوط المجال المغناطيسي.
   * **التأثير:** تسبب تشوهاً وانبعاجاً للشكل الدائري/الكروي للمجال ليصبح شكله بيضاوياً (Ellipsoid).

3. **الانحراف المغناطيسي (Magnetic Declination):**
   * **السبب:** عدم تطابق الشمال المغناطيسي للأرض مع الشمال الجغرافي الحقيقي.
   * **التأثير:** اختلاف القراءة حسب الموقع الجغرافي على سطح الأرض.


---

## 🛠️ خطوات عمل المعايرة

### الخطوة الأولى: جمع قراءات المستشعر (MATLAB & Arduino)
1. قُم بربط مستشعر **QMC5883L** مع لوحة Arduino عبر بروتوكول I2C (العنوان غالباً `0x0D`).
2. شغّل سكريبت MATLAB لجمع البيانات؛ حيث يتم أخذ القراءات الخام (Raw Readings) لـ 1000 عينة أو أكثر أثناء تدوير المستشعر في جميع الاتجاهات (3D Space).
3. تُحفظ البيانات في ملف نصي باسم `matrix.txt`.

### الخطوة الثانية: حساب مصفوفة التصحيح ومُتجه الإزاحة (A & B)
لحل مشكلتي الـ Hard Iron والـ Soft Iron، نستخدم برنامج **CalibMag** (المرفق في المستودع):

1. احصل على شدة المجال المغناطيسي الكلية للموقع الجغرافي الحالي من خلال موقع **NOAA (National Oceanic and Atmospheric Administration)**:
   * اختر حاسبة المجال المغناطيسي (Magnetic Field Calculator).
   * أدخل اسم المكان/الموقع واضغط على حساب الإحداثيات (Calculate Coordinates).
   * اضغط على **Calculate Magnetic Field** لمعرفة قيمة شدة المجال (Total Intensity).


2. افتح برنامج **CalibMag (exe)**، وادخل:
   * اسم ملف القراءات (`matrix.txt`).
   * قيمة شدة المجال المغناطيسي المحسوبة من موقع NOAA.

3. سيقوم الجزءالاخير من الكود بحساب:
   * **المصفوفة $A$ (Correction Matrix):** لضبط وإزالة تشوه الـ Soft Iron.
   * **المتجه $B$ (Offset Vector):** لتصحيح إزاحة الـ Hard Iron.

### الخطوة الثالثة: حساب الانحراف المغناطيسي (Magnetic Declination)
لحل مشكلة عدم تطابق الشمال المغناطيسي مع الجغرافي:
1. من موقع **NOAA**، اختر حاسبة الانحراف المغناطيسي (Declination).
2. أدخل الموقع واحتسب قيم الانحراف بالدرجات والدقائق.
3. تحويل الدقائق إلى درجات: 
   $$	ext{Declination} = 	ext{Degrees} + rac{	ext{Minutes}}{60}$$
4. **تحديد الإشارة:**
   * إذا كان الاتجاه **شرقاً (East)**: تكون القراءة **موجبة (+)**.
   * إذا كان الاتجاه **غرباً (West)**: تكون القراءة **سالبة (-)**.

---

## 💻 كود التشغيل والمعايرة (MATLAB Code)

```matlab
% This script reads and calibrates data from QMC5883L to calculate heading
clc; clear; close all;

%% 1. Connect to Arduino and Magnetometer
arduinoObj = arduino();
addr = '0x0D'; % I2C address for QMC5883L
magnetometer = device(arduinoObj, 'I2CAddress', addr);

% Initialize QMC5883L
write(magnetometer, [0x0B, 0x01]);  % Set control register to Continuous Measurement mode
write(magnetometer, [0x09, 0x1D]);  % Set configuration (Data Rate, Range, Mode)
pause(0.1);  % Small delay for sensor initialization

%% 2. Read Raw Magnetometer Data
Samples = 1000;
readings = [];

for i = 1:Samples
    write(magnetometer, 0x00); % Set register pointer to data output
    rawData = read(magnetometer, 6, 'uint8');  % Read 6 bytes of data
    x = typecast(uint8(rawData(1:2)), 'int16');
    y = typecast(uint8(rawData(5:6)), 'int16');
    z = typecast(uint8(rawData(3:4)), 'int16');
    
    mag = [y, -x, z]; 
    readings = [readings; mag];
end

% Save raw data for CalibMag software
save('matrix.txt', 'readings', "-ascii");

%% 3. Apply Calibration Parameters (A & B)
% Matrices obtained from CalibMag execution
A = [0.968,  0.018, -0.045;
     0.018,  1.015, -0.006;
    -0.045, -0.006,  0.989];

B = [38.3, 3.7, 0.709];

numReadings = size(readings, 1);
calibrated = zeros(numReadings, 3);

for i = 1:numReadings
    Reading = readings(i, :);
    % Custom function CalibrateMag applies: Calibrated = A * (Reading - B)'
    magcalibrated = CalibrateMag(A, B, Reading);
    calibrated(i, :) = magcalibrated;
end    

%% 4. Calculate Corrected Heading Angle
headingAngle = zeros(numReadings, 1);

% Define Declination angle obtained from NOAA
declination = +4.73; % Positive for East, Negative for West

for i = 1:numReadings
    heading = (atan2(calibrated(i, 2), calibrated(i, 1))) * 180 / pi;
    
    % Add magnetic declination
    heading = heading + declination;
    
    % Wrap angle to [0, 360] degrees
    if heading < 0
        heading = heading + 360;
    end
    
    headingAngle(i, :) = heading;
end
```

---

## 📁 ملفات المستودع

* `CalibrateMag.m`: دالة تحسب القراءة المصححة باستخدام $A$ و $B$.
* `MagHeading.m`: دالة لحساب زاوية الاتجاه (Heading).
* `matrix.txt`: القراءات الخام الناتجة من المستشعر.
* `output.txt`: مخرجات وقيم التصحيح.
* `levietduc0712-CalibMag-6258a08.zip`: برنامج CalibMag المستخدم في التجميع والتصحيح.

