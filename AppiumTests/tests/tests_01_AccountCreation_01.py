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

class AccountCreateUserATest(BaseTest):
    def test_create_user_a(self):
        """create an account"""
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
        
        """accpet map location permission"""
        # if the alert is shown, allow
        # if the alert is not shown, skip
        try:
            self.driver.switch_to.alert.accept()
        except:
            print("Map location permission not shown")
        time.sleep(1)

        # print file name and done create an account
        print(f"Done create an account: {__file__}")

        """copy user id"""
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
        user_id = self.driver.get_clipboard_text()
        print(f"User A User ID: {user_id}")
        # Save the user ID for later use
        shared_data.save_user_id('user_a', user_id)
        
        # go back to the settings
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Settings')
        element.click()
        time.sleep(1)

        # go back to the home screen
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Back')
        element.click()
        time.sleep(1)

        print(f"Done copy user id: {__file__}")

        """Log out"""
        logout(self.driver)

        print(f"Done log out: {__file__}")

if __name__ == '__main__':
    unittest.main() 