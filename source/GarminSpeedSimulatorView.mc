using Toybox.WatchUi;
using Toybox.System;
using Toybox.Sensor;
using Toybox.Math;
using Toybox.Application.Properties;
using Toybox.UserProfile;
using Toybox.FitContributor;
using Toybox.ActivityRecording;

// Physics constants
const GRAVITY = 9.81;              // m/s^2
const AIR_DENSITY = 1.225;         // kg/m^3 at sea level
const ROLLING_COEFFICIENT = 0.004;  // typical for road bike tires
const FIT_SPEED_FIELD_ID = 0;      // Unique identifier for our speed field

class GarminSpeedSimulatorView extends WatchUi.DataField {
    var currentSpeed = 0.0f;
    var settings;
    var speedField;  // FIT Contributor field
    
    // Bike profiles with their characteristics
    var bikeProfiles = {
        "road" => {
            "dragCoefficient" => 0.7,  // Cd*A for road bike position
            "wheelRadius" => 0.311,     // 700c wheel
            "efficiency" => 0.95        // drivetrain efficiency
        },
        "tt" => {
            "dragCoefficient" => 0.6,
            "wheelRadius" => 0.311,
            "efficiency" => 0.95
        },
        "mtb" => {
            "dragCoefficient" => 0.9,
            "wheelRadius" => 0.3429,    // 29er wheel
            "efficiency" => 0.93
        }
    };
    
    function initialize() {
        DataField.initialize();
        //initializeFromProfile();
        //loadSettings();
        createSpeedField();
    }
    
    // Create and register the speed field
    function createSpeedField() {
        speedField = createField(
            "computed_speed",
            FIT_SPEED_FIELD_ID,
            FitContributor.DATA_TYPE_FLOAT,
            { :mesgType => FitContributor.MESG_TYPE_RECORD,
              :units => "m/s" }
        );
    }
    
    // Initialize settings from Garmin profile
  function initializeFromProfile() {
    if (!Application.Properties.getValue("firstRun")) {
        Application.Properties.setValue("userWeight", 75.0);
        Application.Properties.setValue("userHeight", 175.0);
        Application.Properties.setValue("bikeType", "road");
        Application.Properties.setValue("bikeWeight", 8.0);
        Application.Properties.setValue("wheelset", "medium");
        Application.Properties.setValue("gradient", 0.0);
        Application.Properties.setValue("firstRun", true);
    }
}

    // Periodic profile check
    function checkProfileUpdates() {
        var profile = UserProfile.getProfile();
        var settingsChanged = false;
        
        if (profile.weight != null) {
            var newWeight = profile.weight / 1000.0;
            // Replace Math.abs with direct comparison
            if ((newWeight - settings["weight"]).abs() > 0.1) {
                Properties.setValue("userWeight", newWeight);
                settingsChanged = true;
            }
        }
        
        if (profile.height != null) {
            var newHeight = profile.height;
            // Replace Math.abs with direct comparison
            if ((newHeight - settings["height"]).abs() > 0.1) {
                Properties.setValue("userHeight", newHeight);
                settingsChanged = true;
            }
        }
        
        if (settingsChanged) {
            loadSettings();
        }
    }
        
    // Load current settings
    function loadSettings() {
        settings = {
            "weight" => Properties.getValue("userWeight"),
            "height" => Properties.getValue("userHeight"),
            "bikeType" => Properties.getValue("bikeType"),
            "bikeWeight" => Properties.getValue("bikeWeight"),
            "wheelset" => Properties.getValue("wheelset"),
            "gradient" => Properties.getValue("gradient")
        };
    }
    
    // Calculate total mass (rider + bike)
    function getTotalMass() {
        return (settings["weight"] + settings["bikeWeight"]).toFloat();
    }
    
    // Calculate frontal area based on height and bike position
    function getFrontalArea() {
        var heightM = settings["height"] / 100.0;
        var baseArea = 0.0276 * Math.pow(heightM, 0.725) * Math.pow(settings["weight"], 0.425);
        var bikeProfile = bikeProfiles[settings["bikeType"]];
        return baseArea * bikeProfile["dragCoefficient"];
    }
    
    // Calculate wheel inertia based on wheelset type
    function getWheelInertia() {
        var wheelsetFactors = {
            "light" => 0.9,
            "medium" => 1.0,
            "heavy" => 1.1
        };
        return wheelsetFactors[settings["wheelset"]];
    }
    
    // Main physics calculation
    function calculateSpeed(power, cadence) {
        if (power <= 0 || cadence <= 0) {
            currentSpeed *= 0.95;
            return currentSpeed;
        }
        
        var bikeProfile = bikeProfiles[settings["bikeType"]];
        var totalMass = getTotalMass();
        var frontalArea = getFrontalArea();
        var wheelInertia = getWheelInertia();
        
        // Convert gradient to radians
        var gradientRad = Math.atan(settings["gradient"] / 100.0);
        
        // Calculate forces
        var gravityForce = totalMass * GRAVITY * Math.sin(gradientRad);
        var normalForce = totalMass * GRAVITY * Math.cos(gradientRad);
        var rollingResistance = ROLLING_COEFFICIENT * normalForce;
        
        // Iterative approach to find equilibrium speed
        var testSpeed = currentSpeed;
        var iterations = 5;
        
        for (var i = 0; i < iterations; i++) {
            var airResistance = 0.5 * AIR_DENSITY * frontalArea * testSpeed * testSpeed;
            var totalResistance = airResistance + rollingResistance + gravityForce;
            var powerAtWheel = power * bikeProfile["efficiency"];
            var newSpeed = (powerAtWheel / totalResistance).toFloat();
            testSpeed = (testSpeed * 0.7 + newSpeed * 0.3).toFloat();
        }
        
        // Add cadence influence
        var cadenceFactor = 1.0 + (cadence - 90) * 0.001;
        testSpeed *= cadenceFactor;
        
        // Add random variation (±2%)
        var randomValue = Math.rand() % 40 - 20;  // Generate number between -20 and 20
        var randomFactor = (1.0 + randomValue / 1000.0).toFloat();  // Convert to ±2%
        testSpeed *= randomFactor;
        
        // Smooth transition from previous speed
        currentSpeed = (currentSpeed * 0.8 + testSpeed * 0.2).toFloat();
        
        return currentSpeed;
    }
    
    // Handle sensor data
    function compute(info) {
        // Check if GPS is enabled in the current activity profile
        var isGpsEnabled = (info has :position && info.position != null) || 
                        (info has :currentLocation && info.currentLocation != null);
        
        // Debug log GPS status
        System.println("GPS Status - Enabled: " + isGpsEnabled);
        
        // If GPS is enabled, don't simulate speed
        if (isGpsEnabled) {
            System.println("GPS active - Speed simulation disabled");
            return null;  // Let device use GPS speed
        }
        
        // No GPS, so simulate speed from power/cadence
        var power = info.currentPower;
        var cadence = info.currentCadence;
        
        // Debug log sensor data
        System.println("Sensor Data - Power: " + power + "W, Cadence: " + cadence + "rpm");
        
        if (power != null && cadence != null) {
            var speed = calculateSpeed(power, cadence);
            
            // Debug log calculated speed
            System.println("Simulated Speed: " + speed.format("%.1f") + "m/s");
            
            if (speedField != null) {
                speedField.setData(speed);
                System.println("Speed data written to FIT file");
            } else {
                System.println("Warning: speedField is null");
            }
            
            return speed;
        }
        
        System.println("No power/cadence data available");
        return null;
    }
}