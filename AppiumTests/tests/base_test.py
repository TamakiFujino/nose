import unittest
from utils.driver_setup import DriverSetup

class BaseTest(unittest.TestCase):
    driver = None
    _test_count = 0
    _test_completed = 0

    @classmethod
    def setUpClass(cls):
        if BaseTest.driver is None:
            BaseTest.driver = DriverSetup().get_driver()
            # Count total number of test classes
            BaseTest._test_count = len([name for name in dir(cls) if name.startswith('test_')])
        cls.driver = BaseTest.driver

    @classmethod
    def tearDownClass(cls):
        BaseTest._test_completed += 1
        # Only quit the driver after all test classes are complete
        if BaseTest._test_completed >= BaseTest._test_count:
            if BaseTest.driver is not None:
                BaseTest.driver.quit()
                BaseTest.driver = None 