public ArrayList <GroupController> groupSequences = new ArrayList<GroupController>();
boolean debugGroupControllers = false;

abstract class GroupController {
  public ArrayList <Magnet> members = new ArrayList<Magnet>();
  public Timer timer = new Timer(0);
  public abstract void update(Iterator<GroupController> iterator);
  String toString() {
    return getClass().getSimpleName();
  }

  void addToGroup(Magnet magnet) {
    members.add(magnet);
    magnet.prev_mode = magnet.mode;
    magnet.owner = this;
  }

  void addToGroup(int magnet_index) {
    this.members.add(magnets[magnet_index]);
    magnets[magnet_index].prev_mode = magnets[magnet_index].mode;
    magnets[magnet_index].owner = this;
  }

  void removeFromGroup(Magnet magnet) {
    this.members.remove(magnet);
    magnet.owner = null;
  }

  void removeFromGroup(int magnet_index) {
    magnets[magnet_index].setMode(Mode.RUN);
    magnets[magnet_index].owner = null;
  }

  //removes the list index not the magnet index!
  void removeIndexFromGroup(int list_index) {
    members.get(list_index).owner = null;
    this.members.remove(list_index);
  }

  void removeAllFromGroup() {
    for (Magnet magnet : members) {
      magnet.owner = null;
      magnet.setMode(Mode.RUN); //reset mode
    }
    members.clear();
  }

  void setAllInGroup(int value) {
    for (Magnet magnet : members) {
      magnet.slider.setValue(value);
    }
  }

  // void deselectAllInGroup() {
  //   for (Magnet magnet : members) {
  //     selectedMags.remove((Integer) magnet.index);
  //     magButtons[magnet.index].setState(false);
  //   }
  // }
}

// BFS path planner: finds shortest path from start to end avoiding obstacles
// detected by camera. Tries optimal path (obstacles + 8 neighbors blocked) first,
// falls back to sub-optimal path (only obstacles blocked) if no optimal path exists.
// Returns ordered list of indices, or null if no path at all.
ArrayList<Integer> bfsPath(int start, int end, int numRows, int numCols) {
  int total = numRows * numCols;

  // Get fresh camera detection for obstacle map
  updateCameraBallDetection();

  // Build obstacle-only set (cells with actual objects)
  HashSet<Integer> obstacles = new HashSet<Integer>();
  for (int i = 0; i < total; i++) {
    if (i == start || i == end) continue;
    if (cameraBallPresent != null && cameraBallPresent[i]) {
      obstacles.add(i);
    }
  }

  // Build expanded set: obstacles + all 8 neighbors
  HashSet<Integer> expanded = new HashSet<Integer>(obstacles);
  int[] nbDr = {-1, -1, -1, 0, 0, 1, 1, 1};
  int[] nbDc = {-1, 0, 1, -1, 1, -1, 0, 1};
  for (int obs : obstacles) {
    int r = obs / numCols;
    int c = obs % numCols;
    for (int d = 0; d < 8; d++) {
      int nr = r + nbDr[d];
      int nc = c + nbDc[d];
      if (nr >= 0 && nr < numRows && nc >= 0 && nc < numCols) {
        expanded.add(getMagIndexFromCoord(nr, nc));
      }
    }
  }
  expanded.remove(start);
  expanded.remove(end);
  obstacles.remove(start);
  obstacles.remove(end);

  // Try optimal path first (full clearance), then sub-optimal (obstacles only)
  ArrayList<Integer> path = bfsWithBlocked(start, end, numRows, numCols, expanded);
  if (path != null) return path;
  println("No optimal path — trying sub-optimal (through neighbor cells)");
  return bfsWithBlocked(start, end, numRows, numCols, obstacles);
}

// BFS helper: finds shortest path avoiding a given blocked set.
// Returns ordered list of indices, or null if no path.
ArrayList<Integer> bfsWithBlocked(int start, int end, int numRows, int numCols, HashSet<Integer> blocked) {
  int total = numRows * numCols;
  boolean[] visited = new boolean[total];
  int[] parent = new int[total];
  Arrays.fill(parent, -1);

  LinkedList<Integer> queue = new LinkedList<Integer>();
  queue.add(start);
  visited[start] = true;

  int[] dr = {-1, 1, 0, 0};
  int[] dc = {0, 0, -1, 1};

  boolean found = false;
  while (!queue.isEmpty()) {
    int curr = queue.poll();
    if (curr == end) {
      found = true;
      break;
    }
    int cr = curr / numCols;
    int cc = curr % numCols;
    for (int d = 0; d < 4; d++) {
      int nr = cr + dr[d];
      int nc = cc + dc[d];
      if (nr < 0 || nr >= numRows || nc < 0 || nc >= numCols) continue;
      int next = getMagIndexFromCoord(nr, nc);
      if (visited[next] || blocked.contains(next)) continue;
      visited[next] = true;
      parent[next] = curr;
      queue.add(next);
    }
  }

  if (!found) return null;

  // Reconstruct path
  ArrayList<Integer> path = new ArrayList<Integer>();
  int curr = end;
  while (curr != -1) {
    path.add(0, curr);
    curr = parent[curr];
  }
  return path;
}

// void sendLoopSettings() {
//   if (mode != ActionMode.LOOP) {
//     return;
//   }

//   if (selectedMags.size() < 2) {
//     println("Not enough magnets selected for loop");
//     return;
//   }

//   int loopDelay = (int)cp5.getController("loopDelay").getValue();
//   int loopDirection = (int)cp5.getController("loopDirection").getValue();
//   int loopHopSpeed = (int)cp5.getController("loopHopSpeed").getValue();
//   int loopHopDelay = (int)cp5.getController("loopHopDelay").getValue();
//   groupSequences.add(new LoopController(loopDelay, loopDirection, loopHopSpeed, loopHopDelay));

//   // Record the event
//   recordEvent(mode.name(), "LoopController", selectedMags, getCurrentParameters());

//   println("Loop created");
//   //loopMagnets();
// }

void startShake() {
  if (selectedMags.size() == 0) {
    println("No magnets selected for shake");
    return;
  }

  boolean useGlobal = cp5.getController("shakeUseGlobal").getValue() > 0;
  if (useGlobal) {
    startGlobalShake();
    return;
  }

  // Get shake parameters from UI settings
  int shakeIntensity = (int)cp5.getController("shakeIntensity").getValue();
  int shakeIntensityLow = (int)cp5.getController("shakeIntensityLow").getValue();
  int shakeDuration = (int)cp5.getController("shakeDuration").getValue();
  int shakeCycles = (int)cp5.getController("shakeCycles").getValue();
  int shakeFinalIntensity = (int)cp5.getController("shakeFinalIntensity").getValue();

  // Create the shake controller directly
  ShakeController shake = new ShakeController(selectedMags, shakeIntensity, shakeIntensityLow, shakeDuration, shakeCycles, shakeFinalIntensity);
  groupSequences.add(shake);

  println("Shake started with " + selectedMags.size() + " magnets");
}

void startGlobalShake() {
  if (selectedMags.size() == 0) {
    println("No magnets selected for global shake");
    return;
  }

  int shakeIntensity = (int)cp5.getController("shakeIntensity").getValue();
  int shakeIntensityLow = (int)cp5.getController("shakeIntensityLow").getValue();
  int shakeDuration = (int)cp5.getController("shakeDuration").getValue();
  int shakeCycles = (int)cp5.getController("shakeCycles").getValue();
  int shakeFinalIntensity = (int)cp5.getController("shakeFinalIntensity").getValue();
  int sweepDir = (int)cp5.getController("shakeDirection").getValue();

  GlobalShakeController gshake = new GlobalShakeController(
    selectedMags, shakeIntensity, shakeIntensityLow,
    shakeDuration, shakeCycles, shakeFinalIntensity, sweepDir);
  groupSequences.add(gshake);

  println("Global shake started with " + selectedMags.size() + " magnets, direction=" + sweepDir);
}

// Helper function to create shake from a pattern (useful for shape transitions)
void createShakeFromPattern(ArrayList<Integer> patternMagnets) {
  if (patternMagnets.size() == 0) {
    println("No magnets in pattern for shake");
    return;
  }

  // Get shake parameters from UI settings
  int shakeIntensity = (int)cp5.getController("shakeIntensity").getValue();
  int shakeIntensityLow = (int)cp5.getController("shakeIntensityLow").getValue();
  int shakeDuration = (int)cp5.getController("shakeDuration").getValue();
  int shakeCycles = (int)cp5.getController("shakeCycles").getValue();
  int shakeFinalIntensity = (int)cp5.getController("shakeFinalIntensity").getValue();

  // Create the shake controller
  ShakeController shake = new ShakeController(patternMagnets, shakeIntensity, shakeIntensityLow, shakeDuration, shakeCycles, shakeFinalIntensity);
  groupSequences.add(shake);

  if (debugGroupControllers) {
    println("ShakeController created from pattern with " + patternMagnets.size() + " magnets");
  }
}



// // Helper function to load pattern from file (you may need to implement this based on your pattern loading system)
// ArrayList<Integer> loadPatternFromFile(String filename) {
//   ArrayList<Integer> pattern = new ArrayList<Integer>();
//   // This is a placeholder - you'll need to implement based on your pattern loading system
//   // The pattern files seem to use format: magnet_index:selected (0 or 1)
//   return pattern;
// }

// Helper function to apply pattern to magnets
// void applyPatternToMagnets(ArrayList<Integer> pattern) {
//   // This is a placeholder - you'll need to implement based on your pattern application system
//   println("Applying pattern to magnets");
// }

//@todo not finished
class LoopController extends GroupController {
  boolean closedLoop;
  int loopDelay = 1000;
  int loopDirection = 1; //closed loop: ccw is -1 cw is 1. open loop: forward or back
  //@todo hops don't do anything yet
  int loopHopSpeed = 80;
  int loopHopDelay = 20;
  MoveControllerV0 current;
  int curr_index = 0;
  //fix these controllers

  public LoopController(int loopDelay, int loopDirection, int loopHopSpeed, int loopHopDelay) {
    this.loopDelay = loopDelay;
    this.loopDirection = loopDirection;
    this.loopHopSpeed = loopHopSpeed;
    this.loopHopDelay = loopHopDelay;
    for (int m : selectedMags) { //adds all selected in order
      addToGroup(magnets[m]);
    }
    //if first and last are the same then it is a closed loop
    if (members.get(0) == members.get(members.size() - 1)) {
      closedLoop = true;
    } else {
      closedLoop = false;
    }
    current = new MoveControllerV0(members.get(0).index, members.get(1).index);
    groupSequences.add(current);
  }

  void update(Iterator<GroupController> iterator) {
    //saving for later. logic is for each position it creates a new MoveControllerV0. when the controller
    //is removed from the list it creates a new one for the next index.
    //for open loop it goes forward and back, for closed loop it goes in a circle
    //   if (groupSequences.contains(current)) { //move not finished
    //     return;
    //   }
    //   //open loop
    //   if (!closedLoop) {
    //need to standardize for negative and positive
    //     if (curr_index + 1 < members.size()) { //move to next
    //       curr_index ++;
    //       current = new MoveControllerV0(members.get(curr_index).index, members.get(curr_index + 1).index);
    //       return;

    //   }
    //   //closed loop
    // }
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
//}


//@todo deal with intersecting paths

// Convert EM speed in mm/s to internal fadeSpeed
// EM pixel spacing = 25.4mm, fade goes from +moveIntensity to -maxIntensity
// The fade range is 2x intensity (e.g. +255 to -255 = 510), so we compensate
// by using only the single-sided range (moveIntensity) for the speed calculation
int emSpeedMMToFade(float speedMM, int moveIntensity) {
  if (speedMM <= 0) return 5;
  float emSpacingMM = 25.4;
  float fadeDelay = cp5.getController("fadeDelay").getValue();
  if (fadeDelay <= 0) fadeDelay = 10;
  float fullFadeRange = moveIntensity + maxIntensity; // actual range the fade traverses
  float pixelTimeMs = emSpacingMM / speedMM * 1000;   // desired time per pixel
  // fadeSpeed must traverse fullFadeRange in pixelTimeMs, but the physical movement
  // only corresponds to the single-sided range, so double the fadeSpeed
  return max(1, round(fullFadeRange * fadeDelay / pixelTimeMs * 2));
}

class MoveControllerV0 extends GroupController {
  int start;
  int end;
  int moveIntensity = (int) maxIntensity;
  int fadeSpeed;
  int hopSpeed;
  int hopDelay;
  boolean valid = true;

  public MoveControllerV0(int start, int end, int fadeSpeed, int moveIntensity, int hopSpeed, int hopDelay) {
    if (debugGroupControllers) {
      println("MoveControllerV0 created"+start+"to"+end+"with fadeSpeed"+fadeSpeed+"hopSpeed"+hopSpeed+"hopDelay"+hopDelay);
    }
    this.start = start;
    this.end = end;
    this.moveIntensity = moveIntensity;
    this.fadeSpeed = fadeSpeed;
    //@todo currently no hop
    this.hopSpeed = hopSpeed;
    this.hopDelay = hopDelay;
    cp5.getController("fadeSpeed").setValue(fadeSpeed);
    cp5.getController("fadeStart").setValue(moveIntensity);
    if (usingEM) {
      cp5.getController("fadeEnd").setValue(-maxIntensity);
    } else {
      cp5.getController("fadeEnd").setValue(0);
    }
    //note, if end to start and remove from end it would be slightly more efficient
    int pathResult = calculatePath(start, end);
    if (pathResult != 0) {
      println("failed to calculate path" + (pathResult == -2 ? " (no valid path around obstacles)" : ""));
      valid = false;
      return;
    }
    println("succesfully calculated path" );
    //starts fade -- may need to move later
    members.get(0).setMode(Mode.FADE);
    members.get(1).setMode(Mode.RUN);
    println(members.get(1).slider == null);
    members.get(1).slider.setValue(moveIntensity);

    // Record the event
    ArrayList<Integer> moveMagnets = new ArrayList<Integer>();
    moveMagnets.add(start);
    moveMagnets.add(end);
    recordEvent(mode.name(), "MoveControllerV0", moveMagnets, getCurrentParameters());
  }

  public MoveControllerV0(int start, int end, int fadeSpeed, int moveIntensity) {
    this(start, end, fadeSpeed, moveIntensity, 0, 0);
  }
  public MoveControllerV0(int start, int end) {
    this(start, end, emSpeedMMToFade(cp5.getController("moveSpeed").getValue(), (int)cp5.getController("moveIntensity").getValue()), (int)cp5.getController("moveIntensity").getValue());
  }

  //@todo change fade to ext control & dont change fade sliders
  public void update(Iterator<GroupController> iterator) {
    if (!valid) {
      removeAllFromGroup();
      iterator.remove();
      return;
    }
    if (members.size() < 2 && members.get(0).mode != Mode.FADE) {    //move is finished, only end remains
      members.get(0).slider.setValue(moveIntensity);
      removeFromGroup(0);
      iterator.remove();
      println("done moving");

      return;
    } else if (members.get(0).mode == Mode.RUN) { //fade is completed, move to next magnet
      members.get(0).slider.setValue(0);
      removeIndexFromGroup(0);
      if (members.size() <= 1) {
        return;
      }
      members.get(0).setMode(Mode.FADE);
      members.get(1).slider.setValue(moveIntensity);
    }
  }
  //adds magnets to member list in order
  int calculatePath(int start, int end) {
    if (start == end) {
      addToGroup(start);
      println("start and end are the same!");
      return -1;
    }

    if (moveAvoidObstaclesEnabled) {
      ArrayList<Integer> path = bfsPath(start, end, num_rows, num_motors_per_row);
      if (path == null) {
        println("No valid path found (BFS)");
        return -2;
      }
      for (int idx : path) {
        try { addToGroup(magnets[idx]); }
        catch (Exception e) { println("magnet index out of bounds"); return -1; }
      }
      return 0;
    }

    // Original naive Manhattan path
    int curr_pos = start;
    int target_row = end / num_motors_per_row;
    int target_col = end % num_motors_per_row;
    try {
      addToGroup(curr_pos);
    }
    catch (Exception e) {
      println("magnet index out of bounds");
      return -1;
    }
    while (curr_pos != end) {
      int curr_row = curr_pos / num_motors_per_row;
      int curr_col = curr_pos % num_motors_per_row;
      curr_row = curr_pos / num_motors_per_row;
      curr_col = curr_pos % num_motors_per_row;
      if (curr_row < target_row) {  //needs to increase row
        curr_pos = getMagIndexFromCoord(curr_row + 1, curr_col);
      } else if (curr_row > target_row) {  //needs to decrease row
        curr_pos =  getMagIndexFromCoord(curr_row - 1, curr_col);
      } else if (curr_col < target_col) {  //needs to increase col
        curr_pos = getMagIndexFromCoord(curr_row, curr_col + 1);
      } else if (curr_col > target_col) {  //needs to decrease col
        curr_pos = getMagIndexFromCoord(curr_row, curr_col - 1);
      } else {
        curr_pos = end;
      }
      try {
        addToGroup(magnets[curr_pos]);
      }
      catch (Exception e) {
        println("magnet index out of bounds");
        return -1;
      }
    }
    return 0;
  }
}

class MoveControllerPM extends GroupController {
  int start;
  int end;
  int moveIntensity;
  float speedMM;          // mm/s - controls wave speed across the grid
  int setupDelay;         // ms user-configured wait after all magnets raised
  int retractDelay;       // ms between each magnet retraction (calculated from speedMM)
  final int PIXEL_SPACING_MM = 15;
  final int PM_FADE_SPEED = 50;  // fast fade for individual magnet retraction
  final int SETUP_RAISE_DELAY = 50; // ms between each magnet turning on during setup
  int currentRetractIndex = 0;
  int setupRaiseIndex = 1; // next magnet to raise (0 is raised in constructor)
  int phase = 0;           // 0=raising one by one, 1=setup wait, 2=retracting
  boolean fading = false;
  boolean valid = true;

  public MoveControllerPM(int start, int end, float speedMM, int moveIntensity, int setupDelay) {
    if (debugGroupControllers) {
      println("MoveControllerPM created " + start + " to " + end + " at " + speedMM + " mm/s, setup " + setupDelay + "ms");
    }
    this.start = start;
    this.end = end;
    this.moveIntensity = moveIntensity;
    this.speedMM = speedMM > 0 ? speedMM : 15;
    this.setupDelay = setupDelay;
    this.retractDelay = (int)(PIXEL_SPACING_MM / this.speedMM * 1000);

    int pathResult = calculatePath(start, end);
    if (pathResult != 0) {
      println("failed to calculate path" + (pathResult == -2 ? " (no valid path around obstacles)" : ""));
      valid = false;
      return;
    }
    println("PM move: path " + members.size() + " magnets, retract every " + retractDelay + "ms, stagger " + (members.size() - 1) * SETUP_RAISE_DELAY + "ms + setup " + setupDelay + "ms");

    // Configure fade settings for later retraction
    cp5.getController("fadeSpeed").setValue(PM_FADE_SPEED);
    cp5.getController("fadeStart").setValue(moveIntensity);
    cp5.getController("fadeEnd").setValue(0);

    // Phase 0: raise magnets one by one (start to end) to avoid power spike
    members.get(0).slider.setValue(moveIntensity);
    timer.setDuration(SETUP_RAISE_DELAY);
    timer.start();

    // Record the event
    ArrayList<Integer> moveMagnets = new ArrayList<Integer>();
    moveMagnets.add(start);
    moveMagnets.add(end);
    HashMap<String, Float> params = getCurrentParameters();
    params.put("moveSpeedMM", speedMM);
    params.put("moveSetupDelay", (float)setupDelay);
    recordEvent(mode.name(), "MoveControllerPM", moveMagnets, params);
  }

  public MoveControllerPM(int start, int end, float speedMM, int moveIntensity) {
    this(start, end, speedMM, moveIntensity, (int)cp5.getController("moveSetupDelay").getValue());
  }

  public MoveControllerPM(int start, int end) {
    this(start, end, readMoveSpeedMM(), (int)cp5.getController("moveIntensity").getValue());
  }

  public void update(Iterator<GroupController> iterator) {
    if (!valid) {
      removeAllFromGroup();
      iterator.remove();
      return;
    }

    switch (phase) {
    case 0: // Raising magnets one by one from start to end
      if (timer.triggered()) {
        if (setupRaiseIndex < members.size()) {
          members.get(setupRaiseIndex).slider.setValue(moveIntensity);
          setupRaiseIndex++;
        }
        if (setupRaiseIndex >= members.size()) {
          // All raised — switch to user-configured setup delay
          timer.setDuration(setupDelay);
          phase = 1;
        }
      }
      break;

    case 1: // Setup wait (all magnets raised, waiting before retraction)
      if (timer.triggered()) {
        // Begin retraction: fade first magnet
        cp5.getController("fadeStart").setValue(moveIntensity);
        cp5.getController("fadeEnd").setValue(0);
        cp5.getController("fadeSpeed").setValue(PM_FADE_SPEED);
        members.get(currentRetractIndex).setMode(Mode.FADE);
        fading = true;
        phase = 2;
      }
      break;

    case 2: // Retracting magnets one by one from start to end
      if (fading) {
        // Wait for current magnet to finish fading (mode goes back to RUN)
        if (members.get(currentRetractIndex).mode != Mode.FADE) {
          members.get(currentRetractIndex).slider.setValue(0);
          fading = false;
          currentRetractIndex++;

          if (currentRetractIndex >= members.size() - 1) {
            // All retracted except destination - done
            members.get(members.size() - 1).slider.setValue(moveIntensity);
            removeAllFromGroup();
            iterator.remove();
            println("PM move complete");
            return;
          }

          // Start retract delay before next magnet
          timer.setDuration(retractDelay);
          timer.reset();
        }
      } else {
        // Waiting for retract delay between magnets
        if (timer.triggered()) {
          // Re-set fade settings (safety against other controllers changing them)
          cp5.getController("fadeStart").setValue(moveIntensity);
          cp5.getController("fadeEnd").setValue(0);
          cp5.getController("fadeSpeed").setValue(PM_FADE_SPEED);
          // Start fading current magnet
          members.get(currentRetractIndex).setMode(Mode.FADE);
          fading = true;
        }
      }
      break;
    }
  }

  int calculatePath(int start, int end) {
    if (start == end) {
      addToGroup(start);
      println("start and end are the same!");
      return -1;
    }

    if (moveAvoidObstaclesEnabled) {
      ArrayList<Integer> path = bfsPath(start, end, num_rows, num_motors_per_row);
      if (path == null) {
        println("No valid path found (BFS)");
        return -2;
      }
      for (int idx : path) {
        try { addToGroup(magnets[idx]); }
        catch (Exception e) { println("magnet index out of bounds"); return -1; }
      }
      return 0;
    }

    // Original naive Manhattan path
    int curr_pos = start;
    int target_row = end / num_motors_per_row;
    int target_col = end % num_motors_per_row;
    try {
      addToGroup(curr_pos);
    }
    catch (Exception e) {
      println("magnet index out of bounds");
      return -1;
    }
    while (curr_pos != end) {
      int curr_row = curr_pos / num_motors_per_row;
      int curr_col = curr_pos % num_motors_per_row;
      if (curr_row < target_row) {
        curr_pos = getMagIndexFromCoord(curr_row + 1, curr_col);
      } else if (curr_row > target_row) {
        curr_pos = getMagIndexFromCoord(curr_row - 1, curr_col);
      } else if (curr_col < target_col) {
        curr_pos = getMagIndexFromCoord(curr_row, curr_col + 1);
      } else if (curr_col > target_col) {
        curr_pos = getMagIndexFromCoord(curr_row, curr_col - 1);
      } else {
        curr_pos = end;
      }
      try {
        addToGroup(magnets[curr_pos]);
      }
      catch (Exception e) {
        println("magnet index out of bounds");
        return -1;
      }
    }
    return 0;
  }
}

class MoveControllerPMStep extends GroupController {
  int start;
  int end;
  int moveIntensity;
  float speedMM;
  int pixelDelay;        // ms per pixel transition (calculated from speedMM)
  final int PIXEL_SPACING_MM = 15;
  final int STAGGER_DELAY = 50;
  int windowStart = 0;   // trailing edge of the 2-magnet window
  int windowEnd = 0;     // leading edge of the 2-magnet window
  int phase = 0;         // 0=initial raise, 1=wait, 2=advance window, 4=done
  int subStep = 0;
  boolean valid = true;

  public MoveControllerPMStep(int start, int end, float speedMM, int moveIntensity) {
    if (debugGroupControllers) {
      println("MoveControllerPMStep created " + start + " to " + end + " at " + speedMM + " mm/s");
    }
    this.start = start;
    this.end = end;
    this.moveIntensity = moveIntensity;
    this.speedMM = speedMM > 0 ? speedMM : 15;
    this.pixelDelay = (int)(PIXEL_SPACING_MM / this.speedMM * 1000);

    int pathResult = calculatePath(start, end);
    if (pathResult != 0) {
      println("failed to calculate path" + (pathResult == -2 ? " (no valid path around obstacles)" : ""));
      valid = false;
      return;
    }
    println("PM step move: path " + members.size() + " magnets, " + pixelDelay + "ms per pixel");

    // Phase 0: raise first magnet immediately
    members.get(0).slider.setValue(moveIntensity);
    timer.setDuration(STAGGER_DELAY);
    timer.start();

    // Record the event
    ArrayList<Integer> moveMagnets = new ArrayList<Integer>();
    moveMagnets.add(start);
    moveMagnets.add(end);
    HashMap<String, Float> params = getCurrentParameters();
    params.put("moveSpeedMM", speedMM);
    recordEvent(mode.name(), "MoveControllerPMStep", moveMagnets, params);
  }

  public MoveControllerPMStep(int start, int end) {
    this(start, end, readMoveSpeedMM(), (int)cp5.getController("moveIntensity").getValue());
  }

  public void update(Iterator<GroupController> iterator) {
    if (!valid) {
      removeAllFromGroup();
      iterator.remove();
      return;
    }

    switch (phase) {
    case 0: // Initial raise: raise first two magnets with stagger
      if (timer.triggered()) {
        if (members.size() > 1) {
          members.get(1).slider.setValue(moveIntensity);
          windowEnd = 1;
        }
        // All initial magnets raised, wait one pixel delay
        timer.setDuration(pixelDelay);
        phase = 1;
      }
      break;

    case 1: // Waiting pixelDelay between steps
      if (timer.triggered()) {
        if (windowEnd >= members.size() - 1) {
          // Leading edge is at destination — lower trailing magnet
          if (windowStart < windowEnd) {
            members.get(windowStart).slider.setValue(0);
            windowStart++;
            timer.setDuration(pixelDelay);
          }
          if (windowStart >= windowEnd) {
            phase = 4; // done
          }
        } else {
          // Advance the window: raise next, then lower trailing
          phase = 2;
          subStep = 0;
        }
      }
      break;

    case 2: // Advancing window — raise new leading magnet
      if (subStep == 0) {
        windowEnd++;
        members.get(windowEnd).slider.setValue(moveIntensity);
        timer.setDuration(STAGGER_DELAY);
        timer.reset();
        subStep = 1;
      } else if (subStep == 1 && timer.triggered()) {
        // Lower trailing magnet
        members.get(windowStart).slider.setValue(0);
        windowStart++;
        // Wait pixelDelay before next step
        timer.setDuration(pixelDelay);
        phase = 1;
      }
      break;

    case 4: // Done — destination stays at moveIntensity
      members.get(members.size() - 1).slider.setValue(moveIntensity);
      removeAllFromGroup();
      iterator.remove();
      println("PM step move complete");
      return;
    }
  }

  int calculatePath(int start, int end) {
    if (start == end) {
      addToGroup(start);
      println("start and end are the same!");
      return -1;
    }

    if (moveAvoidObstaclesEnabled) {
      ArrayList<Integer> path = bfsPath(start, end, num_rows, num_motors_per_row);
      if (path == null) {
        println("No valid path found (BFS)");
        return -2;
      }
      for (int idx : path) {
        try { addToGroup(magnets[idx]); }
        catch (Exception e) { println("magnet index out of bounds"); return -1; }
      }
      return 0;
    }

    int curr_pos = start;
    int target_row = end / num_motors_per_row;
    int target_col = end % num_motors_per_row;
    try {
      addToGroup(curr_pos);
    }
    catch (Exception e) {
      println("magnet index out of bounds");
      return -1;
    }
    while (curr_pos != end) {
      int curr_row = curr_pos / num_motors_per_row;
      int curr_col = curr_pos % num_motors_per_row;
      if (curr_row < target_row) {
        curr_pos = getMagIndexFromCoord(curr_row + 1, curr_col);
      } else if (curr_row > target_row) {
        curr_pos = getMagIndexFromCoord(curr_row - 1, curr_col);
      } else if (curr_col < target_col) {
        curr_pos = getMagIndexFromCoord(curr_row, curr_col + 1);
      } else if (curr_col > target_col) {
        curr_pos = getMagIndexFromCoord(curr_row, curr_col - 1);
      } else {
        curr_pos = end;
      }
      try {
        addToGroup(magnets[curr_pos]);
      }
      catch (Exception e) {
        println("magnet index out of bounds");
        return -1;
      }
    }
    return 0;
  }
}


// class MoveControllerV1 extends GroupController {
//   int delay;
//   int intensity;
//   public MoveControllerV1(ArrayList<Integer> moveArray, int intensity, int delay) {
//     this.delay = delay;
//     this.intensity = intensity;
//     for (int i = 0; i < moveArray.size(); i++) {
//       addToGroup(magnets[moveArray.get(i)]);
//     }
//     timer.setDuration(delay);
//     timer.start();
//     println("MoveControllerV1 created");
//   }
//   public void update(Iterator<GroupController> iterator) {
//     if (timer.triggered()) {
//       if (members.size() > 0) {
//       }
//     }
//   }

class SplitController extends GroupController {
  // side - center - otherSide
  //  |
  // companion
  public Magnet center;
  public Magnet side;
  public Magnet otherSide;
  public Magnet companion; //a magnet next to side
  int frequency = (int)cp5.getController("splitFrequency").getValue();
  public SplitController(int center, int side) {
    addToGroup(magnets[center]);
    addToGroup(magnets[side]);
    this.center = magnets[center];
    this.side = magnets[side];
    addOtherSide();
    this.side.setMode(Mode.RUN);
    otherSide.setMode(Mode.RUN);
    this.center.setMode(Mode.EXT_CONT);
    this.side.slider.setValue(maxIntensity);
    otherSide.slider.setValue(-maxIntensity);
    if (companion != null) {
      companion.slider.setValue(-maxIntensity);
    }
    timer.setDuration((int)cp5.getController("splitDuration").getValue());
    timer.start();

    // Record the event
    ArrayList<Integer> splitMagnets = new ArrayList<Integer>();
    splitMagnets.add(center);
    splitMagnets.add(side);
    recordEvent(mode.name(), "SplitController", splitMagnets, getCurrentParameters());

    println("split controller created");
  }
  public void update(Iterator<GroupController> iterator) {
    if (timer.triggered()) {  //if split is finished
      center.slider.setValue(0);
      if (companion != null) {
        companion.slider.setValue(0);
      }
      removeAllFromGroup();
      iterator.remove();
      return;
    }
    // when the split is not finished, the center keeps vibrating
    center.prev_mode = center.mode;
    center.vibrate((int)maxIntensity, frequency);
  }
  //sets magnet next to "other side" to be the opposite polarity to improve split
  void addCompanion(int magnet_index) {
    println(magnet_index);
    Magnet magnet;
    try {
      magnet = magnets[magnet_index];
    }
    catch(Exception e) {
      println("magnet index out of bounds");
      return;
    }
    addToGroup(magnet);
    magnet.setMode(Mode.EXT_CONT);
    companion = magnet;
  }

  //finds "otherSide" magnet in split and adds as member
  void addOtherSide() {
    if (members.size() < 2) {
      return;
    }
    if (center == side) {
      println("center and side are the same");
      return;
    }
    int other;

    if (center.getRow() != side.getRow()) { //within column split
      if (center.getRow() > side.getRow()) {
        other = (center.getRow()+1) * num_motors_per_row + center.getCol();
      } else { // side is below center
        other = (center.getRow()-1) * num_motors_per_row + center.getCol();
      }

      if (side.getCol() + 1 > num_motors_per_row) {
        addCompanion(side.getRow() * num_motors_per_row + side.getCol() + 1);
      } else {
        addCompanion(side.getRow() * num_motors_per_row + side.getCol() - 1);
      }
    } else { //within row split
      if (center.getCol() > side.getCol()) { //side is left of center
        other = (center.getRow()) * num_motors_per_row + center.getCol() + 1;
      } else { // side is right of center
        other = center.getRow() * num_motors_per_row + center.getCol() - 1;
      }

      if (side.getRow() + 1 > num_rows) {
        addCompanion((side.getRow() + 1) * num_motors_per_row + side.getCol());
      } else {
        addCompanion((side.getRow() - 1) * num_motors_per_row + side.getCol());
      }
    }
    addToGroup(other);
    otherSide = magnets[other];
  }
}

class SplitControllerPM extends GroupController { //permanent magnet split
  // side - center - otherSide
  // step1 High, High, High
  // step2 Medium, Medium-High, High
  // step3 High, High, High
  // step4 High, Low, High -> final step
  public Magnet center;
  public Magnet side;
  public Magnet otherSide;
  int step = 0;
  int frequency = (int)cp5.getController("splitFrequency").getValue();
  int startPointIntensity = readStartPointIntensity();
  int finalPointIntensity = (int)cp5.getController("finalPointIntensity").getValue();

  public SplitControllerPM(int center, int side, int startPointIntensity, int finalPointIntensity) {
    addToGroup(magnets[center]);
    addToGroup(magnets[side]);
    this.center = magnets[center];
    this.side = magnets[side];
    addOtherSide();
    this.side.setMode(Mode.RUN);
    otherSide.setMode(Mode.RUN);
    this.center.setMode(Mode.RUN);

    this.startPointIntensity = startPointIntensity;
    this.finalPointIntensity = finalPointIntensity;

    // step1 High, High, High
    step = 0;
    this.side.slider.setValue(maxIntensity);
    this.center.slider.setValue(maxIntensity);
    otherSide.slider.setValue(maxIntensity);
    timer.setDuration((int)cp5.getController("splitDuration").getValue());
    timer.start();
    println("split controller created");

    // Record the event
    ArrayList<Integer> splitMagnets = new ArrayList<Integer>();
    splitMagnets.add(center);
    splitMagnets.add(side);
    HashMap<String, Float> params = getCurrentParameters();
    params.put("startPointIntensity", (float)startPointIntensity);
    params.put("finalPointIntensity", (float)finalPointIntensity);
    recordEvent(mode.name(), "SplitControllerPM", splitMagnets, params);
  }

  public SplitControllerPM(int center, int side) {
    this(center, side, readStartPointIntensity(), (int)cp5.getController("finalPointIntensity").getValue());
  }
  public void update(Iterator<GroupController> iterator) {
    while (timer.triggered()) {  // when current step is finished
      step++;
      switch (step) {
      case 1:
        this.side.slider.setValue(maxIntensity);
        this.center.slider.setValue(maxIntensity);
        this.otherSide.slider.setValue(maxIntensity);
        break;
      case 2:
        this.side.slider.setValue(startPointIntensity);
        this.center.slider.setValue((maxIntensity+min(startPointIntensity, finalPointIntensity))/2);
        this.otherSide.slider.setValue(finalPointIntensity);
        break;
      case 3:
        //if (startPointIntensity != 0) {
        this.side.slider.setValue(maxIntensity);
        this.center.slider.setValue(maxIntensity);
        //}
        this.otherSide.slider.setValue(maxIntensity);
        break;
      case 4:
        // this.side.slider.setValue(maxIntensity);
        this.center.slider.setValue(0);
        // this.otherSide.slider.setValue(maxIntensity);
        removeAllFromGroup();
        iterator.remove();
        return;
        //break;
      default:
        println("Error: step is greater than 4, can't happen!");
        removeAllFromGroup();
        iterator.remove();
        return;
        //break;
      }
    }
  }

  //finds "otherSide" magnet in split and adds as member
  void addOtherSide() {
    if (members.size() < 2) {
      return;
    }
    if (center == side) {
      println("center and side are the same");
      return;
    }
    int other;

    if (center.getRow() != side.getRow()) { //within column split
      if (center.getRow() > side.getRow()) {
        other = (center.getRow()+1) * num_motors_per_row + center.getCol();
      } else { // side is below center
        other = (center.getRow()-1) * num_motors_per_row + center.getCol();
      }

      //if (side.getCol() + 1 > num_motors_per_row) {
      //  addCompanion(side.getRow() * num_motors_per_row + side.getCol() + 1);
      //} else {
      //  addCompanion(side.getRow() * num_motors_per_row + side.getCol() - 1);
      //}
    } else { //within row split
      if (center.getCol() > side.getCol()) { //side is left of center
        other = (center.getRow()) * num_motors_per_row + center.getCol() + 1;
      } else { // side is right of center
        other = center.getRow() * num_motors_per_row + center.getCol() - 1;
      }

      //if (side.getRow() + 1 > num_rows) {
      //  addCompanion((side.getRow() + 1) * num_motors_per_row + side.getCol());
      //} else {
      //  addCompanion((side.getRow() - 1) * num_motors_per_row + side.getCol());
      //}
    }
    addToGroup(other);
    otherSide = magnets[other];
  }
}

class MergeController extends GroupController {
  public Magnet first;
  public Magnet second;
  public Magnet target;
  MoveControllerV0 one;
  MoveControllerV0 two;
  public MergeController(int first, int second, int target) {
    addToGroup(magnets[first]);
    addToGroup(magnets[second]);
    addToGroup(magnets[target]);
    println("added all components");

    this.first = magnets[first];
    this.second = magnets[second];
    this.target = magnets[target];

    this.target.setMode(Mode.EXT_CONT);
    this.target.slider.setValue(maxIntensity);

    one = new MoveControllerV0(first, target, (int)cp5.getController("mergeSpeed").getValue(), (int)maxIntensity);
    two = new MoveControllerV0(second, target, (int)cp5.getController("mergeSpeed").getValue(), (int)maxIntensity);
    groupSequences.add(one);
    groupSequences.add(two);

    // Record the event
    ArrayList<Integer> mergeMagnets = new ArrayList<Integer>();
    mergeMagnets.add(first);
    mergeMagnets.add(second);
    mergeMagnets.add(target);
    recordEvent(mode.name(), "MergeController", mergeMagnets, getCurrentParameters());

    println("created object");
  }
  public void update(Iterator<GroupController> iterator) {
    // println("contains 1 " + groupSequences.contains(one));
    // println("contains 2 " + groupSequences.contains(two));

    if (!groupSequences.contains(one) && !groupSequences.contains(two)) { //done
      println("done merging");
      removeAllFromGroup();
      if (selectedMags.contains(target.index)) {
        selectedMags.remove((Integer) target.index);
      }
      magButtons[target.index].setValue(false);
      // target.slider.setValue(0);

      iterator.remove();
      return;
    }
  }
}

// note: doesnt include center in members
class RotateController extends GroupController {
  public Magnet center;
  int direction;
  float repellIntensity = 0.6 * maxIntensity;
  //int end; //default to full rotation
  //int curr_index;
  // public RotateController(Magnet center, int start, int direction, int end) {
  //   this.end = end;
  //   finishInstantiation();
  //   //curr_index = start;
  // }
  // public RotateController(Magnet center, int start) {
  //   direction = 1;
  //   end = start;
  //   finishInstantiation();
  // }
  public RotateController(Magnet center) {
    this.center = center;
    direction = 1; //clockwise
    int start;
    try {
      start = getMagIndexFromCoord(center.getRow() - 1, center.getCol());
    }
    catch (Exception e) {
      println("can't rotate here");
    }
    if (!usingEM) {
      cp5.getController("fadeStart").setValue(repellIntensity);
      cp5.getController("fadeEnd").setValue(0);
    } else {
      cp5.getController("fadeStart").setValue(-0.3*repellIntensity);
      cp5.getController("fadeEnd").setValue(0);
    }
    finishInstantiation();

    // Record the event
    ArrayList<Integer> rotateMagnets = new ArrayList<Integer>();
    rotateMagnets.add(center.index);
    recordEvent(mode.name(), "RotateController", rotateMagnets, getCurrentParameters());
  }

  void finishInstantiation() {
    calculateSurroundingMagnets();
    center.setMode(Mode.EXT_CONT);
    if (usingEM) {
      center.slider.setValue(-repellIntensity);
    } else {
      center.slider.setValue(repellIntensity);
    }
    //shortcut should be fixed!!
    cp5.getController("fadeSpeed").setValue((int)cp5.getController("rotateSpeed").getValue());
    if (usingEM) {
      members.get(0).setMode(Mode.FADE);
      members.get(1).setMode(Mode.RUN);
      members.get(1).slider.setValue(maxIntensity);
    } else {
      if (members.size() < 4) {
        println("not enough magnets to rotate");
        return;
      }
      members.get(0).setMode(Mode.FADE);
      members.get(1).setMode(Mode.FADE);
      members.get(2).setMode(Mode.RUN);
      members.get(3).setMode(Mode.RUN);
      members.get(2).slider.setValue(repellIntensity);
      members.get(3).slider.setValue(repellIntensity);
    }
  }

  void calculateSurroundingMagnets() {
    int shield = center.getRow();
    int motor = center.getCol();
    if (direction == 1) { //clockwise
      try {
        if (usingEM) {
          addToGroup(getMagIndexFromCoord(shield - 1, motor)); //top
          addToGroup(getMagIndexFromCoord(shield - 1, motor + 1)); //top right
          addToGroup(getMagIndexFromCoord(shield, motor + 1)); //right
          addToGroup(getMagIndexFromCoord(shield + 1, motor + 1)); //bottom right
          addToGroup(getMagIndexFromCoord(shield + 1, motor)); //bottom
          addToGroup(getMagIndexFromCoord(shield + 1, motor - 1)); //bottom left
          addToGroup(getMagIndexFromCoord(shield, motor - 1)); //left
          addToGroup(getMagIndexFromCoord(shield - 1, motor - 1)); //top left
          addToGroup(getMagIndexFromCoord(shield - 1, motor)); //top
          addToGroup(getMagIndexFromCoord(shield - 1, motor + 1)); //top right
          addToGroup(getMagIndexFromCoord(shield, motor + 1)); //right
          addToGroup(getMagIndexFromCoord(shield + 1, motor + 1)); //bottom right
          addToGroup(getMagIndexFromCoord(shield + 1, motor)); //bottom
          addToGroup(getMagIndexFromCoord(shield + 1, motor - 1)); //bottom left
          addToGroup(getMagIndexFromCoord(shield, motor - 1)); //left
          addToGroup(getMagIndexFromCoord(shield - 1, motor - 1)); //top left
        } else {
          addToGroup(getMagIndexFromCoord(shield + 1, motor - 1)); //bottom left
          addToGroup(getMagIndexFromCoord(shield - 1, motor)); //top

          addToGroup(getMagIndexFromCoord(shield - 1, motor - 1)); //top left
          addToGroup(getMagIndexFromCoord(shield, motor + 1)); //right

          addToGroup(getMagIndexFromCoord(shield - 1, motor + 1)); //top right
          addToGroup(getMagIndexFromCoord(shield + 1, motor)); //bottom

          addToGroup(getMagIndexFromCoord(shield + 1, motor + 1)); //bottom right
          addToGroup(getMagIndexFromCoord(shield, motor - 1)); //left

          addToGroup(getMagIndexFromCoord(shield + 1, motor - 1)); //bottom left
          addToGroup(getMagIndexFromCoord(shield - 1, motor)); //top

          addToGroup(getMagIndexFromCoord(shield - 1, motor - 1)); //top left
          addToGroup(getMagIndexFromCoord(shield, motor + 1)); //right

          addToGroup(getMagIndexFromCoord(shield - 1, motor + 1)); //top right
          addToGroup(getMagIndexFromCoord(shield + 1, motor)); //bottom

          addToGroup(getMagIndexFromCoord(shield + 1, motor + 1)); //bottom right
          addToGroup(getMagIndexFromCoord(shield, motor - 1)); //left
        }
      }
      catch (Exception e) {
        println("can't rotate here");
        return;
      }
    } else {
      try {
        addToGroup(getMagIndexFromCoord(shield + 1, motor)); //bottom
        addToGroup(getMagIndexFromCoord(shield + 1, motor - 1)); //bottom left
        addToGroup(getMagIndexFromCoord(shield, motor - 1)); //left
        addToGroup(getMagIndexFromCoord(shield - 1, motor - 1)); //top left
        addToGroup(getMagIndexFromCoord(shield - 1, motor)); //top
        addToGroup(getMagIndexFromCoord(shield - 1, motor + 1)); //top right
        addToGroup(getMagIndexFromCoord(shield, motor + 1)); //right
        addToGroup(getMagIndexFromCoord(shield + 1, motor + 1)); //bottom right
      }
      catch (Exception e) {
        println("can't rotate here");
        return;
      }
    }
  }

  void update(Iterator<GroupController> iterator) {
    // if (curr_index == end) {
    //   removeAllFromGroup();
    //   iterator.remove();
    //   return;
    // }
    if (members.size() < 2 || !usingEM && members.size() < 4) { //done -> for now
      members.get(0).slider.setValue(0);
      if (!usingEM) {
        for (int i = 1; i < members.size(); i++) {
          members.get(i).slider.setValue(0);
        }
      }
      // center.slider.setValue(0);
      // center.mode = center.prev_mode;
      removeAllFromGroup();
      iterator.remove();
      println("done rotating");
      return;
    }
    if (members.get(0).mode != Mode.FADE) { //fade is done
      if (usingEM) {
        members.get(0).slider.setValue(0);
        removeIndexFromGroup(0);
        if (members.size() <= 1) {
          return;
        }
        members.get(0).setMode(Mode.FADE);
        members.get(1).setMode(Mode.RUN);
        members.get(1).slider.setValue(maxIntensity);
      } else {
        members.get(0).slider.setValue(0);
        members.get(1).slider.setValue(0);
        removeIndexFromGroup(0);
        removeIndexFromGroup(0);
        if (members.size() <= 3) {
          return;
        }
        members.get(0).setMode(Mode.FADE);
        members.get(1).setMode(Mode.FADE);
        members.get(2).setMode(Mode.RUN);
        members.get(3).setMode(Mode.RUN);
        members.get(2).slider.setValue(repellIntensity);
        members.get(3).slider.setValue(repellIntensity);
      }
    }
  }
}


// void stopLoop() {
//   for (GroupController group : groupSequences) {
//     if (group instanceof LoopController) {
//       group.removeAllFromGroup();
//     }
//   }
// }

class ConstantController extends GroupController {
  public Magnet magnet;
  public ConstantController(int magnetIndex, int intensity) {
    addToGroup(magnets[magnetIndex]);
    this.magnet = magnets[magnetIndex];
    this.magnet.setMode(Mode.RUN);
    this.magnet.slider.setValue(intensity);

    // Record the event
    ArrayList<Integer> constantMagnets = new ArrayList<Integer>();
    constantMagnets.add(magnetIndex);
    recordEvent(mode.name(), "ConstantController", constantMagnets, getCurrentParameters());
  }
  public void update(Iterator<GroupController> iterator) {
    removeAllFromGroup();
    iterator.remove();
  }
}

class ShakeController extends GroupController {
  // Parameters for shake behavior
  int shakeIntensity = (int)defaultEndRange;        // High intensity for active magnets
  int shakeIntensityLow = (int)(140.0/200.0 * defaultEndRange);     // Medium intensity for alternating magnets
  int shakeDuration = 500;         // Duration of each shake phase in ms
  int shakeCycles = 2;             // Number of complete shake cycles
  int finalIntensity = (int)defaultEndRange;        // Final intensity after shake

  // State tracking
  int currentCycle = 0;
  int currentPhase = 0;            // 0 = phase A, 1 = phase B, 2 = fix phase
  Timer phaseTimer = new Timer(0);
  boolean isShaking = true;

  // Two groups of magnets for alternating activation
  ArrayList<Magnet> groupA = new ArrayList<Magnet>();
  ArrayList<Magnet> groupB = new ArrayList<Magnet>();

  public ShakeController(ArrayList<Integer> shakeArray) {
    this(shakeArray, (int)defaultEndRange, (int)(140.0/200.0 * defaultEndRange), 500, 2, (int)defaultEndRange);
  }

  public ShakeController(ArrayList<Integer> shakeArray, int shakeIntensity, int shakeIntensityLow, int shakeDuration, int shakeCycles, int finalIntensity) {
    this.shakeIntensity = shakeIntensity;
    this.shakeIntensityLow = shakeIntensityLow;
    this.shakeDuration = shakeDuration;
    this.shakeCycles = shakeCycles;
    this.finalIntensity = finalIntensity;

    // Add all selected magnets to the main group
    for (int magnetIndex : shakeArray) {
      addToGroup(magnetIndex);
    }

    // Split magnets into two alternating groups
    splitMagnetsIntoGroups();

    // Start the first shake phase
    startShakePhase();

    // Record the event
    recordEvent(mode.name(), "ShakeController", shakeArray, getCurrentParameters());

    if (debugGroupControllers) {
      println("ShakeController created with " + shakeArray.size() + " magnets, " + shakeCycles + " cycles");
    }
  }

  void splitMagnetsIntoGroups() {
    // Clear the groups first to avoid accumulation
    groupA.clear();
    groupB.clear();

    // Alternate magnets between group A and group B
    for (Magnet magnet : members) {
      if (magnet.index % 2 == 0) {
        groupA.add(magnet);
      } else {
        groupB.add(magnet);
      }
    }

    if (debugGroupControllers) {
      println("Split magnets: Group A has " + groupA.size() + " magnets, Group B has " + groupB.size() + " magnets");
    }
  }

  void startShakePhase() {
    phaseTimer.setDuration(shakeDuration);
    phaseTimer.start();

    if (currentPhase == 0) {
      // Phase A: Group A high, Group B medium
      setGroupIntensity(groupA, shakeIntensity);
      setGroupIntensity(groupB, shakeIntensityLow);
      if (debugGroupControllers) {
        println("Phase A: Group A high, Group B medium");
      }
    } else if (currentPhase == 1) {
      // Phase B: Group A medium, Group B high
      setGroupIntensity(groupA, shakeIntensityLow);
      setGroupIntensity(groupB, shakeIntensity);
      if (debugGroupControllers) {
        println("Phase B: Group A medium, Group B high");
      }
    } else {
      // Fix phase: All magnets to final intensity
      setGroupIntensity(groupA, finalIntensity);
      setGroupIntensity(groupB, finalIntensity);
      if (debugGroupControllers) {
        println("Fix phase: All magnets to final intensity");
      }
    }
  }

  void setGroupIntensity(ArrayList<Magnet> group, int intensity) {
    if (debugGroupControllers) {
      for (Magnet magnet : group) {
        println("Time is:" + millis());
        println("Setting intensity for magnet " + magnet.index + " to " + intensity);
      }
    }
    for (Magnet magnet : group) {
      magnet.setMode(Mode.RUN);
      magnet.slider.setValue(intensity);
    }
    if (debugGroupControllers) {
      println("Done Set intensity for group " + group.size() + " magnets, to intensity " + intensity);
    }
  }

  public void update(Iterator<GroupController> iterator) {
    if (!isShaking) {
      return;
    }

    if (phaseTimer.triggered()) {
      currentPhase++;

      if (currentPhase <= 1) {
        // Continue with next shake phase
        startShakePhase();
      } else {
        // Fix phase completed, check if we need more cycles
        currentCycle++;
        if (currentCycle < shakeCycles) {
          // Start next cycle
          currentPhase = 0;
          startShakePhase();
        } else {
          // Shake completed
          completeShake();
          removeAllFromGroup();
          iterator.remove();
          if (debugGroupControllers) {
            println("ShakeController completed " + shakeCycles + " cycles");
          }
        }
      }
    }
  }

  void completeShake() {
    // Ensure all magnets are at final intensity
    setGroupIntensity(groupA, finalIntensity);
    setGroupIntensity(groupB, finalIntensity);
    isShaking = false;
  }
}

class GlobalShakeController extends GroupController {
  // Parameters
  int shakeIntensity;
  int shakeIntensityLow;
  int shakeDuration;
  int shakeCycles;
  int finalIntensity;
  int sweepDirection; // 0=L-to-R, 1=R-to-L, 2=T-to-B, 3=B-to-T

  // State tracking
  int currentCycle = 0;
  int currentStep = 0;
  Timer stepTimer = new Timer(0);
  boolean isSweeping = true;

  // Ordered groups: each entry is magnets sharing one column (or row)
  ArrayList<ArrayList<Magnet>> sortedGroups = new ArrayList<ArrayList<Magnet>>();

  public GlobalShakeController(ArrayList<Integer> shakeArray) {
    this(shakeArray, (int)defaultEndRange, (int)(140.0/200.0 * defaultEndRange),
         500, 2, (int)defaultEndRange, 0);
  }

  public GlobalShakeController(ArrayList<Integer> shakeArray, int shakeIntensity,
      int shakeIntensityLow, int shakeDuration, int shakeCycles,
      int finalIntensity, int sweepDirection) {
    this.shakeIntensity = shakeIntensity;
    this.shakeIntensityLow = shakeIntensityLow;
    this.shakeDuration = shakeDuration;
    this.shakeCycles = shakeCycles;
    this.finalIntensity = finalIntensity;
    this.sweepDirection = sweepDirection;

    for (int magnetIndex : shakeArray) {
      addToGroup(magnetIndex);
    }

    buildSortedGroups();

    if (sortedGroups.size() > 0) {
      startStep();
    } else {
      isSweeping = false;
    }

    recordEvent(mode.name(), "GlobalShakeController", shakeArray, getCurrentParameters());

    if (debugGroupControllers) {
      println("GlobalShakeController created with " + shakeArray.size() + " magnets, "
        + sortedGroups.size() + " groups, direction=" + sweepDirection);
    }
  }

  void buildSortedGroups() {
    TreeMap<Integer, ArrayList<Magnet>> groupMap = new TreeMap<Integer, ArrayList<Magnet>>();

    for (Magnet magnet : members) {
      int key;
      if (sweepDirection <= 1) {
        key = magnet.getCol(); // group by column for L/R sweep
      } else {
        key = magnet.getRow(); // group by row for T/B sweep
      }

      if (!groupMap.containsKey(key)) {
        groupMap.put(key, new ArrayList<Magnet>());
      }
      groupMap.get(key).add(magnet);
    }

    // Convert to ordered list
    sortedGroups.clear();
    for (Map.Entry<Integer, ArrayList<Magnet>> entry : groupMap.entrySet()) {
      sortedGroups.add(entry.getValue());
    }

    // Reverse for R-to-L or B-to-T
    if (sweepDirection == 1 || sweepDirection == 3) {
      Collections.reverse(sortedGroups);
    }
  }

  void startStep() {
    stepTimer.setDuration(shakeDuration);
    stepTimer.start();

    // Set active group to HIGH, all others to LOW
    for (int i = 0; i < sortedGroups.size(); i++) {
      int intensity = (i == currentStep) ? shakeIntensity : shakeIntensityLow;
      for (Magnet magnet : sortedGroups.get(i)) {
        magnet.setMode(Mode.RUN);
        magnet.slider.setValue(intensity);
      }
    }

    if (debugGroupControllers) {
      println("GlobalShake step " + currentStep + "/" + sortedGroups.size()
        + " cycle " + currentCycle + "/" + shakeCycles);
    }
  }

  public void update(Iterator<GroupController> iterator) {
    if (!isSweeping) return;

    if (stepTimer.triggered()) {
      currentStep++;

      if (currentStep >= sortedGroups.size()) {
        // One sweep completed
        currentCycle++;
        if (currentCycle < shakeCycles) {
          currentStep = 0;
          startStep();
        } else {
          // All cycles done
          completeSweep();
          removeAllFromGroup();
          iterator.remove();
          if (debugGroupControllers) {
            println("GlobalShakeController completed " + shakeCycles + " cycles");
          }
        }
      } else {
        startStep();
      }
    }
  }

  void completeSweep() {
    for (ArrayList<Magnet> group : sortedGroups) {
      for (Magnet magnet : group) {
        magnet.setMode(Mode.RUN);
        magnet.slider.setValue(finalIntensity);
      }
    }
    isSweeping = false;
  }
}

class RedistributeController extends GroupController {
  boolean[] targetPattern;
  int morphFinalIntensity;
  float fillThreshold = 0.30;
  int moveIntensity = 200;
  int holdIntensity = 185;
  HashSet<Integer> safeZone = new HashSet<Integer>();
  boolean inCleanup = false;

  // Timeout / retry limits
  final int MAX_MOVES = 10;
  final int MAX_SAME_PAIR_RETRIES = 3;
  final int SETTLE_DELAY = 1700; // ms wait after each move
  int totalMoveCount = 0;
  // Track retries per source-dest pair: key = "source,dest", value = count
  HashMap<String, Integer> pairRetryCounts = new HashMap<String, Integer>();
  int lastSource = -1;
  int lastDest = -1;

  // Move state
  ArrayList<Integer> currentPath = null;
  // 0=SCAN, 1=RAISE_PATH, 2=SETUP_WAIT, 3=RETRACT, 4=SETTLE, 5=SHAKE, 6=DONE
  int phase = 0;
  int raiseIndex = 0;
  int retractIndex = 0;
  boolean fading = false;
  Timer moveTimer = new Timer(0);
  final int RAISE_DELAY = 50;
  int retractDelay;
  final int PIXEL_SPACING_MM = 15;
  final int PM_FADE_SPEED = 50;

  // Post-move shake
  ShakeController postMoveShake = null;

  public RedistributeController(boolean[] targetPattern, int morphFinalIntensity) {
    this.targetPattern = targetPattern;
    this.morphFinalIntensity = morphFinalIntensity;

    // Calculate retract delay from move speed
    float speedMM = readMoveSpeedMM();
    this.retractDelay = (int)(PIXEL_SPACING_MM / (speedMM > 0 ? speedMM : 15) * 1000);

    // Build safe zone: index 0 and its 8 neighbors
    int[] nbDr = {-1, -1, -1, 0, 0, 0, 1, 1, 1};
    int[] nbDc = {-1, 0, 1, -1, 0, 1, -1, 0, 1};
    for (int d = 0; d < 9; d++) {
      int nr = 0 + nbDr[d];
      int nc = 0 + nbDc[d];
      if (nr >= 0 && nr < num_rows && nc >= 0 && nc < num_motors_per_row) {
        safeZone.add(getMagIndexFromCoord(nr, nc));
      }
    }

    // Add all magnets to group
    for (int i = 0; i < NUM_MAGNETS; i++) {
      addToGroup(i);
    }

    println("RedistributeController created, safe zone: " + safeZone);
  }

  String pairKey(int source, int dest) {
    return source + "," + dest;
  }

  boolean isPairExhausted(int source, int dest) {
    String key = pairKey(source, dest);
    return pairRetryCounts.containsKey(key) && pairRetryCounts.get(key) >= MAX_SAME_PAIR_RETRIES;
  }

  void recordPairAttempt(int source, int dest) {
    String key = pairKey(source, dest);
    int count = pairRetryCounts.containsKey(key) ? pairRetryCounts.get(key) : 0;
    pairRetryCounts.put(key, count + 1);
  }

  // Find source and dest for next move. Returns int[]{source, dest} or null.
  int[] planNextMove(float[] fillRatios) {
    // Find target pixel with lowest fill below threshold
    int dest = -1;
    float destFill = Float.MAX_VALUE;
    for (int i = 0; i < targetPattern.length; i++) {
      if (targetPattern[i] && fillRatios[i] < fillThreshold && fillRatios[i] < destFill) {
        destFill = fillRatios[i];
        dest = i;
      }
    }

    if (dest == -1) return null; // all target pixels above threshold

    // Priority 1: non-target pixel with particles, highest fill, not in safe zone
    int source = -1;
    float sourceFill = -1;
    for (int i = 0; i < targetPattern.length; i++) {
      if (!targetPattern[i] && !safeZone.contains(i)
          && cameraBallPresent != null && cameraBallPresent[i]
          && fillRatios[i] > sourceFill && !isPairExhausted(i, dest)) {
        sourceFill = fillRatios[i];
        source = i;
      }
    }

    if (source != -1) return new int[]{source, dest};

    // Priority 2: target pixel with highest fill, not in safe zone, not dest
    for (int i = 0; i < targetPattern.length; i++) {
      if (targetPattern[i] && i != dest && !safeZone.contains(i)
          && cameraBallPresent != null && cameraBallPresent[i]
          && fillRatios[i] > sourceFill && !isPairExhausted(i, dest)) {
        sourceFill = fillRatios[i];
        source = i;
      }
    }

    if (source != -1) return new int[]{source, dest};
    return null;
  }

  // Find non-target pixel with particles for cleanup. Returns source index or -1.
  int planCleanupSource() {
    if (cameraBallPresent == null) return -1;
    for (int i = 0; i < targetPattern.length; i++) {
      if (!targetPattern[i] && !safeZone.contains(i) && cameraBallPresent[i]
          && !isPairExhausted(i, 0)) {
        return i;
      }
    }
    return -1;
  }

  ArrayList<Integer> buildManhattanPath(int start, int end) {
    ArrayList<Integer> path = new ArrayList<Integer>();
    int currPos = start;
    int targetRow = end / num_motors_per_row;
    int targetCol = end % num_motors_per_row;
    path.add(currPos);
    while (currPos != end) {
      int currRow = currPos / num_motors_per_row;
      int currCol = currPos % num_motors_per_row;
      if (currRow < targetRow) {
        currPos = getMagIndexFromCoord(currRow + 1, currCol);
      } else if (currRow > targetRow) {
        currPos = getMagIndexFromCoord(currRow - 1, currCol);
      } else if (currCol < targetCol) {
        currPos = getMagIndexFromCoord(currRow, currCol + 1);
      } else if (currCol > targetCol) {
        currPos = getMagIndexFromCoord(currRow, currCol - 1);
      }
      path.add(currPos);
    }
    return path;
  }

  void setupMove(int source, int dest) {
    // Calculate path: BFS first, Manhattan fallback
    ArrayList<Integer> path = bfsPath(source, dest, num_rows, num_motors_per_row);
    if (path == null) {
      println("Redistribute: BFS failed, using Manhattan path");
      path = buildManhattanPath(source, dest);
    }
    currentPath = path;
    lastSource = source;
    lastDest = dest;
    recordPairAttempt(source, dest);
    totalMoveCount++;
    raiseIndex = 0;
    retractIndex = 0;
    fading = false;

    // Target shape magnets to holdIntensity (185), non-target to 0, path will be overridden
    HashSet<Integer> pathSet = new HashSet<Integer>(currentPath);
    for (int i = 0; i < NUM_MAGNETS; i++) {
      if (!pathSet.contains(i)) {
        magnets[i].setMode(Mode.RUN);
        magnets[i].slider.setValue(targetPattern[i] ? holdIntensity : 0);
      }
    }

    // Start raising path magnets one by one
    magnets[currentPath.get(0)].setMode(Mode.RUN);
    magnets[currentPath.get(0)].slider.setValue(moveIntensity);
    raiseIndex = 1;
    moveTimer.setDuration(RAISE_DELAY);
    moveTimer.start();
    phase = 1; // RAISE_PATH

    println("Redistribute move #" + totalMoveCount + ": " + source + " -> " + dest
      + ", path length " + path.size()
      + ", pair attempt " + pairRetryCounts.get(pairKey(source, dest)));
  }

  // Start local shake on target pixels after a move
  void startPostMoveShake() {
    ArrayList<Integer> onMagnets = new ArrayList<Integer>();
    for (int i = 0; i < targetPattern.length; i++) {
      if (targetPattern[i]) onMagnets.add(i);
    }
    if (onMagnets.size() > 0) {
      // Read shake params from SHAPE settings
      int shakeInt = (int)cp5.getController("shakeIntensity").getValue();
      int shakeIntLow = (int)cp5.getController("shakeIntensityLow").getValue();
      int shakeDur = (int)cp5.getController("shakeDuration").getValue();
      int shakeCyc = (int)cp5.getController("shakeCycles").getValue();
      int shakeFinal = morphFinalIntensity;
      postMoveShake = new ShakeController(onMagnets, shakeInt, shakeIntLow, shakeDur, shakeCyc, shakeFinal);
      pendingGroupSequences.add(postMoveShake);
      phase = 5; // SHAKE
    } else {
      phase = 0; // back to SCAN
    }
  }

  public void update(Iterator<GroupController> iterator) {
    switch (phase) {

    case 0: // SCAN
      // Check move limit
      if (totalMoveCount >= MAX_MOVES) {
        println("Redistribute: max moves (" + MAX_MOVES + ") reached, finishing");
        phase = 6; // DONE
        break;
      }

      float[] fillRatios = scanFillRatios();
      updateCameraBallDetection();

      if (!inCleanup) {
        int[] move = planNextMove(fillRatios);
        if (move != null) {
          setupMove(move[0], move[1]);
        } else {
          // All target pixels >= threshold (or all pairs exhausted), switch to cleanup
          inCleanup = true;
          int cleanupSource = planCleanupSource();
          if (cleanupSource != -1) {
            setupMove(cleanupSource, 0); // dest = grid corner index 0
          } else {
            phase = 6; // DONE
          }
        }
      } else {
        int cleanupSource = planCleanupSource();
        if (cleanupSource != -1) {
          setupMove(cleanupSource, 0);
        } else {
          phase = 6; // DONE
        }
      }
      break;

    case 1: // RAISE_PATH - raising magnets one by one
      if (moveTimer.triggered()) {
        if (raiseIndex < currentPath.size()) {
          magnets[currentPath.get(raiseIndex)].setMode(Mode.RUN);
          magnets[currentPath.get(raiseIndex)].slider.setValue(moveIntensity);
          raiseIndex++;
        }
        if (raiseIndex >= currentPath.size()) {
          // All raised, wait user-configured setup delay before retraction
          int setupDelay = (int)cp5.getController("moveSetupDelay").getValue();
          moveTimer.setDuration(setupDelay);
          phase = 2; // SETUP_WAIT
        }
      }
      break;

    case 2: // SETUP_WAIT - brief pause after all path magnets raised
      if (moveTimer.triggered()) {
        // Start retracting from source end
        cp5.getController("fadeStart").setValue(moveIntensity);
        cp5.getController("fadeEnd").setValue(0);
        cp5.getController("fadeSpeed").setValue(PM_FADE_SPEED);
        magnets[currentPath.get(retractIndex)].setMode(Mode.FADE);
        fading = true;
        phase = 3; // RETRACT
      }
      break;

    case 3: // RETRACT - fading magnets one by one from source to dest
      if (fading) {
        if (magnets[currentPath.get(retractIndex)].mode != Mode.FADE) {
          // Fade finished for this magnet
          magnets[currentPath.get(retractIndex)].slider.setValue(0);
          fading = false;
          retractIndex++;

          if (retractIndex >= currentPath.size() - 1) {
            // All retracted except destination
            magnets[currentPath.get(currentPath.size() - 1)].slider.setValue(moveIntensity);
            println("Redistribute move complete, settling for " + SETTLE_DELAY + "ms");
            moveTimer.setDuration(SETTLE_DELAY);
            moveTimer.start();
            phase = 4; // SETTLE
            break;
          }
          // Delay before next retraction
          moveTimer.setDuration(retractDelay);
          moveTimer.reset();
        }
      } else {
        if (moveTimer.triggered()) {
          cp5.getController("fadeStart").setValue(moveIntensity);
          cp5.getController("fadeEnd").setValue(0);
          cp5.getController("fadeSpeed").setValue(PM_FADE_SPEED);
          magnets[currentPath.get(retractIndex)].setMode(Mode.FADE);
          fading = true;
        }
      }
      break;

    case 4: // SETTLE - wait 1.7s for move to physically complete
      if (moveTimer.triggered()) {
        // Restore target pattern before shake
        for (int i = 0; i < NUM_MAGNETS; i++) {
          magnets[i].setMode(Mode.RUN);
          magnets[i].slider.setValue(targetPattern[i] ? morphFinalIntensity : 0);
        }
        startPostMoveShake();
      }
      break;

    case 5: // SHAKE - wait for post-move local shake to complete
      if (postMoveShake != null && groupSequences.contains(postMoveShake)) {
        return; // still shaking
      }
      postMoveShake = null;
      phase = 0; // back to SCAN
      break;

    case 6: // DONE
      // Restore all magnets to target pattern
      for (int i = 0; i < NUM_MAGNETS; i++) {
        magnets[i].setMode(Mode.RUN);
        magnets[i].slider.setValue(targetPattern[i] ? morphFinalIntensity : 0);
      }
      removeAllFromGroup();
      iterator.remove();
      println("RedistributeController completed after " + totalMoveCount + " moves");
      break;
    }
  }
}
