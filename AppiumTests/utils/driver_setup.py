from appium import webdriver
from appium.options.ios import XCUITestOptions

class DriverSetup:
    def __init__(self):
        """ Set up desired capabilities for iOS Appium driver """
        options = XCUITestOptions()
        options.platform_name = 'iOS'
        options.platform_version = '18.2'
        options.device_name = 'iPhone 16 Pro'
        options.app = '/Users/tamakifujino/Library/Developer/Xcode/DerivedData/nose-azrmgrrquncuczcwgevpuqyfssst/Build/Products/Development-iphonesimulator/nose.app'
        options.automation_name = 'XCUITest'

        self.driver = webdriver.Remote('http://localhost:4723', options=options)

    def get_driver(self):
        return self.driver