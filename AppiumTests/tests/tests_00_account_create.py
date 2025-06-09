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

class AccountCreateTest(BaseTest):
    def test_create_user_a(self):
        """Test creating User A and getting their User ID"""
        # Find a google login button says "Continue with Google"
        google_login_button = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Continue with Google')
        google_login_button.click()
        time.sleep(2)

        # click on the button on the iOS alert
        self.driver.switch_to.alert.accept()
        time.sleep(3)

        # click one of the account
        element = self.driver.find_element(By.XPATH, f'//XCUIElementTypeLink[@name="{config.TEST_USERS["user_a"]["name"]} {config.TEST_USERS["user_a"]["email"]}"]')
        element.click()
        time.sleep(2)

        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Continue')
        element.click()
        time.sleep(7)

        # see the text What should we call you?
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'What should we call you?')
        assert element.text == 'What should we call you?'
        # find and tap XCUIElementTypeTextField
        element = self.driver.find_element(By.CLASS_NAME, 'XCUIElementTypeTextField')
        element.click()

        # input 1 character
        element.send_keys('1')
        # tap button XCUIElementTypeButton "Continue"
        element = self.driver.find_element(By.CLASS_NAME, 'XCUIElementTypeButton')
        element.click()
        # see the alert XCUIElementTypeAlert[`name == "Error"`]
        element = self.driver.find_element(By.XPATH, '//XCUIElementTypeAlert[@name="Error"]')
        assert element.text == 'Error'
        time.sleep(1)
        # tap "OK"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'OK')
        element.click()
        time.sleep(1)

        # input 31 characters
        element = self.driver.find_element(By.CLASS_NAME, 'XCUIElementTypeTextField')
        element.click()
        # clear the text
        element.clear()
        element.send_keys('1234567890123456789012345678901')
        # tap button XCUIElementTypeButton "Continue"
        element = self.driver.find_element(By.CLASS_NAME, 'XCUIElementTypeButton')
        element.click()
        # see the alert XCUIElementTypeAlert[`name == "Error"`]
        element = self.driver.find_element(By.XPATH, '//XCUIElementTypeAlert[@name="Error"]')
        assert element.text == 'Error'
        time.sleep(1)
        # tap "OK"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'OK')
        element.click()
        time.sleep(1)

        # input name "User A"
        element = self.driver.find_element(By.CLASS_NAME, 'XCUIElementTypeTextField')
        element.click()
        # clear the text
        element.clear()
        element.send_keys(config.TEST_USERS['user_a']['display_name'])
        # tap button XCUIElementTypeButton "Continue"
        element = self.driver.find_element(By.CLASS_NAME, 'XCUIElementTypeButton')
        element.click()
        time.sleep(5)

        # tap "Personal Library"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Personal Library')
        element.click()
        time.sleep(1)

        # check Friend ID
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Add Friend')
        element.click()
        time.sleep(1)
        # tap "Add Friend"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Add Friend')
        element.click()
        time.sleep(1)
        # tap copy icon and save the text for later use
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'copy')
        element.click()
        time.sleep(1)
        shared_data.userA_userid = self.driver.get_clipboard_text()
        print(f"User A User ID: {shared_data.userA_userid}")
        # go back to the settings
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Settings')
        element.click()
        time.sleep(1)

        # log out
        # find and tap "Account"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Account')
        element.click()
        time.sleep(1)
        # find and tap "Log Out"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Logout')
        element.click()
        time.sleep(1)
        # tap "Confirm"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Confirm')
        element.click()
        time.sleep(1)
        # tap "OK" in the confirmation alert
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'OK')
        element.click()
        time.sleep(3)

    def test_create_user_b(self):
        """Test creating User B and adding User A as friend"""
        # Find a google login button says "Continue with Google"
        google_login_button = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Continue with Google')
        google_login_button.click()
        time.sleep(2)

        # click on the button on the iOS alert
        self.driver.switch_to.alert.accept()
        time.sleep(3)

        # click one of the account
        element = self.driver.find_element(By.XPATH, f'//XCUIElementTypeLink[@name="{config.TEST_USERS["user_b"]["name"]} {config.TEST_USERS["user_b"]["email"]}"]')
        element.click()
        time.sleep(2)

        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, '次へ')
        element.click()
        time.sleep(7)

        # see the text What should we call you?
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'What should we call you?')
        assert element.text == 'What should we call you?'
        # input name "User B"
        element = self.driver.find_element(By.CLASS_NAME, 'XCUIElementTypeTextField')
        element.click()
        # clear the text
        element.clear()
        element.send_keys(config.TEST_USERS['user_b']['display_name'])
        # tap button XCUIElementTypeButton "Continue"
        element = self.driver.find_element(By.CLASS_NAME, 'XCUIElementTypeButton')
        element.click()
        time.sleep(5)

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
        element.send_keys(shared_data.userA_userid)
        # enter
        element.send_keys(Keys.RETURN)
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

        # log out
        # find and tap "Account"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Account')
        element.click()
        time.sleep(1)
        # find and tap "Log Out"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Logout')
        element.click()
        time.sleep(1)
        # tap "Confirm"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Confirm')
        element.click()
        time.sleep(1)
        # tap "OK" in the confirmation alert
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'OK')
        element.click()
        time.sleep(1)

if __name__ == '__main__':
    unittest.main() 