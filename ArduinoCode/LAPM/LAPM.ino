// This is the Arduino code for the 7x7 motor LAPM system, upload it to the 4 teensy 3.2s. You should change the DEVICE_ID constant to the coorsponding teensy.
#include <Encoder.h>
// #include <PID_v1.h>
#include <Wire.h>
#include <Adafruit_MotorShield.h>
#include <Adafruit_I2CDevice.h>
#include <array>
#include <optional>

#define DEVICE_ID 4 // 1, 2, 3, 4 For different teensy on the motherboard.
#define HOST_ID 4   // The device that handles the communication with the PC

// Define the number of motors connected to each device
#if DEVICE_ID == 1
const int numMotors = 14;
const int gID_start = 0;
const int gID_end = 13;
#elif DEVICE_ID == 2
const int numMotors = 14;
const int gID_start = 14;
const int gID_end = 27;
#elif DEVICE_ID == 3
const int numMotors = 14;
const int gID_start = 28;
const int gID_end = 41;
#elif DEVICE_ID == 4
const int numMotors = 7;
const int gID_start = 42;
const int gID_end = 48;
#endif

// RoeyMotors class
class RoeyMotors
{
private:
public:
    static const int maxSpeed = 255;
    Adafruit_DCMotor *motorDriver;
    int M_APin;       // Pin connected to phase A
    int M_BPin;       // Pin connected to phase B
    Encoder mEncoder; // Encoder object

    double pulseCountReading = 0;         // Current pulse count
    double lastPulseCount = 0;            // Previous pulse count
    double targetDistance = 0.0;          // Target position
    double targetPulseCount = 0.0;        // Target pulse count
    float speedReading = 0.0;             // Motor speed reading (rpm)
    double speedTarget = 0;               // Motor speed output
    double motorSpeedRecord = 0;          // Motor speed history to prevent frequent speed writes
    unsigned long previousSpeedWrite = 0; // Stores the last time speedWrite
    // PID mPID;                             // PID controller

    RoeyMotors(int M_APin, int M_BPin, Adafruit_DCMotor *motorDriver);
    ~RoeyMotors();
};

RoeyMotors::RoeyMotors(int M_APin, int M_BPin, Adafruit_DCMotor *motorDriver) : M_APin(M_APin), M_BPin(M_BPin), motorDriver(motorDriver), mEncoder(M_APin, M_BPin) {}

RoeyMotors::~RoeyMotors() {}

// Create the motor shield object with the default I2C address
Adafruit_MotorShield MotorDriver_50 = Adafruit_MotorShield(0x50);
Adafruit_MotorShield MotorDriver_51 = Adafruit_MotorShield(0x51);
Adafruit_MotorShield MotorDriver_52 = Adafruit_MotorShield(0x52);
Adafruit_MotorShield MotorDriver_53 = Adafruit_MotorShield(0x53);
Adafruit_MotorShield MotorDriver_54 = Adafruit_MotorShield(0x54);
Adafruit_MotorShield MotorDriver_55 = Adafruit_MotorShield(0x55);
Adafruit_MotorShield MotorDriver_56 = Adafruit_MotorShield(0x56);
Adafruit_MotorShield MotorDriver_57 = Adafruit_MotorShield(0x57);
Adafruit_MotorShield MotorDriver_58 = Adafruit_MotorShield(0x58);
Adafruit_MotorShield MotorDriver_59 = Adafruit_MotorShield(0x59);
Adafruit_MotorShield MotorDriver_5A = Adafruit_MotorShield(0x5A);
Adafruit_MotorShield MotorDriver_5B = Adafruit_MotorShield(0x5B);
Adafruit_MotorShield MotorDriver_5C = Adafruit_MotorShield(0x5C);
Adafruit_MotorShield MotorDriver_5D = Adafruit_MotorShield(0x5D);
Adafruit_MotorShield MotorDriver_5E = Adafruit_MotorShield(0x5E);
Adafruit_MotorShield MotorDriver_5F = Adafruit_MotorShield(0x5F);
// Define the encoder pins for each motor
// tsy1 <-> gID 0-13, tsy2 <-> gID 14-27,
// tsy3 <-> gID 28-41, tsy4 <-> gID 42-49
const int M0_APin = 10;  // Pin connected to phase A
const int M0_BPin = 9;   // Pin connected to phase B
const int M1_APin = 16;  // Pin connected to phase A
const int M1_BPin = 17;  // Pin connected to phase B
const int M2_APin = 22;  // Pin connected to phase A
const int M2_BPin = 23;  // Pin connected to phase B
const int M3_APin = 32;  // Pin connected to phase A
const int M3_BPin = 33;  // Pin connected to phase B
const int M4_APin = 26;  // Pin connected to phase A
const int M4_BPin = 27;  // Pin connected to phase B
const int M5_APin = 7;   // Pin connected to phase A
const int M5_BPin = 6;   // Pin connected to phase B
const int M6_APin = 3;   // Pin connected to phase A
const int M6_BPin = 2;   // Pin connected to phase B
const int M7_APin = 12;  // Pin connected to phase A
const int M7_BPin = 11;  // Pin connected to phase B
const int M8_APin = 14;  // Pin connected to phase A
const int M8_BPin = 15;  // Pin connected to phase B
const int M9_APin = 20;  // Pin connected to phase A
const int M9_BPin = 21;  // Pin connected to phase B
const int M10_APin = 30; // Pin connected to phase A
const int M10_BPin = 31; // Pin connected to phase B
const int M11_APin = 24; // Pin connected to phase A
const int M11_BPin = 25; // Pin connected to phase B
const int M12_APin = 28; // Pin connected to phase A
const int M12_BPin = 8;  // Pin connected to phase B
const int M13_APin = 5;  // Pin connected to phase A
const int M13_BPin = 4;  // Pin connected to phase B

const int T4_M0_APin = 17; // Pin connected to phase A
const int T4_M0_BPin = 20; // Pin connected to phase B
const int T4_M1_APin = 15; // Pin connected to phase A
const int T4_M1_BPin = 16; // Pin connected to phase B
const int T4_M2_APin = 23; // Pin connected to phase A
const int T4_M2_BPin = 29; // Pin connected to phase B
const int T4_M3_APin = 21; // Pin connected to phase A
const int T4_M3_BPin = 22; // Pin connected to phase B
const int T4_M4_APin = 32; // Pin connected to phase A
const int T4_M4_BPin = 33; // Pin connected to phase B
const int T4_M5_APin = 30; // Pin connected to phase A
const int T4_M5_BPin = 31; // Pin connected to phase B
const int T4_M6_APin = 26; // Pin connected to phase A
const int T4_M6_BPin = 27; // Pin connected to phase B

// Define motor objects for each device
#if DEVICE_ID == 1
RoeyMotors motors[numMotors] = {
    RoeyMotors(M0_APin, M0_BPin, MotorDriver_50.getMotor(3)), // M0 gM0
    RoeyMotors(M1_APin, M1_BPin, MotorDriver_51.getMotor(1)), // M1 gM1
    RoeyMotors(M2_APin, M2_BPin, MotorDriver_51.getMotor(3)), // M2 gM2
    RoeyMotors(M3_APin, M3_BPin, MotorDriver_52.getMotor(1)), // M3 gM3
    RoeyMotors(M4_APin, M4_BPin, MotorDriver_52.getMotor(3)), // M4 gM4
    RoeyMotors(M5_APin, M5_BPin, MotorDriver_53.getMotor(1)), // M5 gM5
    RoeyMotors(M6_APin, M6_BPin, MotorDriver_53.getMotor(3)), // M6 gM6

    RoeyMotors(M7_APin, M7_BPin, MotorDriver_50.getMotor(4)),   // M7 gM7
    RoeyMotors(M8_APin, M8_BPin, MotorDriver_51.getMotor(2)),   // M8 gM8
    RoeyMotors(M9_APin, M9_BPin, MotorDriver_51.getMotor(4)),   // M9 gM9
    RoeyMotors(M10_APin, M10_BPin, MotorDriver_52.getMotor(2)), // M10 gM10
    RoeyMotors(M11_APin, M11_BPin, MotorDriver_52.getMotor(4)), // M11 gM11
    RoeyMotors(M12_APin, M12_BPin, MotorDriver_53.getMotor(2)), // M12 gM12
    RoeyMotors(M13_APin, M13_BPin, MotorDriver_53.getMotor(4))  // M13 gM13
};
#elif DEVICE_ID == 2
RoeyMotors motors[numMotors] = {
    RoeyMotors(M0_APin, M0_BPin, MotorDriver_54.getMotor(3)), // M0 gM14
    RoeyMotors(M1_APin, M1_BPin, MotorDriver_55.getMotor(1)), // M1 gM15
    RoeyMotors(M2_APin, M2_BPin, MotorDriver_55.getMotor(3)), // M2 gM16
    RoeyMotors(M3_APin, M3_BPin, MotorDriver_56.getMotor(1)), // M3 gM17
    RoeyMotors(M4_APin, M4_BPin, MotorDriver_56.getMotor(3)), // M4 gM18
    RoeyMotors(M5_APin, M5_BPin, MotorDriver_57.getMotor(1)), // M5 gM19
    RoeyMotors(M6_APin, M6_BPin, MotorDriver_57.getMotor(3)), // M6 gM20

    RoeyMotors(M7_APin, M7_BPin, MotorDriver_54.getMotor(4)),   // M7 gM21
    RoeyMotors(M8_APin, M8_BPin, MotorDriver_55.getMotor(2)),   // M8 gM22
    RoeyMotors(M9_APin, M9_BPin, MotorDriver_55.getMotor(4)),   // M9 gM23
    RoeyMotors(M10_APin, M10_BPin, MotorDriver_56.getMotor(2)), // M10 gM24
    RoeyMotors(M11_APin, M11_BPin, MotorDriver_56.getMotor(4)), // M11 gM25
    RoeyMotors(M12_APin, M12_BPin, MotorDriver_57.getMotor(2)), // M12 gM26
    RoeyMotors(M13_APin, M13_BPin, MotorDriver_57.getMotor(4))  // M13 gM27
};
#elif DEVICE_ID == 3
RoeyMotors motors[numMotors] = {
    RoeyMotors(M0_APin, M0_BPin, MotorDriver_58.getMotor(3)), // M0 gM28
    RoeyMotors(M1_APin, M1_BPin, MotorDriver_59.getMotor(1)), // M1 gM29
    RoeyMotors(M2_APin, M2_BPin, MotorDriver_59.getMotor(3)), // M2 gM30
    RoeyMotors(M3_APin, M3_BPin, MotorDriver_5A.getMotor(1)), // M3 gM31
    RoeyMotors(M4_APin, M4_BPin, MotorDriver_5A.getMotor(3)), // M4 gM32
    RoeyMotors(M5_APin, M5_BPin, MotorDriver_5B.getMotor(1)), // M5 gM33
    RoeyMotors(M6_APin, M6_BPin, MotorDriver_5B.getMotor(3)), // M6 gM34

    RoeyMotors(M7_APin, M7_BPin, MotorDriver_58.getMotor(4)),   // M7 gM35
    RoeyMotors(M8_APin, M8_BPin, MotorDriver_59.getMotor(2)),   // M8 gM36
    RoeyMotors(M9_APin, M9_BPin, MotorDriver_59.getMotor(4)),   // M9 gM37
    RoeyMotors(M10_APin, M10_BPin, MotorDriver_5A.getMotor(2)), // M10 gM38
    RoeyMotors(M11_APin, M11_BPin, MotorDriver_5A.getMotor(4)), // M11 gM39
    RoeyMotors(M12_APin, M12_BPin, MotorDriver_5B.getMotor(2)), // M12 gM40
    RoeyMotors(M13_APin, M13_BPin, MotorDriver_5B.getMotor(4))  // M13 gM41
};
#elif DEVICE_ID == 4
RoeyMotors motors[numMotors] = {
    RoeyMotors(T4_M0_APin, T4_M0_BPin, MotorDriver_5C.getMotor(1)), // M0 gM42
    RoeyMotors(T4_M1_APin, T4_M1_BPin, MotorDriver_5C.getMotor(2)), // M1 gM43
    RoeyMotors(T4_M2_APin, T4_M2_BPin, MotorDriver_5C.getMotor(3)), // M2 gM44
    RoeyMotors(T4_M3_APin, T4_M3_BPin, MotorDriver_5C.getMotor(4)), // M3 gM45
    RoeyMotors(T4_M4_APin, T4_M4_BPin, MotorDriver_5D.getMotor(1)), // M4 gM46
    RoeyMotors(T4_M5_APin, T4_M5_BPin, MotorDriver_5D.getMotor(2)), // M5 gM47
    RoeyMotors(T4_M6_APin, T4_M6_BPin, MotorDriver_5D.getMotor(3)), // M6 gM48

};
#endif

enum class Error
{
    NO_ERROR,
    FAILED_TO_FIND_MOTOR_SHIELD,
    INVALID_INPUT,
    MOTOR_STUCK,
    FAILED_TO_ENTER_I2C_FAST_PLUS_MODE
};
enum class State
{
    POS_TRACKING,
    TOGGLE,
    CYCLE,
    MOTION
};

/*
 * DEFINE VARIABLES, CONSTANS AND FLAGS
 */
// flag for debug mode
bool debug = false;
bool echo = true;
// default value for the motor position
int onD = 0;
int offD = 10;
// precision threshold for the motor position
int threshold = 40;
// max speed of the motor
const int maxSpeed = 255;

// specs of the hardware system
const int pulsePerRound = 120; // ppr for the motor encoder
const float threadPitch = 0.5; // the pitch of the thread(mm)

// Set the initial error to NO_ERROR, state to POS_TRACKING
Error error = Error::NO_ERROR;
State state = State::POS_TRACKING;

/*
 * END OF DEFINE VARIABLES, CONSTANS AND FLAGS
 */

void setup()
{
    serialSetup();
    debugLedSetup();
    while (initMotorShield() == false)
    {
        if (debug)
        {
            Serial.println("Failed to find motor shield. Retrying...");
        }
        delay(1000); // Wait for 1 second before retrying
    }

    if (debug)
    {
        Serial.println("Debug mode activated.");
        // intervalPrint = 1000;
    }
}

void loop()
{
    // update timer
    // unsigned long currentMillis = millis();

    // Print Debug messages to PC
    if (DEVICE_ID == HOST_ID)
    {
        printStuff();
        pcCommunicationHandler();
        tsyCommunicationHandler_Host();
    }
    else
    {
        tsyCommunicationHandler_Peripheral();
    }
    motorGotoUpdate();
    blinkLED();
}

/*
 * Start the serial communication
 */
void serialSetup()
{
    Serial.begin(115200);
    Serial1.begin(115200);
    delay(500); // Wait for serial to initialize
}

/*
 * debugLedSetup
 */
void debugLedSetup()
{
    pinMode(LED_BUILTIN, OUTPUT);
    digitalWrite(LED_BUILTIN, HIGH);
}

/*
 * initMotorShield
 * start I2C communication with the motor shield
 */
#if DEVICE_ID == 1
boolean initMotorShield()
{
    if (!MotorDriver_50.begin())
    {
        Serial.println("Could not find Motor Shield 50. Check wiring.");
        error = Error::FAILED_TO_FIND_MOTOR_SHIELD;
        return false;
    }
    if (!MotorDriver_51.begin())
    {
        Serial.println("Could not find Motor Shield 51. Check wiring.");
        error = Error::FAILED_TO_FIND_MOTOR_SHIELD;
        return false;
    }
    if (!MotorDriver_52.begin())
    {
        Serial.println("Could not find Motor Shield 52. Check wiring.");
        error = Error::FAILED_TO_FIND_MOTOR_SHIELD;
        return false;
    }
    if (!MotorDriver_53.begin())
    {
        Serial.println("Could not find Motor Shield 53. Check wiring.");
        error = Error::FAILED_TO_FIND_MOTOR_SHIELD;
        return false;
    }
    Serial.println("Motor Shield found.");
    Wire.setClock(1000000); // set the I2C clock to 1MHz, enable FastMode+
    // verify the connection
    Adafruit_I2CDevice *i2c_dev = new Adafruit_I2CDevice(0x50);
    if (!i2c_dev->detected())
    {
        Serial.println("Failed to enter I2C Fast Plus mode.");
        error = Error::FAILED_TO_ENTER_I2C_FAST_PLUS_MODE;
        delete i2c_dev;
        return false;
    }
    delete i2c_dev;
    error = Error::NO_ERROR;
    return true;
}
#elif DEVICE_ID == 2
boolean initMotorShield()
{
    if (!MotorDriver_54.begin())
    {
        Serial.println("Could not find Motor Shield 54. Check wiring.");
        error = Error::FAILED_TO_FIND_MOTOR_SHIELD;
        return false;
    }
    if (!MotorDriver_55.begin())
    {
        Serial.println("Could not find Motor Shield 55. Check wiring.");
        error = Error::FAILED_TO_FIND_MOTOR_SHIELD;
        return false;
    }
    if (!MotorDriver_56.begin())
    {
        Serial.println("Could not find Motor Shield 56. Check wiring.");
        error = Error::FAILED_TO_FIND_MOTOR_SHIELD;
        return false;
    }
    if (!MotorDriver_57.begin())
    {
        Serial.println("Could not find Motor Shield 57. Check wiring.");
        error = Error::FAILED_TO_FIND_MOTOR_SHIELD;
        return false;
    }
    Serial.println("Motor Shield found.");
    Wire.setClock(1000000); // set the I2C clock to 1MHz, enable FastMode+
    // verify the connection
    Adafruit_I2CDevice *i2c_dev = new Adafruit_I2CDevice(0x54);
    if (!i2c_dev->detected())
    {
        Serial.println("Failed to enter I2C Fast Plus mode.");
        error = Error::FAILED_TO_ENTER_I2C_FAST_PLUS_MODE;
        delete i2c_dev;
        return false;
    }
    delete i2c_dev;
    error = Error::NO_ERROR;
    return true;
}
#elif DEVICE_ID == 3
boolean initMotorShield()
{
    if (!MotorDriver_58.begin())
    {
        Serial.println("Could not find Motor Shield 58. Check wiring.");
        error = Error::FAILED_TO_FIND_MOTOR_SHIELD;
        return false;
    }
    if (!MotorDriver_59.begin())
    {
        Serial.println("Could not find Motor Shield 59. Check wiring.");
        error = Error::FAILED_TO_FIND_MOTOR_SHIELD;
        return false;
    }
    if (!MotorDriver_5A.begin())
    {
        Serial.println("Could not find Motor Shield 5A. Check wiring.");
        error = Error::FAILED_TO_FIND_MOTOR_SHIELD;
        return false;
    }
    if (!MotorDriver_5B.begin())
    {
        Serial.println("Could not find Motor Shield 5B. Check wiring.");
        error = Error::FAILED_TO_FIND_MOTOR_SHIELD;
        return false;
    }
    Serial.println("Motor Shield found.");
    Wire.setClock(1000000); // set the I2C clock to 1MHz, enable FastMode+
    // verify the connection
    Adafruit_I2CDevice *i2c_dev = new Adafruit_I2CDevice(0x58);
    if (!i2c_dev->detected())
    {
        Serial.println("Failed to enter I2C Fast Plus mode.");
        error = Error::FAILED_TO_ENTER_I2C_FAST_PLUS_MODE;
        delete i2c_dev;
        return false;
    }
    delete i2c_dev;
    error = Error::NO_ERROR;
    return true;
}
#elif DEVICE_ID == 4
boolean initMotorShield()
{
    if (!MotorDriver_5C.begin())
    {
        Serial.println("Could not find Motor Shield 5C. Check wiring.");
        error = Error::FAILED_TO_FIND_MOTOR_SHIELD;
        return false;
    }
    if (!MotorDriver_5D.begin())
    {
        Serial.println("Could not find Motor Shield 5D. Check wiring.");
        error = Error::FAILED_TO_FIND_MOTOR_SHIELD;
        return false;
    }
    Serial.println("Motor Shield found.");
    Wire.setClock(1000000); // set the I2C clock to 1MHz, enable FastMode+
    // verify the connection
    Adafruit_I2CDevice *i2c_dev = new Adafruit_I2CDevice(0x5C);
    if (!i2c_dev->detected())
    {
        Serial.println("Failed to enter I2C Fast Plus mode.");
        error = Error::FAILED_TO_ENTER_I2C_FAST_PLUS_MODE;
        delete i2c_dev;
        return false;
    }
    delete i2c_dev;
    error = Error::NO_ERROR;
    return true;
}
#endif
/*
 * end of initMotorShield
 */

void printStuff()
{
    unsigned long currentMillis = millis(); // Get the current time in milliseconds
    static unsigned long previousMillisPrint = currentMillis;
    const unsigned long intervalPrint = 500;
    // Check if the specified interval has passed
    if (currentMillis - previousMillisPrint >= intervalPrint)
    {
        Serial.println(currentMillis);
        // printSpeedReadings();
        // printSpeedTargets({0});
        // printTargetDistances();
        // printTargetPulseCounts();
        // printPulseCounts({0, 1, 3, 5, 7});
        // printPIDParameters();
        // printCurrentMode();

        previousMillisPrint = currentMillis; // Save the current time for the next cycle
    }
}
/*
 * tsyCommunication
 * communicate with teensy boards via serial1
 * if controling Motors: "r,gID,Distance;r,gID,Distance;..."
 * if boardcasting commands: "c,<command>;"
 *
 */

void tsyCommunicationHandler_Peripheral()
{
    if (Serial1.available())
    {
        String data = Serial1.readStringUntil('\n');
        if (debug)
        {
            Serial.println(String(DEVICE_ID) + " Received: " + data);
        }
        // parse the data r,xx,distance;
        if (data.startsWith("r,"))
        {
            int indexComma = 4;
            int indexSemiColon = data.indexOf(';');
            int gID = data.substring(2, indexComma).toInt();
            float distance = data.substring(indexComma + 1, indexSemiColon).toFloat();
            int localID = getLocalMotorID(gID);
            if (localID == -1)
            {
                if (debug)
                {
                    Serial.println("Not my motor" + String(gID));
                }
                Serial1.println(data);
                return;
            }
            motorSetTargetDistance(localID, distance);
            // Serial1.println("r," + String(gID) + "," + String(distance) + ";");
        }
        else if (data.startsWith("c,"))
        {
            Serial1.println(data);
            commandHandler(data.substring(2, data.length() - 1));
        }
    }
}

void tsyCommunicationHandler_Host()
{
    if (Serial1.available())
    {
        String data = Serial1.readStringUntil('\n');
        Serial.println(String(DEVICE_ID) + " Received: " + data);
    }
}

void pcCommunicationHandler()
{
    if (Serial.available())
    {
        String data = Serial.readStringUntil('\n');
        if (debug)
        {
            Serial.println(String(DEVICE_ID) + " Received: " + data);
        }
        if (echo)
        {
            Serial.println(data);
        }
        // parse the data r,xx,distance;
        if (data.startsWith("r,"))
        {
            int indexComma = 4;
            int indexSemiColon = data.indexOf(';');
            int gID = data.substring(2, indexComma).toInt();
            float distance = data.substring(indexComma + 1, indexSemiColon).toFloat();
            int localID = getLocalMotorID(gID);
            if (localID == -1)
            {
                if (debug)
                {
                    Serial.println("Not my motor" + String(gID));
                }
                // Forward the command to the peripherals
                Serial1.println(data);
                return;
            }
            motorSetTargetDistance(localID, distance);
            Serial.println("r," + String(gID) + "," + String(distance) + ";");
        }
        else if (data.startsWith("c,"))
        {
            // Forward the command to the peripherals, then handle the command in the host
            Serial1.println(data);
            commandHandler(data.substring(2, data.length() - 1));
        }
    }
}

/*
 * getLocalMotorID
 * get the local motor ID from the global motor ID
 */
int getLocalMotorID(int gID)
{
    if (gID < gID_start || gID > gID_end)
    {
        return -1;
    }
    return gID - gID_start;
}

void motorSpeedWrite(int localID, int speed)
{
    if (motors[localID].motorSpeedRecord == speed)
    {
        static unsigned long safetyTimerLimit = 2000;
        // safety timer
        if (speed != 0 && millis() - motors[localID].previousSpeedWrite > safetyTimerLimit)
        {
            /* meltdown here */
            motors[localID].motorDriver->run(RELEASE);
            error = Error::MOTOR_STUCK;
        }
        return; // Prevent frequent writes of duplicate values
    }

    motors[localID].previousSpeedWrite = millis();

    motors[localID].motorSpeedRecord = speed;

    // bound speed between -maxSpeed and maxSpeed
    speed = max(min(speed, maxSpeed), -maxSpeed);
    // If maxSpeed is 255, use speed directly; otherwise, map speed to the range -255 to 255
    int x = maxSpeed == 255 ? speed : map(speed, -maxSpeed, maxSpeed, -255, 255);
    motors[localID].motorDriver->setSpeed(abs(x));
    if (abs(x) < threshold)
    {
        motors[localID].motorDriver->run(RELEASE);
    }
    else if (x > 0)
    {
        motors[localID].motorDriver->run(FORWARD);
    }
    else if (x < 0)
    {
        motors[localID].motorDriver->run(BACKWARD);
    }
    else
    {
        motors[localID].motorDriver->run(RELEASE);
    }
    // myMotor->setSpeed(150);
    // myMotor->run(FORWARD);
    // turn on motor
    // myMotor->run(RELEASE);
    // int p1 = max(x, 0);
    // int p2 = abs(min(x, 0));
    // Serial.print("Setting Motor ");
    // Serial.print(id);
    // Serial.print(" to voltage: ");
    // Serial.print(x);
    // Serial.print(" ");
    // Serial.print(p1);
    // Serial.print(" ");
    // Serial.println(p2);
    // if (motors[id].motorSpeedRecord == speed)
    // {
    //     return; // Prevent frequent writes of duplicate values
    // }
    // else
    // {
    //     motors[id].motorSpeedRecord = speed;
    //     analogWrite(motors[id].M_APin, p1); // 0-255
    //     analogWrite(motors[id].M_BPin, p2); // 0-255
    // }
}

// update the motor speed according to a set distance
void motorGotoUpdate()
{
    unsigned long currentMillis = millis();
    if (debug)
    {
        Serial.print("5.1:");
        Serial.println(millis() - currentMillis);
    }
    // Read the current pulseCounts of all motors
    for (int i = 0; i < numMotors; i++)
    {
        motors[i].pulseCountReading = (double)motors[i].mEncoder.read();
    }
    if (debug)
    {
        Serial.print("5.2:");
        Serial.println(millis() - currentMillis);
    }

    // calculate the deltaPulseCount between target position and current position.
    long deltaPulseCounts[numMotors];
    for (int i = 0; i < numMotors; i++)
    {
        deltaPulseCounts[i] = motors[i].targetPulseCount - motors[i].pulseCountReading;
    }

    // Set the threshold for the motor to stop
    for (int i = 0; i < numMotors; i++)
    {
        if (abs(deltaPulseCounts[i]) > threshold)
        {
            if (deltaPulseCounts[i] > 0)
            {
                motors[i].speedTarget = maxSpeed;
                motorSpeedWrite(i, maxSpeed);
            }
            else
            {
                motors[i].speedTarget = -maxSpeed;
                motorSpeedWrite(i, -maxSpeed);
            }
        }
        else
        {
            motors[i].speedTarget = 0;
            motorSpeedWrite(i, 0);
        }

        if (debug)
        {
            Serial.print("5.3:");
            Serial.println(millis() - currentMillis);
        }
    }
}

void motorSetTargetDistance(int localID, float distance)
{
    if (localID < 0 || localID >= numMotors)
    {
        Serial.print("Invalid motor ID: ");
        Serial.println(localID);
        while (1)
            ;
        return;
    }
    else
    {
        motors[localID].targetDistance = distance;                                        // Set target distance
        motors[localID].targetPulseCount = distance * (float)pulsePerRound / threadPitch; // updateTargetPulseCounts
    }
}

void motorReset()
{
    state = State::POS_TRACKING;
    for (int i = 0; i < numMotors; i++)
    {
        motorSetTargetDistance(i, 0.0);
    }
}

void motorPause()
{
    state = State::POS_TRACKING;
    for (int i = 0; i < numMotors; i++)
    {
        motorSpeedWrite(i, 0);
    }
}

// reset motor related variables, Encoder pulseCount, lastPulseCount and targetDistance
void motorCalibrate()
{
    state = State::POS_TRACKING;
    for (int i = 0; i < numMotors; i++)
    {
        motors[i].mEncoder.write(0);
        motors[i].lastPulseCount = 0;
        motors[i].targetDistance = 0.0;
        motors[i].targetPulseCount = 0.0;
    }
}

void blinkLED()
{
    unsigned long currentMillis = millis();
    static unsigned long previousMillis = 0;

    static unsigned long intervalLEDBlinked = 1000;
    if (currentMillis - previousMillis >= intervalLEDBlinked)
    {
        if (error == Error::NO_ERROR)
        {
            intervalLEDBlinked = 1000;
        }
        else if (error == Error::FAILED_TO_ENTER_I2C_FAST_PLUS_MODE)
        {
            intervalLEDBlinked = 2000;
        }
        else
        {
            intervalLEDBlinked = 100;
        }
        digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN));
        previousMillis = currentMillis;
    }
}

void commandHandler(String command)
{
    if (command == "reset")
    {
        motorReset();
        Serial.println("Reset");
    }
    else if (command == "pause")
    {
        motorPause();
        Serial.println("Paused");
    }
    else if (command == "calibrate")
    {
        motorCalibrate();
        Serial.println("Calibrated");
    }
    else if (command == "clearError")
    {
        error = Error::NO_ERROR;
        Serial.println("Error cleared.");
    }
}