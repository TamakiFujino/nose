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

class DeleteCollectionTest(BaseTest):
    def test_delete_collection(self):
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

        """unshare the collection"""
        # the future dot
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'right_dot')
        element.click()
        time.sleep(2)
        # find a button with accessibility id "sparkle"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'sparkle')
        element.click()
        time.sleep(2)
        # tap "National Parks" collection
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'National Parks')
        element.click()
        time.sleep(2)
        # make sure you do not see "Pinnacles National Park"
        elements = self.driver.find_elements(AppiumBy.ACCESSIBILITY_ID, 'Pinnacles National Park')
        assert len(elements) == 0, "Element 'Pinnacles National Park' was found when it should not exist"
        time.sleep(2)
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
        # see the text "Will be removed"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Will be removed')
        assert element.is_displayed()
        # tap "Share"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Update Sharing')
        element.click()
        time.sleep(2)
        # check the number of shared collections is 1
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'shared_friends_count_label')
        assert element.get_attribute("value") == '1', "Number of shared collections is not 1"

        """delete a spot from the collection"""
        # check the saved spot from myself is listed
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Kings Canyon National Park')
        assert element.is_displayed()
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

        # Click delete button //XCUIElementTypeButton[@name="Delete"] that appears after swipe
        delete_button = self.driver.find_element(By.XPATH, '//XCUIElementTypeButton[@name="Delete"]')
        delete_button.click()
        time.sleep(2)

        # click the "Delete" button of the modal
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Delete')
        element.click()
        time.sleep(2)

        # swipe down to close the modal
        self.driver.swipe(200, 350, 500, 650)
        time.sleep(2)
        # tap somewhere on the screen to close the modal
        self.driver.tap([(200, 200)])
        time.sleep(2)
        
        """reload the modal and make sure the spot is deleted"""
        # the future dot
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'right_dot')
        element.click()
        time.sleep(2)
        # find a button with accessibility id "sparkle"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'sparkle')
        element.click()
        time.sleep(2)

        # tap "National Parks" collection
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'National Parks')
        element.click()
        time.sleep(2)

        # make sure the spot is deleted
        elements = self.driver.find_elements(AppiumBy.ACCESSIBILITY_ID, 'Kings Canyon National Park')
        assert len(elements) == 0, "Element 'Kings Canyon National Park' was found when it should not exist"

        """delete the collection"""
        # tap three dot button
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'More')
        element.click()
        time.sleep(2)
        # tap "Delete Collection"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Delete Collection')
        element.click()
        time.sleep(2)
        # tap "Delete"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Delete')
        element.click()
        time.sleep(5)

        # see the title of "My Collections"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'My Collections')
        assert element.is_displayed()
        # tap somewhere on the screen to close the modal
        self.driver.tap([(200, 200)])
        time.sleep(2)

        """reload the modal and make sure the collection is deleted"""
        # the future dot
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'right_dot')
        element.click()
        time.sleep(2)
        # find a button with accessibility id "sparkle"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'sparkle')
        element.click()
        time.sleep(2)
        # Make sure National Parks is not listed
        elements = self.driver.find_elements(AppiumBy.ACCESSIBILITY_ID, 'National Parks')
        assert len(elements) == 0, "Element 'National Parks' was found when it should not exist"

        # tap somewhere on the screen to close the modal
        self.driver.tap([(200, 200)])
        time.sleep(2)

        """log out"""
        logout(self.driver)

if __name__ == '__main__':
    unittest.main()