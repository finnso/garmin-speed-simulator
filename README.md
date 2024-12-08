# Garmin Speed Simulator for Indoor Cycling

A Garmin Connect IQ Data Field app that calculates and records virtual speed based on power and cadence data from an indoor bike trainer. This app is particularly useful for indoor cycling sessions where GPS speed is not available.

## Features

- Calculates virtual speed based on power output and cadence
- Uses physics-based calculations including:
  - Air resistance
  - Rolling resistance
  - Gradient effects
  - Bike and rider characteristics
- Automatically pulls rider weight and height from Garmin Connect profile
- Supports multiple bike types (Road, TT, MTB)
- Configurable settings for bike weight and wheelset type
- Records speed data to your activity FIT file
- Works with ANT+ power meters and smart trainers

## Requirements

- Compatible Garmin Edge devices (530, 830, 1030, 1030 Plus, 1040, 1040 Solar)
- ANT+ power meter or smart trainer providing power and cadence data
- Garmin Connect IQ SDK 4.1.0 or higher

## Installation

1. Download the app from the Garmin Connect IQ Store
2. Transfer to your Edge device using Garmin Express or Garmin Connect Mobile
3. Add the data field to one of your activity profiles

## Configuration

The following settings can be configured:
- Rider weight (auto-populated from Garmin Connect profile)
- Rider height (auto-populated from Garmin Connect profile)
- Bike type (Road/TT/MTB)
- Bike weight
- Wheelset type (Light/Medium/Heavy)
- Gradient simulation

## Development Setup

1. Install the Garmin Connect IQ SDK
2. Install Visual Studio Code and the Monkey C extension
3. Clone this repository
4. Open the project in VS Code
5. Build and test using the Garmin simulator

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT 

## Acknowledgments

- Thanks to Claude.ai
- Physics calculations based on standard cycling aerodynamics models

## Support

For issues and feature requests, please use the GitHub issues page.