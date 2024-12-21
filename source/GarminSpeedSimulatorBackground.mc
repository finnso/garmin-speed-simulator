using Toybox.WatchUi;
using Toybox.Graphics;

class Background extends WatchUi.DataField {
    function initialize() {
        DataField.initialize();
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
    }
}   
