void setUpCamera() {
  if (!cameraEnabled) {
    return;
  }

  String[] cameras = Capture.list();
  if (cameras.length == 0) {
    println("No cameras available");
    cameraEnabled = false;
    return;
  }

  // Print available cameras/formats
  println("Available camera formats:");
  printArray(cameras);

  // Calculate motor section dimensions
  int motorSectionWidth = getMotorSectionWidth();
  int motorSectionHeight = getMotorSectionHeight();

  // Find camera device index by searching for camera name
  int deviceIndex = -1;
  int preferredWidth = motorSectionWidth;
  int preferredHeight = motorSectionHeight;
  int fps = 30;

  // First, try to find camera with preferred resolution and fps
  for (int i = 0; i < cameras.length; i++) {
    String camInfo = cameras[i];
    if (camInfo.contains(cameraName) &&
      camInfo.contains("size=" + preferredWidth + "x" + preferredHeight) &&
      camInfo.contains("fps=" + fps)) {
      deviceIndex = i;
      println("Found " + cameraName + " with preferred resolution " + preferredWidth + "x" + preferredHeight + " at " + fps + "fps");
      break;
    }
  }

  // Fallback: Find camera by name only (any resolution)
  if (deviceIndex == -1) {
    for (int i = 0; i < cameras.length; i++) {
      if (cameras[i].contains(cameraName)) {
        deviceIndex = i;
        println("Found " + cameraName + " (any resolution)");
        // Try to extract resolution from the camera string
        String camInfo = cameras[i];
        if (camInfo.contains("size=")) {
          String sizePart = camInfo.substring(camInfo.indexOf("size=") + 5);
          sizePart = sizePart.split(",")[0].split(" ")[0];
          if (sizePart.contains("x")) {
            String[] dims = sizePart.split("x");
            try {
              preferredWidth = Integer.parseInt(dims[0]);
              preferredHeight = Integer.parseInt(dims[1]);
              println("Using camera resolution: " + preferredWidth + "x" + preferredHeight);
            }
            catch (Exception e) {
              // Use motor section dimensions
            }
          }
        }
        break;
      }
    }
  }

  // Final fallback: Use first available camera (FaceTime HD)
  if (deviceIndex == -1) {
    println("Could not find " + cameraName + ", using first available camera as fallback");
    deviceIndex = 0;
    // Try to get resolution from first camera
    String firstCam = cameras[0];
    if (firstCam.contains("size=")) {
      String sizePart = firstCam.substring(firstCam.indexOf("size=") + 5);
      sizePart = sizePart.split(",")[0].split(" ")[0];
      if (sizePart.contains("x")) {
        String[] dims = sizePart.split("x");
        try {
          preferredWidth = Integer.parseInt(dims[0]);
          preferredHeight = Integer.parseInt(dims[1]);
        }
        catch (Exception e) {
          // Use motor section dimensions
        }
      }
    }
  }

  // Use the chosen format index directly as the pipeline device-index.
  // On macOS with avfvideosrc, format index and device-index typically align.
  int actualDeviceIndex = max(0, min(deviceIndex, cameras.length - 1));
  println("Using device-index: " + actualDeviceIndex + " (format index " + deviceIndex + ")");
  println("Resolution: " + preferredWidth + "x" + preferredHeight + " at " + fps + "fps");

  // Try to initialize camera with pipeline approach
  boolean initialized = false;

  // Try with preferred resolution first
  cam = tryInitializeCamera(preferredWidth, preferredHeight, actualDeviceIndex, fps);
  if (cam != null && cam.width > 0 && cam.height > 0) {
    println("Camera initialized successfully at " + cam.width + "x" + cam.height);
    initialized = true;
  }

  // Fallback: Try with motor section dimensions
  if (!initialized) {
    cam = tryInitializeCamera(motorSectionWidth, motorSectionHeight, actualDeviceIndex, fps);
    if (cam != null && cam.width > 0 && cam.height > 0) {
      println("Camera initialized with motor section dimensions: " + cam.width + "x" + cam.height);
      initialized = true;
    }
  }

  // Final fallback: Try with default resolution (let camera choose)
  if (!initialized) {
    // Try common resolutions
    int[] commonWidths = {1920, 1280, 640};
    int[] commonHeights = {1080, 720, 480};
    for (int w : commonWidths) {
      for (int h : commonHeights) {
        cam = tryInitializeCamera(w, h, actualDeviceIndex, fps);
        if (cam != null && cam.width > 0 && cam.height > 0) {
          println("Camera initialized at " + cam.width + "x" + cam.height);
          initialized = true;
          break;
        }
      }
      if (initialized) break;
    }
  }

  if (!initialized) {
    println("Failed to initialize camera");
    println("Try:");
    println("  1. Change cameraName to a different camera (e.g., 'FaceTime HD Camera')");
    println("  2. Check if the camera is being used by another application");
    println("  3. Restart the program");
    cameraEnabled = false;
    cam = null;
  } else {
    println("Camera ready: " + cam.width + "x" + cam.height);
  }
}


//========housekeeping setups=============
// Helper function to safely initialize camera using pipeline approach
Capture tryInitializeCamera(int width, int height, int deviceIndex, int fps) {
  try {
    String pipeline = "pipeline:avfvideosrc device-index=" + deviceIndex;
    Capture testCam = new Capture(this, width, height, pipeline, fps);
    testCam.start();
    // Give camera time to initialize
    delay(200);
    return testCam;
  }
  catch (Exception e) {
    println("Failed to initialize camera with device-index=" + deviceIndex + ": " + e.toString());
    return null;
  }
}

// Called by Processing on GStreamer's thread whenever a new frame arrives.
// Reading here prevents frames from piling up in the pipeline buffer,
// which is what causes progressive video lag.
void captureEvent(Capture c) {
  c.read();
  cameraFrameReady = true;
}

// Track if we've successfully read a frame
boolean cameraFrameRead = false;
int cameraReadAttempts = 0;
// Latest camera frame snapshot (copied off the GStreamer thread)
PImage cameraFrame = null;
boolean cameraFrameReady = false;
// Camera overlay transparency (0 = fully transparent, 255 = fully opaque)
int cameraOverlayAlpha = 150;

// Camera crop / calibration (trim & zoom)
boolean cameraCropEnabled = false;
boolean cameraCalibrating = false;
int cameraCalibrationStep = 0; // 0=idle, 1=waiting top-left, 2=waiting bottom-right
float cameraCropX1 = 0;
float cameraCropY1 = 0;
float cameraCropX2 = 0;
float cameraCropY2 = 0;
PVector cameraCalibScreenP1 = null;
PVector cameraCalibScreenP2 = null;
boolean cameraMirrorEnabled = false;

// Particle presence: one entry per motor cell (row-major, same index as magButtons).
boolean[] cameraBallPresent;
// Set false to skip work each frame.
boolean cameraBallDetectEnabled = true;
int cameraBallBrightnessThreshold = 128;
float cameraBallMinFill = 0.045f;
float cameraBallInsetFrac = 0.22f;

void initCameraBallDetectionArrays() {
  cameraBallPresent = new boolean[num_rows * num_motors_per_row];
}

void getCameraRoiForMotorLocal(float lx1, float ly1, float lx2, float ly2, int[] outRect) {
  int W = getMotorSectionWidth();
  int H = getMotorSectionHeight();
  float u1 = constrain(lx1 / W, 0, 1);
  float u2 = constrain(lx2 / W, 0, 1);
  float v1 = constrain(ly1 / H, 0, 1);
  float v2 = constrain(ly2 / H, 0, 1);

  if (cameraMirrorEnabled) {
    float tu1 = u1;
    u1 = 1 - u2;
    u2 = 1 - tu1;
  }

  int cx1, cy1, cx2, cy2;
  if (cameraCropEnabled && !cameraCalibrating && cam != null) {
    int sx1 = constrain(round(cameraCropX1), 0, max(0, cam.width - 1));
    int sy1 = constrain(round(cameraCropY1), 0, max(0, cam.height - 1));
    int sx2 = constrain(round(cameraCropX2), 0, max(0, cam.width));
    int sy2 = constrain(round(cameraCropY2), 0, max(0, cam.height));
    int left = min(sx1, sx2);
    int right = max(sx1, sx2);
    int top = min(sy1, sy2);
    int bottom = max(sy1, sy2);
    if (right <= left) right = min(left + 1, cam.width);
    if (bottom <= top) bottom = min(top + 1, cam.height);
    cx1 = round(left + u1 * (right - left));
    cx2 = round(left + u2 * (right - left));
    cy1 = round(top + v1 * (bottom - top));
    cy2 = round(top + v2 * (bottom - top));
  } else if (cam != null && cam.width > 0 && cam.height > 0) {
    cx1 = round(u1 * cam.width);
    cx2 = round(u2 * cam.width);
    cy1 = round(v1 * cam.height);
    cy2 = round(v2 * cam.height);
  } else {
    outRect[0] = outRect[1] = outRect[2] = outRect[3] = 0;
    return;
  }

  int ix1 = min(cx1, cx2);
  int ix2 = max(cx1, cx2);
  int iy1 = min(cy1, cy2);
  int iy2 = max(cy1, cy2);
  ix1 = constrain(ix1, 0, max(0, cam.width - 1));
  ix2 = constrain(ix2, 0, max(0, cam.width - 1));
  iy1 = constrain(iy1, 0, max(0, cam.height - 1));
  iy2 = constrain(iy2, 0, max(0, cam.height - 1));
  if (ix2 <= ix1) ix2 = min(ix1 + 1, cam.width - 1);
  if (iy2 <= iy1) iy2 = min(iy1 + 1, cam.height - 1);
  outRect[0] = ix1;
  outRect[1] = iy1;
  outRect[2] = ix2;
  outRect[3] = iy2;
}

boolean cameraBallPixelIsDark(int p) {
  int r = (p >> 16) & 0xFF;
  int g = (p >> 8) & 0xFF;
  int b = p & 0xFF;
  int gray = (int)(0.299f * r + 0.587f * g + 0.114f * b);
  return gray < cameraBallBrightnessThreshold;
}

void updateCameraBallDetection() {
  if (!cameraEnabled || cam == null || cameraCalibrating) {
    return;
  }
  if (cam.width <= 0 || cam.height <= 0 || !cameraFrameRead) {
    return;
  }
  if (cameraBallPresent == null || cameraBallPresent.length != num_rows * num_motors_per_row) {
    initCameraBallDetectionArrays();
  }

  cam.loadPixels();
  int[] roi = new int[4];
  float inset = buttonSize * cameraBallInsetFrac;

  for (int i = 0; i < cameraBallPresent.length; i++) {
    int col = i % num_motors_per_row;
    int row = i / num_motors_per_row;
    float lx1 = col * spacingX + inset;
    float ly1 = row * spacingY + inset;
    float lx2 = col * spacingX + buttonSize - inset;
    float ly2 = row * spacingY + buttonSize - inset;
    if (lx2 <= lx1 + 2 || ly2 <= ly1 + 2) {
      cameraBallPresent[i] = false;
      continue;
    }
    getCameraRoiForMotorLocal(lx1, ly1, lx2, ly2, roi);
    int ix1 = roi[0], iy1 = roi[1], ix2 = roi[2], iy2 = roi[3];

    long darkCount = 0;
    long tot = 0;
    for (int y = iy1; y <= iy2; y++) {
      int rowOff = y * cam.width;
      for (int x = ix1; x <= ix2; x++) {
        tot++;
        if (cameraBallPixelIsDark(cam.pixels[rowOff + x])) {
          darkCount++;
        }
      }
    }
    cameraBallPresent[i] = tot > 0 && (float) darkCount / (float) tot >= cameraBallMinFill;
  }
}

// One-shot fill ratio scan. Returns float[] of fill ratios (0.0-1.0) per magnet.
// Does NOT update cameraBallPresent[]. Call only when needed (not every frame).
float[] scanFillRatios() {
  int total = num_rows * num_motors_per_row;
  float[] ratios = new float[total];
  if (!cameraEnabled || cam == null || cam.width <= 0 || cam.height <= 0 || !cameraFrameRead) {
    return ratios;
  }
  cam.loadPixels();
  int[] roi = new int[4];
  float inset = buttonSize * cameraBallInsetFrac;

  for (int i = 0; i < total; i++) {
    int col = i % num_motors_per_row;
    int row = i / num_motors_per_row;
    float lx1 = col * spacingX + inset;
    float ly1 = row * spacingY + inset;
    float lx2 = col * spacingX + buttonSize - inset;
    float ly2 = row * spacingY + buttonSize - inset;
    if (lx2 <= lx1 + 2 || ly2 <= ly1 + 2) {
      ratios[i] = 0;
      continue;
    }
    getCameraRoiForMotorLocal(lx1, ly1, lx2, ly2, roi);
    int ix1 = roi[0], iy1 = roi[1], ix2 = roi[2], iy2 = roi[3];

    long darkCount = 0;
    long tot = 0;
    for (int y = iy1; y <= iy2; y++) {
      int rowOff = y * cam.width;
      for (int x = ix1; x <= ix2; x++) {
        tot++;
        if (cameraBallPixelIsDark(cam.pixels[rowOff + x])) {
          darkCount++;
        }
      }
    }
    ratios[i] = tot > 0 ? (float) darkCount / (float) tot : 0;
  }
  return ratios;
}

/** Print grid to the console (1 = ball, 0 = empty). Press B in the sketch when file list is closed. */
void printCameraBallPresentDebug() {
  if (cameraBallPresent == null) {
    println("cameraBallPresent: null");
    return;
  }
  println("--- cameraBallPresent (row 0 = top, cols left->right); mag index = row * " + num_motors_per_row + " + col ---");
  for (int r = 0; r < num_rows; r++) {
    String line = "";
    for (int c = 0; c < num_motors_per_row; c++) {
      int i = r * num_motors_per_row + c;
      line += cameraBallPresent[i] ? "1" : "0";
      if (c < num_motors_per_row - 1) line += " ";
    }
    println(line);
  }
  print("indices true: ");
  boolean any = false;
  for (int i = 0; i < cameraBallPresent.length; i++) {
    if (cameraBallPresent[i]) {
      if (any) print(", ");
      print(i);
      any = true;
    }
  }
  if (!any) print("(none)");
  println();
}

// ControlP5 callback (Bang) from management panel
void cameraCalibration() {
  if (!cameraEnabled || cam == null) {
    instructions = "camera not available";
    return;
  }
  cameraCalibrating = true;
  cameraCalibrationStep = 1;
  cameraCalibScreenP1 = null;
  cameraCalibScreenP2 = null;
  instructions = "Camera calibration: click TOP-LEFT corner in video";
}

boolean isInsideMotorSection(int x, int y) {
  int motorSectionWidth = getMotorSectionWidth();
  int motorSectionHeight = getMotorSectionHeight();
  return x >= startX && x <= (startX + motorSectionWidth) && y >= startY && y <= (startY + motorSectionHeight);
}

// Called from mousePressed() to capture calibration clicks
void handleCameraCalibrationClick(int x, int y) {
  if (!cameraCalibrating || !cameraEnabled || cam == null) {
    return;
  }
  if (!isInsideMotorSection(x, y)) {
    return;
  }
  if (cam.width <= 0 || cam.height <= 0) {
    return;
  }

  int motorSectionWidth = getMotorSectionWidth();
  int motorSectionHeight = getMotorSectionHeight();

  // During calibration we treat the displayed image as the full camera frame.
  float sx = map(x, startX, startX + motorSectionWidth, 0, cam.width);
  float sy = map(y, startY, startY + motorSectionHeight, 0, cam.height);
  // If the preview is mirrored, map clicks into original camera coordinates.
  if (cameraMirrorEnabled) {
    sx = cam.width - sx;
  }

  if (cameraCalibrationStep == 1) {
    cameraCropX1 = sx;
    cameraCropY1 = sy;
    cameraCalibScreenP1 = new PVector(x, y);
    cameraCalibrationStep = 2;
    instructions = "Camera calibration: click BOTTOM-RIGHT corner in video";
    return;
  }

  if (cameraCalibrationStep == 2) {
    cameraCropX2 = sx;
    cameraCropY2 = sy;
    cameraCalibScreenP2 = new PVector(x, y);

    float x1 = constrain(min(cameraCropX1, cameraCropX2), 0, cam.width);
    float y1 = constrain(min(cameraCropY1, cameraCropY2), 0, cam.height);
    float x2 = constrain(max(cameraCropX1, cameraCropX2), 0, cam.width);
    float y2 = constrain(max(cameraCropY1, cameraCropY2), 0, cam.height);

    // Prevent zero/near-zero crop
    if (abs(x2 - x1) < 10 || abs(y2 - y1) < 10) {
      instructions = "Camera calibration: selection too small, try again";
      cameraCalibrationStep = 1;
      cameraCalibScreenP1 = null;
      cameraCalibScreenP2 = null;
      return;
    }

    cameraCropX1 = x1;
    cameraCropY1 = y1;
    cameraCropX2 = x2;
    cameraCropY2 = y2;

    cameraCropEnabled = true;
    cameraCalibrating = false;
    cameraCalibrationStep = 0;
    saveCameraCalibration();
    instructions = "Camera calibration: done (saved)";
    return;
  }
}

void drawCameraOverlay() {
  if (!cameraEnabled || cam == null) {
    return;
  }

  try {
    // Calculate motor section bounds
    int motorSectionWidth = getMotorSectionWidth();
    int motorSectionHeight = getMotorSectionHeight();

    // Frames are read in captureEvent() on GStreamer's thread so they
    // never pile up in the pipeline buffer. Here we just check if a
    // new frame has arrived since the last draw().
    if (cameraFrameReady) {
      cameraFrameRead = true;
      cameraReadAttempts = 0;
      cameraFrameReady = false;
    } else {
      cameraReadAttempts++;
      if (cameraReadAttempts > 300 && !cameraFrameRead) {
        println("Camera not providing frames, attempting restart...");
        try {
          cam.stop();
          cam.start();
          cameraReadAttempts = 0;
        }
        catch (Exception restartE) {
          println("Failed to restart camera: " + restartE.toString());
        }
      }
    }

    // Draw camera feed as background in the motor section area
    // Note: Some cameras (like Brio) may show "Internal data stream error" warnings
    // in the console, but the camera may still work. This is often a GStreamer warning.
    if (cam.width > 0 && cam.height > 0) {
      // Only draw if we have valid dimensions
      // Mirror happens BEFORE crop/zoom: we flip the draw transform, then apply crop.
      pushMatrix();
      if (cameraMirrorEnabled) {
        translate(startX + motorSectionWidth, startY);
        scale(-1, 1);
      } else {
        translate(startX, startY);
      }

      if (cameraCropEnabled && !cameraCalibrating) {
        // Crop + zoom the selected region into the motor section bounds
        int sx1 = constrain(round(cameraCropX1), 0, max(0, cam.width - 1));
        int sy1 = constrain(round(cameraCropY1), 0, max(0, cam.height - 1));
        int sx2 = constrain(round(cameraCropX2), 0, max(0, cam.width));
        int sy2 = constrain(round(cameraCropY2), 0, max(0, cam.height));
        // Ensure proper ordering and non-zero size
        int left = min(sx1, sx2);
        int right = max(sx1, sx2);
        int top = min(sy1, sy2);
        int bottom = max(sy1, sy2);
        if (right <= left) right = min(left + 1, cam.width);
        if (bottom <= top) bottom = min(top + 1, cam.height);

        pushStyle();
        tint(255, cameraOverlayAlpha);
        image(cam, 0, 0, motorSectionWidth, motorSectionHeight, left, top, right, bottom);
        popStyle();
      } else {
        // Show full frame (also used during calibration)
        pushStyle();
        tint(255, cameraOverlayAlpha);
        image(cam, 0, 0, motorSectionWidth, motorSectionHeight);
        popStyle();
      }
      popMatrix();

      // Draw calibration overlay UI (rectangle + points) on top of the video
      if (cameraCalibrating) {
        pushStyle();
        noFill();
        stroke(255, 0, 0);
        strokeWeight(2);
        if (cameraCalibScreenP1 != null) {
          ellipse(cameraCalibScreenP1.x, cameraCalibScreenP1.y, 10, 10);
        }
        if (cameraCalibScreenP2 != null) {
          ellipse(cameraCalibScreenP2.x, cameraCalibScreenP2.y, 10, 10);
        }
        if (cameraCalibScreenP1 != null && cameraCalibScreenP2 != null) {
          float rx = min(cameraCalibScreenP1.x, cameraCalibScreenP2.x);
          float ry = min(cameraCalibScreenP1.y, cameraCalibScreenP2.y);
          float rw = abs(cameraCalibScreenP2.x - cameraCalibScreenP1.x);
          float rh = abs(cameraCalibScreenP2.y - cameraCalibScreenP1.y);
          rect(rx, ry, rw, rh);
        }
        popStyle();
      }
    } else if (cameraReadAttempts < 10) {
      // Debug: print camera dimensions if they're invalid
      println("Camera dimensions invalid: " + cam.width + "x" + cam.height);
    }
  }
  catch (Exception e) {
    println("Camera read error: " + e.toString());
    // Try to recover by checking if camera is still valid
    try {
      if (cam != null && (cam.width <= 0 || cam.height <= 0)) {
        println("Camera appears to have invalid dimensions, attempting restart...");
        cam.stop();
        cam.start();
      }
    }
    catch (Exception recoverE) {
      println("Failed to recover camera: " + recoverE.toString());
    }
  }
}

// Shared source of truth for camera/motor section dimensions.
int getMotorSectionWidth() {
  return (num_motors_per_row - 1) * spacingX + buttonSize;
}

int getMotorSectionHeight() {
  return (num_rows - 1) * spacingY + buttonSize;
}

String cameraCalibrationFile = usingEM ? "camera_calibration_EM.txt" : "camera_calibration_PM.txt";

void saveCameraCalibration() {
  try {
    String[] lines = {
      cameraCropX1 + "," + cameraCropY1 + "," + cameraCropX2 + "," + cameraCropY2,
      str(cameraMirrorEnabled ? 1 : 0),
      str(cameraOverlayAlpha),
      str(cameraBallBrightnessThreshold),
      str(cameraBallMinFill)
    };
    saveStrings(dataPath(cameraCalibrationFile), lines);
    println("Camera calibration saved");
  }
  catch (Exception e) {
    println("Failed to save camera calibration: " + e.toString());
  }
}

void loadCameraCalibration() {
  try {
    File f = new File(dataPath(cameraCalibrationFile));
    if (!f.exists()) {
      println("No saved camera calibration found");
      return;
    }
    String[] lines = loadStrings(dataPath(cameraCalibrationFile));
    if (lines == null || lines.length < 1) return;

    // Line 0: crop coordinates
    String[] coords = split(lines[0], ',');
    if (coords.length == 4) {
      cameraCropX1 = float(coords[0]);
      cameraCropY1 = float(coords[1]);
      cameraCropX2 = float(coords[2]);
      cameraCropY2 = float(coords[3]);
      cameraCropEnabled = true;
    }

    // Line 1: mirror
    if (lines.length >= 2) {
      cameraMirrorEnabled = int(lines[1]) == 1;
      if (cameraMirrorToggle != null) {
        cameraMirrorToggle.setValue(cameraMirrorEnabled ? 1 : 0);
      }
    }

    // Line 2: overlay alpha
    if (lines.length >= 3) {
      cameraOverlayAlpha = int(lines[2]);
      if (cameraOverlayAlphaSlider != null) {
        cameraOverlayAlphaSlider.setValue(cameraOverlayAlpha);
      }
    }

    // Line 3: brightness threshold
    if (lines.length >= 4) {
      cameraBallBrightnessThreshold = int(lines[3]);
      if (cameraBallBrightnessSlider != null) {
        cameraBallBrightnessSlider.setValue(cameraBallBrightnessThreshold);
      }
    }

    // Line 4: fill threshold
    if (lines.length >= 5) {
      cameraBallMinFill = float(lines[4]);
      if (cameraBallFillSlider != null) {
        cameraBallFillSlider.setValue(cameraBallMinFill * 100);
      }
    }

    println("Camera calibration loaded");
  }
  catch (Exception e) {
    println("Failed to load camera calibration: " + e.toString());
  }
}