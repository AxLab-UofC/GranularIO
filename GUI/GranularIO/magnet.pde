import java.lang.Integer;

Magnet magnets[] = new Magnet[sliders.length];
class Magnet {
  public int index;
  Timer timer;
  GroupController owner = null;
  Mode prev_mode = Mode.RUN;
  private Mode mode = Mode.RUN;
  Slider slider; // reference to corresponding slider for simplicity
  ArrayList<Integer> parameters;
  boolean debugMagnet = false;
  //constructor
  public Magnet(int index) {
    this.index = index;
    timer = new Timer(0);
    timer.stop();
    parameters = new ArrayList<Integer>();
    slider = sliders[index]; //not the best practice. need to put setup sliders before set up buttons
  }



  public void update() {
    switch(this.mode) {
    case FADE:
      //println("Fading");
      fade();
      break;
    case VIBRATE:
      vibrate();
      if (debugMagnet) {
        println("Vibrating");
        println("Mode: " + mode.name());
      }
      break;
    default: //run
      //println("Running");
      break;
    }
  }
  public void setMode(Mode mode) {
    if (debugMagnet) {
      println("Setting mode to " + mode.name());
    }
    if (mode != Mode.EXT_CONT) {
      prev_mode = this.mode;
    } else {
      prev_mode = Mode.RUN; //ext cont is a special case
    }
    //println("setting mode to " + mode.name()+". "+ "previous mode was " + prev_mode.name());
    this.mode = mode;
    if (mode == Mode.RUN) {
      timer.stop();
      timer.reset();
      if (debugMagnet) {
        println("Resetting timer");
        println("Mode: " + mode.name());
      }
    }
  }
  public String toString() {
    return "Index: " + index;
  }

  public int getRow() {
    return index / num_motors_per_row;
  }
  public int getCol() {
    return index % num_motors_per_row;
  }

  //safety checks & defaults
  void parseFadeSettings() {
    parameters.clear();
    int starting_val;
    try {
      starting_val = (int)cp5.getController("fadeStart").getValue();
    }
    catch (Exception e) {
      starting_val = (int)maxIntensity;
    }
    int ending_val;
    try {
      ending_val = (int)cp5.getController("fadeEnd").getValue();
    }
    catch (Exception e) {
      ending_val = 0;
    }
    int skips;
    try {
      skips = (int)cp5.getController("fadeSpeed").getValue();
    }
    catch (Exception e) {
      skips = 1;
    }
    int delay_amt;
    try {
      delay_amt = (int)cp5.getController("fadeDelay").getValue();
    }
    catch (Exception e) {
      delay_amt = 10;
    }
    parameters.add(starting_val);
    parameters.add(ending_val);
    parameters.add(skips);
    parameters.add(delay_amt);
  }

  void fade() {
    if (!timer.running) {
      parseFadeSettings();
      timer.setDuration(parameters.get(3));
      timer.start();
      sliders[index].setValue((int)parameters.get(0));
      //println("Fading");
    }
    int starting_val = (int)parameters.get(0);
    int ending_val = (int)parameters.get(1);
    int skips = (int)parameters.get(2);
    if (starting_val > ending_val) {  //going down
      if ((int)sliders[index].getValue() - skips < ending_val) {
        timer.stop();
        sliders[index].setValue(ending_val);
        mode = Mode.RUN;
      } else {
        // println("decreasing"));
        if (timer.triggered()) {
          sliders[index].setValue((int)sliders[index].getValue() - skips);
        }
      }
    } else {   //going up
      if ((int)sliders[index].getValue() + skips > ending_val) {
        timer.stop();
        println("stoppping fade");
        sliders[index].setValue(ending_val);
        mode = Mode.RUN;
      } else {
        if (timer.triggered()) {
          //println("increasing");
          sliders[index].setValue((int)sliders[index].getValue() + skips);
        }
      }
    }
  }

  void vibrate() {
    int skips;
    try {
      skips = parameters.get(0);
    }
    catch (NumberFormatException e) {
      skips = 1;
    }
    int delay_amt;
    try {
      delay_amt = parameters.get(1);
    }
    catch (NumberFormatException e) {
      delay_amt = 10;
    }
    vibrate(skips, delay_amt);
  }
  // temp fix for syncing vibrate
  // boolean vibrateHelper = false;
  void vibrate(int speed_amt, int delay_amt) {
    if (!timer.running) {
      println("starting vibration");
      timer.setDuration(delay_amt);
      timer.start();
      sliders[index].setValue(speed_amt);
    }
    if (timer.triggered()) {
      // if (vibrateHelper) {
      //   sliders[index].setValue(-1 * speed_amt);
      //   vibrateHelper = false;
      // } else {
      //   sliders[index].setValue(speed_amt);
      //   vibrateHelper = true;
      // }

      // temp fix for syncing vibrate
      if (!globalVibrateFlagLock) {
        globalVibrateFlag = !globalVibrateFlag;
        globalVibrateFlagLock = true;
      }
      sliders[index].setValue(globalVibrateFlag ? speed_amt : -1 * speed_amt);
    }
  }
}
void resetAllMagnets() {
  for (Magnet m : magnets) {
    m.mode = Mode.RUN;
    m.timer.stop();
    m.timer.reset();
  }
}

public enum Mode {
  RUN, FADE, VIBRATE, EXT_CONT
}

int getMagIndexFromCoord(int shield, int motor) {
  return shield * num_motors_per_row + motor;
}
