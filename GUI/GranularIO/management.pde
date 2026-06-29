Bang stopEverything;
Bang selectAll;
Bang deselectAll;
Bang resetSliders;
int managementStartX = 1150;
int managementStartY = 650;
int managementXSize = 100;
int managementYSize = 40;
int managementYSpacing = managementYSize + 20;
void setUpManagementButtons() {
  stopEverything = cp5.addBang("stopEverything")
    .setPosition(managementStartX, managementStartY)
    .setSize(managementXSize, managementYSize)
    .setTriggerEvent(Bang.RELEASE)
    .setLabel("stop everything")
    .setColor(debugColor)
    .addCallback(cursorCB)
    ;
  deselectAll = cp5.addBang("selectAll")
    .setPosition(managementStartX, managementStartY + managementYSpacing)
    .setSize(managementXSize, managementYSize)
    .setTriggerEvent(Bang.RELEASE)
    .setLabel("select all")
    .setColor(debugColor)
    .addCallback(cursorCB)
    ;
  deselectAll = cp5.addBang("deselectAll")
    .setPosition(managementStartX, managementStartY + 2 * managementYSpacing)
    .setSize(managementXSize, managementYSize)
    .setTriggerEvent(Bang.RELEASE)
    .setLabel("deselect all")
    .setColor(debugColor)
    .addCallback(cursorCB)
    ;
  resetSliders = cp5.addBang("resetSliders")
    .setPosition(managementStartX, managementStartY + 3 * managementYSpacing)
    .setSize(managementXSize, managementYSize)
    .setTriggerEvent(Bang.RELEASE)
    .setLabel("reset all")
    .setColor(debugColor)
    .addCallback(cursorCB)
    ;

  showAllSliders = cp5.addToggle("showAllSliders")
    .setPosition(managementStartX, managementStartY + 4 * managementYSpacing)
    .setSize(managementXSize, managementYSize)
    .setLabel("show all sliders")
    .setColor(debugColor)
    .addCallback(cursorCB)
    .addListener(new ControlListener() {
    public void controlEvent(ControlEvent sliderEvent) {
      if (showAllSliders.getBooleanValue()) {
        showSliders();
      } else {
        hideSliders();
      }
    }
  }
  );
}

void drawSectionHeaders() {
  // "Controls" header above management buttons
  fill(80);
  textAlign(LEFT);
  textSize(13);
  text("Controls", managementStartX, managementStartY - 18);
  stroke(180);
  strokeWeight(1);
  line(managementStartX, managementStartY - 12, managementStartX + managementXSize, managementStartY - 12);
  noStroke();

  // "Recording" header above recording buttons
  int recordingStartX = managementStartX + 130;
  text("Recording", recordingStartX, managementStartY - 18);
  stroke(180);
  strokeWeight(1);
  line(recordingStartX, managementStartY - 12, recordingStartX + managementXSize, managementStartY - 12);
  noStroke();

  // "Demo" header above demo toggles
  int demoStartX = recordingStartX + 130;
  text("Demo", demoStartX, managementStartY - 18);
  stroke(180);
  strokeWeight(1);
  line(demoStartX, managementStartY - 12, demoStartX + managementXSize, managementStartY - 12);
  noStroke();

  textSize(16);
  textAlign(LEFT);
}

void stopEverything() {
  clearCommandQueue();
  if (enableSerial) {
    serialPort.write("x\n");
  }
  if (mode == ActionMode.LOOP) {
    mode = ActionMode.MANUAL;
    modeButtons.activate(0);
  }
  groupSequences.clear();
  morphPlaybackActive = false;

  resetSliders();
  resetAllMagnets();

  println("Stopping everything");
  deselectAll();
}

void selectAll() {
  for (Toggle t : magButtons) {
    t.setState(true);
  }
  if (usingEM) {
    selectedMags.addAll(Arrays.asList(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15));
  } else {
    selectedMags.addAll(Arrays.asList(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48));
  }
}

void deselectAll() {
  for (Toggle t : magButtons) {
    t.setState(false);
  }
  selectedMags.clear();
}
