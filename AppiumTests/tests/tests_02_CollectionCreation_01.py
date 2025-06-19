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

class CollectionCreationTest(BaseTest):
    def test_create_collection(self):
        """login"""
        google_login(self.driver, 'user_a')

        print(f"Done login: {__file__}")

        """accpet map location permission"""
        # if the alert is shown, allow
        # if the alert is not shown, skip
        try:
            self.driver.switch_to.alert.accept()
        except:
            print("Map location permission not shown")
        time.sleep(1)

        """search a spot"""
        # click the search button icon
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Search')
        element.click()
        time.sleep(2)

        # type "Kings Canyon national park" in the sarch bar
        search_bar = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Search for a place')
        search_bar.click()
        search_bar.send_keys('K')
        time.sleep(1)
        search_bar.send_keys('i')
        time.sleep(1)
        search_bar.send_keys('n')
        time.sleep(1)
        search_bar.send_keys('g')
        time.sleep(1)
        search_bar.send_keys('s ')
        time.sleep(1)
        search_bar.send_keys('Canyon ')
        time.sleep(2)
        search_bar.send_keys('National ')
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

        print(f"Done searching a spot: {__file__}")

        """create a collection"""
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

        print(f"Done creating a collection: {__file__}")

        """add a spot to the collection"""
        # click save button
        save_button = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Save')
        save_button.click()
        time.sleep(2)

        # tap the center of the screen to close the modal
        self.driver.tap([(500, 500)])
        time.sleep(2)

        print(f"Done adding a spot to the collection: {__file__}")

        """cannot add a same spot to the collection"""
        # add later

        """check the collection content"""
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

        """check the number of spots is 1"""
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'places_count_label').get_attribute("value")
        assert element == '1', "Number of spots is not 1"

        print(f"Done checking the collection content: {__file__}")

        """share the collection with user B"""
        # tap three dot button
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'More')
        element.click()
        time.sleep(2)
        # tap "Share with Friends"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Share with Friends')
        element.click()
        time.sleep(2)
        # select User B
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, config.TEST_USERS["user_b"]["updated_name"])
        element.click()
        time.sleep(2)
        # tap "Share"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Update Sharing')
        element.click()
        time.sleep(2)
        """check the number of shared collections is 2"""
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'shared_friends_count_label')
        # make sure the element value is 2
        assert element.get_attribute("value") == '2', "Number of shared spots is not 2"

        # swipe down to close the modal
        self.driver.swipe(200, 350, 500, 650)
        time.sleep(2)
        # tap somewhere on the screen to close the modal
        self.driver.tap([(200, 200)])
        time.sleep(2)

        print(f"Done sharing the collection with user B: {__file__}")

        """log out"""
        logout(self.driver)

        print(f"Done log out: {__file__}")

if __name__ == '__main__':
    unittest.main()