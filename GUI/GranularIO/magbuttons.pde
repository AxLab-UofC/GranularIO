Toggle magButtons[] = new Toggle[sliders.length];
int startX = 350;
int startY = 60;
int spacingX = 120;
int spacingY = 120;
int buttonSize = 80;
void setUpButtonGrid() {
  for (int i = 0; i < magButtons.length; i++) {
    final int index = i;
    magButtons[i] = cp5.addToggle("toggle_" + i)
      .setPosition(startX + (i % num_motors_per_row) * spacingX, startY + (i / num_motors_per_row) * spacingY)
      .setSize(buttonSize, buttonSize)
      .setColor(buttonColor)
      .setLabel("Magnet "+ i)
      .setColorLabel(blk)
      .addListener(new ControlListener() {
      public void controlEvent(ControlEvent e) {
        //keeping track of which magnets are selected & removes if deselected
        boolean activated = magButtons[index].getBooleanValue();
        if (activated) {
          addToSelectedMags(index);
        } else {
          selectedMags.remove(Integer.valueOf(index));
        }
        magButtonFunc(index, activated) ;
      }
    }
    );
    magButtons[i].addCallback(cursorCB);
  }
  for (int i = 0; i < magnets.length; i++) {
    magnets[i] = new Magnet(i); //initialize magnets
  }
  for (int i = 0; i < toggleColors.length; i++) {
    toggleColors[i] = color(200);
  }
}
ArrayList<Integer> selectedMags = new ArrayList<Integer>();

// Safe add function that prevents duplicates
void addToSelectedMags(int magnetIndex) {
  if (!selectedMags.contains(magnetIndex)) {
    selectedMags.add(magnetIndex);
    if (debugGroupControllers) {
      println("Added magnet " + magnetIndex + " to selectedMags. Total selected: " + selectedMags.size());
    }
  } else {
    println("Magnet " + magnetIndex + " is already selected, skipping add");
    if (debugGroupControllers) {
      println("Magnet " + magnetIndex + " is already selected, skipping add");
    }
  }
}


void magButtonFunc(int index, boolean activated) {
  //println("mag button pressed: "+index + ". activated? " + activated);
  switch(mode) {
  case MANUAL:
    //show hide sliders for manual control
    magnets[index].mode = Mode.RUN;
    if (activated) {
      sliders[index].show();
    } else {
      if (!showAllSliders.getBooleanValue()) {
        sliders[index].hide();
      }
    }
    break;
  case VIBRATE:
    if (!activated) {
      break;
    } // doesn't run if we are deselecting
    magnets[index].parameters.clear();
    magnets[index].timer.stop(); //to reset settings if applicable
    //question mark on this one
    //if (magnets[index].mode != Mode.VIBRATE) {

    int speed = (int)cp5.getController("vibrateIntensity").getValue();
    magnets[index].parameters.add(speed);
    float hz = cp5.getController("vibrateHz").getValue();
    int delay = (int)(500.0 / hz); // Hz -> per-toggle delay in ms
    magnets[index].parameters.add(delay);
    magnets[index].mode = Mode.VIBRATE;

    // Record individual magnet action
    ArrayList<Integer> singleMagnetVibrate = new ArrayList<Integer>();
    singleMagnetVibrate.add(index);
    recordEvent(mode.name(), "IndividualMagnet", singleMagnetVibrate, getCurrentParameters());

    //println("added parameters speed = "+speed+ " and delay = " +delay);

    // serialPort.write(index + ";v;" + distance + "," + speed + "\n");
    //sliders[index].setColor(vibrateColor);
    //println(index + ";v;" + distance + "," + delay+ "\n");
    //println("should have vibrated motor");
    // } else {
    //   magnets[index].mode = Mode.RUN;
    // }
    break;
    // case 3:
    // break;
  case FADE:
    if (!activated) {
      break;
    } // doesn't run if we are deselecting
    magnets[index].mode = Mode.FADE;
    magnets[index].parameters.clear();
    magnets[index].parameters.add((int)cp5.getController("fadeStart").getValue());
    magnets[index].parameters.add((int)cp5.getController("fadeEnd").getValue());
    magnets[index].parameters.add((int)cp5.getController("fadeSpeed").getValue());
    magnets[index].parameters.add((int)cp5.getController("fadeDelay").getValue());

    // Record individual magnet action
    ArrayList<Integer> singleMagnetFade = new ArrayList<Integer>();
    singleMagnetFade.add(index);
    recordEvent(mode.name(), "IndividualMagnet", singleMagnetFade, getCurrentParameters());

    // serialPort.write(index + ";f;" + distance + "\n");
    magButtons[index].setValue(false);
    break;
  case SPLIT:
    if (!activated) { //ignore deselections
      break;
    }
    if (selectedMags.size() > 1) {
      int center = selectedMags.get(0);
      int side = selectedMags.get(1);
      if (usingEM) {
        groupSequences.add(new SplitController(center, side));
      } else {
        groupSequences.add(new SplitControllerPM(side, center)); //for PM, side is center, center is side
      }
      //deselects both
      magButtons[center].setValue(false);
      magButtons[side].setValue(false);
    } else if (selectedMags.size() == 1) {
      instructions = "select second split target";
    }
    break;


  case MOVE:
    if (!activated) { //ignore deselections
      break;
    }
    if (selectedMags.size() > 1) {
      instructions = "";
      int first = selectedMags.get(0);
      int second = selectedMags.get(1);
      println("ready to move");

      // Pre-check path if obstacle avoidance is enabled
      if (moveAvoidObstaclesEnabled) {
        ArrayList<Integer> testPath = bfsPath(first, second, num_rows, num_motors_per_row);
        if (testPath == null) {
          instructions = "No valid path found";
          magButtons[first].setValue(false);
          magButtons[second].setValue(false);
          break;
        }
      }

      if (usingEM) {
        groupSequences.add(new MoveControllerV0(first, second));
      } else if (moveStepByStepEnabled) {
        groupSequences.add(new MoveControllerPMStep(first, second));
      } else {
        groupSequences.add(new MoveControllerPM(first, second));
      }
      println("made it here");
      magButtons[first].setValue(false);
      magButtons[second].setValue(false);
    } else if (selectedMags.size() == 1) {
      instructions = "select end point";
    }
    break;
  case MERGE:
    if (!activated) { //ignore deselections
      break;
    }
    if (selectedMags.size() == 1) {
      instructions = "select second merge pile";
    } else if (selectedMags.size() == 2) {
      instructions = "select target magnet";
    } else if (selectedMags.size() > 2) {
      instructions = "";

      int first = selectedMags.get(0);
      int second = selectedMags.get(1);
      int target = selectedMags.get(2);
      println("ready to merge");
      groupSequences.add(new MergeController(first, second, target));
      magButtons[first].setValue(false);
      magButtons[second].setValue(false);
    }
    break;
    // case LOOP:
    //   if (!activated) {
    //     break;
    //   }
    //   // LoopController loop = new LoopController();
    //   // loop.addToGroup(index); //adding in sequential order
    // }

  case ROTATE:
    if (!activated) { //ignore deselections
      break;
    }
    if (selectedMags.size() == 1) {
      Magnet center = magnets[selectedMags.get(0)];
      groupSequences.add(new RotateController(center));
      magButtons[selectedMags.get(0)].setValue(false);
      instructions = "";
    }
    break;

  case CONSTANT:
    if (!activated) { //ignore deselections
      break;
    }
    groupSequences.add(new ConstantController(index, (int)cp5.getController("constantIntensity").getValue()));
    // deselect the magnet
    magButtons[index].setValue(false);
    instructions = "";
    break;
  case DRAW:
    // In DRAW mode, just keep track of selected magnets for pattern creation
    // No automatic deselection - user manually selects/deselects to create pattern
    break;
  default:
    break;
  }
}

void hideButtons() {
  for (Toggle t : magButtons) {
    t.hide();
  }
}

void updateToggleColor(int index, int value) {
  if (debugSlider) {
    println("updateToggleColor: " + index + " " + value);
  }
  int r, g, b;
  if (value == 0) {
    r = g = b = 200; // gray
    toggleColors[index] = (color(r, g, b));
    return;
  }
  float pct = 1.0 * abs(value) / maxIntensity;
  if (usingEM) {
    if (value > 0) {
      r = (int)lerp(200, 200, pct);  // gray to red: red stays 200
      g = (int)lerp(200, 0, pct);    // green goes from 200 to 0
      b = (int)lerp(200, 0, pct);    // blue goes from 200 to 0
    } else {
      r = (int)lerp(200, 0, pct);    // gray to blue: red goes from 200 to 0
      g = (int)lerp(200, 0, pct);    // green goes from 200 to 0
      b = (int)lerp(200, 200, pct);  // blue stays 200
    }
  } else {
    if (index %2!=0) {
      r = (int)lerp(200, 200, pct);  // gray to red: red stays 200
      g = (int)lerp(200, 0, pct);    // green goes from 200 to 0
      b = (int)lerp(200, 0, pct);    // blue goes from 200 to 0
    } else {
      r = (int)lerp(200, 0, pct);    // gray to blue: red goes from 200 to 0
      g = (int)lerp(200, 0, pct);    // green goes from 200 to 0
      b = (int)lerp(200, 200, pct);  // blue stays 200
    }
  }
  if (debugSlider) {
    println("updateToggleColor: " + index + " " + value + " " + r + " " + g + " " + b);
  }
  toggleColors[index] = (color(r, g, b));
}

color toggleColors[] = new color[magButtons.length];
void drawCircles() {
  for (int i = 0; i < magButtons.length; i++) {
    int x = startX + (i % num_motors_per_row) * spacingX;
    int y = startY + (i / num_motors_per_row) * spacingY;
    int cx = x + buttonSize / 2;
    int cy = y + buttonSize / 2;
    // println(cx + " " + cy);
    fill(toggleColors[i]);
    noStroke();
    ellipse(cx, cy, buttonSize - 10, buttonSize - 10);
  }
}
