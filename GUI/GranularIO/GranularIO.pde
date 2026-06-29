import processing.serial.*;
import controlP5.*;
import processing.video.*;
import java.util.Arrays;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.TreeMap;
import java.util.Map;
import java.util.Collections;

ControlP5 cp5;
Serial serialPort;  // Create object from Serial class
boolean enableSerial = false;

// Camera overlay for motor section
Capture cam;
boolean cameraEnabled = true;
String cameraName = "BRIO";

boolean usingEM = true;
int num_rows = usingEM ? 4 : 7;
int num_motors_per_row = usingEM ? 4 : 7;
float maxIntensity = 255.0;
final int NUM_MAGNETS = num_rows * num_motors_per_row ;
boolean resetting = false;


// temp fix for syncing vibrate
boolean globalVibrateFlag = true;
boolean globalVibrateFlagLock = false;

void setup() {
  size(1600, 950, P2D);
  noStroke();
  try {
    PFont font = loadFont("LucidaGrande-16.vlw");
    textFont(font);
    cp5 = new ControlP5(this);
  }
  catch (Exception e) {
    println("font not found");
    println(e.toString());
    delay(5000);
  }
  cp5.setAutoDraw(false);

  //set up number of rows and motors per row according to usingEM
  if (usingEM) {
    num_rows = 4;
    num_motors_per_row = 4;
    startX = 350;
    startY = 100;
    spacingX = 200;
    spacingY = 200;
    buttonSize = 150;
  } else {
    num_rows = 7;
    num_motors_per_row = 7;
    startX = 300;
    startY = 60;
    spacingX = 120;
    spacingY = 120;
    buttonSize = 80;
  }

  setUpCallbacks();

  //hideButtons();
  setUpSliders(startX, startY, spacingX, spacingY);
  hideSliders();
  println("set up sliders");

  loadNewMotors();
  println("loaded new motors config");

  setUpButtonGrid();
  initCameraBallDetectionArrays();
  println("set up buttons");

  setUpSerial();
  println("set up serial");

  setUpModes();
  println("set up modes");

  setUpManagementButtons();
  println("set up management");

  setUpSettings();
  println("set up settings");

  setUpRecordingButtons();
  println("set up recording");

  // Load saved patterns
  loadAllSavedPatterns();
  println("loaded patterns");

  // Initialize camera for motor section overlay
  setUpCamera();
  println("set up camera");

  // Restore saved camera calibration (crop, mirror, alpha)
  loadCameraCalibration();
  println("loaded camera calibration");
}

void exit() {
  // Auto-save camera calibration on close
  if (cameraEnabled && cameraCropEnabled) {
    saveCameraCalibration();
  }
  super.exit();
}

void draw() {
  background(bgColor);
  processCommandQueue();
  inputHandler();
  cp5.draw();
  // temp fix for syncing vibrate
  globalVibrateFlagLock = false;
  for (Magnet magnet : magnets) {
    try {
      magnet.update();
    }
    catch (Exception e) {
      println("magnet problem?");
      println(e.toString());
    }
  }
  for (Iterator<GroupController> iter = groupSequences.iterator(); iter.hasNext(); ) {
    GroupController sequence = iter.next();
    try {
      sequence.update(iter);
    }
    catch (Exception e) {
      println("sequence problem with type: " + sequence.toString());
      println(e.getMessage());
    }
  }
  // Add any controllers queued during iteration (avoids ConcurrentModificationException)
  if (!pendingGroupSequences.isEmpty()) {
    groupSequences.addAll(pendingGroupSequences);
    pendingGroupSequences.clear();
  }

  // Draw mode Labels
  drawModeLabels();

  // Draw section headers for Controls and Recording
  drawSectionHeaders();

  writeInstructions();

  drawCircles();

  // Draw camera overlay over motor section circles
  drawCameraOverlay();

  // Update playback if active
  updatePlayback();

  // Draw file selection interface if active
  drawFileSelection();

  // Draw thumbnail grid if active
  drawThumbnailGrid();

  // Draw morph overlay and filmstrip
  drawMorphOverlay();
  drawMorphFilmstrip();
  drawMorphPatternIndicators();

  //println(sliders[4].isVisible());
}


void setUpSerial() {
  // find the serial port that starts with "/dev/cu.usbmodem"
  String[] portNames = Serial.list();
  String portName = portNames[0];
  printArray(portNames);
  for (int i = 0; i < portNames.length; i++) {
    if (portNames[i].startsWith("/dev/cu.usbmodem")) {
      //serialIndex = i;
      portName = portNames[i];
      enableSerial = true;
      break;
    }
  }
  if (!enableSerial) {
    println("serial not enabled");
    serialPort = null;
    return;
  }
  // if portName is not in the entire list
  // if (!Arrays.asList(Serial.list()).contains(portName)) {
  //   portName = "/dev/cu.Bluetooth-Incoming-Port";
  //   println("Port not found, trying bluetooth port");
  //   printArray(Serial.list());
  // }
  println("connecting to serial port: " + portName);
  serialPort = new Serial(this, portName, 115200);
  serialPort.clear();
}



CallbackListener cb;
CallbackListener cursorCB;

void setUpCallbacks() {
  cb = new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
      switch(theEvent.getAction()) {
        case(ControlP5.ACTION_RELEASE):
        updateRangeSliders(defaultStartRange, defaultEndRange);
        break;
        case(ControlP5.ACTION_PRESSED):
        updateRangeSliders(defaultStartRange, defaultEndRange);
        break;
      }
    }
  };
  cursorCB = new CallbackListener() {
    public void controlEvent(CallbackEvent theEvent) {
      switch(theEvent.getAction()) {
        case(ControlP5.ACTION_ENTER):
        cursor(HAND);
        break;
        case(ControlP5.ACTION_LEAVE):
        case(ControlP5.ACTION_RELEASEDOUTSIDE):
        cursor(ARROW);
        break;
      }
    }
  };
}



void inputHandler() {
  if (!enableSerial) {
    return;
  }
  if (serialPort.available() > 0) {
    String input = serialPort.readStringUntil('\n');
    print("Received: ");
    println(input);
    if (input == null) {
      serialPort.clear();
      return;
    }

    String[] inputList = split(input, ',');
    for (int i = 0; i < inputList.length; i++) {
      if (inputList[i].startsWith("Manual")) {
        modeButtons.activate(0);
      }
    }
  }
}

String instructions = "";
void writeInstructions() {
  text(instructions, 500, 50);
}

// Shared scrollbar drawing utility
// horizontal: true for horizontal, false for vertical
void drawScrollbar(boolean horizontal, int trackX, int trackY,
                   int trackLength, int trackThickness,
                   int totalItems, int visibleItems, int scrollOffset) {
  if (totalItems <= visibleItems) return; // No scrollbar needed

  // Track
  fill(200, 200, 200, 120);
  noStroke();
  if (horizontal) {
    rect(trackX, trackY, trackLength, trackThickness, 3);
  } else {
    rect(trackX, trackY, trackThickness, trackLength, 3);
  }

  // Thumb
  float thumbRatio = (float)visibleItems / totalItems;
  int thumbSize = max(20, (int)(trackLength * thumbRatio));
  int scrollRange = totalItems - visibleItems;
  int thumbPos = (scrollRange > 0) ? (int)((float)scrollOffset / scrollRange * (trackLength - thumbSize)) : 0;

  fill(120, 120, 120, 200);
  if (horizontal) {
    rect(trackX + thumbPos, trackY, thumbSize, trackThickness, 3);
  } else {
    rect(trackX, trackY + thumbPos, trackThickness, thumbSize, 3);
  }
}

// Handle keyboard input for file selection
void keyPressed() {
  if (showFileList) {
    processFileSelectionKey(keyCode);
    return;
  }
  if (key == 'b' || key == 'B') {
    printCameraBallPresentDebug();
  }
}

// Handle mouse clicks
void mousePressed() {
  // File selection dialog is modal — consume all clicks when active
  if (showFileList) {
    handleFileSelectionClick(mouseX, mouseY);
    return;
  }

  // Handle thumbnail delete (red X) before regular thumbnail click
  if (showThumbnailGrid) {
    if (handleThumbnailDeleteClick(mouseX, mouseY)) {
      return; // delete handled, skip loading
    }
    handleThumbnailClick(mouseX, mouseY);
  }

  // Handle filmstrip clicks for morph mode
  if (mode == ActionMode.MORPH && currentMorphSequence != null) {
    handleFilmstripClick(mouseX, mouseY);
  }

  // Handle target preview drag start for morph sequence reordering
  if (mode == ActionMode.MORPH) {
    handleTargetPreviewMousePressed(mouseX, mouseY);
  }

  // Handle camera calibration clicks (top-left then bottom-right)
  if (cameraCalibrating) {
    handleCameraCalibrationClick(mouseX, mouseY);
  }
}

// Track mouse movement for thumbnail hover
void mouseMoved() {
  updateThumbnailHover(mouseX, mouseY);
}

// Handle drag for target preview reordering
void mouseDragged() {
  handleTargetPreviewMouseDragged(mouseX, mouseY);
}

// Handle drop for target preview reordering
void mouseReleased() {
  handleTargetPreviewMouseReleased();
}

// Handle mouse wheel scrolling
void mouseWheel(MouseEvent event) {
  float e = event.getCount();
  if (showFileList) {
    handleFileListScroll(e);
    return;
  }

  // In MORPH mode, scroll filmstrip or target preview when cursor is over the bottom strip area
  if (mode == ActionMode.MORPH) {
    boolean overStrip = mouseY >= (filmstripY - 30) && mouseY <= (filmstripY + filmstripThumbSize + 30) &&
      mouseX >= (filmstripX - 40) && mouseX <= width;
    if (overStrip) {
      if (currentMorphSequence != null) {
        filmstripScrollOffset -= (int)e;
      } else {
        targetPreviewScrollOffset -= (int)e;
      }
      return;
    }
  }

  if (showThumbnailGrid) {
    handleThumbnailScroll(e);
    return;
  }
}
