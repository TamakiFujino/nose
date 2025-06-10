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

class AccountCreateUserBTest(BaseTest):
    def test_create_user_b(self):
        """create an account"""
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

        print(f"Done create an account: {__file__}")

        """accpet map location permission"""
        # if the alert is shown, allow
        # if the alert is not shown, skip
        try:
            self.driver.switch_to.alert.accept()
        except:
            print("Map location permission not shown")
        time.sleep(1)
            
        """Add user A as a friend"""
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
        
        # Load User A's ID from the stored data
        user_a_id = shared_data.load_user_id('user_a')
        if not user_a_id:
            raise Exception("User A ID not found in stored data. Please run User A creation test first.")
        element.send_keys(user_a_id)
        # enter
        element.send_keys(Keys.RETURN)
        time.sleep(1)
        # find and tap a button "Add Friend"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'add_friend_button')
        element.click()
        time.sleep(1)
        # Dismiss the confirmation alert by tapping "OK"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'OK')
        element.click()
        time.sleep(1)

        """Copy user B's user ID and store in shared_data"""
        # tap copy icon and save the text for later use
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'copy')
        element.click()
        time.sleep(1)
        user_id = self.driver.get_clipboard_text()
        print(f"User B User ID: {user_id}")
        # Save the user ID for later use
        shared_data.save_user_id('user_b', user_id)

        # Go back to the settings
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Settings')
        element.click()
        time.sleep(1)

        print(f"Done add user A as a friend: {__file__}")

        """Update user B's name"""
        # find "Name" and tap it
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Name')
        element.click()
        time.sleep(2)
        
        # input 1 characters
        # input an updated name
        element = self.driver.find_element(By.CLASS_NAME, 'XCUIElementTypeTextField')
        element.click()
        # clear the text
        element.clear()
        element.send_keys('1')
        # tap button "Save"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Save')
        element.click()
        # see the alert class name XCUIElementTypeAlert
        element = self.driver.find_element(By.CLASS_NAME, 'XCUIElementTypeAlert')
        assert element.is_displayed()
        time.sleep(1)
        # tap "OK"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'OK')
        element.click()
        time.sleep(1)

        # input 31 characters
        # input an updated name
        element = self.driver.find_element(By.CLASS_NAME, 'XCUIElementTypeTextField')
        element.click()
        # clear the text
        element.clear()
        element.send_keys('1234567890123456789012345678901')
        # tap button "Save"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Save')
        element.click()
        # see the alert class name XCUIElementTypeAlert
        element = self.driver.find_element(By.CLASS_NAME, 'XCUIElementTypeAlert')
        assert element.is_displayed()
        time.sleep(1)
        # tap "OK"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'OK')
        element.click()
        time.sleep(1)

        # input an updated name
        element = self.driver.find_element(By.CLASS_NAME, 'XCUIElementTypeTextField')
        element.click()
        # clear the text
        element.clear()
        element.send_keys(config.TEST_USERS['user_b']['updated_name'])
        # tap "Save"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Save')
        element.click()
        time.sleep(2)
        # tap OK
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'OK')
        element.click()
 
        # make sure the screen goes back to the Settings
        # find "Name"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Name')
        assert element.text == 'Name'
        time.sleep(2)

        # go back to the home screen
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Back')
        element.click()
        time.sleep(1)

        print(f"Done update user B's name: {__file__}")

        """Log out"""
        logout(self.driver)

        print(f"Done log out: {__file__}")

        # swipe down to close the modal
        self.driver.swipe(200, 350, 200, 650)
        time.sleep(2)
        # tap somewhere on the screen to close the modal
        self.driver.tap([(200, 200)])
        time.sleep(2)

if __name__ == '__main__':
    unittest.main() 