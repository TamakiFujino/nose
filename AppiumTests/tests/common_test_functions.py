import time
from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoAlertPresentException, TimeoutException
from selenium.webdriver.support.ui import WebDriverWait
from utils.config import TEST_USERS

def _accept_alert_if_present(driver, timeout=10):
    """Wait for an iOS system alert and accept it. Do nothing if no alert appears."""
    try:
        WebDriverWait(driver, timeout).until(lambda d: _try_accept_alert(d))
    except TimeoutException:
        pass

def _try_accept_alert(driver):
    try:
        driver.switch_to.alert.accept()
        return True
    except NoAlertPresentException:
        return False

def google_login(driver, user_key):
    """
    Perform Google login for a specific user

    Args:
        driver: Appium WebDriver instance
        user_key: Key of the user in TEST_USERS dict ('user_a' or 'user_b')
    """
    # Find and click Google login button
    google_login_button = driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Continue with Google')
    google_login_button.click()

    # Accept iOS alert if it appears (e.g. "Sign In" consent dialog)
    _accept_alert_if_present(driver, timeout=10)
    time.sleep(2)

    # Select user account
    user = TEST_USERS[user_key]
    element = driver.find_element(By.XPATH, f'//XCUIElementTypeLink[@name="{user["name"]} {user["email"]}"]')
    element.click()
    time.sleep(2)

    # Click Continue
    try:
        element = driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Continue')
    except:
        element = driver.find_element(AppiumBy.ACCESSIBILITY_ID, '次へ')
    element.click()
    time.sleep(10)

def logout(driver):
    """
    Perform logout from the app
    
    Args:
        driver: Appium WebDriver instance
    """
    # Navigate to Personal Library
    element = driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Personal Library')
    element.click()
    time.sleep(2)

    # Navigate to Account
    element = driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Account')
    element.click()
    time.sleep(1)

    # Click Logout
    element = driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Logout')
    element.click()
    time.sleep(1)

    # Confirm logout
    element = driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Confirm')
    element.click()
    time.sleep(1)

    # Accept confirmation alert
    element = driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'OK')
    element.click()
    time.sleep(1) 