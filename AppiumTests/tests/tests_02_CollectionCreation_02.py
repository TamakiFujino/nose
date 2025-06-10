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

class CollectionSharedTest(BaseTest):
    def test_collection_shared(self):
        """login"""
        google_login(self.driver, 'user_b')

        """search a spot"""
        # click the search button icon
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Search')
        element.click()
        time.sleep(2)

        # type "Pinnacles National Park" in the sarch bar
        search_bar = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Search for a place')
        search_bar.click()
        search_bar.send_keys('Pin')
        time.sleep(2)
        search_bar.send_keys('nacles ')
        time.sleep(2)
        search_bar.send_keys('National')
        time.sleep(2)

        # click the first suggestion from the search result, not mentioning the name
        element = self.driver.find_element(By.XPATH, '//XCUIElementTypeCell[1]')
        element.click()
        time.sleep(2)

        # check the title of the space
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Pinnacles National Park')
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
        # tap the first collection called "National Parks"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'National Parks')
        element.click() 
        time.sleep(2)

        # click save button to the shared collection
        save_button = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Save')
        save_button.click()
        time.sleep(2)

         # tap the center of the screen to close the modal
        self.driver.tap([(500, 500)])
        time.sleep(2)

        """see the shared collection detail"""
        # the future dot
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'right_dot')
        element.click()
        time.sleep(2)
        # find a button with accessibility id "sparkle"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'sparkle')
        element.click()
        time.sleep(2)

        # click the shared collection
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'From Friends')
        element.click()
        time.sleep(2)
 
        # tap "National Parks" collection
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'National Parks')
        element.click()
        time.sleep(2)

        # check the saved spot from a friend is listed
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Kings Canyon National Park')
        # make sure the element is visible
        assert element.is_displayed()

        # check the saved spot from myself is listed
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Pinnacles National Park')
        assert element.is_displayed()

        # make sure there is no element with accessibility id "More"
        elements = self.driver.find_elements(AppiumBy.ACCESSIBILITY_ID, 'More')
        assert len(elements) == 0, "Element 'More' was found when it should not exist"

        # swipe down to close the modal
        self.driver.swipe(200, 350, 500, 650)
        time.sleep(2)
        # tap somewhere on the screen to close the modal
        self.driver.tap([(200, 200)])
        time.sleep(2)

        """log out"""
        logout(self.driver)

    def test_swipe_element_left(self):
        """login"""
        google_login(self.driver, 'user_b')

        # Navigate to Personal Library
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Personal Library')
        element.click()
        time.sleep(2)

        # Find the element to swipe
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'National Parks')
        
        # Get element location and size
        location = element.location
        size = element.size
        
        # Calculate swipe coordinates
        start_x = location['x'] + size['width'] * 0.8  # Start from 80% of element width
        start_y = location['y'] + size['height'] * 0.5  # Middle of element height
        end_x = location['x'] + size['width'] * 0.2    # End at 20% of element width
        end_y = start_y  # Keep same y coordinate for horizontal swipe
        
        # Perform the swipe
        self.driver.swipe(start_x, start_y, end_x, end_y)
        time.sleep(2)

        """log out"""
        logout(self.driver)

if __name__ == '__main__':
    unittest.main()