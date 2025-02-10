from appium import webdriver
from appium.options.ios import XCUITestOptions

class DriverSetup:
    def __init__(self):
        """ Set up desired capabilities for iOS Appium driver """
        options = XCUITestOptions()
        options.platform_name = 'iOS'
        options.platform_version = '18.2'  # Update to match your iOS version
        options.device_name = 'iPhone 16 Pro'  # Update to match your simulator/device
        options.app = '/Users/tamakifujino/Library/Developer/Xcode/DerivedData/nose-azrmgrrquncuczcwgevpuqyfssst/Build/Products/Debug-iphonesimulator/nose.app'  # Replace with the actual app path
        options.automation_name = 'XCUITest'
        options.no_reset = True  # Preserve app state between test runs
        options.full_reset = False  # Avoid reinstalling the app

        self.driver = webdriver.Remote('http://localhost:4723', options=options)

    def get_driver(self):
        return self.driver
