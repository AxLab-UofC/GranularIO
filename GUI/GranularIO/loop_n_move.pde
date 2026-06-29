// // int loopDelay = 10;
// // int loopDirection = 1; //ccw is -1 cw is 1
// // int magSpeed = 10000;
// // int magDirection = 1; //forward is 1 backward is 2 (input is -1,1)
// // int loopHopSpeed = 80;
// // int loopHopDelay = 20;



// Timer loopTimer = new Timer(0);
// //void loopMagnets() {
// //  if (loopTimer.getDuration() == 0) {
// //    loopTimer.setDuration(loopDelay);
// //    curr_motor = 0;
// //    curr_shield = 0;
// //  }
// //  if (!loopTimer.running) {
// //    resetSliders();
// //    loopTimer.start();
// //  }

// //  //magnets[curr_shield][curr_motor].motor->setSpeed(speed);

// //  ///
// //  if (loopTimer.triggered()) {
// //    //hopBackBlock(&magnets[curr_shield][curr_motor], hop_val, hop_delay, true);
// //    loopCalculate();
// //  }
// //}


// boolean loopEnabled = false;
// int curr_shield = -1;
// int curr_motor = -1;
// int curr_pos = -1;
// int prev_pos = -1;
// int target_pos = -1;


// void loopCalculate() {
//   if (curr_shield == 0) {                   //on top row
//     if (curr_motor + 1 < num_motors_per_row) {  //not at right side
//       curr_motor++;
//     } else {
//       curr_shield++;
//     }
//     return;
//   }
//   if (curr_shield == (num_rows - 1)) {  //on bottom row
//     if (curr_motor > 0) {                  //not at left side
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


// // int getMagIndexFromCoord(int shield, int motor) {
// //   println("next is: " + shield * num_motors_per_row + motor);
// //   return shield * num_motors_per_row + motor;
// // }


// ////-------------------------------------------------
// boolean moveEnabled = false;

// int calculateNextMagnetAB(int curr_pos) {
//   //calcul
//   int curr_row = curr_pos / num_motors_per_row;
//   int curr_col = curr_pos % num_motors_per_row;
//   int target_row = target_pos / num_motors_per_row;
//   if (curr_row < target_row) {  //needs to increase row
//     return getMagIndexFromCoord(curr_row + 1, curr_col);
//   }
//   if (curr_row > target_row) {  //needs to decrease row
//     return getMagIndexFromCoord(curr_row - 1, curr_col);
//   }
//   //else on right row. check columns
//   int target_col = target_pos % num_motors_per_row;
//   if (curr_col < target_col) {  //needs to increase col
//     return getMagIndexFromCoord(curr_row, curr_col + 1);
//   }
//   if (curr_col > target_col) {  //needs to decrease col
//     return getMagIndexFromCoord(curr_row, curr_col - 1);
//   }
//   return curr_pos;
// }

// void startMoveAB(int start_pos, int end_pos) {

//   println("received moving command");
//   curr_pos = start_pos;
//   target_pos = end_pos;
//   //magButtons.hide();
//   //showSliders();

//   //indivModes[curr_pos] = 2;
//   prev_pos = curr_pos;
// }

// void moveAB(int start_pos, int end_pos) {
//   if (curr_pos == target_pos) {  //stop condition
//     moveEnabled = true;
//     return;
//   }
//   //Magnet *curr_mag = getMagnetFromInteger(curr_pos);
//   //curr_mag->parameters[0][0] = '2';

//   // print("current: "));
//   // println(curr_pos);
//   // println(curr_mag->mode);
//   //if (getMagnetFromInteger(prev_pos)->mode == Mode.NONE) {  //fade is completed
//   //  println(curr_pos);
//   //  int next_pos = calculateNextMagnetAB(curr_pos);
//   //  sliders[next_pos].setValue(255);
//   //  curr_mag->mode = FADE;                          //fade current motor
//   //  prev_pos = curr_pos;
//   //  curr_pos = next_pos;
//   //  println(curr_pos);
//   //}
//   //println("============="));
// }


// /////==================================
