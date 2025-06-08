import sys
import os
import time
import unittest
from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.common.by import By
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from tests.base_test import BaseTest

class HomePastTest(BaseTest):
    def test_home_past(self):
        # tap past dot
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'left_dot')
        element.click()
        time.sleep(2)
        # find a button with accessibility id "sparkle"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'archive')
        element.click()
        time.sleep(2)
        # make sure the modal title is "My Collections"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Completed Collections')
        assert element.text == 'Completed Collections'
        # tap "National Parks" collection
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'National Parks')
        element.click()
        time.sleep(2)
        # check the saved spot is listed
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Kings Canyon National Park')
        assert element.text == 'Kings Canyon National Park'
        # tap three dot button
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'More')
        element.click()
        time.sleep(2)
        # complete the collection
        # tap "Complete"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Put back collection')
        element.click()
        time.sleep(5)
        # tap the center of the screen to close the modal
        self.driver.tap([(500, 500)])
        time.sleep(2)

if __name__ == '__main__':
    unittest.main()