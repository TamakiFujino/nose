import sys
import os
import time
import unittest
from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.common.by import By
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from tests.base_test import BaseTest

class DeleteAccountTest(BaseTest):
    def test_delete_account(self):
         # tap "Personal Library"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Personal Library')
        element.click()
        time.sleep(2)

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
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'OK')
        element.click()
        time.sleep(2)
        # make sure the screen goes back to the launch screen
        google_login_button = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Continue with Google')
        assert google_login_button.is_displayed()


if __name__ == '__main__':
    unittest.main()