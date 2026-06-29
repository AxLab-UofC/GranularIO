import java.util.EnumSet;
ActionMode mode = ActionMode.MANUAL;
int uiMode = 0; //0 is sliders, 1 is buttons

RadioButton modeButtons;

// Define the set of modes that are displayed in the UI
// This serves as a single source of truth for both setup and drawing
private static final EnumSet<ActionMode> DISPLAYED_MODES = EnumSet.of(
  ActionMode.MANUAL,
  ActionMode.FADE,
  ActionMode.CONSTANT,
  ActionMode.VIBRATE,
  ActionMode.MOVE,
  ActionMode.SPLIT,
  ActionMode.MERGE,
  ActionMode.ROTATE,
  ActionMode.DRAW,
  ActionMode.SHAPE,
  ActionMode.MORPH
  );

// Mapping from ActionMode to settings accordion item index
// This calculates the index based on the order modes are added to the accordion
// (in ActionMode enum order, excluding MANUAL and TOGGLE)
private int getSettingsIndex(ActionMode mode) {
  // If mode has no settings panel, return -1
  if (mode == ActionMode.MANUAL || mode == ActionMode.TOGGLE) {
    return -1;
  }

  // Calculate index based on enum order, skipping MANUAL and TOGGLE
  int accordionIndex = 0;
  for (ActionMode currentMode : ActionMode.values()) {
    if (currentMode == mode) {
      return accordionIndex;
    }
    // Only increment index for modes that have settings panels
    if (currentMode != ActionMode.MANUAL && currentMode != ActionMode.TOGGLE) {
      accordionIndex++;
    }
  }

  return -1; // Should not reach here
}

int modeStartX = 80;
int modeStartY = 50;
int modeSizeX = 100;
int modeSizeY = 50;
int modeSpacingY = 30;

void setUpModes() {
  modeButtons = cp5.addRadioButton("modeButtonFunc")
    .setPosition(modeStartX, modeStartY)
    .setSize(modeSizeX, modeSizeY)
    .setColor(regularColor)
    .setColorLabel(blk)
    .setItemsPerRow(1)
    .setSpacingRow(modeSpacingY);

  // Add items dynamically from DISPLAYED_MODES
  for (ActionMode mode : DISPLAYED_MODES) {
    modeButtons.addItem(mode.name(), mode.id);
  }

  modeButtons.hideLabels(); //Labels are drawn in drawModeLabels()
  //cp5.getController("Vibrate").setColorActive(yellowDark);
}

// Draws text labels for each mode button in the UI
void drawModeLabels() {
  int textStartX = modeStartX + modeSizeX + 10;
  int textStartY = modeStartY + modeSizeY / 2 + 5;
  int textSpacingY = modeSizeY + modeSpacingY;
  fill(0); // set text color to black

  // Draw labels for each displayed mode
  int index = 0;
  for (ActionMode mode : DISPLAYED_MODES) {
    text(mode.displayName(), textStartX, textStartY + index * textSpacingY);
    index++;
  }
}

void modeButtonFunc(int modeId) {
  settingsAccordion.close();

  //serialPort.write("!\n");
  mode = ActionMode.fromInt(modeId);
  println("a radio Button event: "+mode);
  // snapToZero.setValue(false);
  //if (mode != 5 && mode != 6 && uiMode == 1) {
  //  println("hiding ui");
  //  uiMode = 0;
  //  //magButtons.hide();
  //  showSliders();
  //}
  if (modeId == -1) {
    // if the unclicked, reclick the manual
    modeButtons.activate(0);
    settingsAccordion.close();
    //hideSliders();
    println("Manual");
    mode = ActionMode.MANUAL;

    return;
  }
  deselectAll();
  if (mode == ActionMode.MANUAL) {
    instructions = "";
    settingsAccordion.close();
    println("closed??");
    // snapToZero.setValue(true);

    println("Manual");
    for (int i = 0; i < sliders.length; i++) {
      sliders[i]
        //     .setValue(0)
        .showTickMarks(false)
        .snapToTickMarks(false)
        ;
    }
  } else if (mode == ActionMode.VIBRATE) {
    println("Vibrate");
    int idx = getSettingsIndex(ActionMode.VIBRATE);
    openSettingsAccordionItem(settingsAccordion, idx);
    //resetSliders();
  } else if (mode == ActionMode.FADE) {
    println("Fade");
    int idx = getSettingsIndex(ActionMode.FADE);
    openSettingsAccordionItem(settingsAccordion, idx);
  } else if (mode == ActionMode.LOOP) {
    println("Loop");
    int idx = getSettingsIndex(ActionMode.LOOP);
    openSettingsAccordionItem(settingsAccordion, idx);
    //serialPort.write("l\n");
  } else if (mode == ActionMode.TOGGLE) {
    println("Toggle");
    settingsAccordion.close();
    toggleOn();
  } else if (mode == ActionMode.SPLIT) {
    instructions = "select first split target";
    println("Split");
    int idx = getSettingsIndex(ActionMode.SPLIT);
    openSettingsAccordionItem(settingsAccordion, idx);
  } else if (mode == ActionMode.MOVE) {
    instructions = "select start point";

    println("Move To");
    int idx = getSettingsIndex(ActionMode.MOVE);
    openSettingsAccordionItem(settingsAccordion, idx);
    deselectAll();
    //magButtons.show();
    uiMode = 1;
    //hideSliders();
  } else if (mode == ActionMode.MERGE) {
    instructions = "select first merge pile";

    int idx = getSettingsIndex(ActionMode.MERGE);
    openSettingsAccordionItem(settingsAccordion, idx);
  } else if (mode == ActionMode.ROTATE) {
    instructions = "select center";
    int idx = getSettingsIndex(ActionMode.ROTATE);
    openSettingsAccordionItem(settingsAccordion, idx);
  } else if (mode == ActionMode.CONSTANT) {
    instructions = "select magnet";
    int idx = getSettingsIndex(ActionMode.CONSTANT);
    openSettingsAccordionItem(settingsAccordion, idx);
  } else if (mode == ActionMode.DRAW) {
    instructions = "select magnets to draw pattern";
    int idx = getSettingsIndex(ActionMode.DRAW);
    openSettingsAccordionItem(settingsAccordion, idx);
  } else if (mode == ActionMode.SHAPE) {
    instructions = "Select pattern to shake";
    if (!showThumbnailGrid) {
      showThumbnails();
    }
    int idx = getSettingsIndex(ActionMode.SHAPE);
    openSettingsAccordionItem(settingsAccordion, idx);
  } else if (mode == ActionMode.MORPH) {
    instructions = "Select START pattern from thumbnails";
    morphSelectionState = 0;
    morphStartPattern = null;
    morphEndPattern = null;
    currentMorphSequence = null;
    morphSequenceTargets.clear();
    morphSequenceDisplayedTargets.clear();
    targetPreviewScrollOffset = 0;
    if (!showThumbnailGrid) {
      showThumbnails();
    }
    int idx = getSettingsIndex(ActionMode.MORPH);
    openSettingsAccordionItem(settingsAccordion, idx);
  } else {
    instructions = "";
    println("Unknown");
    mode = ActionMode.MANUAL;
    settingsAccordion.close();
  }
  println("mode is: "+ mode.name());
}

void toggleOn() {
  for (int i = 0; i < sliders.length; i++) {
    sliders[i]
      .showTickMarks(true)
      .setNumberOfTickMarks(3)
      .snapToTickMarks(true);
  }
}
//void setAllModes(int mode) {
//  for (Magnet mag : indivModes) {
//    mag = 0;
//  }
//}

public enum ActionMode {
  MANUAL(0, "MANUAL"), FADE(1, "FADE"), CONSTANT(2, "CONSTANT"),
  VIBRATE(3, "VIBRATE"), LOOP(4, "LOOP"), TOGGLE(5, "TOGGLE"),
  MOVE(6, "MOVE"), SPLIT(7, "SPLIT"), MERGE(8, "MERGE"),
  ROTATE(9, "ROTATE"), DRAW(10, "DRAW"),
  SHAPE(11, "SHAKE"), MORPH(12, "SHAPE\nTRANSITION");

  private final int id;
  private final String displayName;

  ActionMode(int id, String displayName) {
    this.id = id;
    this.displayName = displayName;
  }

  public String displayName() {
    return displayName;
  }

  public static ActionMode fromInt(int id) {
    for (ActionMode mode : ActionMode.values()) {
      if (mode.id == id) return mode;
    }
    return MANUAL; // default fallback
  }
}
