import sys
import os
import time
import unittest

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from utils.driver_setup import DriverSetup
from pages.page_01_login import LoginPage

class LoginTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.driver = DriverSetup().get_driver()
        cls.login_page = LoginPage(cls.driver)

    def test_google_login(self):
        self.login_page.click_google_login()
        time.sleep(1)
        self.login_page.click_continue_ios_alert()
        time.sleep(1)
        self.login_page.click_existing_google_account()
        time.sleep(3)
        self.login_page.click_continue_login_button()
        time.sleep(3)

    def tearDown(self):
        # Quit the driver
        self.driver.quit()

if __name__ == '__main__':
    unittest.main()