# Appium Tests

This directory contains automated UI tests for the iOS app using Appium.

## Setup

### Prerequisites
- Python 3.11+
- Node.js (for Appium)
- Xcode 16.2+
- iOS Simulator (iPhone 16 Pro with iOS 18.2)

### Local Development Setup

1. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Install Appium globally:
   ```bash
   npm install -g appium
   ```

3. Build the iOS app:
   ```bash
   xcodebuild build \
     -workspace nose.xcworkspace \
     -scheme nose-staging \
     -configuration Development \
     -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.2'
   ```

4. Start Appium server:
   ```bash
   appium --base-path /wd/hub
   ```

5. Run tests:
   ```bash
   python test_runner.py
   ```

## GitHub Actions

The tests automatically run on:
- Push to `staging` branch
- Pull requests to `staging` branch

### Workflow Steps
1. Set up Python and Ruby environments
2. Install dependencies (Python packages and CocoaPods)
3. Build the iOS app for simulator
4. Start Appium server
5. Boot iOS simulator
6. Install app on simulator
7. Run Appium tests
8. Upload test results and logs as artifacts

### Test Results
Test results and logs are uploaded as GitHub Actions artifacts and can be downloaded from the Actions tab.

## Test Structure

- `test_runner.py` - Main test runner script
- `tests/` - Test files organized by feature
- `utils/` - Utility classes and helper functions
- `base_test.py` - Base test class with common setup/teardown
- `driver_setup.py` - Appium driver configuration

## Troubleshooting

### Common Issues
1. **Simulator not booting**: Check Xcode version and simulator availability
2. **Appium server not starting**: Verify Node.js installation and port availability
3. **App not installing**: Check build configuration and app path
4. **Tests failing**: Check simulator state and app installation

### Logs
- Appium server logs: `appium.log`
- Test execution logs: `AppiumTests/logs/test_output.log`
- Test results summary: `AppiumTests/test-results/summary.txt` 