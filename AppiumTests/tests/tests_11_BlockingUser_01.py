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

class BlockingUserAsNonOwnerTest(BaseTest):
    def test_blocking_user_as_non_owner(self):
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

        """block user"""
        # tap "Personal Library"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Personal Library')
        element.click()
        time.sleep(2)
        # tap "Friend List"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Friend List')
        element.click()
        time.sleep(2)
        # tap "User B"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'User A')
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
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'User A')
        assert element.is_displayed()

        """Make sure the collection is not shared with the blocked user"""
        # back to settings
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Settings')
        element.click()
        time.sleep(2)
        # back to Home
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Back')
        element.click()
        time.sleep(2)
        # middle dot
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'middle_dot')
        element.click()
        time.sleep(2)
        # click the search button icon
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Search')
        element.click()
        time.sleep(2)
        # type "Pinnacles National Park" in the sarch bar
        search_bar = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Search for a place')
        search_bar.click()
        search_bar.send_keys('yose')
        time.sleep(2)
        search_bar.send_keys('mite ')
        time.sleep(2)
        search_bar.send_keys('National')
        time.sleep(2)

        # click the first suggestion from the search result, not mentioning the name
        element = self.driver.find_element(By.XPATH, '//XCUIElementTypeCell[1]')
        element.click()
        time.sleep(2)

        # check the title of the space
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Yosemite National Park')
        # click the save button with accessibiliy id "bookmark"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'bookmark')
        element.click()
        time.sleep(2)

        # check the title of the modal
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Save to Collection')
        # click the shared collection
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'From Friends')
        element.click()
        time.sleep(2)
        # you do not see the collection called "National Parks"
        elements = self.driver.find_elements(AppiumBy.ACCESSIBILITY_ID, 'National Parks')
        assert len(elements) == 0, "Element 'National Parks' was found when it should not exist"
        time.sleep(2)

        # tap close button
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Close')
        element.click()
        time.sleep(2)
        # tap the center of the screen to close the modal
        self.driver.tap([(500, 500)])
        time.sleep(2)

        """Make sure the shared collection is not listed"""
        # tap right dot
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'right_dot')
        element.click()
        time.sleep(2)
        # tap sparkle button
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'sparkle')
        element.click()
        time.sleep(2)
        # tap From Friends
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'From Friends')
        element.click()
        time.sleep(2)
        # you do not see the collection called "National Parks"
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