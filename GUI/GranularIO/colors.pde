
// define colors
color blk = rgb(0, 0, 0);
color white = rgb(255, 255, 255);

color bgColor = rgba(245, 245, 245, 1);
color redLite = rgba(255, 178, 178, 1);
color redDark = rgba(255, 71, 71, 1);
color redMagnet = rgb(200, 0, 0);
color blueMagnet = rgb(0, 0, 200);

color greenLite = rgb(36, 244, 36);
color greenDark = rgb(21, 127, 21);
color blueLiter = rgba(158, 206, 255, 1);
color blueLite = rgb(43, 174, 255);
color blueDark = rgb(30, 113, 196);
color blueDarker = rgb(0, 21, 114);
color yellowLite = rgb(255, 255, 119);
color yellowDark = rgb(175, 175, 0);
color uselected = rgba(217, 217, 217, 1);
color selected = rgba(151, 151, 151, 1);

CColor regularColor = new CColor(
/*cfg = */  blueLite,
/*cbg = */  blueDarker,
/*cactive = */  blueLiter,
/*ccaptionlabel = */  blk,
/*cvaluelabel = */  blk
  );

CColor grayscale = new CColor(
/*cfg = */  ControlP5Constants.GRAY,
/*cbg = */  uselected,
/*cactive = */  ControlP5Constants.GRAY,
/*ccaptionlabel = */  blk,
/*cvaluelabel = */  blk
  );
CColor sliderColor = new CColor(
/*cfg = */  redMagnet,
/*cbg = */  blueMagnet,
/*cactive = */  redMagnet,
/*ccaptionlabel = */  white,
/*cvaluelabel = */  white
  );
CColor buttonColor = new CColor(
/*cfg = */  bgColor,
/*cbg = */  bgColor,
/*cactive = */  ControlP5Constants.GRAY,
/*ccaptionlabel = */  blk,
/*cvaluelabel = */  blk
  );
CColor vibrateColor = new CColor(
/*cfg = */  yellowLite,
/*cbg = */  yellowDark,
/*cactive = */  yellowLite,
/*ccaptionlabel = */  blk,
/*cvaluelabel = */  blk
  );

CColor debugColor = new CColor(
/*cfg = */  blueDark,
/*cbg = */  blueDark,
/*cactive = */  redLite,
/*ccaptionlabel = */  blk,
/*cvaluelabel = */  blk
  );

color rgba(int r, int g, int b, float a) {
  return color(r, g, b);
}
color rgb(int r, int g, int b) {
  return color(r, g, b);
}
// End of color definitions
