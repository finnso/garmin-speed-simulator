using Toybox.Application;
using Toybox.WatchUi;

class GarminSpeedSimulatorApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [new GarminSpeedSimulatorView()];
    }
}

function getApp() as GarminSpeedSimulatorApp {
    return Application.getApp() as GarminSpeedSimulatorApp;
}