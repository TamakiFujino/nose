import sys
import os
import time
import unittest
from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.common.by import By
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from tests.base_test import BaseTest

class HomeFutureTest(BaseTest):
    def test_home_future(self):
        # which is the future dot
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
        # check the number of spots is 1
        # element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, '2')
        # assert element.text == '1 spot'
        # tap three dot button
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'More')
        element.click()
        time.sleep(2)
        # tap "Share with Friends"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Share with Friends')
        element.click()
        time.sleep(2)
        # select User B
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, '{config.TEST_USERS["user_b"]["display_name"]}')
        element.click()
        time.sleep(2)
        # tap "Share"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Share')
        element.click()
        # tap "close"
        # element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'close')
        # element.click()
        
        # complete the collection
        # tap "Complete"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Complete the Collection')
        element.click()
        time.sleep(2)
        # tap "Complete"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Complete')
        element.click()
        time.sleep(5)
        # tap the center of the screen to close the modal
        self.driver.tap([(500, 500)])
        time.sleep(2)

if __name__ == '__main__':
    unittest.main()