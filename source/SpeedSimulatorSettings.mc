using Toybox.Application.Properties;
using Toybox.UserProfile;
using Toybox.System;

class SpeedSimulatorSettings {
    // Default values
    static const DEFAULT_SETTINGS = {
        "userWeight" => 75.0,      // kg
        "userHeight" => 175.0,     // cm
        "bikeType" => "road",      // road, tt, mtb
        "bikeWeight" => 8.0,       // kg
        "wheelset" => "medium",    // light, medium, heavy
        "gradient" => 0.0,         // percent
        "ascentRate" => 500.0      // meters per hour
    };
    
    // Valid ranges for settings
    static const SETTING_RANGES = {
        "userWeight" => { "min" => 30.0, "max" => 150.0 },
        "userHeight" => { "min" => 120.0, "max" => 220.0 },
        "bikeWeight" => { "min" => 5.0, "max" => 20.0 },
        "gradient" => { "min" => -25.0, "max" => 25.0 },
        "ascentRate" => { "min" => 0.0, "max" => 2000.0 }
    };
    
    // Valid options for enum settings
    static const VALID_OPTIONS = {
        "bikeType" => ["road", "tt", "mtb"],
        "wheelset" => ["light", "medium", "heavy"]
    };
    
    // Initialize settings on first run
    function initializeSettings() {
        if (Properties.getValue("firstRun") == null || Properties.getValue("firstRun") == true) {
            var profile = UserProfile.getProfile();
            
            // Initialize with profile data if available, otherwise use defaults
            initializeFromProfile(profile);
            
            // Set remaining defaults
            var keys = DEFAULT_SETTINGS.keys();
            for (var i = 0; i < keys.size(); i++) {
                var key = keys[i].toString();
                if (Properties.getValue(key) == null) {
                    var value = DEFAULT_SETTINGS[keys[i]];
                    
                    // Convert numeric values to float
                    if (SETTING_RANGES.hasKey(key)) {
                        value = value.toFloat();
                    }
                    // Convert string values to string
                    else if (VALID_OPTIONS.hasKey(key)) {
                        value = value.toString();
                    }
                    
                    Properties.setValue(key, value);
                }
            }
            
            Properties.setValue("firstRun", false);
        }
    }
    
    // Initialize from Garmin profile
    function initializeFromProfile(profile) {
        if (profile.weight != null) {
            var weightKg = (profile.weight / 1000.0).toFloat();
            if (isValueInRange("userWeight", weightKg)) {
                Properties.setValue("userWeight".toString(), weightKg);
            }
        }
        
        if (profile.height != null) {
            var height = profile.height.toFloat();
            if (isValueInRange("userHeight", height)) {
                Properties.setValue("userHeight".toString(), height);
            }
        }
    }
    
    // Update a single setting
    function updateSetting(key, value) {
        if (!validateSetting(key, value)) {
            System.println("Invalid setting value for " + key + ": " + value);
            return false;
        }
        
        // Convert key to string and value to appropriate type before saving
        var keyStr = key.toString();
        var convertedValue = null;
        
        // Handle numeric values
        if (SETTING_RANGES.hasKey(keyStr)) {
            convertedValue = value.toFloat();
        }
        // Handle string enum values
        else if (VALID_OPTIONS.hasKey(keyStr)) {
            convertedValue = value.toString();
        }
        
        if (convertedValue != null) {
            Properties.setValue(keyStr, convertedValue);
            return true;
        }
        return false;
    }
    
    // Validate setting value
    function validateSetting(key, value) {
        // Check numeric ranges
        if (SETTING_RANGES.hasKey(key)) {
            return isValueInRange(key, value);
        }
        
        // Check enum values
        if (VALID_OPTIONS.hasKey(key)) {
            return VALID_OPTIONS[key].indexOf(value) != -1;
        }
        
        return false;
    }
    
    // Check if value is within valid range
    function isValueInRange(key, value) {
        if (!SETTING_RANGES.hasKey(key)) {
            return false;
        }
        
        var range = SETTING_RANGES[key];
        return value >= range["min"] && value <= range["max"];
    }
    
    // Sync with profile (call periodically)
    function syncWithProfile() {
        var profile = UserProfile.getProfile();
        var settingsChanged = false;
        
        if (profile.weight != null) {
            var newWeight = profile.weight / 1000.0;
            if (isValueInRange("userWeight", newWeight)) {
                var currentWeight = Properties.getValue("userWeight");
                if ((newWeight - currentWeight).abs() > 0.1) {
                    Properties.setValue("userWeight", newWeight);
                    settingsChanged = true;
                }
            }
        }
        
        if (profile.height != null) {
            if (isValueInRange("userHeight", profile.height)) {
                var currentHeight = Properties.getValue("userHeight");
                if ((profile.height - currentHeight).abs() > 0.1) {
                    Properties.setValue("userHeight", profile.height);
                    settingsChanged = true;
                }
            }
        }
        
        return settingsChanged;
    }
    
    // Get all current settings
    function getAllSettings() {
        // Create new dictionary with same structure as DEFAULT_SETTINGS
        var settings = {
            "userWeight" => Properties.getValue("userWeight"),
            "userHeight" => Properties.getValue("userHeight"),
            "bikeType" => Properties.getValue("bikeType"),
            "bikeWeight" => Properties.getValue("bikeWeight"),
            "wheelset" => Properties.getValue("wheelset"),
            "gradient" => Properties.getValue("gradient"),
            "ascentRate" => Properties.getValue("ascentRate")
        };
        return settings;
    }
    
    // Reset all settings to defaults
    function resetToDefaults() {
        var keys = DEFAULT_SETTINGS.keys();
        for (var i = 0; i < keys.size(); i++) {
            var key = keys[i].toString();
            var value = DEFAULT_SETTINGS[keys[i]];
            
            // Convert numeric values to float
            if (SETTING_RANGES.hasKey(key)) {
                value = value.toFloat();
            }
            // Convert string values to string
            else if (VALID_OPTIONS.hasKey(key)) {
                value = value.toString();
            }
            
            Properties.setValue(key, value);
        }
    }
}