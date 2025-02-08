# pages/base_page.py
from selenium.webdriver.common.keys import Keys

class BasePage:
    def __init__(self, driver):
        self.driver = driver

    def find_element(self, locator_type, locator):
        return self.driver.find_element(locator_type, locator)

    def click(self, locator_type, locator):
        self.find_element(locator_type, locator).click()

    def enter_text(self, locator_type, locator, text):
        self.find_element(locator_type, locator).send_keys(text)
        # and click return
        self.find_element(locator_type, locator).send_keys(Keys.RETURN)
