import time
from appium.webdriver.common.appiumby import AppiumBy

class TestHomeCurrent:
    def test_home_current(self):
        # click the first suggestion from the search result, not mentioning the name
        element = self.driver.find_element(AppiumBy.ID, '27000000-0000-0000-CBAC-000000000000')
        element.click()
        time.sleep(2) 