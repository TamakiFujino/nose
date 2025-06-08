import sys
import os
import time
import unittest
from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.common.by import By
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from tests.base_test import BaseTest

class AccountCreateTest(BaseTest):
    def test_account_create(self):
        # Find a google login button says "Continue with Google"
        google_login_button = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Continue with Google')
        google_login_button.click()
        time.sleep(2)

        # click on the button on the iOS alert
        self.driver.switch_to.alert.accept()
        time.sleep(3)

        # click new login button
        # element = self.driver.find_element(By.XPATH, '//XCUIElementTypeOther[@name="ログイン - Google アカウント"]/XCUIElementTypeOther[4]/XCUIElementTypeOther[2]')
        # element.click()
        # time.sleep(3)

        # find the email input field and input the email by not accessibility id
        # element = self.driver.find_element(By.XPATH, '//XCUIElementTypeTextField')
        # element.send_keys('email@gmail.com') 
        # element.send_keys(Keys.RETURN)
        # time.sleep(3)

        # find the password input field and input the password
        # element = self.driver.find_element(By.XPATH, '//XCUIElementTypeSecureTextField')
        # element.send_keys('YourPassword')
        # element.send_keys(Keys.RETURN)
        # time.sleep(5)

         # click one of the account
        element = self.driver.find_element(By.XPATH, '//XCUIElementTypeLink[@name="Tamaki Fujino tamakifujino526@gmail.com"]')
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
        time.sleep(2)
        # tap "OK"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'OK')
        element.click()
        time.sleep(2)

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
        time.sleep(2)
        # tap "OK"
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'OK')
        element.click()
        time.sleep(2)

        # input name "User A"
        element = self.driver.find_element(By.CLASS_NAME, 'XCUIElementTypeTextField')
        element.click()
        # clear the text
        element.clear()
        element.send_keys('User A')
        # tap button XCUIElementTypeButton "Continue"
        element = self.driver.find_element(By.CLASS_NAME, 'XCUIElementTypeButton')
        element.click()
        time.sleep(5)

if __name__ == '__main__':
    unittest.main()