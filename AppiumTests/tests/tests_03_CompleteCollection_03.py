import sys
import os
import time
import unittest
from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.common.by import By
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from tests.base_test import BaseTest
from tests import google_login, logout
from utils import config

class CollectionPutBackTest(BaseTest):
    def test_collection_put_back(self):
        """login"""
        google_login(self.driver, 'user_a')

        """put back the collection"""
        # tap past dot
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'left_dot')
        element.click()
        time.sleep(2)
        # find a button with accessibility id "archive"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'archive')
        element.click()
        time.sleep(2)
        # make sure the modal title is "Completed Collections"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Completed Collections')
        assert element.is_displayed()
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
        # put back the collection
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Put back collection')
        element.click()
        time.sleep(5)
        # swipe down to close the modal
        self.driver.swipe(200, 350, 500, 650)
        time.sleep(2)
        # tap somewhere on the screen to close the modal
        self.driver.tap([(200, 200)])

        """log out"""
        logout(self.driver)

if __name__ == '__main__':
    unittest.main()