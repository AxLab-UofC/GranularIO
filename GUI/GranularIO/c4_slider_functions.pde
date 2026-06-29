import java.util.HashSet;
import java.util.LinkedHashMap;

// Rate-limited serial command queue (prevents overwhelming the serial bus)
int COMMAND_DELAY_MS = 10;
long lastCommandSentTime = 0;
LinkedHashMap<Integer, String> commandQueue = new LinkedHashMap<Integer, String>();

void enqueueCommand(int motorIndex, String command) {
  // Replace any existing pending command for this motor (only latest value matters)
  commandQueue.put(motorIndex, command);
}

void processCommandQueue() {
  if (!enableSerial || commandQueue.isEmpty()) return;
  while (!commandQueue.isEmpty() && millis() - lastCommandSentTime >= COMMAND_DELAY_MS) {
    // Get and remove the first entry
    Integer key = commandQueue.keySet().iterator().next();
    String cmd = commandQueue.remove(key);
    serialPort.write(cmd);
    lastCommandSentTime = millis();
  }
}

void clearCommandQueue() {
  commandQueue.clear();
}

Slider sliders[] = new Slider[NUM_MAGNETS];
Toggle showAllSliders;
Toggle snapToZero;
boolean snapToZeroEnabled = false;
boolean debugSlider = true;
HashSet<Integer> newMotors = new HashSet<Integer>();

void loadNewMotors() {
  try {
    File f = new File(dataPath("new_motors.txt"));
    if (!f.exists()) {
      println("No new_motors.txt found, all motors use default scaling");
      return;
    }
    String[] lines = loadStrings(dataPath("new_motors.txt"));
    for (String line : lines) {
      line = line.trim();
      if (line.startsWith("#") || line.isEmpty()) continue;
      String[] parts = split(line, ',');
      for (String part : parts) {
        part = part.trim();
        if (!part.isEmpty()) {
          newMotors.add(Integer.parseInt(part));
        }
      }
    }
    println("Loaded new motors: " + newMotors);
  } catch (Exception e) {
    println("Error loading new_motors.txt: " + e.toString());
  }
}
void updateRangeSliders(int startRange, int endRange) {
  for (int i = 0; i < sliders.length; i++) {
    sliders[i].setRange(startRange, endRange);
  }
}
void updateRangeSliders(float startRange, float endRange) {
  for (int i = 0; i < sliders.length; i++) {
    sliders[i].setRange(startRange, endRange);
  }
}
float defaultStartRange;
float defaultEndRange;
boolean snap = false;

void setDefaultRanges() {
  if (usingEM) {
    defaultStartRange = -maxIntensity;
    defaultEndRange = maxIntensity;
  } else { //using Permament magnets
    defaultStartRange = 0;
    defaultEndRange = 200;
  }
}

void setUpSliders(int startX, int startY, int spacingX, int spacingY) {
  setDefaultRanges();
  resetting = true;
  for (int i = 0; i < sliders.length; i++) {
    final int index = i;
    sliders[i] = cp5.addSlider("slider_" + i)
      .setPosition(startX + (i % num_motors_per_row) * spacingX, startY + (i / num_motors_per_row) * spacingY + buttonSize + 20)
      .setSize(buttonSize, 20)
      .setRange(defaultStartRange, defaultEndRange)
      .setValue(0)
      .setColor(grayscale)
      .setLabel("")
      .addListener(new ControlListener() {
      public void controlEvent(ControlEvent sliderEvent) {
        // if (snapToZeroEnabled) {
        //   snapToZero(sliderEvent);
        // }
        // if (snap) return;
        handleSliderChange(index, (int)sliderEvent.getValue());
      }
    }
    );
  }
  resetting = false;

  // snapToZero = cp5.addToggle("snapToZeroEnabled")
  //   .setPosition(1350, 800)
  //   .setSize(managementYSize, managementYSize)
  //   .setLabel("snap to zero")
  //   .setColor(grayscale)
  //   .addCallback(cursorCB)
  //   .addListener(new ControlListener() {
  //   public void controlEvent(ControlEvent sliderEvent) {
  //     // if (snapToZeroEnabled) {
  //     //   snapToZeroEnabled = true;
  //     // } else {
  //     //   snapToZeroEnabled = false;
  //     // }
  //   }
  // }
  // );
}

// void snapToZero(ControlEvent sliderEvent) {
//   //snap to zero
//   if (snap) return;
//   int index = Integer.parseInt(sliderEvent.getController().getName().split("_")[1]);
//   float val = sliderEvent.getValue();
//   float snapThreshold = 30; //threshhold that becomes 0

//   if (abs(val) < snapThreshold) {
//     snap = true;
//     val = 0;
//     sliders[index].setValue(0);
//   }
//   snap = false;
// }
void showSliders() {
  for (int i = 0; i < sliders.length; i++) {
    sliders[i].show();
  }
}
boolean handlingMulti = false;
void handleSliderChange(int index, int distance) {
  if (debugSlider) {
    println("handleSliderChange: " + index + " " + distance);
  }
  if (selectedMags.size() < 2 || handlingMulti || !selectedMags.contains(index) || mode != ActionMode.MANUAL) {
    if (debugSlider) {
      println("handleSliderChangeSingle: " + index + " " + distance);
    }
    handleSliderChangeSingle(index, distance);
  } else {
    if (debugSlider) {
      println("handleSliderChangeMulti: " + index + " " + distance);
    }
    handleSliderChangeSingle(index, distance);// first set the current slider to the distance, otherwise when multi, there's no change so currentslider will not work
    handleSliderChangeMulti(distance);
  }
}

void handleSliderChangeSingle(int index, int distance) {
  updateToggleColor(index, distance);

  if (resetting) {
    return;
  }
  if (!enableSerial) {
    return;
  }
  if (usingEM) {
    if (newMotors.contains(index)) {
      distance = distance / 2;
    }
    enqueueCommand(index, index + ";r;" + distance + "\n");
  } else {
    distance = (int)defaultEndRange - distance;
    if (newMotors.contains(index)) {
      distance = distance / 2;
    }
    // send command to Teensy in format "r,00,00;\n"
    if (index < 10) {
      enqueueCommand(index, "r,0" + index + "," + distance/10.0 + ";\n");
    } else {
      enqueueCommand(index, "r," + index + "," + distance/10.0 + ";\n");
    }
  }
  //println("a slider event. setting motor " + (index) + " to " + distance);
}

void handleSliderChangeMulti(int distance) {
  handlingMulti = true;
  if (debugSlider) {
    println("handleSliderChangeMulti, current selectedMags: " + selectedMags);
  }
  for (Integer i : selectedMags) {
    if (debugSlider) {
      println("setting slider: " + i + " " + distance);
    }
    sliders[i].setValue(distance);
  }
  handlingMulti = false;
}

void resetSliders() {
  resetting = true;
  for (int i = 0; i < sliders.length; i++) {
    sliders[i]
      .setValue(0)
      .setColor(grayscale)
      ;
  }
  resetting = false;
}

void hideSliders() {
  for (int i = 0; i < sliders.length; i++) {
    sliders[i].hide();
  }
}
