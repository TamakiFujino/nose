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

class BlockingUserAsNonOwnerBlockedTest(BaseTest):
    def test_blocking_user_as_non_owner_blocked(self):
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

        """Make sure the shared collection is not listed"""
        # tap right dot
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'right_dot')
        element.click()
        time.sleep(2)
        # tap sparkle button
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'sparkle')
        element.click()
        time.sleep(2)
        # tap National Parks
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'National Parks')
        element.click()
        time.sleep(2)
        # the number of shared collections is 1
        friends_value = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'shared_friends_count_label').get_attribute("value")
        assert friends_value == '1', "Shared friends count is not 1"
        # tap three dots
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'More')
        element.click()
        time.sleep(2)
        # tap "Share with Friends"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Share with Friends')
        element.click()
        time.sleep(2)
        # you do not see the user B in the list
        elements = self.driver.find_elements(AppiumBy.ACCESSIBILITY_ID, 'User B')
        assert len(elements) == 0, "Element 'User B' was found when it should not exist"
        # tap close button
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'close')
        element.click()
        time.sleep(2)
        # swipe down to close the modal
        self.driver.swipe(300, 350, 300, 650)
        time.sleep(2)
        # tap somewhere on the screen to close the modal
        self.driver.tap([(200, 200)])
        time.sleep(2)

        """log out"""
        logout(self.driver)

if __name__ == '__main__':
    unittest.main()