import sys
import os
import time
import unittest
from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.common.by import By
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from tests.base_test import BaseTest

class AccountAboutTest(BaseTest):
    def test_account_about(self):
        # tap Privacy Policy
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Privacy Policy')
        element.click()
        time.sleep(5)
        # will take screenshot
        # go back to settings
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Settings')
        element.click()
        time.sleep(2)
        # tap Terms of Service
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Terms of Service')
        element.click()
        time.sleep(5)
        # will take screenshot
        # go back to settings
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Settings')
        element.click()
        time.sleep(2)
        # check app version in App Version cell
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'App Version')
        assert element.text == 'App Version'
        # check the actual version number later

        # tap Lisences
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Licenses')
        element.click()
        time.sleep(2)
        # see the text "AppAuth" and tap
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'AppAuth')
        element.click()
        time.sleep(2)
        # check the XCUIElementTypeStaticText "AppAuth"
        element = self.driver.find_element(By.CLASS_NAME, 'XCUIElementTypeStaticText')
        assert element.text == 'AppAuth'
        time.sleep(2)
        # tap "Back"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Licenses')
        element.click()
        time.sleep(2)
        # go back to settings
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Settings')
        element.click()
        time.sleep(2)

if __name__ == '__main__':
    unittest.main()