# Downshift Tests

This directory contains unit tests for the Downshift rally racing app.

## Setting Up the Test Target in Xcode

To run these tests, you need to add a test target to your Xcode project:

### Steps:

1. **Open Downshift.xcodeproj in Xcode**

2. **Add a New Test Target:**
   - Click on the project in the navigator (Downshift)
   - At the bottom left, click the **+** button to add a new target
   - Select **iOS** → **Unit Testing Bundle**
   - Click **Next**
   - Name it `DownshiftTests`
   - Make sure "Target to be Tested" is set to `Downshift`
   - Click **Finish**

3. **Delete the Auto-Generated Test File:**
   - Xcode will create a default `DownshiftTests.swift` file
   - Delete this file (you won't need it)

4. **Add Your Test Files:**
   - Right-click on the `DownshiftTests` group in Xcode
   - Select **Add Files to "Downshift"...**
   - Navigate to the `DownshiftTests` folder
   - Select all `.swift` test files:
     - `FormatHelpersTests.swift`
     - `SavedRouteTests.swift`
     - `UnitPreferenceTests.swift`
   - Make sure **only** the `DownshiftTests` target is checked
   - Click **Add**

5. **Configure Test Target Settings:**
   - Select the `DownshiftTests` target
   - Go to **Build Settings**
   - Search for "Host Application"
   - Set it to `Downshift` if not already set

6. **Run the Tests:**
   - Press `Cmd + U` to run all tests
   - Or click the diamond icon next to individual test methods
   - Or use the Test Navigator (`Cmd + 6`)

## Test Files

### FormatHelpersTests.swift
Tests for time formatting functions:
- `formatDuration()` - Full duration formatting (HH:MM:SS)
- `formatShortDuration()` - Short duration formatting (MM:SS or HH:MM:SS)

### SavedRouteTests.swift
Tests for the SavedRoute model:
- Distance calculations
- Estimated duration
- Coordinate helpers (start/end)
- Reversed route copies
- Equality comparisons

### UnitPreferenceTests.swift
Tests for metric/imperial unit conversions:
- Distance formatting (km vs mi)
- Speed formatting (km/h vs mph)
- Unit properties
- Codable conformance

## Running Tests from Command Line

```bash
xcodebuild test \
  -project Downshift.xcodeproj \
  -scheme Downshift \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest'
```

## CI/CD

Tests are automatically run on every push to `main` via GitHub Actions. See `.github/workflows/ios-ci.yml`.

## Future Tests to Add

For comprehensive coverage, consider adding tests for:
- **RallyNavigationEngine** - Curve detection algorithm (high priority)
- **TurnInstruction** - Rally pace note generation
- **RaceViewModel** - Race state management
- **LocationManager** - GPS tracking and geofencing
- **RouteCreationViewModel** - Route building logic
- **KalmanFilter** - GPS smoothing algorithm

See the agent's analysis for detailed test recommendations.
