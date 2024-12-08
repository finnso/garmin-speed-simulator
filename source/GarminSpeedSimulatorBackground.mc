import Toybox.Application;
import Toybox.Graphics;
import Toybox.WatchUi;

class Background extends WatchUi.DataFieldBackground {

    function initialize() {
        DataFieldBackground.initialize();
    }

    function draw(dc as Dc) as Void {
        // Set background color
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
    }

}
