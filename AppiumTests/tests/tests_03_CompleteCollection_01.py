import sys
import os
import time
import unittest
from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.common.by import By
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from tests.base_test import BaseTest
from tests import google_login, logout

class CollectionCompleteTest(BaseTest):
    def test_collection_complete(self):
        """login"""
        google_login(self.driver, 'user_a')

        """move to the future dot"""
        # the future dot
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'right_dot')
        element.click()
        time.sleep(2)
        # find a button with accessibility id "sparkle"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'sparkle')
        element.click()
        time.sleep(2)
        # make sure the modal title is "My Collections"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'My Collections')
        assert element.text == 'My Collections'
        # tap "National Parks" collection
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'National Parks')
        element.click()
        time.sleep(2)
        # check the saved spot is listed
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Kings Canyon National Park')
        assert element.text == 'Kings Canyon National Park'
        
        """complete the collection"""
        # tap three dot button
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'More')
        element.click()
        time.sleep(2)
        # tap "Complete the Collection"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Complete the Collection')
        element.click()
        time.sleep(2)
        # tap "Complete"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Complete')
        element.click()
        time.sleep(5)
        # tap somewhere on the screen to close the modal
        self.driver.tap([(200, 200)])
        time.sleep(2)

        """log out"""
        logout(self.driver)

if __name__ == '__main__':
    unittest.main()