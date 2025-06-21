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

class DeleteAccountUserBTest(BaseTest):
    def test_delete_account(self):
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

        """check the collection shared with user A is deleted"""
        # tap right dot
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'right_dot')
        element.click()
        time.sleep(2)
        # tap "sparkle"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'sparkle')
        element.click()
        time.sleep(2)
        # tap "From Friends"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'From Friends')
        element.click()
        time.sleep(2)
        # make sure you do not see "National Parks" 
        elements = self.driver.find_elements(AppiumBy.ACCESSIBILITY_ID, 'National Parks')
        assert len(elements) == 0, "Element 'National Parks' was found when it should not exist"
        time.sleep(2)
        # tap somewhere on the screen to close the modal
        self.driver.tap([(200, 200)])
        time.sleep(2)

        """try to add a deleted user as a friend"""
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
        # enter User A's ID
        element.send_keys(shared_data.load_user_id('user_a'))
        # enter
        element.send_keys(Keys.RETURN)
        time.sleep(2)
        # tap "Add Friend"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'add_friend_button')
        element.click()
        time.sleep(2)
        # Check the error message //XCUIElementTypeStaticText[@name="User Not Found"]
        element = self.driver.find_element(By.XPATH, '//XCUIElementTypeStaticText[@name="User Not Found"]')
        assert element.is_displayed()
        # click OK  
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'OK')
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
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'OK')
        element.click()
        time.sleep(2)
        # make sure the screen goes back to the launch screen
        google_login_button = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Continue with Google')
        assert google_login_button.is_displayed()

if __name__ == '__main__':
    unittest.main()