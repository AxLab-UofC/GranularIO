// Pattern management for DRAW mode
import java.io.FileWriter;
import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.io.File;

// Pattern data structure
class SavedPattern {
  String name;
  boolean[] pattern; // Array representing which magnets are selected
  PImage thumbnail;
  String filename;

  SavedPattern(String name, boolean[] pattern, String filename) {
    this.name = name;
    this.pattern = new boolean[pattern.length];
    System.arraycopy(pattern, 0, this.pattern, 0, pattern.length);
    this.filename = filename;
    this.thumbnail = createThumbnail();
  }

  // Create a thumbnail image of the pattern
  PImage createThumbnail() {
    int thumbSize = 100;
    PImage thumb = createImage(thumbSize, thumbSize, RGB);
    thumb.loadPixels();

    // Calculate grid dimensions for thumbnail
    int cols = num_motors_per_row;
    int rows = num_rows;
    int cellWidth = thumbSize / cols;
    int cellHeight = thumbSize / rows;

    for (int i = 0; i < thumb.pixels.length; i++) {
      thumb.pixels[i] = color(240); // Light gray background
    }

    // Draw pattern
    for (int i = 0; i < pattern.length; i++) {
      if (pattern[i]) {
        int col = i % cols;
        int row = i / cols;
        int x = col * cellWidth;
        int y = row * cellHeight;

        // Fill the cell with black
        for (int py = y; py < y + cellHeight && py < thumbSize; py++) {
          for (int px = x; px < x + cellWidth && px < thumbSize; px++) {
            if (px >= 0 && py >= 0 && px < thumbSize && py < thumbSize) {
              thumb.pixels[py * thumbSize + px] = color(0);
            }
          }
        }
      }
    }

    thumb.updatePixels();
    return thumb;
  }
}

// Pattern management variables
ArrayList<SavedPattern> savedPatterns = new ArrayList<SavedPattern>();
boolean showThumbnailGrid = false;
int thumbnailGridX = 1400;
int thumbnailGridY = 100;
int thumbnailSize = 80;
int thumbnailSpacing = 15;
int thumbnailsPerRow = 2;
int hoveredThumbnailIndex = -1;
int thumbnailScrollOffset = 0; // number of rows scrolled

// Button callback functions
void savePattern() {
  if (selectedMags.isEmpty()) {
    instructions = "No magnets selected to save";
    return;
  }

  // Create pattern array
  boolean[] pattern = new boolean[magButtons.length];
  for (int i = 0; i < pattern.length; i++) {
    pattern[i] = magButtons[i].getBooleanValue();
  }

  // Generate filename with timestamp
  String timestamp = str(minute()) + "_" + str(second());
  String filename = "pattern_" + timestamp + ".txt";
  String name = "P_" + timestamp;

  // Save to file
  savePatternToFile(pattern, filename, name, true);

  // Add to saved patterns list
  SavedPattern savedPattern = new SavedPattern(name, pattern, filename);
  savedPatterns.add(savedPattern);

  instructions = "Pattern saved: " + name;
  println("Pattern saved: " + name);
}

// Capture one camera frame and append a SavedPattern (same as Draw → save current pattern). Returns null on failure.
SavedPattern saveCurrentPatternFromCamera() {
  if (!cameraEnabled || cam == null) {
    instructions = "Camera not available — pattern not saved";
    return null;
  }

  // Ensure we sample a fresh frame (avoid capturing the same buffered frame twice).
  cameraFrameReady = false;
  int waitStart = millis();
  while (!cameraFrameReady && (millis() - waitStart) < 200) {
    delay(5);
  }
  if (cameraFrameReady) {
    cameraFrameRead = true;
    cameraFrameReady = false;
  }

  updateCameraBallDetection();
  if (cameraBallPresent == null) {
    instructions = "Camera pattern: detection not ready";
    return null;
  }
  boolean[] pattern = new boolean[magButtons.length];
  int n = min(pattern.length, cameraBallPresent.length);
  for (int i = 0; i < n; i++) {
    pattern[i] = cameraBallPresent[i];
  }
  int count = 0;
  for (int i = 0; i < pattern.length; i++) {
    if (pattern[i]) count++;
  }
  if (count == 0) {
    instructions = "No balls detected — pattern not saved";
    return null;
  }
  String timestamp = nf(hour(), 2) + "_" + nf(minute(), 2) + "_" + nf(second(), 2) + "_" + nf(millis() % 1000, 3);
  String filename = "pattern_cam_" + timestamp + ".txt";
  String name = "Cam_" + timestamp;
  savePatternToFile(pattern, filename, name, false);
  SavedPattern savedPattern = new SavedPattern(name, pattern, filename);
  savedPatterns.add(savedPattern);
  instructions = "Camera pattern saved: " + name + " (" + count + " cells)";
  return savedPattern;
}

// ControlP5 callback: one camera frame → new SavedPattern from ball detection (no console grid).
void saveCurrentPattern() {
  saveCurrentPatternFromCamera();
}

// MORPH + Sequence helper: save current magnet grid as a pattern and append it to the current sequence queue.
void morphSaveCurrentToSequence() {
  if (!morphSequenceEnabled) {
    instructions = "Enable sequence first";
    return;
  }
  SavedPattern camPattern = saveCurrentPatternFromCamera();
  if (camPattern == null) {
    // instructions already set by saveCurrentPatternFromCamera()
    return;
  }
  morphSequenceTargets.add(camPattern);
  instructions = "Saved + queued (" + morphSequenceTargets.size() + "): " + camPattern.name;
}

void clearPattern() {
  // Deselect all magnets
  for (int i = 0; i < magButtons.length; i++) {
    magButtons[i].setValue(false);
  }
  selectedMags.clear();
  instructions = "Pattern cleared";
}

void showThumbnails() {
  showThumbnailGrid = !showThumbnailGrid;
  if (showThumbnailGrid) {
    instructions = "Click thumbnail to load pattern";
  } else {
    instructions = "select magnets to draw pattern";
  }
}

// Save pattern to file
void savePatternToFile(boolean[] pattern, String filename, String name, boolean logToConsole) {
  try {
    FileWriter writer = new FileWriter(dataPath(filename));
    writer.write("# Pattern file: " + name + "\n");
    writer.write("# Format: magnet_index:selected\n");

    for (int i = 0; i < pattern.length; i++) {
      writer.write(i + ":" + (pattern[i] ? "1" : "0") + "\n");
    }

    writer.close();
    if (logToConsole) {
      println("Pattern saved to: " + filename);
    }
  }
  catch (IOException e) {
    println("Error saving pattern: " + e.getMessage());
    instructions = "Error saving pattern: " + e.getMessage();
  }
}

// Load pattern from file
void loadPatternFromFile(String filename) {
  try {
    BufferedReader reader = new BufferedReader(new FileReader(dataPath(filename)));
    String line;
    boolean[] pattern = new boolean[magButtons.length];
    String name = filename;

    while ((line = reader.readLine()) != null) {
      // Skip comment lines
      if (line.startsWith("#")) {
        if (line.contains("Pattern file:")) {
          name = line.substring(line.indexOf(":") + 1).trim();
        }
        continue;
      }

      // Parse pattern data
      String[] parts = line.split(":");
      if (parts.length == 2) {
        int index = Integer.parseInt(parts[0]);
        boolean selected = parts[1].equals("1");
        if (index >= 0 && index < pattern.length) {
          pattern[index] = selected;
        }
      }
    }

    reader.close();

    // Apply pattern to magnet buttons
    applyPattern(pattern);

    instructions = "Pattern loaded: " + name;
    println("Pattern loaded: " + name);
  }
  catch (IOException e) {
    println("Error loading pattern: " + e.getMessage());
    instructions = "Error loading pattern: " + e.getMessage();
  }
}

// Apply pattern to magnet buttons
void applyPattern(boolean[] pattern) {
  // Clear current selection
  selectedMags.clear();

  // Apply pattern
  for (int i = 0; i < pattern.length && i < magButtons.length; i++) {
    magButtons[i].setValue(pattern[i]);
    if (pattern[i]) {
      addToSelectedMags(i);
    }
  }
  instructions = "Pattern applied, " + selectedMags.size() + " magnets selected";
  println("Pattern applied, " + selectedMags.size() + " magnets selected");
}

// Load all saved patterns on startup
void loadAllSavedPatterns() {
  File dataDir = new File(dataPath(""));
  File[] files = dataDir.listFiles();

  if (files != null) {
    for (File file : files) {
      if (file.getName().startsWith("pattern_") && file.getName().endsWith(".txt")) {
        try {
          BufferedReader reader = new BufferedReader(new FileReader(file));
          String line;
          boolean[] pattern = new boolean[magButtons.length];
          String name = file.getName();

          while ((line = reader.readLine()) != null) {
            if (line.startsWith("#")) {
              if (line.contains("Pattern file:")) {
                name = line.substring(line.indexOf(":") + 1).trim();
              }
              continue;
            }

            String[] parts = line.split(":");
            if (parts.length == 2) {
              int index = Integer.parseInt(parts[0]);
              boolean selected = parts[1].equals("1");
              if (index >= 0 && index < pattern.length) {
                pattern[index] = selected;
              }
            }
          }

          reader.close();

          SavedPattern savedPattern = new SavedPattern(name, pattern, file.getName());
          savedPatterns.add(savedPattern);
        }
        catch (IOException e) {
          println("Error loading pattern file: " + file.getName() + " - " + e.getMessage());
        }
      }
    }
  }

  println("Loaded " + savedPatterns.size() + " saved patterns");
}

// Draw thumbnail grid
void drawThumbnailGrid() {
  if (!showThumbnailGrid) return;

  int totalRows = (int)ceil((float)savedPatterns.size() / thumbnailsPerRow);
  int maxVisibleHeight = height - thumbnailGridY - 20;
  int rowHeight = thumbnailSize + thumbnailSpacing + 5; // +5 for name text
  int maxVisibleRows = maxVisibleHeight / rowHeight;
  if (maxVisibleRows < 1) maxVisibleRows = 1;

  // Clamp scroll offset
  int maxScroll = max(0, totalRows - maxVisibleRows);
  thumbnailScrollOffset = constrain(thumbnailScrollOffset, 0, maxScroll);

  int visibleRows = min(totalRows, maxVisibleRows);
  int panelWidth = thumbnailsPerRow * (thumbnailSize + thumbnailSpacing);
  int panelHeight = visibleRows * rowHeight + 10;

  // Draw background
  fill(255, 255, 255, 200);
  stroke(0);
  strokeWeight(2);
  rect(thumbnailGridX - 10, thumbnailGridY - 10, panelWidth, panelHeight);

  // Draw vertical scrollbar on right edge of panel
  drawScrollbar(false, thumbnailGridX + panelWidth - 2, thumbnailGridY - 5,
                panelHeight - 5, 8, totalRows, maxVisibleRows, thumbnailScrollOffset);

  // Draw only visible thumbnails
  int startIndex = thumbnailScrollOffset * thumbnailsPerRow;
  int endIndex = min(savedPatterns.size(), startIndex + maxVisibleRows * thumbnailsPerRow);

  for (int i = startIndex; i < endIndex; i++) {
    SavedPattern pattern = savedPatterns.get(i);
    int col = i % thumbnailsPerRow;
    int visibleRow = i / thumbnailsPerRow - thumbnailScrollOffset;
    int x = thumbnailGridX + col * (thumbnailSize + thumbnailSpacing);
    int y = thumbnailGridY + visibleRow * rowHeight;

    // Draw thumbnail
    image(pattern.thumbnail, x, y, thumbnailSize, thumbnailSize);

    // Draw border
    stroke(0);
    strokeWeight(1);
    noFill();
    rect(x, y, thumbnailSize, thumbnailSize);

    // Draw pattern name
    fill(0);
    textAlign(CENTER);
    textSize(14);
    text(pattern.name, x + thumbnailSize/2, y + thumbnailSize + 15);

    // Draw red X delete button on hover
    if (i == hoveredThumbnailIndex) {
      int btnX = x + thumbnailSize - 16;
      int btnY = y + 2;
      int btnSize = 16;
      fill(220, 30, 30);
      noStroke();
      rect(btnX, btnY, btnSize, btnSize, 3);
      fill(255);
      textAlign(CENTER, CENTER);
      textSize(12);
      text("X", btnX + btnSize / 2, btnY + btnSize / 2 - 1);
    }
  }

  textAlign(LEFT, BASELINE); // Reset text alignment (including vertical)
  textSize(16);              // Reset text size to default
}

// Update hover state for thumbnails
void updateThumbnailHover(int mx, int my) {
  if (!showThumbnailGrid) {
    hoveredThumbnailIndex = -1;
    return;
  }

  int rowHeight = thumbnailSize + thumbnailSpacing + 5;
  int panelWidth = thumbnailsPerRow * (thumbnailSize + thumbnailSpacing);
  int maxVisibleHeight = height - thumbnailGridY - 20;
  int maxVisibleRows = maxVisibleHeight / rowHeight;
  if (maxVisibleRows < 1) maxVisibleRows = 1;
  int visibleRows = min((int)ceil((float)savedPatterns.size() / thumbnailsPerRow), maxVisibleRows);
  int panelHeight = visibleRows * rowHeight + 10;

  if (mx >= thumbnailGridX - 10 && mx <= thumbnailGridX + panelWidth &&
      my >= thumbnailGridY && my <= thumbnailGridY + panelHeight) {
    int col = (mx - thumbnailGridX) / (thumbnailSize + thumbnailSpacing);
    int visibleRow = (my - thumbnailGridY) / rowHeight;
    int index = (visibleRow + thumbnailScrollOffset) * thumbnailsPerRow + col;

    if (col >= 0 && col < thumbnailsPerRow && index >= 0 && index < savedPatterns.size()) {
      hoveredThumbnailIndex = index;
    } else {
      hoveredThumbnailIndex = -1;
    }
  } else {
    hoveredThumbnailIndex = -1;
  }
}

// Handle delete click on thumbnail X button. Returns true if a delete occurred.
boolean handleThumbnailDeleteClick(int mx, int my) {
  if (!showThumbnailGrid || hoveredThumbnailIndex < 0) return false;

  int rowHeight = thumbnailSize + thumbnailSpacing + 5;
  int visibleRow = hoveredThumbnailIndex / thumbnailsPerRow - thumbnailScrollOffset;
  int col = hoveredThumbnailIndex % thumbnailsPerRow;
  int x = thumbnailGridX + col * (thumbnailSize + thumbnailSpacing);
  int y = thumbnailGridY + visibleRow * rowHeight;

  int btnX = x + thumbnailSize - 16;
  int btnY = y + 2;
  int btnSize = 16;

  if (mx >= btnX && mx <= btnX + btnSize && my >= btnY && my <= btnY + btnSize) {
    SavedPattern pattern = savedPatterns.get(hoveredThumbnailIndex);
    // Delete file from disk
    File f = new File(dataPath(pattern.filename));
    if (f.exists()) {
      f.delete();
      println("Deleted pattern file: " + pattern.filename);
    }
    savedPatterns.remove(hoveredThumbnailIndex);
    hoveredThumbnailIndex = -1;
    instructions = "Pattern deleted";
    return true;
  }
  return false;
}

// Handle mouse wheel scroll for thumbnails
void handleThumbnailScroll(float scrollAmount) {
  thumbnailScrollOffset += (int) scrollAmount;
  int totalRows = (int)ceil((float)savedPatterns.size() / thumbnailsPerRow);
  int maxVisibleHeight = height - thumbnailGridY - 20;
  int rowHeight = thumbnailSize + thumbnailSpacing + 5;
  int maxVisibleRows = maxVisibleHeight / rowHeight;
  if (maxVisibleRows < 1) maxVisibleRows = 1;
  int maxScroll = max(0, totalRows - maxVisibleRows);
  thumbnailScrollOffset = constrain(thumbnailScrollOffset, 0, maxScroll);
}

// Handle mouse clicks on thumbnails
void handleThumbnailClick(int mouseX, int mouseY) {
  if (!showThumbnailGrid) return;

  // Check if click is within thumbnail grid bounds
  int rowHeight = thumbnailSize + thumbnailSpacing + 5;
  int gridWidth = thumbnailsPerRow * (thumbnailSize + thumbnailSpacing);
  int maxVisibleHeight = height - thumbnailGridY - 20;
  int maxVisibleRows = maxVisibleHeight / rowHeight;
  if (maxVisibleRows < 1) maxVisibleRows = 1;
  int visibleRows = min((int)ceil((float)savedPatterns.size() / thumbnailsPerRow), maxVisibleRows);
  int gridHeight = visibleRows * rowHeight + 10;

  if (mouseX >= thumbnailGridX && mouseX <= thumbnailGridX + gridWidth &&
    mouseY >= thumbnailGridY && mouseY <= thumbnailGridY + gridHeight) {
    int col = (mouseX - thumbnailGridX) / (thumbnailSize + thumbnailSpacing);
    int visibleRow = (mouseY - thumbnailGridY) / rowHeight;
    int index = (visibleRow + thumbnailScrollOffset) * thumbnailsPerRow + col;

    if (index >= 0 && index < savedPatterns.size()) {
      SavedPattern pattern = savedPatterns.get(index);

      // MORPH + Sequence: queue clicked targets and execute later.
      if (mode == ActionMode.MORPH && morphSequenceEnabled) {
        morphSequenceTargets.add(pattern);
        instructions = "Queued for sequence (" + morphSequenceTargets.size() + "): " + pattern.name;
        return;
      }

      // MORPH + Automate: one click — camera snapshot as start, clicked thumbnail as end, then generate + animate
      if (mode == ActionMode.MORPH && morphAutomateEnabled) {
        stopMorph();
        SavedPattern startSnap = saveCurrentPatternFromCamera();
        if (startSnap == null) {
          return;
        }
        morphStartPattern = startSnap;
        morphEndPattern = pattern;
        morphSelectionState = 2;
        applyPattern(startSnap.pattern);
        generateMorph();
        animateMorph();
        instructions = "Auto transition: " + startSnap.name + " → " + pattern.name;
        return;
      }

      applyPattern(pattern.pattern);
      instructions = "Pattern loaded: " + pattern.name;
      println("Pattern loaded: " + pattern.name);
    }

    // when in SHAPE mode, automatically shake the pattern after loading
    if (mode == ActionMode.SHAPE) {
      for (int i = 0; i < sliders.length; i++) {
        if (selectedMags.contains(i)) {
          sliders[i].setValue(defaultEndRange);
        } else {
          sliders[i].setValue(0);
        }
      }
      startShake();
    }

    // When in MORPH mode, handle two-click start/end pattern selection
    // (skipped when Automate or Sequence is on)
    if (mode == ActionMode.MORPH && !morphAutomateEnabled && !morphSequenceEnabled && index >= 0 && index < savedPatterns.size()) {
      SavedPattern pattern = savedPatterns.get(index);
      if (morphSelectionState == 0) {
        morphStartPattern = pattern;
        morphSelectionState = 1;
        instructions = "Start: " + pattern.name + " -- Now select END pattern";
      } else if (morphSelectionState == 1) {
        morphEndPattern = pattern;
        morphSelectionState = 2;
        applyPattern(pattern.pattern);
        instructions = "Start: " + morphStartPattern.name + " | End: " + pattern.name + " -- Click Generate";
      }
    }
  }
}
