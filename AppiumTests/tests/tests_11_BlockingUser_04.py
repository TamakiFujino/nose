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

class BlockingUserAsOwnerTest(BaseTest):
    def test_blocking_user_as_owner(self):
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

        """Add user B as a friend"""
        # tap "Personal Library"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Personal Library')
        element.click()
        time.sleep(1)

        # add user A as a friend
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Add Friend')
        element.click()
        time.sleep(1)
        # tap "Search by User ID"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Search by User ID')
        element.click()
        
        # Load User A's ID from the stored data
        user_b_id = shared_data.load_user_id('user_b')
        if not user_b_id:
            raise Exception("User B ID not found in stored data. Please run User B creation test first.")
        element.send_keys(user_b_id)
        # enter
        element.send_keys(Keys.RETURN)
        time.sleep(1)
        # find and tap a button "Add Friend"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'add_friend_button')
        element.click()
        time.sleep(1)
        # Dismiss the confirmation alert by tapping "OK"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'OK')
        element.click()
        time.sleep(1)
        # Go back to the settings
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Settings')
        element.click()
        time.sleep(1)

        """Block user B"""
        # tap "Friend List"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Friend List')
        element.click()
        time.sleep(2)
        # tap "User B"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'User B')
        element.click()
        time.sleep(2)
        # tap "Block User"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Block User')
        element.click()
        time.sleep(2)
        # tap "Block"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Block')
        element.click()
        time.sleep(2)

        """Check the user is blocked"""
        # tap "Blocked" tab
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Blocked')
        element.click()
        time.sleep(2)
        # make sure "User B" is in the list
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'User B')
        assert element.is_displayed()

        """Try to add a user as a friend"""
        # go back to settings
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Settings')
        element.click()
        time.sleep(2)
        # tap "Add Friend"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Add Friend')
        element.click()
        time.sleep(2)
        # tap "Search by User ID"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Search by User ID')
        element.click()
        # Load User B's ID from the stored data
        user_b_id = shared_data.load_user_id('user_b')
        if not user_b_id:
            raise Exception("User B ID not found in stored data. Please run User B creation test first.")
        element.send_keys(user_b_id)
        # enter
        element.send_keys(Keys.RETURN)
        time.sleep(2)
        # Check the error message and dismiss it
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
        # tap National Parks
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'National Parks')
        element.click()
        time.sleep(2)
        # the number of shared collections is 0
        friends_value = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'shared_friends_count_label').get_attribute("value")
        assert friends_value == '0', "Shared friends count is not 0"
        # the number of saved spots is 1
        places_value = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'places_count_label').get_attribute("value")
        assert places_value == '2', "Number of spots is not 2"
        # tap three dots
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'More')
        element.click()
        time.sleep(2)
        # tap Share collection button
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Share with Friends')
        element.click()
        time.sleep(2)
        # make sure use B is not in the list
        elements = self.driver.find_elements(AppiumBy.ACCESSIBILITY_ID, 'User B')
        assert len(elements) == 0, "Element 'User B' was found when it should not exist"
        time.sleep(2)
        print("done make sure use B is not in the list")
        # tap close button
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'close')
        element.click()
        time.sleep(3)
        # print done this step
        print("done close  shared collection modal")

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