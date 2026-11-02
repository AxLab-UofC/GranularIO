/*
For use with the Adafruit Motor Shield v2
---->	http://www.adafruit.com/products/1438
*/

#define NONE 0
// #define RUN 1
#define VIBRATE 2
#define FADE 3
#define FADESINE 4

#include <Adafruit_MotorShield.h>
#include <BlockNot.h> //non blocking timer helper

//====================MOTORS AND SHIELDS===========================

// Create the motor shield object with the I2C address

const uint8_t PROGMEM num_rows = 4;
const uint8_t PROGMEM num_motors_per_row = 4;
Adafruit_MotorShield shields[num_rows] = {
    Adafruit_MotorShield(0x72),
    Adafruit_MotorShield(0x73),
    Adafruit_MotorShield(0x74),
    Adafruit_MotorShield(0x76)};

//====================TIMERS ===========================
BlockNot timers[num_rows][num_motors_per_row];

//==================MAGNET STRUCT==============================

// need to update these values in every function in addition to the actual changing via adafruit so that some behaviors work
struct Magnet
{
public:
  Adafruit_DCMotor *motor;
  BlockNot *timer;
  uint8_t direction; // FORWARD,BACKWARD,RELEASE
  uint8_t speed;     // 0-255
  uint8_t mode;

  // idk how to do it better but do not mess up with this lol
  char parameters[5][5]; // this is an array of c strings 5->stores 5 strings of length 3

  Magnet(Adafruit_DCMotor *m, BlockNot *t, uint8_t dir = RELEASE, uint8_t spd = 0)
      : motor(m), timer(t), direction(dir), speed(spd), mode(0) {}
  Magnet()
      : motor(nullptr), timer(nullptr), direction(RELEASE), speed(0), mode(0)
  {
    memset(parameters, 0, sizeof(parameters));
  }
};

Magnet magnets[num_rows][num_motors_per_row];
// int speed, int direction, int delay_amt, int hop_speed = 80, int hop_delay = 10
const uint8_t PROGMEM GROUP_PARAM_MAX = 5;
int groupParams[GROUP_PARAM_MAX] = {INT16_MAX, INT16_MAX, INT16_MAX, INT16_MAX, INT16_MAX};
BlockNot groupTimer(0); // used for loop and moveab
// note on function: magnets need to be passed in by reference &mx_x and function parameters need to be Magnet* m so that struct values save.
/* note on non blocking: any non blocking function that isn't going to run the entire time needs a boolean to toggle whether its enabled or not.
 Then need to run that function in some fashion in loop () (usually check if its enabled first). If it is going to be toggled, should add
 toggler in a separate helper function */

//================== FUNCTIONS==============================

//=============BASIC FUNCTIONS============
// starts shields

// returns the magnet for a single integer by converting to 2d coordinates
Magnet *
getMagnetFromInteger(uint8_t index)
{
  uint8_t row = index / num_motors_per_row;
  uint8_t col = index % num_motors_per_row;
  if (row >= num_rows || col >= num_motors_per_row)
  {
    Serial.println(F("Index out of bounds!"));
    return nullptr;
  }
  return &magnets[row][col];
}

// returns the corresponding magnet index from a row and column
uint8_t getMagIndexFromCoord(uint8_t row, uint8_t col)
{
  Serial.print(F("next is: "));
  Serial.println(row * num_motors_per_row + col);

  return row * num_motors_per_row + col;
}

void setSpeedAll(uint8_t speed)
{
  for (uint8_t i = 0; i < num_rows; i++)
  {
    for (uint8_t j = 0; j < num_motors_per_row; j++)
    {
      if (magnets[i][j].motor != nullptr)
      {
        magnets[i][j].motor->setSpeed(speed);
        magnets[i][j].speed = speed;
      }
    }
  }
}

// takes int speed, array of magnet pointers and size of array
void setSpeeds(uint8_t speed, Magnet *magnets_arr[], int num)
{
  for (uint8_t i = 0; i < num; i++)
  {
    magnets_arr[i]->motor->setSpeed(speed);
    magnets_arr[i]->speed = speed;
  }
}

// void reverseDireciton(Magnet *magnet) {
//   uint8_t direction = get
// }

void runMotor(Magnet *magnet, int speed = 50)
{
  // Serial.println("running motor");
  if (speed < 0)
  {
    magnet->motor->setSpeed(-speed);
    magnet->motor->run(BACKWARD);
    magnet->direction = BACKWARD;
    magnet->speed = -speed;
  }
  else
  {
    magnet->motor->setSpeed(speed);
    magnet->motor->run(FORWARD);
    magnet->direction = FORWARD;
    magnet->speed = speed;
  }
}

// FORWARD, BACKWARD, RELEASE
void setDirectionAll(uint8_t direction)
{
  for (uint8_t i = 0; i < num_rows; i++)
  {
    for (uint8_t j = 0; j < num_motors_per_row; j++)
    {
      if (magnets[i][j].motor != nullptr)
      {
        magnets[i][j].motor->run(direction);
        magnets[i][j].direction = direction;
      }
    }
  }
}

// FORWARD, BACKWARD, RELEASE
void setDirections(uint8_t direction, Magnet *magnets_arr[], uint8_t num)
{
  for (uint8_t i = 0; i < num; i++)
  {
    magnets_arr[i]->motor->run(direction);
    magnets_arr[i]->direction = direction;
  }
}

void setModeAll(uint8_t mode)
{
  for (uint8_t i = 0; i < num_rows; i++)
  {
    for (uint8_t j = 0; j < num_motors_per_row; j++)
    {
      if (magnets[i][j].motor != nullptr)
      {
        magnets[i][j].mode = NONE;
      }
    }
  }
}

//================SINGLE MOTORS==========================

/*timer explanation: if the timer isn't running, that means we are running the function for the first time so we start the fade in. if not, then we are in process of fading in.
 adding the next skip would go over the speed limit, we stop and the function is over. if not, we increase by the skip amt and set speed*/
// fade in

// keeping to simplify moving functions
void fadeOutBlock(Magnet *magnet)
{
  while (magnet->speed > -8)
  {
    runMotor(magnet, magnet->speed - 2);
    delay(10);
    if (magnet->speed - 2 <= -8)
    {
      runMotor(magnet, -8);
    }
  }
  Serial.println("done fading");
}

void fadeSine(Magnet *magnet, int max_speed = 255, int min_speed = 0, int skips = 15, int delay_amt = 10)
{
  int amplitude = floor(abs(max_speed - min_speed) / 2);
  Serial.println(amplitude);

  // Serial.println(magnet->speed);
  if (!(magnet->timer->isRunning()))
  {
    Serial.println(F("Fading  ??"));
    magnet->timer->setDuration(delay_amt);
    magnet->timer->start(true);
    magnet->speed = min_speed;
    magnet->motor->setSpeed(min_speed);
    magnet->motor->run(FORWARD);
    magnet->direction = FORWARD;
    Serial.println(F("Fading sine"));
  }
  else
  {
    Serial.println(magnet->timer->getTimeUntilTrigger());
  }
  if (magnet->timer->triggered())
  {
    int speed = (sin(((millis() / skips) % 360) * (DEG_TO_RAD)) + 1) * amplitude + min_speed;
    Serial.println(speed);
    magnet->speed = speed;
    magnet->motor->setSpeed(speed);
  }
}

// use negative values for backward - defaults to fade out forward
void fade(Magnet *magnet, uint8_t skips = 1, int delay_amt = 10, int starting_speed = 255, int ending_speed = 0)
{
  if (magnet->timer->isStopped())
  {
    magnet->timer->setDuration(delay_amt);
    magnet->timer->start(true);
    runMotor(magnet, starting_speed);
    Serial.println(F("Fading"));
  }

  if (starting_speed > ending_speed)
  { // going down
    if (magnet->speed - skips < ending_speed)
    {
      magnet->timer->stop();
      Serial.println(F("stoppping fade"));
      runMotor(magnet, ending_speed);
      magnet->mode = NONE;
    }
    else
    {
      // Serial.println(F("decreasing"));
      if (magnet->timer->triggered())
      {
        runMotor(magnet, magnet->speed - skips);
      }
    }
  }
  else
  {
    if (magnet->speed + skips > ending_speed)
    { // going up
      magnet->timer->stop();
      //   Serial.println(F("stoppping fade"));
      runMotor(magnet, ending_speed);
      magnet->mode = NONE;
    }
    else
    {
      if (magnet->timer->triggered())
      {
        Serial.println(F("increasing"));

        runMotor(magnet, magnet->speed + skips);
      }
    }
  }
}

bool hopBackEnabled = false;
/*quickly switch polarity from current to opposite direction -> since its using the non blocking timer of each motor
it does NOT work if running within another non-blocking function unless you create a new timer*/
void hopBack(Magnet *magnet, uint8_t speed = 80, int delay_amt = 10, bool stop_after = false)
{
  if (magnet->timer->isStopped())
  {
    magnet->timer->setDuration(delay_amt);
    magnet->motor->run(getReverseDirection(magnet->direction));
    magnet->motor->setSpeed(speed);
    magnet->timer->start(true);
  }
  if (magnet->timer->triggered(true))
  {
    magnet->timer->stop();
    magnet->motor->run(magnet->direction);
    if (stop_after)
    {
      magnet->motor->setSpeed(0);
    }
    hopBackEnabled = false;
  }
}
// might implement reverseDireciton() here instead of whatever i have ^^

// //i don't have a better way
// void manageHopBack(bool m0_1, bool m0_2, bool m0_3, bool m0_4, bool m1_1, bool m1_2, bool m1_3, bool m1_4) {}

// this is a blocking function
void hopBackBlock(Magnet *magnet, uint8_t speed = 80, int delay_amt = 10, bool stop_after = false)
{
  uint8_t opp_dir = FORWARD;
  if (magnet->direction == FORWARD)
  {
    opp_dir = BACKWARD;
  }
  magnet->motor->run(opp_dir);
  magnet->motor->setSpeed(speed);
  delay(delay_amt);
  magnet->motor->run(magnet->direction);
  if (stop_after)
  {
    magnet->motor->setSpeed(0);
    magnet->speed = 0;
  }
}

uint8_t getReverseDirection(uint8_t direction)
{
  if (direction == FORWARD)
  {
    return BACKWARD;
  }
  else
  {
    return FORWARD;
  }
}

void vibrate(Magnet *magnet, uint8_t speed_amt = 150, int delay_amt = 10)
{
  // Serial.println(speed_amt);
  if (magnet->timer->isStopped())
  {
    magnet->timer->setDuration(delay_amt);
    magnet->motor->setSpeed(speed_amt);
    magnet->speed = speed_amt;
    magnet->timer->start(true);
  }
  if (magnet->timer->triggered())
  {
    magnet->direction = getReverseDirection(magnet->direction);
    magnet->motor->run(magnet->direction);
  }
}
// void manageVibrate(bool m0_1, bool m0_2, bool m0_3, bool m0_4, )

// aka turns motors on and offx
void toggleStability(Magnet *magnet, uint8_t speed_amt = 255, uint8_t dir = FORWARD)
{

  if (magnet->direction == RELEASE)
  {
    magnet->motor->setSpeed(speed_amt);
    magnet->speed = speed_amt;
    magnet->motor->run(dir);
    magnet->direction = dir;
  }
  else
  {
    magnet->motor->run(RELEASE);
    magnet->motor->setSpeed(0);
    magnet->speed = 0;
    magnet->direction = RELEASE;
  }
}

void changeDirection(Magnet *magnet)
{
  Serial.println(magnet->direction);
  magnet->direction = (getReverseDirection(magnet->direction));
  magnet->motor->run(magnet->direction);
  Serial.println(magnet->direction);
}
//==================MORE COMPLEX BEHAVIORS==============================
uint8_t curr_pos = -1;
uint8_t target_pos = -1;
uint8_t prev_pos = -1;

// this is a blocking function
//  void moveAB(uint8_t start_pos, uint8_t end_pos) {
//    setSpeedAll(0);
//    curr_pos = start_pos;
//    target_pos = end_pos;
//    Serial.println("received moving command");
//    runMotor(getMagnetFromInteger(curr_pos), 255);
//    while (curr_pos != target_pos) {
//      uint8_t next_pos = calculateNextMagnetAB(curr_pos);
//      runMotor(getMagnetFromInteger(next_pos), 255);  //run next motor
//                                                      //fade method, currently using blocking
//      runMotor(getMagnetFromInteger(curr_pos), 255);
//      fadeOutBlock(getMagnetFromInteger(curr_pos));
//      curr_pos = next_pos;
//      delay(100);
//    }
//  }

bool moveEnabled = false;

void startMoveAB(uint8_t start_pos, uint8_t end_pos)
{
  Serial.println(F("received moving command"));
  curr_pos = start_pos;
  target_pos = end_pos;
  moveEnabled = true;

  // does the first round
  Magnet *curr_mag = getMagnetFromInteger(curr_pos);
  // Serial.print(F("current: "));
  // Serial.println(curr_pos);
  // runMotor(getMagnetFromInteger(next_pos), 255);
  // runMotor(curr_mag, 255);
  // curr_mag->parameters[0][0] = '3';
  curr_mag->mode = FADE;
  // Serial.println(F("done with start command"));
  prev_pos = curr_pos;
}
void startMoveAB()
{
  startMoveAB(groupParams[0], groupParams[1]);
}
void moveAB(uint8_t start_pos, uint8_t end_pos)
{
  if (curr_pos == target_pos)
  { // stop condition
    moveEnabled = false;
    return;
  }
  Magnet *curr_mag = getMagnetFromInteger(curr_pos);
  curr_mag->parameters[0][0] = '2';

  // Serial.print(F("current: "));
  // Serial.println(curr_pos);
  // Serial.println(curr_mag->mode);
  if (getMagnetFromInteger(prev_pos)->mode == NONE)
  { // fade is completed
    Serial.println(curr_pos);
    uint8_t next_pos = calculateNextMagnetAB(curr_pos);
    runMotor(getMagnetFromInteger(next_pos), 255); // run next motor
    curr_mag->mode = FADE;                         // fade current motor
    prev_pos = curr_pos;
    curr_pos = next_pos;
    Serial.println(curr_pos);
  }
  // Serial.println(F("============="));
}
void moveAB()
{
  moveAB(groupParams[0], groupParams[1]);
}

uint8_t calculateNextMagnetAB(uint8_t curr_pos)
{
  // calcul
  uint8_t curr_row = curr_pos / num_motors_per_row;
  uint8_t curr_col = curr_pos % num_motors_per_row;
  uint8_t target_row = target_pos / num_motors_per_row;
  if (curr_row < target_row)
  { // needs to increase row
    Serial.println("increasing row");

    return getMagIndexFromCoord(curr_row + 1, curr_col);
  }
  if (curr_row > target_row)
  { // needs to decrease row
    Serial.println("decreasing row");

    return getMagIndexFromCoord(curr_row - 1, curr_col);
  }
  // else on right row. check columns
  uint8_t target_col = target_pos % num_motors_per_row;
  if (curr_col < target_col)
  { // needs to increase col
    Serial.println("increasing col");

    return getMagIndexFromCoord(curr_row, curr_col + 1);
  }
  if (curr_col > target_col)
  { // needs to decrease col
    Serial.println("decreasing col");

    return getMagIndexFromCoord(curr_row, curr_col - 1);
  }
  Serial.println(curr_pos);
  return curr_pos;
}

bool loopEnabled = false;
uint8_t curr_shield = 0;
uint8_t curr_motor = 0;
// this still runs blocking hopback which is a few ms
void loopMotors(int speed, int direction, int delay_amt, int hop_speed = 80, int hop_delay = 10)
{

  if (groupTimer.getDuration() == 0)
  {
    groupTimer.setDuration(delay_amt);
  }
  if (groupTimer.isStopped())
  {
    setSpeedAll(0);
    setDirectionAll(direction);
    groupTimer.start(true);
  }
  magnets[curr_shield][curr_motor].motor->setSpeed(speed);
  if (groupTimer.triggered(true))
  {
    hopBackBlock(&magnets[curr_shield][curr_motor], hop_speed, hop_delay, true);
    loopCalculate();
  }
}

void loopCalculate()
{
  if (curr_shield == 0)
  { // on top row
    if (curr_motor + 1 < num_motors_per_row)
    { // not at right side
      curr_motor++;
    }
    else
    {
      curr_shield++;
    }
    return;
  }
  if (curr_shield == (num_rows - 1))
  { // on bottom row
    if (curr_motor > 0)
    { // not at left side
      curr_motor--;
    }
    else
    {
      curr_shield--;
    }
    return;
  }
  // somewhere in the middle
  if (curr_motor == 0)
  { // on left side
    curr_shield--;
    return;
  }
  else
  {
    curr_shield++;
  }
}
// void loopCalculate() {
//   if (curr_shield == 0) {                   //on top row
//     if (curr_motor + 1 < num_motors_per_row) {  //not at right side
//       curr_motor++;
//     } else {
//       curr_shield++;
//     }
//     return;
//   }
//   if (curr_shield == (2 - 1)) {  //on bottom row
//     if (curr_motor > 0) {        //not at left side
//       curr_motor--;
//     } else {
//       curr_shield--;
//     }
//     return;
//   }
//   //somewhere in the middle
//   if (curr_motor == 0) {  //on left side
//     curr_shield--;
//     return;
//   } else {
//     curr_shield++;
//   }
// }

// bool moveSlowEnabled = true;
// void moveSlowTest(Magnet *magnet1, Magnet *magnet2) {
//   if (moveSlowEnabled) {
//     fadeInEnabled = true;
//     moveSlowEnabled = false;
//   }
//   if (!fadeOutEnabled) fadeInEnabled = true;
//   if (!fadeInEnabled) fadeOutEnabled = true;
// }

uint8_t direction = BACKWARD;
void split(Adafruit_DCMotor *motor1, Adafruit_DCMotor *motor2, uint8_t speed = 250, int big_delay_amt = 300)
{
  if (direction == FORWARD)
  {
    direction = BACKWARD;
  }
  else
  {
    direction = FORWARD;
  }
  // Serial.println(F("splitting"));

  // delay(3000);
  delay(10);
  motor1->setSpeed(0);
  motor2->setSpeed(0);
  delay(5);

  motor2->run(direction);
  motor2->setSpeed(speed);

  if (direction == FORWARD)
  {
    direction = BACKWARD;
  }
  else
  {
    direction = FORWARD;
  }

  motor1->run(direction);
  motor1->setSpeed(speed);
  delay(big_delay_amt);
  setSpeedAll(0);
  if (direction == FORWARD)
  {
    direction = BACKWARD;
  }
  else
  {
    direction = FORWARD;
  }
}

// in set up you need to run motor 1 and it might be in release
void split2(Adafruit_DCMotor *motor1, Adafruit_DCMotor *motor2, uint8_t speed = 250, int big_delay_amt = 300)
{
  motor2->run(FORWARD);
  motor2->setSpeed(speed);
  motor1->setSpeed(floor(speed / 3));
  Serial.println(F("splitting"));
  delay(big_delay_amt);
  motor2->run(RELEASE);
  // motor2->setSpeed(floor(speed));
  motor1->setSpeed(speed);
}

void split3(Magnet *magnet1, Magnet *magnet2, uint8_t speed = 250, int big_delay_amt = 300)
{
  magnet2->motor->run(FORWARD);
  magnet2->motor->setSpeed(speed);
  magnet1->motor->setSpeed(floor(speed / 3));
  Serial.println(F("splitting"));
  delay(big_delay_amt);
  magnet2->motor->run(BACKWARD);
  delay(100);
  // motor2->setSpeed(floor(speed));
  magnet1->motor->setSpeed(speed);
}

///==============FUNCTIONS FOR INPUT==========
const uint8_t PROGMEM MAX_PARAMETERS = 5; // these are arbitrary
const uint8_t PROGMEM MAX_PARAM_LENGTH = 5;
const uint8_t PROGMEM NUM_CHARS_INPUT = 32;
char inputChars[NUM_CHARS_INPUT]; // an array to store the received input - arbitrarily chose 32

boolean newData = false;
// reading with c strings - saves into inputChars; -> arduino forum
void recvWithEndMarker()
{
  static byte ndx = 0;
  char endMarker = '\n';
  char rc;

  while (Serial.available() > 0 && newData == false)
  {
    rc = Serial.read();

    if (rc != endMarker)
    {
      inputChars[ndx] = rc;
      ndx++;
      if (ndx >= NUM_CHARS_INPUT)
      {
        ndx = NUM_CHARS_INPUT - 1;
      }
    }
    else
    {
      inputChars[ndx] = '\0'; // terminate the string
      ndx = 0;
      newData = true;
    }
  }
}

// uses the information gathered from parseInput to control individual motors -> defaults to toggle
void processIndivControl(Magnet *magnet, char command = 't', bool parameters = false)
{

  // Serial.println(F("received indiv commands"));
  switch (command)
  {
  case 'v': // vibrate
    magnet->mode = VIBRATE;
    break;
  case 'f': // fade sine
    magnet->mode = FADESINE;
    break;
  case 't': // toggle
    magnet->mode = NONE;
    if (parameters)
    {
      toggleHelper(magnet);
    }
    else
    {
      toggleStability(magnet);
    }
    break;
  default: // running is a default = none
    magnet->mode = NONE;
    if (parameters)
    { // speed is the only parameter
      //  Serial.print(F("ran motor at speed: "));
      //   Serial.println(magnet->parameters[0]);
      runMotor(magnet, atoi(magnet->parameters[0]));
    }
    else
    {

      runMotor(magnet);
    }
  }
}
// 2 = backward, 1 = forward, 4 = release
uint8_t parameterToInt(Magnet *magnet, uint8_t paramIdx)
{

  if (magnet->parameters[paramIdx][0] != '\0' && (strcmp(magnet->parameters[paramIdx], "FOR") == 0))
  {
    return FORWARD;
  }
  if (magnet->parameters[paramIdx][0] != '\0' && (strcmp(magnet->parameters[paramIdx], "BAC") == 0))
  {
    return BACKWARD;
  }
  if (magnet->parameters[paramIdx][0] != '\0' && (strcmp(magnet->parameters[paramIdx], "REL") == 0))
  {
    return RELEASE;
  }
  return 99;
}

void toggleHelper(Magnet *magnet)
{ // takes speed and direction
  Serial.println(F("toggling"));
  if (magnet->parameters[0][0] != '\0')
  {
    uint8_t speed = atoi(magnet->parameters[0]);
    uint8_t direction = parameterToInt(magnet, 1);
    if (direction != 99)
    {
      toggleStability(magnet, speed, direction);
    }
    else
    { // no valid direction
      toggleStability(magnet, speed);
    }
  }
  else
  {
    toggleStability(magnet);
  }
}

void fadeSineHelper(Magnet *magnet)
{ // takes max_speed = 255, int min_speed = 0, int skips = 15, int delay_amt = 10
  uint8_t max_speed;
  uint8_t min_speed;
  uint8_t skips;
  int delay_amt;
  if (magnet->parameters[0][0] != '\0')
  { // skip max
    max_speed = atoi(magnet->parameters[0]);
    Serial.println("made it with speed");
  }
  else
  {
    fadeSine(magnet);
    Serial.println("made it ");
    return;
  }
  if (magnet->parameters[1][0] != '\0')
  { // min
    min_speed = atoi(magnet->parameters[1]);
  }
  else
  {
    fadeSine(magnet, max_speed);
    return;
  }
  if (magnet->parameters[2][0] != '\0')
  { // skips
    skips = atoi(magnet->parameters[3]);
  }
  else
  {
    fadeSine(magnet, max_speed, min_speed);
    return;
  }
  if (magnet->parameters[3][0] != '\0')
  { // delay
    delay_amt = atoi(magnet->parameters[3]);
  }
  else
  {
    fadeSine(magnet, max_speed, min_speed, skips);
    return;
  }
  fadeSine(magnet, max_speed, min_speed, skips, delay_amt);
}

// same schtick as vibration
void fadeHelper(Magnet *magnet)
{ // takes skip rate, delay amt, direction, starting speed, max speed
  // Serial.println(F("fading in"));
  uint8_t skips;
  int delay_amt;
  uint8_t starting_speed;
  uint8_t ending_speed;
  if (magnet->parameters[0][0] != '\0')
  { // skip rate
    skips = atoi(magnet->parameters[0]);
  }
  else
  {
    fade(magnet);
    return;
  }
  if (magnet->parameters[1][0] != '\0')
  { // delay amt
    delay_amt = atoi(magnet->parameters[1]);
  }
  else
  {
    fade(magnet, skips);
    return;
  }
  if (magnet->parameters[2][0] != '\0')
  { // starting speed
    starting_speed = atoi(magnet->parameters[3]);
  }
  else
  {
    fade(magnet, skips, delay_amt);
    return;
  }
  if (magnet->parameters[3][0] != '\0')
  { // ending speed
    ending_speed = atoi(magnet->parameters[4]);
  }
  else
  {
    fade(magnet, skips, delay_amt, starting_speed);
    return;
  }
  fade(magnet, skips, delay_amt, starting_speed, ending_speed);
}

// i think this is run for each magnet in the list thing, then this is run in loop
void vibrateHelper(Magnet *magnet)
{ // takes speed and delay
  //  Serial.println(magnet->parameters[0]);
  //  Serial.println(magnet->parameters[1]);

  if (magnet->parameters[0][0] != '\0')
  {
    uint8_t speed = atoi(magnet->parameters[0]);
    if (magnet->parameters[1][0] != '\0')
    {
      uint8_t delay_amt = atoi(magnet->parameters[1]);
      vibrate(magnet, speed, delay_amt);
    }
    else
    {
      vibrate(magnet, speed);
    }
  }
  else
  {
    vibrate(magnet);
  }
}

// print array of parameters stored by magnet for debugging
void printParameters(Magnet *magnet)
{
  Serial.print(F("parameters: "));
  for (int i = 0; i < MAX_PARAMETERS; i++)
  {
    if (magnet->parameters[i][0] != '\0')
    { // Check if the parameter is not empty
      Serial.println(magnet->parameters[i]);
    }
  }
}

// this takes the input string and extracts the motor number, the command character, and puts the parameter into the motor
void parseInputIndiv()
{ // input format: "int motor#; char cmd; [optional] list, of, parameters" -> don't mess this up bc there is minimal validation
  // Serial.println(F("parsing"));
  uint8_t paramIndex = 0;
  char *token;

  // Tokenize input string using semicolon
  token = strtok(inputChars, ";");
  if (token == NULL)
  {
    Serial.println(F("Invalid input"));
    return;
  }

  int id = atoi(token);
  // Serial.print(F("id: "));
  // Serial.println(id);
  Magnet *magnet = getMagnetFromInteger(id);
  magnet->timer->stop();

  if (!magnet)
  {
    Serial.println(F("Invalid ID"));
    return;
  }

  // Clear all parameters
  for (int i = 0; i < MAX_PARAMETERS; i++)
  {
    memset(magnet->parameters[i], '\0', MAX_PARAM_LENGTH);
  }

  // check to see if there is a command
  token = strtok(NULL, ";");
  if (token == NULL || strlen(token) == 0)
  { // no command
    processIndivControl(magnet);
    return;
  }

  char command = token[0];

  // command must be letter
  if (!isAlpha(command))
  {
    Serial.println(F("Invalid or missing command"));
    return;
  }
  // Serial.print(F("command: "));
  // Serial.println(command);

  // Try to get parameters
  token = strtok(NULL, ";");

  if (token != NULL && strlen(token) > 0)
  {
    // Parameters exist — proceed only if command was given
    char *param = strtok(token, ",");

    while (param != NULL && paramIndex < MAX_PARAMETERS)
    {
      strncpy(magnet->parameters[paramIndex], param, MAX_PARAM_LENGTH);
      magnet->parameters[paramIndex][MAX_PARAM_LENGTH - 1] = '\0'; // end with null
      paramIndex++;
      param = strtok(NULL, ",");
    }
    processIndivControl(magnet, command, true);
    // printParameters(magnet);
  }
  else
  {
    // Only command
    processIndivControl(magnet, command);
  }

  // Serial.println(F("parse complete"));
}

void parseGroupParams()
{
  for (uint8_t i = 0; i < GROUP_PARAM_MAX; i++)
  { // reset all group params
    groupParams[i] = INT16_MAX;
  }

  uint8_t paramIndex = 0;
  char *token;
  token = strtok(inputChars, ";");

  // remove first char
  if (token != NULL && token[1] != '\0')
  {
    token = token + 1;
  }

  while (token != NULL && paramIndex < GROUP_PARAM_MAX)
  { // while there are remaining characters & doesn't surpass max
    groupParams[paramIndex] = atoi(token);
    paramIndex++;
    token = strtok(NULL, ";");
  }
}

void manageInput()
{
  if (newData == true)
  {
    // Serial.print(F("Input was: "));
    // Serial.println(inputChars);
    char first_char = (inputChars[0]);
    switch (first_char)
    {
    case 'm':
      //   Serial.println("received command");
      parseGroupParams();
      startMoveAB();
      // moveAB();
      break;
    // a lot of these cases are stupid
    case 'p':
      // split3(&m0_4, &m0_3, 255, 500);
      magnets[3]->motor->run(FORWARD);
      split2(magnets[0][2].motor, magnets[0][3].motor, 200, 300);
      break;
    case 'x':
      Serial.println(F("disabling"));
      disableEverything();
      break;
    // case '!':
    //   Serial.println(F("switching modes"));
    //   switchModesTemp();
    //   break;
    // case 'h':
    //   Serial.println(F("hopping"));
    //   hopBackEnabled = true;
    //   break;
    case 'u':
      Serial.println(F("pausing"));
      delay(5000);
      Serial.println(F("unpausing"));
      break;
    case 'l':
      setModeAll(NONE);
      if (loopEnabled == true)
      {
        loopEnabled = false;
        groupTimer.stop();
        stopAllTimers();
      }
      else
      {
        Serial.println(F("looping"));
        loopEnabled = true;
      }
      loopEnabled = true;
      break;
    case 'v': // toggles vibration enabled but doesnt edit the list

      break;
    case '@': // manage group params
      parseGroupParams();
      Serial.println(groupParams[0]);
      Serial.println(groupParams[1]);
      Serial.println(groupParams[2]);
      Serial.println(groupParams[3]);
      Serial.println(groupParams[4]);
      break;
    default: // indiv control
      // Serial.println(F("running indiv"));
      parseInputIndiv();
      break;
    }

    newData = false;
  }
}

void controlMotor(Magnet *magnet)
{
  switch (magnet->mode)
  {
  case VIBRATE:
    vibrateHelper(magnet);
    break;
  case FADE:
    fadeHelper(magnet);
    break;
  case FADESINE:
    fadeSineHelper(magnet);

  default:
    break;
  }
}

//======HOUSEKEEPING====

void stopAllTimers()
{
  for (uint8_t i = 0; i < num_rows; i++)
  {
    for (uint8_t j = 0; j < num_motors_per_row; j++)
    {
      magnets[i][j].timer->stop();
    }
  }
  groupTimer.stop();
}

void disableEverything()
{
  loopEnabled = false;
  moveEnabled = false;
  setModeAll(0);
  stopAllTimers();
  setSpeedAll(0);
  setDirectionAll(RELEASE);
}
void switchModesTemp()
{
}

void initializeMagnets()
{

  for (uint8_t s = 0; s < num_rows; s++)
  {
    shields[s].begin(); // initialize shields
    if (!shields[s].begin())
    {
      Serial.println(F("Could not find Motor Shield. Check wiring."));
      while (1)
        ;
    }
    // creates magnets and timers
    for (uint8_t m = 0; m < num_motors_per_row; m++)
    {
      Adafruit_DCMotor *motor = shields[s].getMotor(m + 1); // motors 1-4
      BlockNot *timer = &timers[s][m];
      magnets[s][m] = Magnet(motor, timer);
    }
  }
  stopAllTimers();
  setDirectionAll(RELEASE);
}

//======================================
void setup()
{
  // setSpeedAll(0);
  Serial.begin(115200);
  Serial.println(F("success"));
  //======================================

  initializeMagnets();

  // void loop() {
  //   recvWithEndMarker();
  //   manageInput();
}

void loop()
{
  recvWithEndMarker(); // replacement for read string
  manageInput();

  for (uint8_t i = 0; i < num_rows; i++)
  {
    for (uint8_t j = 0; j < num_motors_per_row; j++)
    {
      controlMotor(&magnets[i][j]);
    }
  }

  // if (hopBackEnabled) {
  //   hopBack(&m0_3, 180, 20);
  // }
  if (moveEnabled)
  {
    moveAB();
  }
  if (loopEnabled)
  {
    loopMotors(groupParams[0] == INT16_MAX ? 255 : groupParams[0],     // speed
               groupParams[1] == INT16_MAX ? FORWARD : groupParams[1], // direction
               groupParams[2] == INT16_MAX ? 1000 : groupParams[2],    // delay
               groupParams[3] == INT16_MAX ? 80 : groupParams[3],      // hopback
               groupParams[4] == INT16_MAX ? 20 : groupParams[4]);     // hopback delay
  }
}
