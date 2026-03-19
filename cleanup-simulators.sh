#!/bin/bash
# Script to clean up simulator issues in Xcode

echo "Cleaning up iOS Simulators..."

# Kill all simulator processes
echo "1. Killing Simulator processes..."
killall Simulator 2>/dev/null || true
killall com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true

# Shutdown all running simulators
echo "2. Shutting down all simulators..."
xcrun simctl shutdown all 2>/dev/null || true

# Delete unavailable simulators
echo "3. Deleting unavailable simulators..."
xcrun simctl delete unavailable 2>/dev/null || true

# List remaining simulators
echo "4. Current simulators:"
xcrun simctl list devices | grep "iPhone"

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Tips to prevent duplicate simulators:"
echo "  - Always quit Simulator app (Cmd+Q) after testing"
echo "  - Run this script if you notice duplicates appearing"
echo "  - In Xcode, use Window → Devices and Simulators to manage devices"
