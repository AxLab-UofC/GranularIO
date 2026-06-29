class Timer {
  int duration;
  boolean running;
  int startTime;
  int stopTime = 0;

  //constructor
  public Timer(int duration) {
    this.duration = duration;
    running = false;
  }

  public void setDuration(int duration) {
    this.duration = duration;
  }

  public void reset() {
    startTime = millis();
  }

  public boolean triggered() {
    boolean triggered;
    int sinceReset = timeSinceReset();
    triggered = (sinceReset >= duration);
    if (triggered) reset();
    return (running) && triggered;
  }

  public int timeSinceReset() {
    return millis() - startTime;
  }

  public void start() {
    startTime = millis() - stopTime;

    running = true;
  }
  public void stop() {
    running = false;
    stopTime = millis();
  }

  boolean isRunning() {
    return running;
  }

  int getNextTriggerTime() {
    return startTime + duration;
  }

  int getDuration() {
    return duration;
  }
}

void stopAllTimers() {
  for (int i = 0; i < magnets.length; i++) {
    magnets[i].timer.stop();
  }
}
void resetAllTimers() {
  for (int i = 0; i < magnets.length; i++) {
    magnets[i].timer.stop();
  }
}
