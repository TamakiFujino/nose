import time
import unittest
from appium import webdriver
from appium.options.ios import XCUITestOptions
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from pages.base_page import BasePage
from appium.webdriver.common.appiumby import AppiumBy


class IOSAppiumTest(unittest.TestCase):
    def test_example(self):
        # Find google login button and click it
        element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'GIDSignInButton')
        element.click()

        # click on the button on the iOS alert
        self.driver.switch_to.alert.accept()
        time.sleep(3)

        # click new login button
        element = self.driver.find_element(By.XPATH, '//XCUIElementTypeOther[@name="ログイン - Google アカウント"]/XCUIElementTypeOther[4]/XCUIElementTypeOther[2]')
        element.click()
        time.sleep(3)

        # find the email input field and input the email by not accessibility id
        element = self.driver.find_element(By.XPATH, '//XCUIElementTypeTextField')
        element.send_keys('email@gmail.com') 
        element.send_keys(Keys.RETURN)
        time.sleep(3)

        # find the password input field and input the password
        element = self.driver.find_element(By.XPATH, '//XCUIElementTypeSecureTextField')
        element.send_keys('YourPassword')
        element.send_keys(Keys.RETURN)
        time.sleep(5)

    def tearDown(self):
        # Quit the driver
        self.driver.quit()

if __name__ == '__main__':
    unittest.main()