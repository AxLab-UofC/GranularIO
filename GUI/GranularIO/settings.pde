Accordion settingsAccordion;
float defaultMoveSpeed = 2.5;
int moveSpeedStart = 1;
int moveSpeedEnd = 20;
Toggle cameraMirrorToggle;
Slider cameraOverlayAlphaSlider;
Slider cameraBallBrightnessSlider;
Slider cameraBallFillSlider;
Slider demoActiveSpeedSlider;
Slider demoIdleSpeedSlider;
Slider demoActivePauseSlider;
Slider demoIdlePauseSlider;
Toggle moveAvoidObstaclesToggle;
boolean moveAvoidObstaclesEnabled = false;
Toggle moveStepByStepToggle;
boolean moveStepByStepEnabled = false;
float pmMoveSpeedMM = 15;

float readMoveSpeedMM() {
  return pmMoveSpeedMM;
}

// Read start point intensity from text field
int readStartPointIntensity() {
  try {
    Textfield tf = (Textfield) cp5.getController("startPointIntensity");
    if (tf != null) {
      String text = tf.getText().trim();
      if (text.length() > 0) {
        int val = Integer.parseInt(text);
        if (val >= 0) return val;
        instructions = "Start intensity must be >= 0";
      } else {
        instructions = "Start intensity field is empty";
      }
    }
  } catch (Exception e) {
    instructions = "Invalid start intensity value";
  }
  return (int)(defaultEndRange * 0.6); // fallback default
}

Toggle morphAutomateToggle;
Bang morphExecuteButton;
Toggle morphSequenceToggle;
Bang morphSaveToSequenceButton;

void openSettingsAccordionItem(Accordion accordion, int idx) {
  if (accordion == null || idx < 0) {
    return;
  }
  try {
    java.lang.reflect.Method openMethod =
      accordion.getClass().getMethod("open", int[].class);
    openMethod.invoke(accordion, new Object[] { new int[] { idx } });
  }
  catch (Exception e) {
    println("Failed to open accordion item " + idx + ": " + e.getMessage());
  }
}
// Mapping from ActionMode to its corresponding settings setup function
Group getSettingsGroup(ActionMode mode) {
  switch (mode) {
  case FADE:
    return setUpFadeSettings();
  case VIBRATE:
    return setUpVibrateSettings();
  case MOVE:
    return setUpMoveSettings();
  case SPLIT:
    return setUpSplitSettings();
  case LOOP:
    return setUpLoopSettings();
  case MERGE:
    return setUpMergeSettings();
  case ROTATE:
    return setUpRotateSettings();
  case CONSTANT:
    return setUpConstantSettings();
  case DRAW:
    return setUpDrawSettings();
  case SHAPE:
    return setUpSHAPESettings();
  case MORPH:
    return setUpMORPHSettings();
  default:
    return null; // No settings for MANUAL, TOGGLE
  }
}

void setUpSettings() {
  // Build settings accordion dynamically using ActionMode enum ids
  // Only include modes that have settings panels (exclude MANUAL and TOGGLE)
  settingsAccordion = cp5.addAccordion("settings")
    .setPosition(1150, 50)
    .setWidth(200);


  if (usingEM) {
    defaultMoveSpeed = 20;
    moveSpeedStart = 5;
    moveSpeedEnd = 50;
  }
  // Add settings groups for modes that have them, in order of their enum ids
  for (ActionMode mode : ActionMode.values()) {
    Group settingsGroup = getSettingsGroup(mode);
    if (settingsGroup != null) {
      settingsAccordion.addItem(settingsGroup);
    }
  }

  // Add camera controls into the settings accordion
  settingsAccordion.addItem(setUpCameraSettings());
  // Add demonstration mode controls into the settings accordion
  settingsAccordion.addItem(setUpDemoSettings());
  settingsAccordion.setCollapseMode(Accordion.SINGLE);

  //resetSliders(); //set them all to 0
  modeButtons.activate(0);
}

Group setUpCameraSettings() {
  Group cameraGroup = cp5.addGroup("cameraSettings")
    .setBackgroundColor(color(0, 64))
    .setBackgroundHeight(195)
    ;

  cp5.addBang("cameraCalibration")
    .setPosition(10, 10)
    .setSize(170, 35)
    .setTriggerEvent(Bang.RELEASE)
    .setLabel("camera calibrate")
    .moveTo(cameraGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    ;

  cameraMirrorToggle = cp5.addToggle("cameraMirrorToggle")
    .setPosition(10, 55)
    .setSize(20, 20)
    .setLabel("mirror")
    .setValue(cameraMirrorEnabled ? 1 : 0)
    .moveTo(cameraGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    .addCallback(cursorCB)
    .addListener(new ControlListener() {
    public void controlEvent(ControlEvent theEvent) {
      cameraMirrorEnabled = cameraMirrorToggle.getBooleanValue();
      // If the crop was calibrated in the other orientation, user may need to recalibrate.
      if (cameraCropEnabled && !cameraCalibrating) {
        instructions = "Mirror toggled. If crop looks wrong, recalibrate camera.";
        saveCameraCalibration();
      }
    }
  }
  );

  cameraOverlayAlphaSlider = cp5.addSlider("cameraOverlayAlphaSlider")
    .setPosition(10, 85)
    .setSize(170, 20)
    .setRange(0, 255)
    .setValue(cameraOverlayAlpha)
    .setLabel("overlay alpha")
    .moveTo(cameraGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    .addCallback(cursorCB)
    .addListener(new ControlListener() {
    public void controlEvent(ControlEvent theEvent) {
      cameraOverlayAlpha = round(cameraOverlayAlphaSlider.getValue());
      if (cameraCropEnabled) {
        saveCameraCalibration();
      }
    }
  }
  );

  cameraBallBrightnessSlider = cp5.addSlider("cameraBallBrightnessSlider")
    .setPosition(10, 115)
    .setSize(170, 20)
    .setRange(0, 255)
    .setValue(cameraBallBrightnessThreshold)
    .setLabel("dark threshold")
    .moveTo(cameraGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    .addCallback(cursorCB)
    .addListener(new ControlListener() {
    public void controlEvent(ControlEvent theEvent) {
      cameraBallBrightnessThreshold = round(cameraBallBrightnessSlider.getValue());
      saveCameraCalibration();
    }
  }
  );

  cameraBallFillSlider = cp5.addSlider("cameraBallFillSlider")
    .setPosition(10, 145)
    .setSize(170, 20)
    .setRange(0, 50)
    .setValue(cameraBallMinFill * 100)
    .setLabel("fill threshold %")
    .moveTo(cameraGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    .addCallback(cursorCB)
    .addListener(new ControlListener() {
    public void controlEvent(ControlEvent theEvent) {
      cameraBallMinFill = cameraBallFillSlider.getValue() / 100.0f;
      saveCameraCalibration();
    }
  }
  );

  return cameraGroup;
}

Group setUpDemoSettings() {
  Group demoGroup = cp5.addGroup("demoSettings")
    .setBackgroundColor(color(0, 64))
    .setBackgroundHeight(165)
    ;

  demoActiveSpeedSlider = cp5.addSlider("demoActiveSpeedSlider")
    .setPosition(10, 10)
    .setSize(170, 20)
    .setRange(0.1, 3.0)
    .setValue(demoActiveSpeed)
    .setLabel("active speed")
    .moveTo(demoGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    .addCallback(cursorCB)
    .addListener(new ControlListener() {
    public void controlEvent(ControlEvent theEvent) {
      demoActiveSpeed = demoActiveSpeedSlider.getValue();
    }
  }
  );

  demoIdleSpeedSlider = cp5.addSlider("demoIdleSpeedSlider")
    .setPosition(10, 50)
    .setSize(170, 20)
    .setRange(0.1, 3.0)
    .setValue(demoIdleSpeed)
    .setLabel("idle speed")
    .moveTo(demoGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    .addCallback(cursorCB)
    .addListener(new ControlListener() {
    public void controlEvent(ControlEvent theEvent) {
      demoIdleSpeed = demoIdleSpeedSlider.getValue();
    }
  }
  );

  demoActivePauseSlider = cp5.addSlider("demoActivePauseSlider")
    .setPosition(10, 90)
    .setSize(170, 20)
    .setRange(0, 60)
    .setValue(demoActivePauseSec)
    .setLabel("active pause (s)")
    .moveTo(demoGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    .addCallback(cursorCB)
    .addListener(new ControlListener() {
    public void controlEvent(ControlEvent theEvent) {
      demoActivePauseSec = round(demoActivePauseSlider.getValue());
    }
  }
  );

  demoIdlePauseSlider = cp5.addSlider("demoIdlePauseSlider")
    .setPosition(10, 130)
    .setSize(170, 20)
    .setRange(0, 300)
    .setValue(demoIdlePauseSec)
    .setLabel("idle pause (s)")
    .moveTo(demoGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    .addCallback(cursorCB)
    .addListener(new ControlListener() {
    public void controlEvent(ControlEvent theEvent) {
      demoIdlePauseSec = round(demoIdlePauseSlider.getValue());
    }
  }
  );

  return demoGroup;
}

Group setUpConstantSettings() {

  Group constantGroup = cp5.addGroup("constantSettings")
    .setBackgroundColor(color(0, 64))
    .setBackgroundHeight(40)
    ;
  cp5.addSlider("constantIntensity")
    .setPosition(10, 10)
    .setSize(100, 20)
    .setRange(defaultStartRange, defaultEndRange)
    .setValue(0)
    .moveTo(constantGroup)
    ;
  return constantGroup;
}

Group setUpLoopSettings() {
  Group loopGroup = cp5.addGroup("loopSettings")
    .setBackgroundColor(color(0, 64))
    .setBackgroundHeight(140)
    ;

  cp5.addSlider("loopDelay")
    .setPosition(10, 10)
    .setSize(100, 20)
    .setRange(10, 3000)
    .setLabel("delay")
    .setValue(1000)
    .moveTo(loopGroup)
    ;
  cp5.addSlider("loopDirection")
    .setPosition(10, 40)
    .setSize(100, 20)
    .setRange(-1, 1)
    .setValue(1)
    .setLabel("ccw/cw")
    .setNumberOfTickMarks(2)
    .snapToTickMarks(true)
    .showTickMarks(false)
    .moveTo(loopGroup)
    ;
  cp5.addSlider("loopHopSpeed")
    .setPosition(10, 70)
    .setSize(100, 20)
    .setRange(10, 200)
    .setLabel("hop speed")
    .setValue(80)
    .moveTo(loopGroup)
    ;

  cp5.addSlider("loopHopDelay")
    .setPosition(10, 100)
    .setSize(100, 20)
    .setRange(5, 50)
    .setLabel("hop delay")
    .setValue(10)
    .moveTo(loopGroup)
    ;
  cp5.addBang("sendLoopSettings")
    .setPosition(160, 100)
    .setSize(20, 20)
    .moveTo(loopGroup)
    .setColorForeground(greenDark)
    .setColorActive(greenLite)
    .setLabel("done")
    ;
  cp5.addBang("stopLoop")
    .setPosition(160, 10)
    .setSize(20, 20)
    .moveTo(loopGroup)
    .setColorForeground(redDark)
    .setColorActive(redLite)
    .setLabel("stop")
    ;

  return loopGroup;
}

Group setUpVibrateSettings() {
  Group vibrateGroup = cp5.addGroup("vibrateSettings")
    .setBackgroundColor(color(0, 64))
    .setBackgroundHeight(30)
    ;
  cp5.addSlider("vibrateIntensity")
    .setPosition(10, 10)
    .setSize(100, 20)
    .setRange(0, defaultEndRange)
    .setValue(50)
    .setLabel("intensity")
    .moveTo(vibrateGroup)
    ;
  // Frequency in Hz. The magnet toggles +/-intensity every (500 / Hz) ms,
  // so one full oscillation cycle takes 2 * delay = 1000 / Hz ms.
  // Range 0.5-250 Hz mirrors the old 1000-2 ms delay range.
  cp5.addSlider("vibrateHz")
    .setPosition(10, 40)
    .setSize(100, 20)
    .setRange(0.5, 500)
    .setNumberOfTickMarks(1000) // 0.5 Hz steps across the 0.5-500 Hz range (999 intervals)
    .snapToTickMarks(true)
    .setValue(50)
    .setLabel("HZ")
    .moveTo(vibrateGroup)
    ;

  return vibrateGroup;
}

Group setUpFadeSettings() {
  //int skips, int delay_amt, int starting_val, int ending_val
  Group fadeGroup = cp5.addGroup("fadeSettings")
    .setBackgroundColor(color(0, 64))
    .setBackgroundHeight(140)
    ;
  cp5.addSlider("fadeStart")
    .setPosition(10, 10)
    .setSize(100, 20)
    .setRange(defaultStartRange, defaultEndRange)
    .setValue(maxIntensity)
    .setLabel("starting value")
    .moveTo(fadeGroup)
    ;
  cp5.addSlider("fadeEnd")
    .setPosition(10, 40)
    .setSize(100, 20)
    .setRange(defaultStartRange, defaultEndRange)
    .setValue(0)
    .setLabel("ending value")

    .moveTo(fadeGroup)
    ;
  cp5.addSlider("fadeSpeed")
    .setPosition(10, 70)
    .setSize(100, 20)
    .setRange(0, 50)
    .setValue(5)
    .setLabel("speed")

    .moveTo(fadeGroup)
    ;
  cp5.addSlider("fadeDelay")
    .setPosition(10, 100)
    .setSize(100, 20)
    .setRange(0, 200)
    .setValue(10)
    .setLabel("delay")

    .moveTo(fadeGroup)
    ;
  return fadeGroup;
}
Group setUpMoveSettings() {
  Group moveGroup = cp5.addGroup("moveSettings")
    .setBackgroundColor(color(0, 64))
    .setBackgroundHeight(usingEM ? 110 : 170)
    ;

  // Speed slider — EM shows mm/s (25.4mm spacing), PM has its own slider
  Slider moveSpeedSlider = cp5.addSlider("moveSpeed")
    .setPosition(10, 10)
    .setSize(100, 20)
    .moveTo(moveGroup)
    ;

  if (usingEM) {
    moveSpeedSlider
      .setRange(5, 250)
      .setLabel("speed (mm/s)")
      .setValue(100)
      .setNumberOfTickMarks(246)
      .snapToTickMarks(true)
      .showTickMarks(false)
      ;
  } else {
    moveSpeedSlider
      .setRange(moveSpeedStart, moveSpeedEnd)
      .setLabel("speed")
      .setValue(defaultMoveSpeed)
      ;
    moveSpeedSlider.hide();
    // PM mode: speed in mm/s (pixel spacing = 15mm)
    cp5.addSlider("moveSpeedMM")
      .setPosition(10, 10)
      .setSize(100, 20)
      .setRange(5, 100)
      .setLabel("speed (mm/s)")
      .setValue(pmMoveSpeedMM)
      .setNumberOfTickMarks(96)
      .snapToTickMarks(true)
      .showTickMarks(false)
      .moveTo(moveGroup)
      .addListener(new ControlListener() {
      public void controlEvent(ControlEvent theEvent) {
        pmMoveSpeedMM = theEvent.getValue();
      }
    });
  }

  cp5.addSlider("moveIntensity")
    .setPosition(10, 40)
    .setSize(100, 20)
    .setRange(defaultStartRange, defaultEndRange)
    .setLabel("intensity")
    .setValue(maxIntensity)
    .moveTo(moveGroup)
    ;

  if (!usingEM) {
    // PM mode: delay before retraction begins (setup time for all magnets to raise)
    cp5.addSlider("moveSetupDelay")
      .setPosition(10, 70)
      .setSize(100, 20)
      .setRange(100, 5000)
      .setLabel("setup delay (ms)")
      .setValue(1700)
      .moveTo(moveGroup)
      ;
  }
  int toggleY = usingEM ? 70 : 100;
  moveAvoidObstaclesToggle = cp5.addToggle("moveAvoidObstaclesToggle")
    .setPosition(10, toggleY)
    .setSize(20, 20)
    .setLabel("avoid obstacles")
    .setValue(moveAvoidObstaclesEnabled ? 1 : 0)
    .moveTo(moveGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    .addCallback(cursorCB)
    .addListener(new ControlListener() {
    public void controlEvent(ControlEvent theEvent) {
      moveAvoidObstaclesEnabled = moveAvoidObstaclesToggle.getBooleanValue();
    }
  }
  );

  if (!usingEM) {
    moveStepByStepToggle = cp5.addToggle("moveStepByStepToggle")
      .setPosition(10, 130)
      .setSize(20, 20)
      .setLabel("step-by-step")
      .setValue(moveStepByStepEnabled ? 1 : 0)
      .moveTo(moveGroup)
      .setColorForeground(blueDark)
      .setColorActive(blueLite)
      .addCallback(cursorCB)
      .addListener(new ControlListener() {
      public void controlEvent(ControlEvent theEvent) {
        moveStepByStepEnabled = moveStepByStepToggle.getBooleanValue();
        if (moveStepByStepEnabled) {
          cp5.getController("moveSetupDelay").hide();
        } else {
          cp5.getController("moveSetupDelay").show();
        }
      }
    }
    );
  }

  return moveGroup;
}


Group setUpSplitSettings() {
  Group splitGroup = cp5.addGroup("splitSettings")
    .setBackgroundColor(color(0, 64))
    .setBackgroundHeight(140)
    ;

  cp5.addSlider("splitDuration")
    .setPosition(10, 10)
    .setSize(100, 20)
    .setRange(800, 3000)
    .setLabel("time")
    .setValue(1200)
    .moveTo(splitGroup)
    ;
  cp5.addSlider("splitFrequency")
    .setPosition(10, 40)
    .setSize(100, 20)
    .setRange(50, 500)
    .setLabel("frequency")
    .setValue(300)
    .moveTo(splitGroup)
    ;
  Textfield spiField = cp5.addTextfield("startPointIntensity")
    .setPosition(10, 70)
    .setSize(100, 20)
    .setLabel("start intensity")
    .setInputFilter(ControlP5.INTEGER)
    .setAutoClear(false)
    .setColor(color(255))
    .setColorBackground(color(40, 40, 60))
    .setColorForeground(color(80, 80, 120))
    .moveTo(splitGroup)
    ;
  spiField.setText(str((int)(defaultEndRange * 0.6)));
  spiField.getCaptionLabel().align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER).setPaddingX(5);
  cp5.addSlider("finalPointIntensity")
    .setPosition(10, 100)
    .setSize(100, 20)
    .setRange(defaultStartRange, defaultEndRange)
    .setLabel("final intensity")
    .setValue(defaultEndRange*0.8)
    .moveTo(splitGroup)
    ;

  return splitGroup;
}

Group setUpMergeSettings() {
  Group mergeGroup = cp5.addGroup("mergeSettings")
    .setBackgroundColor(color(0, 40))
    .setBackgroundHeight(40)
    ;
  cp5.addSlider("mergeSpeed")
    .setPosition(10, 10)
    .setSize(100, 20)
    .setRange(moveSpeedStart, moveSpeedEnd)
    .setLabel("speed")
    .setValue(defaultMoveSpeed)
    .moveTo(mergeGroup)
    ;
  return mergeGroup;
}

Group setUpRotateSettings() {
  Group rotateGroup = cp5.addGroup("rotateSettings")
    .setBackgroundColor(color(0, 40))
    .setBackgroundHeight(40)
    ;
  cp5.addSlider("rotateSpeed")
    .setPosition(10, 10)
    .setSize(100, 20)
    .setRange(1, 50)
    .setLabel("speed")
    .setValue(3)
    .moveTo(rotateGroup)
    ;
  return rotateGroup;
}

Group setUpDrawSettings() {
  Group drawGroup = cp5.addGroup("drawSettings")
    .setBackgroundColor(color(0, 64))
    .setBackgroundHeight(120)
    ;

  cp5.addBang("savePattern")
    .setPosition(10, 10)
    .setSize(80, 30)
    .setLabel("Save Pattern")
    .moveTo(drawGroup)
    .setColorForeground(greenDark)
    .setColorActive(greenLite)
    ;

  cp5.addBang("clearPattern")
    .setPosition(100, 10)
    .setSize(80, 30)
    .setLabel("Clear")
    .moveTo(drawGroup)
    .setColorForeground(redDark)
    .setColorActive(redLite)
    ;

  cp5.addBang("showThumbnails")
    .setPosition(10, 50)
    .setSize(80, 30)
    .setLabel("Load Pattern")
    .moveTo(drawGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    ;

  cp5.addBang("saveCurrentPattern")
    .setPosition(100, 50)
    .setSize(80, 30)
    .setLabel("save current pattern")
    .moveTo(drawGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    ;

  return drawGroup;
}

Group setUpSHAPESettings() {
  Group SHAPEGroup = cp5.addGroup("SHAPESettings")
    .setBackgroundColor(color(0, 64))
    .setBackgroundHeight(260)
    .setLabel("SHAKE SETTINGS")
    ;

  cp5.addSlider("shakeIntensity")
    .setPosition(10, 10)
    .setSize(100, 20)
    .setRange(defaultStartRange, defaultEndRange)
    .setLabel("high intensity")
    .setValue(defaultEndRange)
    .moveTo(SHAPEGroup)
    ;

  cp5.addSlider("shakeIntensityLow")
    .setPosition(10, 40)
    .setSize(100, 20)
    .setRange(defaultStartRange, defaultEndRange)
    .setLabel("low intensity")
    .setValue((int)(140.0/200.0 * defaultEndRange))
    .moveTo(SHAPEGroup)
    ;

  cp5.addSlider("shakeDuration")
    .setPosition(10, 70)
    .setSize(100, 20)
    .setRange(100, 2000)
    .setLabel("phase duration (ms)")
    .setValue(500)
    .moveTo(SHAPEGroup)
    ;

  cp5.addSlider("shakeCycles")
    .setPosition(10, 100)
    .setSize(100, 20)
    .setRange(1, 5)
    .setLabel("shake cycles")
    .setValue(2)
    .setNumberOfTickMarks(5)
    .snapToTickMarks(true)
    .showTickMarks(false)
    .moveTo(SHAPEGroup)
    ;

  cp5.addSlider("shakeFinalIntensity")
    .setPosition(10, 130)
    .setSize(100, 20)
    .setRange(defaultStartRange, defaultEndRange)
    .setLabel("final intensity")
    .setValue(defaultEndRange)
    .moveTo(SHAPEGroup)
    ;

  cp5.addToggle("shakeUseGlobal")
    .setPosition(10, 160)
    .setSize(20, 20)
    .setLabel("global shake")
    .setValue(0)
    .moveTo(SHAPEGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    ;

  cp5.addSlider("shakeDirection")
    .setPosition(10, 190)
    .setSize(100, 20)
    .setRange(0, 3)
    .setLabel("direction (L/R/T/B)")
    .setValue(0)
    .setNumberOfTickMarks(4)
    .snapToTickMarks(true)
    .showTickMarks(false)
    .moveTo(SHAPEGroup)
    ;

  cp5.addBang("startShake")
    .setPosition(160, 220)
    .setSize(20, 20)
    .moveTo(SHAPEGroup)
    .setColorForeground(greenDark)
    .setColorActive(greenLite)
    .setLabel("shake")
    ;

  return SHAPEGroup;
}

Group setUpMORPHSettings() {
  Group morphGroup = cp5.addGroup("MORPHSettings")
    .setBackgroundColor(color(0, 64))
    .setBackgroundHeight(450)
    .setLabel("SHAPE TRANSITION SETTINGS")
    ;

  morphAutomateToggle = cp5.addToggle("morphAutomateToggle")
    .setPosition(10, 10)
    .setSize(20, 20)
    .setLabel("Automate")
    .setValue(morphAutomateEnabled ? 1 : 0)
    .moveTo(morphGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    .addCallback(cursorCB)
    .addListener(new ControlListener() {
    public void controlEvent(ControlEvent theEvent) {
      morphAutomateEnabled = morphAutomateToggle.getBooleanValue();
    }
  }
  );

  morphSequenceToggle = cp5.addToggle("morphSequenceToggle")
    .setPosition(100, 10)
    .setSize(20, 20)
    .setLabel("sequence")
    .setValue(morphSequenceEnabled ? 1 : 0)
    .moveTo(morphGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    .addCallback(cursorCB)
    .addListener(new ControlListener() {
    public void controlEvent(ControlEvent theEvent) {
      morphSequenceEnabled = morphSequenceToggle.getBooleanValue();
      morphSequenceTargets.clear();
      if (morphExecuteButton != null) {
        if (morphSequenceEnabled) morphExecuteButton.show();
        else morphExecuteButton.hide();
      }
      if (morphSaveToSequenceButton != null) {
        if (morphSequenceEnabled) morphSaveToSequenceButton.show();
        else morphSaveToSequenceButton.hide();
      }
    }
  }
  );

  // Max steps (caps auto-generated frame count)
  cp5.addSlider("morphMaxSteps")
    .setPosition(10, 40)
    .setSize(100, 20)
    .setRange(5, 50)
    .setLabel("max steps")
    .setValue(30)
    .setNumberOfTickMarks(10)
    .snapToTickMarks(true)
    .showTickMarks(false)
    .moveTo(morphGroup)
    ;

  // Frame hold duration (ms)
  cp5.addSlider("morphFrameDuration")
    .setPosition(10, 70)
    .setSize(100, 20)
    .setRange(200, 5000)
    .setLabel("frame hold (ms)")
    .setValue(1000)
    .moveTo(morphGroup)
    ;

  // Local shake per frame toggle
  cp5.addToggle("morphUseLocalShake")
    .setPosition(10, 100)
    .setSize(20, 20)
    .setLabel("local shake")
    .setValue(1)
    .moveTo(morphGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    ;

  // Global shake per frame toggle
  cp5.addToggle("morphUseGlobalShake")
    .setPosition(100, 100)
    .setSize(20, 20)
    .setLabel("global shake")
    .setValue(0)
    .moveTo(morphGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    ;

  // Shake intensity
  cp5.addSlider("morphShakeIntensity")
    .setPosition(10, 135)
    .setSize(100, 20)
    .setRange(defaultStartRange, defaultEndRange)
    .setLabel("shake intensity")
    .setValue(defaultEndRange)
    .moveTo(morphGroup)
    ;

  // Shake cycles per frame
  cp5.addSlider("morphShakeCycles")
    .setPosition(10, 165)
    .setSize(100, 20)
    .setRange(1, 5)
    .setLabel("shake cycles")
    .setValue(2)
    .setNumberOfTickMarks(5)
    .snapToTickMarks(true)
    .showTickMarks(false)
    .moveTo(morphGroup)
    ;

  // Final intensity per frame
  cp5.addSlider("morphFinalIntensity")
    .setPosition(10, 195)
    .setSize(100, 20)
    .setRange(defaultStartRange, defaultEndRange)
    .setLabel("final intensity")
    .setValue(defaultEndRange)
    .moveTo(morphGroup)
    ;

  // Global shake sweep direction
  cp5.addSlider("morphGlobalShakeDirection")
    .setPosition(10, 225)
    .setSize(100, 20)
    .setRange(0, 3)
    .setLabel("sweep direction (L/R/T/B)")
    .setValue(0)
    .setNumberOfTickMarks(4)
    .snapToTickMarks(true)
    .showTickMarks(false)
    .moveTo(morphGroup)
    ;

  // Redistribute toggle
  cp5.addToggle("morphUseRedistribute")
    .setPosition(10, 255)
    .setSize(20, 20)
    .setLabel("redistribute")
    .setValue(0)
    .moveTo(morphGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    ;

  // Mark frame for redistribution
  cp5.addBang("toggleRedistributeFrame")
    .setPosition(100, 255)
    .setSize(80, 25)
    .setLabel("mark frame")
    .moveTo(morphGroup)
    .setColorForeground(greenDark)
    .setColorActive(greenLite)
    ;

  // Generate button
  cp5.addBang("generateMorph")
    .setPosition(10, 295)
    .setSize(80, 25)
    .setLabel("Generate")
    .moveTo(morphGroup)
    .setColorForeground(greenDark)
    .setColorActive(greenLite)
    ;

  // Animate button
  cp5.addBang("animateMorph")
    .setPosition(100, 295)
    .setSize(80, 25)
    .setLabel("Animate")
    .moveTo(morphGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    ;

  // Stop button
  cp5.addBang("stopMorph")
    .setPosition(100, 330)
    .setSize(80, 25)
    .setLabel("Stop")
    .moveTo(morphGroup)
    .setColorForeground(redDark)
    .setColorActive(redLite)
    ;

  morphExecuteButton = cp5.addBang("executeMorphSequence")
    .setPosition(10, 365)
    .setSize(80, 25)
    .setLabel("execute")
    .moveTo(morphGroup)
    .setColorForeground(greenDark)
    .setColorActive(greenLite)
    ;

  morphSaveToSequenceButton = cp5.addBang("morphSaveCurrentToSequence")
    .setPosition(100, 365)
    .setSize(80, 25)
    .setLabel("save current pattern")
    .moveTo(morphGroup)
    .setColorForeground(blueDark)
    .setColorActive(blueLite)
    ;
  if (!morphSequenceEnabled && morphExecuteButton != null) {
    morphExecuteButton.hide();
  }
  if (!morphSequenceEnabled && morphSaveToSequenceButton != null) {
    morphSaveToSequenceButton.hide();
  }

  return morphGroup;
}
