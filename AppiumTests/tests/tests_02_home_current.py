import sys
import os
import time
import unittest
from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.common.by import By
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from tests.base_test import BaseTest

class HomeCurrentTest(BaseTest):
    def test_home_current(self):
        # click the first option in the alert modal
        # element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'OK')
        # element.click()
        # time.sleep(2)

        # click the search button icon
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Search')
        element.click()
        time.sleep(2)

        # type "Kings Canyon national park" in the sarch bar
        search_bar = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Search for a place')
        search_bar.click()
        search_bar.send_keys('Ki')
        time.sleep(2)
        search_bar.send_keys('ngs ')
        time.sleep(2)
        search_bar.send_keys('Canyon')
        time.sleep(2)

        # click the first suggestion from the search result, not mentioning the name
        element = self.driver.find_element(By.XPATH, '//XCUIElementTypeCell[1]')
        element.click()
        time.sleep(2)

        # check the title of the space
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Kings Canyon National Park')
        # click the save button with accessibiliy id "bookmark"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'bookmark')
        element.click()
        time.sleep(2)

        # check the title of the modal
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Save to Collection')
        # click add button
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'add')
        element.click()
        time.sleep(2)
        # find "XCUIElementTypeTextField", and type "National Parks" in the text field
        text_field = self.driver.find_element(By.XPATH, '//XCUIElementTypeTextField')
        text_field.click()
        text_field.send_keys('National Parks')
        # tap Create
        create_button = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Create')
        create_button.click()
        time.sleep(2)
        # click save button
        save_button = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Save')
        save_button.click()
        time.sleep(2)

        # tap the center of the screen to close the modal
        self.driver.tap([(500, 500)])
        time.sleep(2)

if __name__ == '__main__':
    unittest.main()