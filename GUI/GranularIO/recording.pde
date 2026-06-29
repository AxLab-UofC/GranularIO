// Recording system for magnet modes and controller groups
import java.io.FileWriter;
import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.io.File;

// Recording state
boolean isRecording = false;
boolean isPlaying = false;
long recordingStartTime = 0;
ArrayList<RecordingEvent> recordingEvents = new ArrayList<RecordingEvent>();
ArrayList<RecordingEvent> playbackEvents = new ArrayList<RecordingEvent>();
int currentPlaybackIndex = 0;
long playbackStartTime = 0;
String loadedFilename = ""; // Store the currently loaded filename

// File selection state
boolean showFileList = false;
String[] availableFiles = {};
int selectedFileIndex = -1;
int fileListScrollOffset = 0;
long lastFileClickTime = 0;

// Recording buttons
Bang recordButton;
Bang playButton;
Bang stopPlaybackButton;
Bang saveRecordingButton;
Bang loadRecordingButton;

boolean debugRecording = true;

// Demonstration mode state
boolean isDemoLooping = false;        // master loop on/off
boolean demoActiveProfile = true;      // true=ACTIVE, false=IDLE
float demoActiveSpeed = 1.0;           // 0.1x .. 3.0x
float demoIdleSpeed   = 0.3;
int   demoActivePauseSec = 0;          // pause between loops (sec)
int   demoIdlePauseSec   = 30;
boolean isLoopPausing = false;         // in the inter-loop wait?
long    loopPauseStartMs = 0;

Toggle demoLoopToggle;
Toggle demoProfileToggle;

float currentDemoSpeed() {
  return demoActiveProfile ? demoActiveSpeed : demoIdleSpeed;
}
int currentDemoPauseMs() {
  return 1000 * (demoActiveProfile ? demoActivePauseSec : demoIdlePauseSec);
}

// Data structure for recording events
class RecordingEvent {
  long timestamp;           // Time since recording started (ms)
  String mode;              // ActionMode name
  String controllerType;    // Type of controller (MoveControllerV0, SplitController, etc.)
  ArrayList<Integer> selectedMagnets; // Selected magnet indices
  HashMap<String, Float> parameters;  // Controller parameters

  RecordingEvent(long timestamp, String mode, String controllerType, ArrayList<Integer> selectedMagnets, HashMap<String, Float> parameters) {
    this.timestamp = timestamp;
    this.mode = mode;
    this.controllerType = controllerType;
    this.selectedMagnets = new ArrayList<Integer>(selectedMagnets);
    this.parameters = new HashMap<String, Float>(parameters);
  }

  // Convert to string for file storage
  String toString() {
    String result = timestamp + "," + mode + "," + controllerType + ",";

    // Add selected magnets
    for (int i = 0; i < selectedMagnets.size(); i++) {
      result += selectedMagnets.get(i);
      if (i < selectedMagnets.size() - 1) result += ";";
    }
    result += ",";

    // Add parameters
    for (String key : parameters.keySet()) {
      result += key + ":" + parameters.get(key) + ";";
    }

    return result;
  }
}

// Utility function to create RecordingEvent from string (for file loading)
RecordingEvent createRecordingEventFromString(String line) {
  String[] parts = line.split(",");
  if (parts.length < 4) return null;

  long timestamp = Long.parseLong(parts[0]);
  String mode = parts[1];
  String controllerType = parts[2];

  // Parse selected magnets
  ArrayList<Integer> selectedMagnets = new ArrayList<Integer>();
  if (!parts[3].isEmpty()) {
    String[] magnetStrings = parts[3].split(";");
    if (debugRecording) {
      println("HEREHERE!! magnetStrings"+magnetStrings);
    }
    for (String magnetStr : magnetStrings) {
      if (!magnetStr.isEmpty()) {
        if (debugRecording) {
          selectedMagnets.add(Integer.parseInt(magnetStr));
        }
      }
    }
  }

  // Parse parameters
  HashMap<String, Float> parameters = new HashMap<String, Float>();
  if (parts.length > 4 && !parts[4].isEmpty()) {
    String[] paramStrings = parts[4].split(";");
    for (String paramStr : paramStrings) {
      if (!paramStr.isEmpty() && paramStr.contains(":")) {
        String[] keyValue = paramStr.split(":");
        parameters.put(keyValue[0], Float.parseFloat(keyValue[1]));
      }
    }
  }

  return new RecordingEvent(timestamp, mode, controllerType, selectedMagnets, parameters);
}

void setUpRecordingButtons() {
  int recordingStartX = managementStartX + 130;
  int recordingStartY = managementStartY;
  int recordingXSize = 40;
  int recordingYSize = 40;
  int recordingYSpacing = recordingYSize + 20;

  // Record button
  recordButton = cp5.addBang("toggleRecording")
    .setPosition(recordingStartX, recordingStartY)
    .setSize(recordingXSize, recordingYSize)
    .setTriggerEvent(Bang.RELEASE)
    .setLabel("Start Recording")
    .setColor(debugColor)
    .addCallback(cursorCB);

  // Play button
  playButton = cp5.addBang("startPlayback")
    .setPosition(recordingStartX, recordingStartY + recordingYSpacing)
    .setSize(recordingXSize, recordingYSize)
    .setTriggerEvent(Bang.RELEASE)
    .setLabel("Play Recording")
    .setColor(debugColor)
    .addCallback(cursorCB);

  // Stop playback button
  stopPlaybackButton = cp5.addBang("stopPlayback")
    .setPosition(recordingStartX, recordingStartY + 2 * recordingYSpacing)
    .setSize(recordingXSize, recordingYSize)
    .setTriggerEvent(Bang.RELEASE)
    .setLabel("Stop Playback")
    .setColor(debugColor)
    .addCallback(cursorCB);

  // Save recording button
  saveRecordingButton = cp5.addBang("saveRecordingToFile")
    .setPosition(recordingStartX, recordingStartY + 3 * recordingYSpacing)
    .setSize(recordingXSize, recordingYSize)
    .setTriggerEvent(Bang.RELEASE)
    .setLabel("Save Recording")
    .setColor(debugColor)
    .addCallback(cursorCB);

  // Load recording button
  loadRecordingButton = cp5.addBang("loadRecordingFromFile")
    .setPosition(recordingStartX, recordingStartY + 4 * recordingYSpacing)
    .setSize(recordingXSize, recordingYSize)
    .setTriggerEvent(Bang.RELEASE)
    .setLabel("Load Recording")
    .setColor(debugColor)
    .addCallback(cursorCB);

  // ----- Demo column (right of Recording column) -----
  int demoStartX = recordingStartX + 130;

  demoLoopToggle = cp5.addToggle("demoLoopToggle")
    .setPosition(demoStartX, recordingStartY)
    .setSize(recordingXSize, recordingYSize)
    .setLabel("loop")
    .setColor(debugColor)
    .addCallback(cursorCB)
    .addListener(new ControlListener() {
      public void controlEvent(ControlEvent e) {
        isDemoLooping = demoLoopToggle.getBooleanValue();
      }
    });

  demoProfileToggle = cp5.addToggle("demoProfileToggle")
    .setPosition(demoStartX, recordingStartY + recordingYSpacing)
    .setSize(recordingXSize, recordingYSize)
    .setLabel("active/idle")
    .setValue(demoActiveProfile ? 1 : 0)
    .setColor(debugColor)
    .addCallback(cursorCB)
    .addListener(new ControlListener() {
      public void controlEvent(ControlEvent e) {
        long now = millis();
        float oldSpeed = currentDemoSpeed();
        demoActiveProfile = demoProfileToggle.getBooleanValue();
        float newSpeed = currentDemoSpeed();
        if (isPlaying && !isLoopPausing && oldSpeed > 0 && newSpeed > 0) {
          long virtualElapsed = (long)((now - playbackStartTime) * oldSpeed);
          playbackStartTime = now - (long)(virtualElapsed / newSpeed);
        }
      }
    });
}

void toggleRecording() {
  if (isRecording) {
    stopRecording();
  } else {
    startRecording();
  }
}

void startRecording() {
  isRecording = true;
  recordingStartTime = millis();
  recordingEvents.clear();
  recordButton.setLabel("Stop Recording");
  recordButton.setColor(debugColor);
  println("Recording started");
}

void stopRecording() {
  isRecording = false;
  recordButton.setLabel("Start Recording");
  recordButton.setColor(debugColor);
  println("Recording stopped. Events recorded: " + recordingEvents.size());
}

void recordEvent(String mode, String controllerType, ArrayList<Integer> selectedMagnets, HashMap<String, Float> parameters) {
  if (!isRecording) return;

  long currentTime = millis();
  long timestamp = currentTime - recordingStartTime;

  RecordingEvent event = new RecordingEvent(timestamp, mode, controllerType, selectedMagnets, parameters);
  recordingEvents.add(event);

  println("Recorded event: " + mode + " at " + timestamp + "ms");
}

void startPlayback() {
  if (playbackEvents.isEmpty()) {
    println("No recording loaded for playback");
    return;
  }

  isPlaying = true;
  isLoopPausing = false;
  playbackStartTime = millis();
  currentPlaybackIndex = 0;
  playButton.setColor(debugColor);
  playButton.setLabel("Playing...");
  println("Playback started");
}

void stopPlayback() {
  isPlaying = false;
  isLoopPausing = false;
  playButton.setColor(debugColor);
  playButton.setLabel("Play Recording");
  println("Playback stopped");
  instructions = "Playback Stopped";
}

void updatePlayback() {
  if (!isPlaying || playbackEvents.isEmpty()) return;

  long now = millis();

  // Inter-loop pause window
  if (isLoopPausing) {
    if (now - loopPauseStartMs >= currentDemoPauseMs()) {
      isLoopPausing = false;
      currentPlaybackIndex = 0;
      playbackStartTime = now;
    }
    return;
  }

  long virtualElapsed = (long)((now - playbackStartTime) * currentDemoSpeed());

  while (currentPlaybackIndex < playbackEvents.size()) {
    RecordingEvent nextEvent = playbackEvents.get(currentPlaybackIndex);

    if (virtualElapsed >= nextEvent.timestamp) {
      executePlaybackEvent(nextEvent);
      currentPlaybackIndex++;
    } else {
      break;
    }
  }

  if (currentPlaybackIndex >= playbackEvents.size()) {
    if (isDemoLooping) {
      isLoopPausing = true;
      loopPauseStartMs = now;
      instructions = "Demo loop: pausing " + (currentDemoPauseMs() / 1000) + "s";
    } else {
      stopPlayback();
    }
  }
}

void executePlaybackEvent(RecordingEvent event) {
  println("Executing playback event: " + event.mode + " at " + event.timestamp + "ms");

  // Set the mode
  ActionMode playbackMode = ActionMode.valueOf(event.mode);
  mode = playbackMode;
  //   modeButtons.activate(playbackMode.getValue());
  instructions = "Playback: "+playbackMode;

  // Set selected magnets
  deselectAll();
  //   for (int magnetIndex : event.selectedMagnets) {
  //     if (magnetIndex >= 0 && magnetIndex < magnets.length) {
  //       selectedMags.add(magnetIndex);
  //       magButtons[magnetIndex].setValue(true);
  //     }
  //   }

  // Set parameters based on controller type
  setPlaybackParameters(event);

  // Execute the controller based on type
  executePlaybackController(event);
}

void setPlaybackParameters(RecordingEvent event) {
  // Set parameters in the UI controls
  for (String paramName : event.parameters.keySet()) {
    float value = event.parameters.get(paramName);
    try {
      cp5.getController(paramName).setValue(value);
    }
    catch (Exception e) {
      println("Could not set parameter " + paramName + ": " + e.getMessage());
    }
  }
}

void executePlaybackController(RecordingEvent event) {
  switch (event.controllerType) {
  case "MoveControllerV0":
    if (event.selectedMagnets.size() >= 2) {
      if (debugRecording) {
        println("HERE22222!!!!");
      }
      int start = event.selectedMagnets.get(0);
      int end = event.selectedMagnets.get(1);

      // Get recorded parameters or use current slider values as fallback
      float moveSpeedMM = event.parameters.containsKey("moveSpeed") ?
        event.parameters.get("moveSpeed") : cp5.getController("moveSpeed").getValue();
      float moveIntensity = event.parameters.containsKey("moveIntensity") ?
        event.parameters.get("moveIntensity") : cp5.getController("moveIntensity").getValue();
      int fadeSpeed = emSpeedMMToFade(moveSpeedMM, (int)moveIntensity);

      groupSequences.add(new MoveControllerV0(start, end, fadeSpeed, (int)moveIntensity));
    }
    break;

  case "MoveControllerPM":
    if (event.selectedMagnets.size() >= 2) {
      int start = event.selectedMagnets.get(0);
      int end = event.selectedMagnets.get(1);

      float speedMM = event.parameters.containsKey("moveSpeedMM") ?
        event.parameters.get("moveSpeedMM") : pmMoveSpeedMM;
      float moveIntensity = event.parameters.containsKey("moveIntensity") ?
        event.parameters.get("moveIntensity") : cp5.getController("moveIntensity").getValue();
      float setupDelay = event.parameters.containsKey("moveSetupDelay") ?
        event.parameters.get("moveSetupDelay") : cp5.getController("moveSetupDelay").getValue();

      groupSequences.add(new MoveControllerPM(start, end, speedMM, (int)moveIntensity, (int)setupDelay));
    }
    break;

  case "MoveControllerPMStep":
    if (event.selectedMagnets.size() >= 2) {
      int start = event.selectedMagnets.get(0);
      int end = event.selectedMagnets.get(1);

      float speedMM = event.parameters.containsKey("moveSpeedMM") ?
        event.parameters.get("moveSpeedMM") : pmMoveSpeedMM;
      float moveIntensity = event.parameters.containsKey("moveIntensity") ?
        event.parameters.get("moveIntensity") : cp5.getController("moveIntensity").getValue();

      groupSequences.add(new MoveControllerPMStep(start, end, speedMM, (int)moveIntensity));
    }
    break;

  case "SplitController":
    if (event.selectedMagnets.size() >= 2) {
      int center = event.selectedMagnets.get(0);
      int side = event.selectedMagnets.get(1);
      groupSequences.add(new SplitController(center, side));
    }
    break;

  case "SplitControllerPM":
    if (event.selectedMagnets.size() >= 2) {
      int center = event.selectedMagnets.get(0);
      int side = event.selectedMagnets.get(1);
      int spi = event.parameters.containsKey("startPointIntensity") ? event.parameters.get("startPointIntensity").intValue() : readStartPointIntensity();
      int fpi = event.parameters.containsKey("finalPointIntensity") ? event.parameters.get("finalPointIntensity").intValue() : (int)cp5.getController("finalPointIntensity").getValue();
      groupSequences.add(new SplitControllerPM(center, side, spi, fpi));
    }
    break;

  case "MergeController":
    if (event.selectedMagnets.size() >= 3) {
      int first = event.selectedMagnets.get(0);
      int second = event.selectedMagnets.get(1);
      int target = event.selectedMagnets.get(2);
      groupSequences.add(new MergeController(first, second, target));
    }
    break;

  case "RotateController":
    if (event.selectedMagnets.size() >= 1) {
      int center = event.selectedMagnets.get(0);
      groupSequences.add(new RotateController(magnets[center]));
    }
    break;

  case "LoopController":
    if (event.selectedMagnets.size() >= 2) {
      int loopDelay = event.parameters.containsKey("loopDelay") ?
        event.parameters.get("loopDelay").intValue() : 1000;
      int loopDirection = event.parameters.containsKey("loopDirection") ?
        event.parameters.get("loopDirection").intValue() : 1;
      int loopHopSpeed = event.parameters.containsKey("loopHopSpeed") ?
        event.parameters.get("loopHopSpeed").intValue() : 80;
      int loopHopDelay = event.parameters.containsKey("loopHopDelay") ?
        event.parameters.get("loopHopDelay").intValue() : 20;
      groupSequences.add(new LoopController(loopDelay, loopDirection, loopHopSpeed, loopHopDelay));
    }
    break;

  case "IndividualMagnet":
    if (event.selectedMagnets.size() >= 1) {
      int magnetIndex = event.selectedMagnets.get(0);
      if (magnetIndex >= 0 && magnetIndex < magnets.length) {
        // Set individual magnet parameters based on mode
        switch (event.mode) {
        case "VIBRATE":
          magnets[magnetIndex].mode = Mode.VIBRATE;
          magnets[magnetIndex].parameters.clear();
          if (event.parameters.containsKey("vibrateIntensity")) {
            magnets[magnetIndex].parameters.add(event.parameters.get("vibrateIntensity").intValue());
          }
          if (event.parameters.containsKey("vibrateHz")) {
            float hz = event.parameters.get("vibrateHz").floatValue();
            magnets[magnetIndex].parameters.add((int)(500.0 / hz)); // Hz -> per-toggle delay in ms
          }
          break;

        case "FADE":
          magnets[magnetIndex].mode = Mode.FADE;
          magnets[magnetIndex].parameters.clear();
          if (event.parameters.containsKey("fadeStart")) {
            magnets[magnetIndex].parameters.add(event.parameters.get("fadeStart").intValue());
          }
          if (event.parameters.containsKey("fadeEnd")) {
            magnets[magnetIndex].parameters.add(event.parameters.get("fadeEnd").intValue());
          }
          if (event.parameters.containsKey("fadeSpeed")) {
            magnets[magnetIndex].parameters.add(event.parameters.get("fadeSpeed").intValue());
          }
          if (event.parameters.containsKey("fadeDelay")) {
            magnets[magnetIndex].parameters.add(event.parameters.get("fadeDelay").intValue());
          }
          break;
        }
      }
    }
    break;

  case "ConstantController":
    if (event.selectedMagnets.size() >= 1) {
      int magnetIndex = event.selectedMagnets.get(0);
      groupSequences.add(new ConstantController(magnetIndex, (int)event.parameters.get("constantIntensity").intValue()));
    }
    break;

  default:
    println("Unknown controller type: " + event.controllerType);
    break;
  }
}

// File I/O functions
void saveRecording(String filename) {
  if (recordingEvents.isEmpty()) {
    println("No recording to save");
    return;
  }

  try {
    FileWriter writer = new FileWriter(dataPath(filename));
    writer.write("# Recording file\n");
    writer.write("# Format: timestamp,mode,controllerType,selectedMagnets,parameters\n");
    writer.write("# Parameters format: param1:value1;param2:value2\n");

    for (RecordingEvent event : recordingEvents) {
      writer.write(event.toString() + "\n");
    }

    writer.close();
    println("Recording saved to: " + filename);
  }
  catch (IOException e) {
    println("Error saving recording: " + e.getMessage());
  }
}

void loadRecording(String filename) {
  playbackEvents.clear();

  try {
    BufferedReader reader = new BufferedReader(new FileReader(dataPath(filename)));
    String line;

    while ((line = reader.readLine()) != null) {
      // Skip comment lines
      if (line.startsWith("#")) continue;

      RecordingEvent event = createRecordingEventFromString(line);
      if (event != null) {
        playbackEvents.add(event);
      }
    }

    reader.close();

    // Sort events by timestamp
    playbackEvents.sort(new java.util.Comparator<RecordingEvent>() {
      public int compare(RecordingEvent a, RecordingEvent b) {
        return Long.compare(a.timestamp, b.timestamp);
      }
    }
    );

    loadedFilename = filename; // Store the loaded filename
    instructions = "Loaded: " + filename + " (" + playbackEvents.size() + " events)";
    println("Recording loaded from: " + filename + " (" + playbackEvents.size() + " events)");
  }
  catch (IOException e) {
    println("Error loading recording: " + e.getMessage());
    instructions = "Error loading file: " + e.getMessage();
  }
}

// Helper function to get current parameters based on mode
HashMap<String, Float> getCurrentParameters() {
  HashMap<String, Float> params = new HashMap<String, Float>();

  switch (mode) {
  case FADE:
    params.put("fadeStart", cp5.getController("fadeStart").getValue());
    params.put("fadeEnd", cp5.getController("fadeEnd").getValue());
    params.put("fadeSpeed", cp5.getController("fadeSpeed").getValue());
    params.put("fadeDelay", cp5.getController("fadeDelay").getValue());
    break;

  case VIBRATE:
    params.put("vibrateIntensity", cp5.getController("vibrateIntensity").getValue());
    params.put("vibrateHz", cp5.getController("vibrateHz").getValue());
    break;

  case MOVE:
    params.put("moveIntensity", cp5.getController("moveIntensity").getValue());
    if (usingEM) {
      params.put("moveSpeed", cp5.getController("moveSpeed").getValue());
    } else {
      params.put("moveSpeedMM", readMoveSpeedMM());
      params.put("moveSetupDelay", cp5.getController("moveSetupDelay").getValue());
    }
    break;

  case SPLIT:
    params.put("splitDuration", cp5.getController("splitDuration").getValue());
    params.put("splitFrequency", cp5.getController("splitFrequency").getValue());
    break;

  case MERGE:
    params.put("mergeSpeed", cp5.getController("mergeSpeed").getValue());
    break;

  case ROTATE:
    params.put("rotateSpeed", cp5.getController("rotateSpeed").getValue());
    break;

  case LOOP:
    params.put("loopDelay", cp5.getController("loopDelay").getValue());
    params.put("loopDirection", cp5.getController("loopDirection").getValue());
    params.put("loopHopSpeed", cp5.getController("loopHopSpeed").getValue());
    params.put("loopHopDelay", cp5.getController("loopHopDelay").getValue());
    break;

  case CONSTANT:
    params.put("constantIntensity", cp5.getController("constantIntensity").getValue());
    break;

  default:
    break;
  }

  return params;
}

// Button callback functions
void saveRecordingToFile() {
  if (recordingEvents.isEmpty()) {
    println("No recording to save");
    return;
  }

  // Generate filename with timestamp
  String timestamp = str(year()) + str(month()) + str(day()) + "_" + str(hour()) + str(minute()) + str(second());
  String filename = "recording_" + timestamp + ".txt";

  saveRecording(filename);
}

void loadRecordingFromFile() {
  // Get list of .txt files in the data directory
  File dataDir = new File(dataPath(""));
  File[] files = dataDir.listFiles(new java.io.FilenameFilter() {
    public boolean accept(File dir, String name) {
      return name.toLowerCase().endsWith(".txt");
    }
  }
  );

  if (files == null || files.length == 0) {
    instructions = "No .txt files found in data directory";
    println("No .txt files found in data directory");
    return;
  }

  // Convert to string array
  availableFiles = new String[files.length];
  for (int i = 0; i < files.length; i++) {
    availableFiles[i] = files[i].getName();
  }

  // Show file selection interface
  showFileList = true;
  selectedFileIndex = 0; // Start with first file selected
  fileListScrollOffset = 0; // Reset scroll position
  instructions = "Select file to load (click or use UP/DOWN arrows, ENTER to load, ESC to cancel)";
  println("Available files: " + java.util.Arrays.toString(availableFiles));
}

// Handle file selection with keyboard input
void handleFileSelection() {
  if (!showFileList) return;

  // This will be called from the main keyPressed() function
  // The actual key handling will be in the main file
}

// Draw file selection interface
void drawFileSelection() {
  if (!showFileList) return;

  // Draw semi-transparent background
  fill(0, 0, 0, 150);
  rect(0, 0, width, height);

  // Draw file selection box
  fill(240, 240, 240);
  stroke(100);
  strokeWeight(2);
  int boxX = width/2 - 200;
  int boxY = height/2 - 200;
  int boxWidth = 400;
  int boxHeight = 400;
  rect(boxX, boxY, boxWidth, boxHeight);

  // Draw title
  fill(0);
  textAlign(CENTER);
  textSize(16);
  text("Select Recording File", width/2, boxY + 30);

  // Draw file list with scrolling
  textAlign(LEFT);
  textSize(14);
  int listStartY = boxY + 60;
  int lineHeight = 25;
  int maxVisibleFiles = (boxHeight - 130) / lineHeight; // leave room for title, buttons, instructions
  if (maxVisibleFiles < 1) maxVisibleFiles = 1;

  // Clamp scroll offset
  int maxScroll = max(0, availableFiles.length - maxVisibleFiles);
  fileListScrollOffset = constrain(fileListScrollOffset, 0, maxScroll);

  // Draw vertical scrollbar on right edge of file list
  int listHeight = maxVisibleFiles * lineHeight;
  drawScrollbar(false, boxX + boxWidth - 18, listStartY - 15,
                listHeight, 10, availableFiles.length, maxVisibleFiles, fileListScrollOffset);

  int endIndex = min(availableFiles.length, fileListScrollOffset + maxVisibleFiles);
  for (int i = fileListScrollOffset; i < endIndex; i++) {
    int visibleIndex = i - fileListScrollOffset;
    int y = listStartY + visibleIndex * lineHeight;

    // Highlight selected file
    if (i == selectedFileIndex) {
      fill(200, 220, 255);
      noStroke();
      rect(boxX + 10, y - 15, boxWidth - 20, lineHeight);
    }
    // Highlight hovered file
    else if (mouseX >= boxX + 10 && mouseX <= boxX + boxWidth - 10 &&
             mouseY >= y - 15 && mouseY <= y - 15 + lineHeight) {
      fill(230, 230, 240);
      noStroke();
      rect(boxX + 10, y - 15, boxWidth - 20, lineHeight);
    }

    fill(0);
    stroke(100);
    text(availableFiles[i], boxX + 20, y);
  }

  // Draw Load and Cancel buttons
  int btnWidth = 80;
  int btnHeight = 30;
  int btnY = boxY + boxHeight - 60;
  int loadBtnX = width/2 - btnWidth - 20;
  int cancelBtnX = width/2 + 20;

  // Load button
  fill(60, 130, 60);
  noStroke();
  rect(loadBtnX, btnY, btnWidth, btnHeight, 5);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(14);
  text("Load", loadBtnX + btnWidth / 2, btnY + btnHeight / 2 - 1);

  // Cancel button
  fill(160, 60, 60);
  noStroke();
  rect(cancelBtnX, btnY, btnWidth, btnHeight, 5);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(14);
  text("Cancel", cancelBtnX + btnWidth / 2, btnY + btnHeight / 2 - 1);

  // Draw instructions
  textAlign(CENTER);
  textSize(11);
  fill(100);
  text("Click to select  |  Double-click or Load to open  |  Scroll to navigate", width/2, boxY + boxHeight - 15);

  textAlign(LEFT, BASELINE); // Reset alignment (including vertical)
  textSize(16);              // Reset text size to default
}

// Process file selection input
void processFileSelectionKey(int keyCode) {
  if (!showFileList) return;

  switch(keyCode) {
  case UP:
    if (selectedFileIndex > 0) {
      selectedFileIndex--;
      // Auto-scroll to keep selection visible
      if (selectedFileIndex < fileListScrollOffset) {
        fileListScrollOffset = selectedFileIndex;
      }
    }
    break;

  case DOWN:
    if (selectedFileIndex < availableFiles.length - 1) {
      selectedFileIndex++;
      // Auto-scroll to keep selection visible
      int boxHeight = 400;
      int lineHeight = 25;
      int maxVisibleFiles = (boxHeight - 130) / lineHeight;
      if (selectedFileIndex >= fileListScrollOffset + maxVisibleFiles) {
        fileListScrollOffset = selectedFileIndex - maxVisibleFiles + 1;
      }
    }
    break;

  case ENTER:
  case RETURN:
    // Load the selected file
    if (selectedFileIndex >= 0 && selectedFileIndex < availableFiles.length) {
      String filename = availableFiles[selectedFileIndex];
      showFileList = false;
      loadRecording(filename);
    }
    break;

  case ESC:
    // Cancel file selection
    showFileList = false;
    instructions = "File selection cancelled";
    break;
  }
}

// Handle mouse click on file selection dialog. Returns true if click was consumed.
boolean handleFileSelectionClick(int mx, int my) {
  if (!showFileList) return false;

  int boxX = width/2 - 200;
  int boxY = height/2 - 200;
  int boxWidth = 400;
  int boxHeight = 400;
  int listStartY = boxY + 60;
  int lineHeight = 25;
  int maxVisibleFiles = (boxHeight - 130) / lineHeight;
  if (maxVisibleFiles < 1) maxVisibleFiles = 1;

  // Check Load button
  int btnWidth = 80;
  int btnHeight = 30;
  int btnY = boxY + boxHeight - 60;
  int loadBtnX = width/2 - btnWidth - 20;
  int cancelBtnX = width/2 + 20;

  if (mx >= loadBtnX && mx <= loadBtnX + btnWidth && my >= btnY && my <= btnY + btnHeight) {
    if (selectedFileIndex >= 0 && selectedFileIndex < availableFiles.length) {
      String filename = availableFiles[selectedFileIndex];
      showFileList = false;
      loadRecording(filename);
    }
    return true;
  }

  // Check Cancel button
  if (mx >= cancelBtnX && mx <= cancelBtnX + btnWidth && my >= btnY && my <= btnY + btnHeight) {
    showFileList = false;
    instructions = "File selection cancelled";
    return true;
  }

  // Check file list area click
  if (mx >= boxX + 10 && mx <= boxX + boxWidth - 10) {
    int endIndex = min(availableFiles.length, fileListScrollOffset + maxVisibleFiles);
    for (int i = fileListScrollOffset; i < endIndex; i++) {
      int visibleIndex = i - fileListScrollOffset;
      int fy = listStartY + visibleIndex * lineHeight;
      if (my >= fy - 15 && my <= fy - 15 + lineHeight) {
        long now = millis();
        if (i == selectedFileIndex && (now - lastFileClickTime) < 400) {
          // Double-click: load the file
          String filename = availableFiles[i];
          showFileList = false;
          loadRecording(filename);
        } else {
          selectedFileIndex = i;
          lastFileClickTime = now;
        }
        return true;
      }
    }
  }

  // Click was inside the dialog area but not on an item — still consume it
  if (mx >= boxX && mx <= boxX + boxWidth && my >= boxY && my <= boxY + boxHeight) {
    return true;
  }

  // Click outside dialog — cancel
  showFileList = false;
  instructions = "File selection cancelled";
  return true;
}

// Handle mouse wheel scroll for file list
void handleFileListScroll(float scrollAmount) {
  fileListScrollOffset += (int) scrollAmount;
  int boxHeight = 400;
  int lineHeight = 25;
  int maxVisibleFiles = (boxHeight - 130) / lineHeight;
  int maxScroll = max(0, availableFiles.length - maxVisibleFiles);
  fileListScrollOffset = constrain(fileListScrollOffset, 0, maxScroll);
}
