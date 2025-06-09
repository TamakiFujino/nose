import sys
import os
import time
import unittest
from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.common.by import By
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from tests.base_test import BaseTest

class AccountNameEditTest(BaseTest):
    def test_account_name_edit(self):
        # tap "Personal Library"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Personal Library')
        element.click()
        time.sleep(2)
        # find and tap "Name"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Name')
        element.click()
        time.sleep(2)

        # find class XCUIElementTypeTextField and tap
        element = self.driver.find_element(By.CLASS_NAME, 'XCUIElementTypeTextField')
        element.click()
        # clear the text
        element.clear()

        # input 1 character
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
        element.send_keys("Name Updated")
        # tap "Save"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Save')
        element.click()
        time.sleep(2)
        # tap OK
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'OK')
        element.click()
        time.sleep(2)
        # make sure the screen goes back to the Settings
        # find "Name"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Name')
        assert element.text == 'Name'
        time.sleep(2)

if __name__ == '__main__':
    unittest.main()