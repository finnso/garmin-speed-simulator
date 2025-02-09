using Toybox.WatchUi;
using Toybox.System;
using Toybox.Graphics;
using Toybox.Sensor;
using Toybox.Math;
using Toybox.Application.Properties;
using Toybox.UserProfile;
using Toybox.FitContributor;
using Toybox.Activity;

// Physics constants
const GRAVITY = 9.81;               // m/s^2
const AIR_DENSITY = 1.225;          // kg/m^3 at sea level
const ROLLING_COEFFICIENT = 0.004;  // typical for road bike tires
const SPEED_NATIVE_NUM = 6;         // Speed's native field number in the FIT file

// Smoothing factors
const SMOOTHING_FACTOR_OLD = 0.7;
const SMOOTHING_FACTOR_NEW = 0.3;

class GarminSpeedSimulatorView extends WatchUi.DataField {
    var currentSpeed = 0.0f;
    var settings;
    var speedField; // FIT Contributor field
    var randomFactor;
    var runSpeedSimulator = true;
    
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
        initializeFromProfile();
        loadSettings();
        createSpeedField();

        // Add random variation (±1%)
        var randomValue = (Math.rand() % 21) - 10;  // Generate number between -10 and 10
        randomFactor = (1.0 + randomValue / 1000.0).toFloat();
    }

    function onUpdate(dc) {
        // Clear the background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        
        // Set text color
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        
        // Get the display dimensions
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Determine if speed simulation is ON or OFF
        var simulationStatus = runSpeedSimulator ? "ON" : "OFF";
        var statusColor = runSpeedSimulator ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;

        // Display "Speed simulation" text
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            width/2,                        // x position (center)
            height/2 - 50,                  // y position (above center with padding)
            Graphics.FONT_SMALL,            // smaller font size for "Speed simulation"
            "Speed simulation",             // text to display
            Graphics.TEXT_JUSTIFY_CENTER    // center alignment
        );

        // Display the simulation status
        dc.setColor(statusColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            width/2,                        // x position (center)
            height/2 - 20,                  // y position (center with padding)
            Graphics.FONT_LARGE,            // larger font size for ON/OFF
            simulationStatus,               // text to display
            Graphics.TEXT_JUSTIFY_CENTER    // center alignment
        );

        // If simulation is ON and in debug mode, display the current speed
        if (runSpeedSimulator) {
            var speedDisplayValue = (System.getDeviceSettings().distanceUnits == System.UNIT_METRIC ? 
                (currentSpeed * 3.6).format("%.1f") + " km/h" : 
                (currentSpeed * 2.23694).format("%.1f") + " mph");

            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                width/2,                        // x position (center)
                height/2 + 30,                  // y position (below center with padding)
                Graphics.FONT_MEDIUM,           // same font size as "Speed simulation"
                speedDisplayValue,              // text to display
                Graphics.TEXT_JUSTIFY_CENTER    // center alignment
            );
        }
    }
    
    // Create and register the speed field
    function createSpeedField() {
         // Create speed field that writes to the native speed field
        speedField = createField(
            "speed",
            0,
            FitContributor.DATA_TYPE_FLOAT,
            { :mesgType => FitContributor.MESG_TYPE_RECORD,
              :units => "m/s",
              :nativeNum => SPEED_NATIVE_NUM }  // Write to the native speed field
        );
    }
    
    // Initialize settings from Garmin profile
    function initializeFromProfile() {
        try {
            if (!Properties.getValue("firstRun")) {
                Properties.setValue("simulatorEnabled", true);
                Properties.setValue("userWeight", 75.0);
                Properties.setValue("userHeight", 175.0);
                Properties.setValue("bikeType", "road");
                Properties.setValue("bikeWeight", 8.0);
                Properties.setValue("wheelset", "medium");
                Properties.setValue("gradient", 0.0);
                Properties.setValue("ascentRate", 500.0);
                Properties.setValue("firstRun", true);
            }
        } catch (e) {
            System.println("Error initializing from : " + e);
        }
    }

    // Periodic profile check
    function checkProfileUpdates() {
        var profile = UserProfile.getProfile();
        var settingsChanged = false;
        
        if (profile.weight != null) {
            var newWeight = profile.weight / 1000.0;
            if ((newWeight - settings["weight"]).abs() > 0.1) {
                Properties.setValue("userWeight", newWeight);
                settingsChanged = true;
            }
        }
        
        if (profile.height != null) {
            var newHeight = profile.height;
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
            "simulatorEnabled" => Properties.getValue("simulatorEnabled"),
            "weight" => Properties.getValue("userWeight"),
            "height" => Properties.getValue("userHeight"),
            "bikeType" => Properties.getValue("bikeType"),
            "bikeWeight" => Properties.getValue("bikeWeight"),
            "wheelset" => Properties.getValue("wheelset"),
            "gradient" => Properties.getValue("gradient"),
            "ascentRate" => Properties.getValue("ascentRate")
        };
    }
    
    // Calculate total mass (rider + bike)
    function getTotalMass() {
        return (settings["weight"] + settings["bikeWeight"]).toFloat();
    }
    
    // Calculate frontal area based on height and bike position
    function getFrontalArea() {
        var heightM = settings["height"] / 100.0;
        var baseArea = 0.0233 * Math.pow(heightM, 0.725) * Math.pow(settings["weight"], 0.425);
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

    // Smooth transition from previous speed to new speed
    function smoothSpeedTransition(currentSpeed, testSpeed) {
        return (currentSpeed * SMOOTHING_FACTOR_OLD + testSpeed * SMOOTHING_FACTOR_NEW).toFloat();
    }
    
    // Main physics calculation
    // Calculate simulated speed with ascent rate variations
    function calculateSpeed(power, cadence, elapsedTime) {
        if (power == null || cadence == null || power <= 0 || cadence <= 0) {
            // Gradually reduce speed to simulate coasting
            var decelerationFactor = 0.98;
            currentSpeed *= decelerationFactor;
            return currentSpeed;
        }
        
        var bikeProfile = bikeProfiles[settings["bikeType"]];
        var totalMass = getTotalMass();
        var frontalArea = getFrontalArea();
        var wheelInertia = getWheelInertia();
        
        // Base gradient from settings
        var baseGradient = settings["gradient"];
        
        // Calculate additional gradient variation based on ascent rate
        var ascentRate = settings["ascentRate"];  // meters per hour
        var timeHours = (elapsedTime % 3600) / 3600.0;  // Convert to fraction of hour
        
        // Create a sine wave variation based on time
        var ascentVariation = Math.sin(2.0 * Math.PI * timeHours);
        
        // Scale the variation by the ascent rate (convert to gradient percentage)
        var ascentGradient = (ascentVariation * ascentRate) / 1000.0;
        
        // Combine base gradient with ascent variation
        var effectiveGradient = baseGradient + ascentGradient;
        
        // Convert gradient to radians
        var gradientRad = Math.atan(effectiveGradient / 100.0);
        
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
            
            // Updated physics equation
            var newSpeed = Math.sqrt((2.0 * powerAtWheel) / totalResistance).toFloat();
            testSpeed = (testSpeed * SMOOTHING_FACTOR_OLD + newSpeed * SMOOTHING_FACTOR_NEW).toFloat();
        }
        
        // Add cadence influence with reduced factor
        var cadenceInfluenceFactor = 1.0 + (cadence - 90) * 0.0001;  // Reduced from 0.001
        testSpeed *= cadenceInfluenceFactor;
        
        // Add random factor to simulate real-world variations
        testSpeed *= randomFactor;

        // Smooth transition from previous speed
        currentSpeed = smoothSpeedTransition(currentSpeed, testSpeed);
        
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
            var elapsedTime = info.elapsedTime;
            var speed = calculateSpeed(power, cadence, elapsedTime);
            
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