import sys
import os
import time
import unittest
from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.common.by import By
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from tests.base_test import BaseTest
from tests import google_login, logout
from utils import config

class DeleteAccountUserATest(BaseTest):
    def test_setting_items(self):
        """login"""
        google_login(self.driver, 'user_a')

        """accpet map location permission"""
        # if the alert is shown, allow
        # if the alert is not shown, skip
        try:
            self.driver.switch_to.alert.accept()
        except:
            print("Map location permission not shown")
        time.sleep(1)

        """check setting items"""
         # tap "Personal Library"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Personal Library')
        element.click()
        time.sleep(2)

        """privacy policy"""
        # tap Privacy Policy
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Privacy Policy')
        element.click()
        time.sleep(5)
        # will take screenshot
        # go back to settings
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Settings')
        element.click()
        time.sleep(2)
        
        """terms of service"""
        # tap Terms of Service
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Terms of Service')
        element.click()
        time.sleep(5)
        # will take screenshot
        # go back to settings
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Settings')
        element.click()
        time.sleep(2)

        """app version"""
        # check app version in App Version cell
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'App Version')
        # make sure the element is visible
        assert element.is_displayed()
        # check the actual version number, accessbility app_version_text
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'app_version_text')
        # make sure the element is visible
        assert element.is_displayed()

        """licenses"""
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
        
        """delete account"""
        # find and tap "Account"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Account')
        element.click()
        time.sleep(2)
        # find and tap "Delete Account"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Delete Account')
        element.click()
        # tap "confirm"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Confirm')
        element.click()
        time.sleep(2)
        # tap "OK"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Delete')
        element.click()
        time.sleep(2)
        # make sure the screen goes back to the launch screen
        google_login_button = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Continue with Google')
        assert google_login_button.is_displayed()

if __name__ == '__main__':
    unittest.main()