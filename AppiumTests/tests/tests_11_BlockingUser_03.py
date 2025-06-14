import sys
import os
import time
import unittest
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from utils import shared_data, config
from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys

from tests.base_test import BaseTest
from tests import google_login, logout

class BlockingUserAsNonOwnerUnblockedTest(BaseTest):
    def test_blocking_user_as_non_owner_unblocked(self):
        """login"""
        google_login(self.driver, 'user_b')

        """accpet map location permission"""
        # if the alert is shown, allow
        # if the alert is not shown, skip
        try:
            self.driver.switch_to.alert.accept()
        except:
            print("Map location permission not shown")
        time.sleep(1)

        """Unblock user A"""
        # tap "Personal Library"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Personal Library')
        element.click()
        time.sleep(2)
        # tap "Friend List"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Friend List')
        element.click()
        time.sleep(2)
        # tap "User A"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'User A')
        element.click()
        time.sleep(2)
        # tap "Unblock User"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Unblock User')
        element.click()
        time.sleep(2)
        # tap "Unblock"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Unblock')
        element.click()
        time.sleep(2)
        # make sure "User A" is not in the list
        elements = self.driver.find_elements(AppiumBy.ACCESSIBILITY_ID, 'User A')
        assert len(elements) == 0, "Element 'User A' was found when it should not exist"
        time.sleep(2)
        # go back to settings
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Settings')
        element.click()
        time.sleep(2)

        """log out"""
        logout(self.driver)

if __name__ == '__main__':
    unittest.main()