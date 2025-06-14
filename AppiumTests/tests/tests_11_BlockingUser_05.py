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

class BlockingUserTest(BaseTest):
    def test_being_blocked(self):
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

        """Try to add a user as a friend"""
        # tap "Personal Library"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Personal Library')
        element.click()
        time.sleep(2)
        # tap "Add Friend"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Add Friend')
        element.click()
        time.sleep(2)
        # tap "Search by User ID"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Search by User ID')
        element.click()
        # Load User A's ID from the stored data
        user_a_id = shared_data.load_user_id('user_a')
        if not user_a_id:
            raise Exception("User A ID not found in stored data. Please run User A creation test first.")
        element.send_keys(user_a_id)
        # enter
        element.send_keys(Keys.RETURN)
        # Check the error message //XCUIElementTypeStaticText[@name="User Not Found"]
        element = self.driver.find_element(By.XPATH, '//XCUIElementTypeStaticText[@name="User Not Found"]')
        assert element.is_displayed()
        time.sleep(2)
        # click OK
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'OK')
        element.click()
        time.sleep(2)

        """Make sure the collection is not shared with the blocked user"""
        # back to settings
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Settings')
        element.click()
        time.sleep(2)
        # back to Home
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Back')
        element.click()
        time.sleep(2)
        # future dot
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'right_dot')
        element.click()
        time.sleep(2)
        # tap sparkle button
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'sparkle')
        element.click()
        time.sleep(2)
        # tap "From Friends" tab
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'From Friends')
        element.click()
        time.sleep(2)
        # do not see National Parks
        elements = self.driver.find_elements(AppiumBy.ACCESSIBILITY_ID, 'National Parks')
        assert len(elements) == 0, "Element 'National Parks' was found when it should not exist"
        time.sleep(2)
        # tap somewhere on the screen to close the modal
        self.driver.tap([(200, 200)])
        time.sleep(2)

        """log out"""
        logout(self.driver)


if __name__ == '__main__':
    unittest.main()