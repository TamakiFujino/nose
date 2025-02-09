import sys
import os
import time
import unittest

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from utils.driver_setup import DriverSetup
from pages.page_02_home_currentmap import HomePage

class HomeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.driver = DriverSetup().get_driver()
        cls.home_page = HomePage(cls.driver)
    
    def test_home_page(self):
        self.home_page.click_allow_location_permission()
        time.sleep(1)
        self.home_page.click_search_icon()
        time.sleep(1)
        self.home_page.enter_search_text()
        time.sleep(1)
        self.home_page.click_first_suggestion()
        time.sleep(3)
        self.home_page.verify_location_name()
        self.home_page.verify_address()
        self.home_page.verify_phone_number()
        self.home_page.verify_website()
        self.home_page.verify_rating()
        self.home_page.verify_opening_hours()
        self.home_page.verify_photos()
        self.home_page.click_bookmark_icon()
        time.sleep(1)
        self.home_page.verify_no_bookmark_list()
        self.home_page.click_create_bookmark_list_button()
        time.sleep(1)
        self.home_page.enter_bookmark_list_name()
        time.sleep(1)
        self.home_page.verify_created_bookmark_list()
        self.home_page.verify_zero_pois_saved()
        self.home_page.click_created_bookmark_list()
        self.home_page.verify_check_mark()
        self.home_page.click_confirm_button()
        self.home_page.click_current_location_button()
        time.sleep(3)

    def tearDown(self):
        # Quit the driver
        self.driver.quit()

if __name__ == '__main__':
    unittest.main()