import unittest
from utils.driver_setup import DriverSetup

class BaseTest(unittest.TestCase):
    driver = None

    @classmethod
    def setUpClass(cls):
        if BaseTest.driver is None:
            BaseTest.driver = DriverSetup().get_driver()
        cls.driver = BaseTest.driver

    @classmethod
    def tearDownClass(cls):
        # Only quit the driver after all tests are complete
        if cls.__name__ == 'HomeCurrentTest':  # Last test class
            if BaseTest.driver is not None:
                BaseTest.driver.quit()
                BaseTest.driver = None 