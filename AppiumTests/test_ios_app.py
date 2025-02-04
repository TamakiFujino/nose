import unittest
from appium import webdriver
from appium.webdriver.common.appiumby import AppiumBy
from appium.options.ios import XCUITestOptions

class IOSAppiumTest(unittest.TestCase):
    def setUp(self):
        # Define desired capabilities
        options = XCUITestOptions()
        options.platform_name = 'iOS'
        options.platform_version = '18.2'  # Replace with your iOS version
        options.device_name = 'iPhone 16 Pro'  # Replace with your device name
        options.app = '/Users/tamakifujino/Library/Developer/Xcode/DerivedData/nose-azrmgrrquncuczcwgevpuqyfssst/Build/Products/Debug-iphonesimulator/nose.app'  # Replace with the path to your app
        options.automation_name = 'XCUITest'

        # Initialize the driver
        self.driver = webdriver.Remote('http://localhost:4723', options=options)

    def test_example(self):
        # Example: Find an element by accessibility ID and click it
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'GIDSignInButton')
        element.click()

    def tearDown(self):
        # Quit the driver
        self.driver.quit()

if __name__ == '__main__':
    unittest.main()