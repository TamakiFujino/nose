import time
import unittest
from appium import webdriver
from appium.webdriver.common.appiumby import AppiumBy
from appium.options.ios import XCUITestOptions
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys

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
        # Find google login button and click it
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'GIDSignInButton')
        element.click()

        # click on the button on the iOS alert
        self.driver.switch_to.alert.accept()
        time.sleep(3)

        # for logged in account
        # click one of the account
        # element = self.driver.find_element(By.XPATH, '//XCUIElementTypeLink[@name="Tamaki Fujino tamakifujino526@gmail.com"]')
        # click the Continue button
        # element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Continue')
        # element.click()
        # time.sleep(3)

        # for not logged in account
        # click new login button
        element = self.driver.find_element(By.XPATH, '//XCUIElementTypeOther[@name="ログイン - Google アカウント"]/XCUIElementTypeOther[4]/XCUIElementTypeOther[2]')
        element.click()
        time.sleep(3)

        # find the email input field and input the email by not accessibility id
        element = self.driver.find_element(By.XPATH, '//XCUIElementTypeTextField')
        element.send_keys('tamaki.fujino.yd@gmail.com') 
        element.send_keys(Keys.RETURN)
        time.sleep(3)

        # find the password input field and input the password
        element = self.driver.find_element(By.XPATH, '//XCUIElementTypeSecureTextField')
        element.send_keys('YDta8ma2ki3')
        element.send_keys(Keys.RETURN)
        time.sleep(5)

        # click the Allow Once button of iOS's location permission
        # self.driver.switch_to.alert.accept()
        # element.click()

    def tearDown(self):
        # Quit the driver
        self.driver.quit()

if __name__ == '__main__':
    unittest.main()