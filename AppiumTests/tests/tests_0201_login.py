import sys
import os
import time
import unittest
from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.common.by import By
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from tests.base_test import BaseTest

class LoginTest(BaseTest):
    def test_google_log_in(self):
        # Find a google login button says "Continue with Google"
        google_login_button = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Continue with Google')
        # click the button
        google_login_button.click()
        time.sleep(2)

        # click on the button on the iOS alert
        self.driver.switch_to.alert.accept()
        time.sleep(2)

        # for logged in account
        # click one of the account
        element = self.driver.find_element(By.XPATH, '//XCUIElementTypeLink[@name="Tamaki Fujino tamakifujino526@gmail.com"]')
        element.click()
        time.sleep(2)
        # find and click the button with accessibility id "Continue"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Continue')
        element.click()
        time.sleep(10)

if __name__ == '__main__':
    unittest.main()