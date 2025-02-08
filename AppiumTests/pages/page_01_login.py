from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.common.by import By
from pages.page_99_base import BasePage
import config

class LoginPage(BasePage):
    GOOGLE_LOGIN_BUTTON = (AppiumBy.ACCESSIBILITY_ID, "GIDSignInButton")

    def click_google_login(self):
        self.click(*self.GOOGLE_LOGIN_BUTTON)

    def click_continue_ios_alert(self):
        self.driver.switch_to.alert.accept()

    def click_existing_google_account(self):
        self.click(By.XPATH, f'//XCUIElementTypeLink[@name="{config.GOOGLE_ACCOUNT_NAME}"]')

    def click_continue_login_button(self):
        self.click(AppiumBy.ACCESSIBILITY_ID, 'Continue')
