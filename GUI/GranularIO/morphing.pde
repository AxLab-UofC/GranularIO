// ============================================================
// Morphing System for Automatic Shape Transition Generation
// ============================================================
// Generates tweening frames between two boolean[49] patterns.
// The number of frames is determined by the algorithm, not a fixed count.
// A max-steps parameter caps the output.

// ---- Global State ----
MorphSequence currentMorphSequence = null;
boolean morphPlaybackActive = false;
int morphPreviewFrameIndex = -1;

SavedPattern morphStartPattern = null;
SavedPattern morphEndPattern = null;
int morphSelectionState = 0; // 0=select start, 1=select end, 2=ready
// When true, a single thumbnail click in MORPH saves the camera frame as start, then morphs to the clicked pattern.
boolean morphAutomateEnabled = false;
boolean morphSequenceEnabled = false;
ArrayList<SavedPattern> morphSequenceTargets = new ArrayList<SavedPattern>();
// Sequence that was most recently executed (includes start at index 0).
ArrayList<SavedPattern> morphSequenceDisplayedTargets = new ArrayList<SavedPattern>();

// Filmstrip layout
int filmstripX = 300;
int filmstripY = 885;
int filmstripThumbSize = 50;
int filmstripSpacing = 5;
int filmstripScrollOffset = 0;

// ---- Data Structures ----

class MorphSequence {
  SavedPattern startPattern;
  SavedPattern endPattern;
  ArrayList<boolean[]> frames;
  ArrayList<PImage> frameThumbnails;
  ArrayList<Integer> targetFrameIndices = new ArrayList<Integer>();
  HashSet<Integer> redistributeFrameIndices = new HashSet<Integer>();

  MorphSequence(SavedPattern start, SavedPattern end) {
    this.startPattern = start;
    this.endPattern = end;
    this.frames = new ArrayList<boolean[]>();
    this.frameThumbnails = new ArrayList<PImage>();
  }

  void generateThumbnails() {
    // Thumbnails are drawn directly in drawMorphFilmstrip() to avoid
    // OpenGL texture cache corruption from creating many PImages.
    frameThumbnails.clear();
  }

  int totalFrames() {
    return frames.size();
  }
}

// ---- Utility ----

boolean[] copyPattern(boolean[] src) {
  boolean[] dst = new boolean[src.length];
  System.arraycopy(src, 0, dst, 0, src.length);
  return dst;
}

boolean patternsEqual(boolean[] a, boolean[] b) {
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// Manhattan distance from cell i to nearest ON cell in target (integer)
int distToNearest(int i, boolean[] target, int cols, int rows) {
  int ri = i / cols, ci = i % cols;
  int minDist = Integer.MAX_VALUE;
  for (int j = 0; j < target.length; j++) {
    if (target[j]) {
      int rj = j / cols, cj = j % cols;
      int d = abs(ri - rj) + abs(ci - cj);
      if (d < minDist) minDist = d;
    }
  }
  return minDist;
}

// ---- Tweening Algorithm ----
//
// Each step:
//   1. Look at all neighbouring pixels of the current shape (OFF cells adjacent to ON cells)
//   2. For each neighbour, compute shortest distance to any pixel in the final target
//   3. Add the neighbour with the smallest distance → forms expanded set
//   4. From the expanded set, find the pixel farthest from the target
//   5. Remove it, UNLESS its distance is 0 (it's already in the final shape)
//   6. The result is the new frame
//   7. Repeat until new frame equals final shape, or max steps reached

ArrayList<boolean[]> generateTweening(boolean[] start, boolean[] end, int maxSteps) {
  int cols = num_motors_per_row;
  int rows = num_rows;
  int n = rows * cols;
  // 8-connected neighbours (cardinal + diagonal)
  int[] dx = {-1, 1, 0, 0, -1, -1, 1, 1};
  int[] dy = {0, 0, -1, 1, -1, 1, -1, 1};

  // Precompute distance from each cell to nearest end-ON cell
  int[] distToEnd = new int[n];
  for (int i = 0; i < n; i++) {
    distToEnd[i] = distToNearest(i, end, cols, rows);
  }

  ArrayList<boolean[]> frames = new ArrayList<boolean[]>();
  frames.add(copyPattern(start));

  boolean[] current = copyPattern(start);

  for (int step = 0; step < maxSteps; step++) {
    if (patternsEqual(current, end)) break;

    // Step 1: Find all neighbouring pixels (OFF cells adjacent to current ON cells)
    // Skip neighbours whose closest target pixel is already ON in current frame
    ArrayList<Integer> neighbors = new ArrayList<Integer>();
    for (int i = 0; i < n; i++) {
      if (current[i]) continue;
      int r = i / cols, c = i % cols;
      boolean adjacent = false;
      for (int d = 0; d < dx.length; d++) {
        int nr = r + dy[d], nc = c + dx[d];
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && current[nr * cols + nc]) {
          adjacent = true;
          break;
        }
      }
      if (!adjacent) continue;

      // Check: is this neighbour's closest target pixel already in the current frame?
      int ri = i / cols, ci = i % cols;
      int closestTarget = -1;
      int closestDist = Integer.MAX_VALUE;
      for (int j = 0; j < n; j++) {
        if (!end[j]) continue;
        int rj = j / cols, cj = j % cols;
        int d = abs(ri - rj) + abs(ci - cj);
        if (d < closestDist) {
          closestDist = d;
          closestTarget = j;
        }
      }
      // Only include if closest target pixel is NOT already covered
      if (closestTarget >= 0 && !current[closestTarget]) {
        neighbors.add(i);
      }
    }

    // Step 2: Find the smallest distance among all neighbours
    int bestDist = Integer.MAX_VALUE;
    for (int idx : neighbors) {
      if (distToEnd[idx] < bestDist) {
        bestDist = distToEnd[idx];
      }
    }

    // Step 3: Add ALL neighbours tied at that smallest distance
    boolean[] expanded = copyPattern(current);
    if (bestDist < Integer.MAX_VALUE) {
      for (int idx : neighbors) {
        if (distToEnd[idx] == bestDist) {
          expanded[idx] = true;
        }
      }
    }

    // Step 4: Find the largest distance among all ON pixels in expanded set
    int worstDist = -1;
    for (int i = 0; i < n; i++) {
      if (!expanded[i]) continue;
      if (distToEnd[i] > worstDist) {
        worstDist = distToEnd[i];
      }
    }

    // Step 5: Remove ALL pixels tied at that largest distance,
    //         unless distance is 0 (they are in the final shape)
    if (worstDist > 0) {
      for (int i = 0; i < n; i++) {
        if (expanded[i] && distToEnd[i] == worstDist) {
          expanded[i] = false;
        }
      }
    }

    // Check for no change (avoid infinite loop)
    if (patternsEqual(expanded, current)) break;

    current = expanded;
    frames.add(copyPattern(current));
  }

  // Ensure final frame is the target
  if (!patternsEqual(current, end)) {
    frames.add(copyPattern(end));
  }

  return frames;
}

// ---- Generate Dispatcher ----

MorphSequence generateMorphSequence(SavedPattern start, SavedPattern end, int maxSteps) {
  MorphSequence seq = new MorphSequence(start, end);
  seq.frames = generateTweening(start.pattern, end.pattern, maxSteps);
  seq.targetFrameIndices.add(seq.frames.size() - 1);
  seq.generateThumbnails();
  return seq;
}

// Queue for adding controllers outside of the iteration loop
ArrayList<GroupController> pendingGroupSequences = new ArrayList<GroupController>();

// ---- MorphController: Playback GroupController ----

class MorphController extends GroupController {
  MorphSequence sequence;
  int currentFrameIndex = 0;
  int frameDuration;
  int morphFinalIntensity;
  boolean useLocalShakePerFrame;
  boolean useGlobalShakePerFrame;
  int shakeIntensity;
  int shakeIntensityLow;
  int shakeDuration = 500;
  int shakeCycles = 2;
  int globalShakeSweepDirection = 0;
  boolean useRedistribute;
  HashSet<Integer> redistributeFrameIndices;
  Timer frameTimer = new Timer(0);
  boolean isMorphing = true;
  ShakeController currentShake = null;
  GlobalShakeController currentGlobalShake = null;
  RedistributeController currentRedistribute = null;

  public MorphController(MorphSequence sequence, int frameDuration,
                          boolean useLocalShake, boolean useGlobalShake,
                          int shakeIntensity, int shakeIntensityLow,
                          int shakeCycles, int morphFinalIntensity,
                          int globalShakeSweepDirection,
                          boolean useRedistribute,
                          HashSet<Integer> redistributeFrameIndices) {
    this.sequence = sequence;
    this.frameDuration = frameDuration;
    this.useLocalShakePerFrame = useLocalShake;
    this.useGlobalShakePerFrame = useGlobalShake;
    this.shakeIntensity = shakeIntensity;
    this.shakeIntensityLow = shakeIntensityLow;
    this.shakeCycles = shakeCycles;
    this.morphFinalIntensity = morphFinalIntensity;
    this.globalShakeSweepDirection = globalShakeSweepDirection;
    this.useRedistribute = useRedistribute;
    this.redistributeFrameIndices = redistributeFrameIndices != null
      ? redistributeFrameIndices : new HashSet<Integer>();

    for (int i = 0; i < NUM_MAGNETS; i++) {
      addToGroup(i);
    }

    applyFrame(0);
    frameTimer.setDuration(frameDuration);
    frameTimer.start();

    println("MorphController started: " + sequence.totalFrames() + " frames, " + frameDuration + "ms each");
  }

  void applyFrame(int frameIndex) {
    if (frameIndex < 0 || frameIndex >= sequence.totalFrames()) return;
    currentFrameIndex = frameIndex;
    boolean[] frame = sequence.frames.get(frameIndex);

    for (int i = 0; i < frame.length && i < members.size(); i++) {
      Magnet m = members.get(i);
      m.slider.setValue(frame[i] ? morphFinalIntensity : 0);
    }

    morphPreviewFrameIndex = frameIndex;

    // Auto-scroll filmstrip to keep current frame visible
    int maxVisible = (780 - filmstripX) / (filmstripThumbSize + filmstripSpacing);
    if (maxVisible > 0) {
      if (frameIndex < filmstripScrollOffset) {
        filmstripScrollOffset = frameIndex;
      } else if (frameIndex >= filmstripScrollOffset + maxVisible) {
        filmstripScrollOffset = frameIndex - maxVisible + 1;
      }
    }
  }

  ArrayList<Integer> getOnMagnets() {
    boolean[] frame = sequence.frames.get(currentFrameIndex);
    ArrayList<Integer> onMagnets = new ArrayList<Integer>();
    for (int i = 0; i < frame.length; i++) {
      if (frame[i]) onMagnets.add(i);
    }
    return onMagnets;
  }

  // Try to start redistribution for the current frame. Returns true if started.
  boolean tryStartRedistribute() {
    if (useRedistribute && redistributeFrameIndices.contains(currentFrameIndex)) {
      boolean[] frame = sequence.frames.get(currentFrameIndex);
      currentRedistribute = new RedistributeController(frame, morphFinalIntensity);
      pendingGroupSequences.add(currentRedistribute);
      return true;
    }
    return false;
  }

  public void update(Iterator<GroupController> iterator) {
    if (!isMorphing) return;

    // Wait for redistribute to complete
    if (currentRedistribute != null && groupSequences.contains(currentRedistribute)) {
      return;
    }
    if (currentRedistribute != null) {
      currentRedistribute = null;
      frameTimer.setDuration(frameDuration);
      frameTimer.start();
      return;
    }

    // Wait for global shake to complete
    if (currentGlobalShake != null && groupSequences.contains(currentGlobalShake)) {
      return;
    }
    if (currentGlobalShake != null) {
      // Global shake just finished - start local shake if enabled
      currentGlobalShake = null;
      if (useLocalShakePerFrame) {
        ArrayList<Integer> onMagnets = getOnMagnets();
        if (onMagnets.size() > 0) {
          currentShake = new ShakeController(onMagnets, shakeIntensity,
            shakeIntensityLow, shakeDuration, shakeCycles, morphFinalIntensity);
          pendingGroupSequences.add(currentShake);
          return;
        }
      }
      // No local shake, try redistribute
      if (tryStartRedistribute()) return;
      frameTimer.setDuration(frameDuration);
      frameTimer.start();
      return;
    }

    // Wait for local shake to complete
    if (currentShake != null && groupSequences.contains(currentShake)) {
      return;
    }
    if (currentShake != null) {
      // Local shake just finished, try redistribute
      currentShake = null;
      if (tryStartRedistribute()) return;
      frameTimer.setDuration(frameDuration);
      frameTimer.start();
      return;
    }

    if (frameTimer.triggered()) {
      currentFrameIndex++;

      if (currentFrameIndex >= sequence.totalFrames()) {
        isMorphing = false;
        applyFrame(sequence.totalFrames() - 1);
        removeAllFromGroup();
        iterator.remove();
        morphPlaybackActive = false;
        instructions = "Shape transition complete";
        println("MorphController completed");
        return;
      }

      applyFrame(currentFrameIndex);

      // Start shakes: global first, then local
      ArrayList<Integer> onMagnets = getOnMagnets();

      if (useGlobalShakePerFrame && onMagnets.size() > 0) {
        currentGlobalShake = new GlobalShakeController(onMagnets, shakeIntensity,
          shakeIntensityLow, shakeDuration, shakeCycles,
          morphFinalIntensity, globalShakeSweepDirection);
        pendingGroupSequences.add(currentGlobalShake);
      } else if (useLocalShakePerFrame && onMagnets.size() > 0) {
        currentShake = new ShakeController(onMagnets, shakeIntensity,
          shakeIntensityLow, shakeDuration, shakeCycles, morphFinalIntensity);
        pendingGroupSequences.add(currentShake);
      } else if (tryStartRedistribute()) {
        // Redistribute without shakes
      } else {
        frameTimer.setDuration(frameDuration);
        frameTimer.start();
      }
    }
  }
}

// ---- Button Callbacks ----

void generateMorph() {
  int maxSteps = (int)cp5.getController("morphMaxSteps").getValue();

  // Sequence mode: generate from sequence targets
  if (morphSequenceEnabled && morphSequenceTargets.size() > 0) {
    SavedPattern startPat = null;
    int firstTargetIndex = 0;

    if (morphAutomateEnabled) {
      startPat = saveCurrentPatternFromCamera();
      if (startPat == null) return;
    } else {
      if (morphSequenceTargets.size() == 1) {
        boolean[] current = new boolean[magButtons.length];
        for (int i = 0; i < current.length; i++) {
          current[i] = magButtons[i].getBooleanValue();
        }
        startPat = new SavedPattern("Current", current, "runtime");
        firstTargetIndex = 0;
      } else {
        startPat = morphSequenceTargets.get(0);
        firstTargetIndex = 1;
      }
    }

    boolean[] current = copyPattern(startPat.pattern);
    ArrayList<boolean[]> allFrames = new ArrayList<boolean[]>();
    allFrames.add(copyPattern(current));
    ArrayList<Integer> targetIndices = new ArrayList<Integer>();
    SavedPattern finalTarget = null;

    for (int i = firstTargetIndex; i < morphSequenceTargets.size(); i++) {
      SavedPattern target = morphSequenceTargets.get(i);
      ArrayList<boolean[]> seg = generateTweening(current, target.pattern, maxSteps);
      for (int f = 1; f < seg.size(); f++) {
        allFrames.add(copyPattern(seg.get(f)));
      }
      current = copyPattern(target.pattern);
      targetIndices.add(allFrames.size() - 1);
      finalTarget = target;
    }

    if (finalTarget == null) {
      instructions = "Sequence needs at least one target";
      return;
    }

    morphStartPattern = startPat;
    morphEndPattern = finalTarget;
    morphSelectionState = 2;
    currentMorphSequence = new MorphSequence(startPat, finalTarget);
    currentMorphSequence.frames = allFrames;
    currentMorphSequence.targetFrameIndices = targetIndices;
    currentMorphSequence.generateThumbnails();
    morphPreviewFrameIndex = 0;
    filmstripScrollOffset = 0;
    instructions = "Generated " + currentMorphSequence.totalFrames() + " frames (" + morphSequenceTargets.size() + " targets)";
    return;
  }

  // Simple start→end mode
  if (morphStartPattern == null || morphEndPattern == null) {
    instructions = "Select start and end patterns first";
    return;
  }

  currentMorphSequence = generateMorphSequence(morphStartPattern, morphEndPattern, maxSteps);
  morphPreviewFrameIndex = 0;
  filmstripScrollOffset = 0;
  instructions = "Generated " + currentMorphSequence.totalFrames() + " frames";
  println("Generated: " + currentMorphSequence.totalFrames() + " frames");
}

void animateMorph() {
  if (currentMorphSequence == null || currentMorphSequence.frames.isEmpty()) {
    instructions = "Generate transition sequence first";
    return;
  }
  if (morphPlaybackActive) {
    instructions = "Transition already playing";
    return;
  }

  for (Iterator<GroupController> iter = groupSequences.iterator(); iter.hasNext(); ) {
    GroupController gc = iter.next();
    gc.removeAllFromGroup();
    iter.remove();
  }

  int frameDuration = (int)cp5.getController("morphFrameDuration").getValue();
  boolean useLocalShake = cp5.getController("morphUseLocalShake").getValue() > 0;
  boolean useGlobalShake = cp5.getController("morphUseGlobalShake").getValue() > 0;
  int shakeInt = (int)cp5.getController("morphShakeIntensity").getValue();
  int shakeIntLow = (int)(shakeInt * 0.7);
  int shakeCyc = (int)cp5.getController("morphShakeCycles").getValue();
  int finalInt = (int)cp5.getController("morphFinalIntensity").getValue();
  int globalDir = (int)cp5.getController("morphGlobalShakeDirection").getValue();
  boolean useRedistribute = cp5.getController("morphUseRedistribute").getValue() > 0;

  MorphController morph = new MorphController(currentMorphSequence, frameDuration,
    useLocalShake, useGlobalShake, shakeInt, shakeIntLow, shakeCyc, finalInt, globalDir,
    useRedistribute, currentMorphSequence.redistributeFrameIndices);
  groupSequences.add(morph);
  morphPlaybackActive = true;
  instructions = "Shape transition started";
}

void stopMorph() {
  Iterator<GroupController> iter = groupSequences.iterator();
  while (iter.hasNext()) {
    GroupController gc = iter.next();
    if (gc instanceof MorphController || gc instanceof RedistributeController) {
      gc.removeAllFromGroup();
      iter.remove();
    }
  }
  morphPlaybackActive = false;
  instructions = "Shape transition stopped";
  morphSequenceDisplayedTargets.clear();
}

void toggleRedistributeFrame() {
  if (currentMorphSequence == null || morphPreviewFrameIndex < 0
      || morphPreviewFrameIndex >= currentMorphSequence.totalFrames()) {
    instructions = "Generate a sequence first, then select a frame";
    return;
  }
  int idx = morphPreviewFrameIndex;
  if (currentMorphSequence.redistributeFrameIndices.contains(idx)) {
    currentMorphSequence.redistributeFrameIndices.remove(idx);
    instructions = "Removed redistribute marker from frame " + (idx + 1);
  } else {
    currentMorphSequence.redistributeFrameIndices.add(idx);
    instructions = "Added redistribute marker to frame " + (idx + 1);
  }
}

void executeMorphSequence() {
  if (!morphSequenceEnabled) {
    instructions = "Enable sequence first";
    return;
  }
  if (morphSequenceTargets.isEmpty()) {
    instructions = "Sequence is empty: click patterns to queue";
    return;
  }

  // Generate the sequence frames (reuses generateMorph logic)
  stopMorph();
  generateMorph();

  if (currentMorphSequence == null || currentMorphSequence.frames.isEmpty()) {
    return;
  }

  // Apply start pattern and animate
  applyPattern(currentMorphSequence.startPattern.pattern);
  animateMorph();
  instructions = "Sequence transition started (" + morphSequenceTargets.size() + " targets)";
  morphSequenceDisplayedTargets.clear();
  morphSequenceTargets.clear();
}

// ---- Drawing Functions ----

void drawMorphOverlay() {
  if (mode != ActionMode.MORPH) return;
  if (currentMorphSequence == null) return;
  if (morphPreviewFrameIndex < 0 || morphPreviewFrameIndex >= currentMorphSequence.totalFrames()) return;

  boolean[] frame = currentMorphSequence.frames.get(morphPreviewFrameIndex);
  int cols = num_motors_per_row;

  for (int i = 0; i < frame.length; i++) {
    int col = i % cols;
    int row = i / cols;
    int x = startX + col * spacingX + buttonSize / 2;
    int y = startY + row * spacingY + buttonSize / 2;

    if (frame[i]) {
      fill(0, 200, 0, 100);
    } else if (currentMorphSequence.startPattern.pattern[i]) {
      fill(200, 0, 0, 60);
    } else {
      continue;
    }
    noStroke();
    ellipse(x, y, buttonSize - 20, buttonSize - 20);
  }

  // Frame counter moved to filmstrip area (drawMorphFilmstrip)
}

void drawMorphFilmstrip() {
  if (mode != ActionMode.MORPH) return;
  if (currentMorphSequence == null || currentMorphSequence.frames.isEmpty()) return;

  int totalFrames = currentMorphSequence.totalFrames();
  // Leave ~120px right margin for frame counter text
  int maxVisible = (780 - filmstripX) / (filmstripThumbSize + filmstripSpacing);
  filmstripScrollOffset = constrain(filmstripScrollOffset, 0, max(0, totalFrames - maxVisible));
  int startFrame = filmstripScrollOffset;
  int visibleCount = min(totalFrames - startFrame, maxVisible);

  int cols = num_motors_per_row;
  int rows_grid = num_rows;
  int cellW = filmstripThumbSize / cols;
  int cellH = filmstripThumbSize / rows_grid;

  // Background bar (includes space for labels above and frame counter to the right)
  fill(40, 40, 40, 200);
  noStroke();
  rect(filmstripX - 10, filmstripY - 15,
       visibleCount * (filmstripThumbSize + filmstripSpacing) + 120,
       filmstripThumbSize + 20);

  int lastThumbX = filmstripX + (visibleCount - 1) * (filmstripThumbSize + filmstripSpacing);

  // Determine number of targets for labeling
  int numTargets = currentMorphSequence.targetFrameIndices.size();

  // Draw each frame thumbnail directly
  for (int i = 0; i < visibleCount; i++) {
    int frameIndex = startFrame + i;
    if (frameIndex >= totalFrames) break;
    int tx = filmstripX + i * (filmstripThumbSize + filmstripSpacing);
    int ty = filmstripY;
    boolean[] frame = currentMorphSequence.frames.get(frameIndex);

    // Light gray background
    fill(240);
    noStroke();
    rect(tx, ty, filmstripThumbSize, filmstripThumbSize);

    // Draw ON cells as black
    fill(0);
    for (int ci = 0; ci < frame.length; ci++) {
      if (frame[ci]) {
        int gc = ci % cols;
        int gr = ci / cols;
        rect(tx + gc * cellW, ty + gr * cellH, cellW, cellH);
      }
    }

    // Highlight current preview frame
    if (frameIndex == morphPreviewFrameIndex) {
      stroke(0, 255, 0);
      strokeWeight(3);
      noFill();
      rect(tx - 2, ty - 2, filmstripThumbSize + 4, filmstripThumbSize + 4);
      noStroke();
    }

    // Draw "Start" label on frame 0
    textSize(10);
    textAlign(CENTER);
    if (frameIndex == 0) {
      fill(0, 220, 0);
      text("Start", tx + filmstripThumbSize / 2, ty - 3);
    }

    // Draw "Target" / "Target N" labels on target frames
    for (int t = 0; t < numTargets; t++) {
      if (frameIndex == currentMorphSequence.targetFrameIndices.get(t)) {
        fill(220, 100, 0);
        if (numTargets == 1) {
          text("Target", tx + filmstripThumbSize / 2, ty - 3);
        } else {
          text("Target " + (t + 1), tx + filmstripThumbSize / 2, ty - 3);
        }
      }
    }
    // Fallback: if no targets recorded, label last frame as "Target"
    if (numTargets == 0 && frameIndex == totalFrames - 1) {
      fill(220, 100, 0);
      text("Target", tx + filmstripThumbSize / 2, ty - 3);
    }

    // Redistribute marker below thumbnail
    if (currentMorphSequence.redistributeFrameIndices.contains(frameIndex)) {
      fill(180, 0, 220); // purple
      text("R", tx + filmstripThumbSize / 2, ty + filmstripThumbSize + 12);
    }
    textSize(16);
  }

  // Horizontal scrollbar below filmstrip thumbnails
  int scrollbarY = filmstripY + filmstripThumbSize + 4;
  int scrollbarWidth = visibleCount * (filmstripThumbSize + filmstripSpacing);
  drawScrollbar(true, filmstripX, scrollbarY, scrollbarWidth, 6, totalFrames, maxVisible, filmstripScrollOffset);

  // Frame counter at right end of filmstrip
  int counterX = filmstripX + visibleCount * (filmstripThumbSize + filmstripSpacing) + 15;
  int counterY = filmstripY + filmstripThumbSize / 2 + 5;
  fill(255);
  textAlign(LEFT);
  textSize(14);
  text("Frame " + (morphPreviewFrameIndex + 1) + " / " + totalFrames, counterX, counterY);
  textSize(16);

  textAlign(LEFT);
}

// Scroll offset for the target preview thumbnail strip
int targetPreviewScrollOffset = 0;

// Drag-and-drop reordering state for target preview
boolean targetDragActive = false;
int targetDragSourceIndex = -1;     // index in morphSequenceTargets being dragged
int targetDragCurrentSlot = -1;     // visual slot the drag is hovering over
int targetDragMouseOffsetX = 0;
int targetDragMouseOffsetY = 0;

// Called from mousePressed -- checks if the user clicked on a target preview thumbnail
void handleTargetPreviewMousePressed(int mx, int my) {
  if (mode != ActionMode.MORPH) return;
  if (currentMorphSequence != null && currentMorphSequence.totalFrames() > 0) return;
  if (!morphSequenceEnabled || morphSequenceTargets == null || morphSequenceTargets.isEmpty()) return;

  int thumbSize = filmstripThumbSize;
  int gap = 8;
  int baseX = filmstripX;
  int baseY = filmstripY;
  int maxVisible = (780 - baseX) / (thumbSize + gap);
  if (maxVisible < 1) maxVisible = 1;

  int startIdx = targetPreviewScrollOffset;
  int visibleCount = min(morphSequenceTargets.size() - startIdx, maxVisible);

  // Account for camera placeholder offset in automate mode
  int listOffset = morphAutomateEnabled ? 1 : 0;

  for (int vi = 0; vi < visibleCount; vi++) {
    int seqIdx = startIdx + vi;
    int x = baseX + (vi + listOffset) * (thumbSize + gap);
    int y = baseY;

    // Check if click is on the red X delete button (top-right 14x14)
    int btnSize = 14;
    int btnX = x + thumbSize - btnSize;
    int btnY = y;
    if (mx >= btnX && mx <= btnX + btnSize && my >= btnY && my <= btnY + btnSize) {
      SavedPattern removed = morphSequenceTargets.remove(seqIdx);
      instructions = "Removed " + removed.name + " from sequence (" + morphSequenceTargets.size() + " remaining)";
      // Clamp scroll offset after removal
      int maxScroll = max(0, morphSequenceTargets.size() - maxVisible);
      targetPreviewScrollOffset = constrain(targetPreviewScrollOffset, 0, maxScroll);
      return;
    }

    // Otherwise, start drag (only if 2+ targets for reordering)
    if (morphSequenceTargets.size() >= 2 &&
        mx >= x && mx <= x + thumbSize && my >= y && my <= y + thumbSize) {
      targetDragActive = true;
      targetDragSourceIndex = seqIdx;
      targetDragCurrentSlot = seqIdx;
      targetDragMouseOffsetX = mx - x;
      targetDragMouseOffsetY = my - y;
      return;
    }
  }
}

// Called from mouseDragged -- updates the drop target slot
void handleTargetPreviewMouseDragged(int mx, int my) {
  if (!targetDragActive) return;

  int thumbSize = filmstripThumbSize;
  int gap = 8;
  int baseX = filmstripX;
  int maxVisible = (780 - baseX) / (thumbSize + gap);
  if (maxVisible < 1) maxVisible = 1;

  // Determine which slot the mouse is hovering over
  int relX = mx - baseX + targetPreviewScrollOffset * (thumbSize + gap);
  int slot = relX / (thumbSize + gap);
  targetDragCurrentSlot = constrain(slot, 0, morphSequenceTargets.size() - 1);
}

// Called from mouseReleased -- performs the reorder
void handleTargetPreviewMouseReleased() {
  if (!targetDragActive) return;
  targetDragActive = false;

  int from = targetDragSourceIndex;
  int to = targetDragCurrentSlot;

  if (from != to && from >= 0 && from < morphSequenceTargets.size()
      && to >= 0 && to < morphSequenceTargets.size()) {
    SavedPattern dragged = morphSequenceTargets.remove(from);
    morphSequenceTargets.add(to, dragged);
    instructions = "Reordered target to position " + (to + 1);
  }

  targetDragSourceIndex = -1;
  targetDragCurrentSlot = -1;
}

void drawMorphPatternIndicators() {
  if (mode != ActionMode.MORPH) return;

  // Hide selection previews once frames have been generated (filmstrip shows them)
  if (currentMorphSequence != null && currentMorphSequence.totalFrames() > 0) return;

  // Unified preview: show selected patterns as a row of thumbnails
  // No dark background -- this is just the selection preview, not the filmstrip
  int thumbSize = filmstripThumbSize; // 50px
  int gap = 8;
  int baseX = filmstripX; // X=300, clears mode label area
  int baseY = filmstripY;

  // Max visible thumbs based on available width (up to right panel at ~900)
  int maxVisible = (780 - baseX) / (thumbSize + gap);
  if (maxVisible < 1) maxVisible = 1;

  // Build the list of patterns to display
  ArrayList<SavedPattern> displayList = new ArrayList<SavedPattern>();
  ArrayList<String> labelList = new ArrayList<String>();

  if (morphSequenceEnabled) {
    // Sequence mode: Start (if not automate) + Targets
    if (morphAutomateEnabled) {
      displayList.add(null); // camera placeholder
      labelList.add("Start");
    }
    if (morphSequenceTargets != null) {
      for (int i = 0; i < morphSequenceTargets.size(); i++) {
        displayList.add(morphSequenceTargets.get(i));
        if (!morphAutomateEnabled && i == 0 && morphSequenceTargets.size() >= 2) {
          labelList.add("Start");
        } else {
          int targetNum = morphAutomateEnabled ? (i + 1) : i;
          labelList.add(displayList.size() <= 2 && !morphAutomateEnabled ? "Target" : "Target " + targetNum);
        }
      }
    }
  } else {
    // Single mode: Start + Target
    if (morphStartPattern != null) {
      displayList.add(morphStartPattern);
      labelList.add("Start");
    }
    if (morphEndPattern != null) {
      displayList.add(morphEndPattern);
      labelList.add("Target");
    }
  }

  if (displayList.isEmpty()) return;

  int totalCount = displayList.size();

  // Clamp scroll offset
  int maxScroll = max(0, totalCount - maxVisible);
  targetPreviewScrollOffset = constrain(targetPreviewScrollOffset, 0, maxScroll);
  int startIdx = targetPreviewScrollOffset;
  int visibleCount = min(totalCount - startIdx, maxVisible);

  pushStyle();
  for (int vi = 0; vi < visibleCount; vi++) {
    int i = startIdx + vi;
    int x = baseX + vi * (thumbSize + gap);
    int y = baseY;
    SavedPattern sp = displayList.get(i);
    String label = labelList.get(i);

    // During drag: dim the source item, highlight the drop slot
    boolean isSource = targetDragActive && morphSequenceEnabled
      && (i - (morphAutomateEnabled ? 1 : 0)) == targetDragSourceIndex;
    boolean isDropSlot = targetDragActive && morphSequenceEnabled
      && (i - (morphAutomateEnabled ? 1 : 0)) == targetDragCurrentSlot
      && targetDragCurrentSlot != targetDragSourceIndex;

    // Drop slot indicator: draw a colored insertion line
    if (isDropSlot) {
      fill(80, 180, 255, 120);
      noStroke();
      rect(x - 2, y - 2, thumbSize + 4, thumbSize + 4, 3);
    }

    // Thumbnail background
    if (isSource) {
      fill(240, 240, 240, 100); // dimmed
    } else {
      fill(240);
    }
    noStroke();
    rect(x, y, thumbSize, thumbSize);

    if (sp != null && !isSource) {
      image(sp.thumbnail, x, y, thumbSize, thumbSize);
    } else if (sp != null && isSource) {
      tint(255, 80); // ghost of the source
      image(sp.thumbnail, x, y, thumbSize, thumbSize);
      noTint();
    } else if (sp == null) {
      // Camera placeholder
      fill(220, 60, 60, isSource ? 80 : 220);
      rect(x + 2, y + 2, thumbSize - 4, thumbSize - 4);
      fill(255);
      textAlign(CENTER, CENTER);
      textSize(11);
      text("CAM", x + thumbSize / 2, y + thumbSize / 2);
    }

    // Color-coded border: green for Start, orange for Target
    if (label.equals("Start")) {
      stroke(0, 220, 0);
    } else {
      stroke(220, 140, 0);
    }
    strokeWeight(2);
    noFill();
    rect(x - 1, y - 1, thumbSize + 2, thumbSize + 2);
    noStroke();

    // Red X delete button on top-right corner (all items in sequence mode except CAM placeholder)
    if (morphSequenceEnabled && sp != null && !targetDragActive) {
      int btnSize = 14;
      int btnX = x + thumbSize - btnSize;
      int btnY = y;
      fill(220, 30, 30);
      noStroke();
      rect(btnX, btnY, btnSize, btnSize, 2);
      fill(255);
      textAlign(CENTER, CENTER);
      textSize(10);
      text("X", btnX + btnSize / 2, btnY + btnSize / 2 - 1);
    }

    // Label below
    if (label.equals("Start")) fill(0, 220, 0);
    else fill(220, 140, 0);
    textAlign(CENTER);
    textSize(10);
    text(label, x + thumbSize / 2, y + thumbSize + 12);
  }

  // Draw the dragged thumbnail at mouse position
  if (targetDragActive && targetDragSourceIndex >= 0
      && targetDragSourceIndex < morphSequenceTargets.size()) {
    SavedPattern dragPat = morphSequenceTargets.get(targetDragSourceIndex);
    if (dragPat != null) {
      int dx = mouseX - targetDragMouseOffsetX;
      int dy = mouseY - targetDragMouseOffsetY;
      // Semi-transparent floating thumbnail
      tint(255, 200);
      image(dragPat.thumbnail, dx, dy, thumbSize, thumbSize);
      noTint();
      stroke(80, 180, 255);
      strokeWeight(2);
      noFill();
      rect(dx - 1, dy - 1, thumbSize + 2, thumbSize + 2);
      noStroke();
    }
  }

  // Draw scrollbar if targets overflow
  if (totalCount > maxVisible) {
    int scrollbarY = baseY + thumbSize + 18;
    int scrollbarWidth = visibleCount * (thumbSize + gap);
    drawScrollbar(true, baseX, scrollbarY, scrollbarWidth, 5, totalCount, maxVisible, targetPreviewScrollOffset);
  }

  popStyle();
  textAlign(LEFT, BASELINE);
  textSize(16);
}

void handleFilmstripClick(int mx, int my) {
  if (currentMorphSequence == null) return;
  if (my < filmstripY || my > filmstripY + filmstripThumbSize) return;
  if (mx < filmstripX) return;

  int clickedLocal = (mx - filmstripX) / (filmstripThumbSize + filmstripSpacing);
  int clickedIndex = filmstripScrollOffset + clickedLocal;
  if (clickedIndex >= 0 && clickedIndex < currentMorphSequence.totalFrames()) {
    morphPreviewFrameIndex = clickedIndex;
    applyPattern(currentMorphSequence.frames.get(clickedIndex));
    instructions = "Previewing frame " + (clickedIndex + 1) + " / " + currentMorphSequence.totalFrames();
  }
}

// ============================================================
// ARCHIVED ALGORITHMS (kept for reference)
// ============================================================
// Previous algorithms: SDF Interpolation, Erosion/Dilation, Amoeba Morphing
// These have been replaced by the Tweening algorithm above.
// Uncomment and add back to the dispatcher if needed.
//
// --- SDF Interpolation ---
// Computed signed distance fields for start/end, interpolated, thresholded.
// Problem: cells appear/disappear independently, no spatial coherence.
//
// --- Erosion/Dilation ---
// Eroded start from boundary while dilating end from core.
// Problem: shape disappears then reappears, not a smooth morph.
//
// --- Amoeba Morphing (Optimal Transport) ---
// Simulated grow-toward-target + retract-from-back micro-steps.
// Problem: bridge cells and independent add/remove caused disconnected frames.
// ============================================================
