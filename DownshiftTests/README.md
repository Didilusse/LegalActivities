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
     - `UserProfileTests.swift`
     - `RaceResultTests.swift`
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

### FormatHelpersTests.swift (15 tests)
Tests for time formatting functions:
- `formatDuration()` - Full duration formatting (HH:MM:SS)
- `formatShortDuration()` - Short duration formatting (MM:SS or HH:MM:SS)
- Edge cases: zero seconds, hours, minutes

### SavedRouteTests.swift (18 tests)
Tests for the SavedRoute model:
- Distance calculations (empty, single, multiple coordinates)
- Estimated duration computation
- Coordinate helpers (start/end)
- Reversed route copies
- Equality comparisons
- Metadata preservation

### UnitPreferenceTests.swift (16 tests)
Tests for metric/imperial unit conversions:
- Distance formatting (km vs mi)
- Speed formatting (km/h vs mph)
- Unit properties
- Codable conformance
- Zero values and edge cases

### UserProfileTests.swift (59 tests)
Tests for user profile and car models:
- **UserProfile**: Default/custom initialization, primary car selection, Codable
- **Car**: Initialization, display name, equality, Codable
- **Difficulty**: All cases, raw values, colors, Codable
- **CarMake**: Popular brands, all cases count
- **CarColor**: Common colors, all cases count

### RaceResultTests.swift (20 tests)
Tests for race result model:
- Basic initialization and custom dates
- Multiple laps and edge cases
- Unique ID generation
- Hashable conformance
- Codable and JSON encoding
- Performance metrics (fastest/slowest lap, average lap time)

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
