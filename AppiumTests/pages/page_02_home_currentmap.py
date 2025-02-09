from appium.webdriver.common.appiumby import AppiumBy
from selenium.webdriver.common.by import By
from pages.page_99_base import BasePage
import config

class HomePage(BasePage):
    # click the first option in the alert modal
    def click_allow_location_permission(self):
        self.driver.switch_to.alert.dismiss()

    # click the search icon button
    SEARCH_ICON = (AppiumBy.ACCESSIBILITY_ID, 'Search')

    def click_search_icon(self):
        self.click(*self.SEARCH_ICON)

    # type 'Golden Gate Bridge' in the search bar
    SEARCH_BAR = (AppiumBy.ACCESSIBILITY_ID, 'Search for a place')

    def enter_search_text(self):
        self.enter_text(*self.SEARCH_BAR, 'Golden Gate Bridge')

    # click the first suggestion from the search result
    FIRST_SUGGESTION = (AppiumBy.XPATH, '//XCUIElementTypeTable/XCUIElementTypeCell[1]/XCUIElementTypeOther[1]/XCUIElementTypeOther')

    def click_first_suggestion(self):
        self.click(*self.FIRST_SUGGESTION)

    # in detail view, see there is a location name, address, phone number, website, rating, opening hours, and photos
    LOCATION_NAME = (AppiumBy.ACCESSIBILITY_ID, 'Golden Gate Bridge Vista Point')

    def verify_location_name(self):
        self.find_element(*self.LOCATION_NAME)

    ADDRESS = (AppiumBy.ACCESSIBILITY_ID, ' Golden Gate Bridge Vista Point, San Francisco, CA 94129, USA')

    def verify_address(self):
        self.find_element(*self.ADDRESS)

    PHONE_NUMBER = (AppiumBy.XPATH, '(//XCUIElementTypeStaticText[@name=" N/A"])[1]')

    def verify_phone_number(self):
        self.find_element(*self.PHONE_NUMBER)

    WEBSITE = (AppiumBy.XPATH, '//XCUIElementTypeButton[@name=" N/A"]')

    def verify_website(self):
        self.find_element(*self.WEBSITE)

    RATING = (AppiumBy.XPATH, '//XCUIElementTypeStaticText[@name=" 4.8"]')

    def verify_rating(self):
        self.find_element(*self.RATING)

    OPENING_HOURS = (AppiumBy.XPATH, '//XCUIElementTypeStaticText[@name="Opening Hours: N/A"]')

    def verify_opening_hours(self):
        self.find_element(*self.OPENING_HOURS)

    PHOTOS = (AppiumBy.XPATH, '//XCUIElementTypeCollectionView')

    def verify_photos(self):
        self.find_element(*self.PHOTOS)

    # click the book mark icon button
    BOOKMARK_ICON = (AppiumBy.ACCESSIBILITY_ID, 'bookmark')

    def click_bookmark_icon(self):
        self.click(*self.BOOKMARK_ICON)
    
    # make sure you see the message "No bookmark lists created yet"
    NO_BOOKMARK_LIST = (AppiumBy.ACCESSIBILITY_ID, 'No bookmark lists created yet.')

    def verify_no_bookmark_list(self):
        self.find_element(*self.NO_BOOKMARK_LIST)

    # click Create Bookmark List button
    CREATE_BOOKMARK_LIST_BUTTON = (AppiumBy.XPATH, '//XCUIElementTypeStaticText[@name="Create Bookmark List"]')

    def click_create_bookmark_list_button(self):
        self.click(*self.CREATE_BOOKMARK_LIST_BUTTON)

    # type 'trip to San Francisco' in the bookmark list name
    BOOKMARK_LIST_NAME = (AppiumBy.XPATH, '//XCUIElementTypeCell/XCUIElementTypeOther/XCUIElementTypeOther/XCUIElementTypeOther/XCUIElementTypeOther[2]')

    def enter_bookmark_list_name(self):
        self.enter_text(*self.BOOKMARK_LIST_NAME, 'trip to SF')

    # make sure there is a list name with 'trip to San Francisco'
    TRIP_TO_SAN_FRANCISCO = (AppiumBy.XPATH, '//XCUIElementTypeCell/XCUIElementTypeOther[1]/XCUIElementTypeOther')

    def verify_created_bookmark_list(self):
        self.find_element(*self.TRIP_TO_SAN_FRANCISCO)

    # and make sure it says 0 POIs saved
    ZERO_POIS_SAVED = (AppiumBy.ACCESSIBILITY_ID, '0 POIs saved')

    def verify_zero_pois_saved(self):
        self.find_element(*self.ZERO_POIS_SAVED)

    # click the 'trip to San Francisco' bookmark list
    TRIP_TO_SAN_FRANCISCO = (AppiumBy.ACCESSIBILITY_ID, 'trip to SF')

    def click_created_bookmark_list(self):
        self.click(*self.TRIP_TO_SAN_FRANCISCO)

    # make sure there is a check mark on the 'trip to San Francisco' bookmark list
    CHECK_MARK = (AppiumBy.ACCESSIBILITY_ID, 'checkmark')

    def verify_check_mark(self):
        self.find_element(*self.CHECK_MARK)

    # tap the Confirm button
    CONFIRM_BUTTON = (AppiumBy.XPATH, '//XCUIElementTypeStaticText[@name="Confirm"]')

    def click_confirm_button(self):
        self.click(*self.CONFIRM_BUTTON)

    # tap the google map anywhere on the screen
    def click_current_location_button(self):
        self.driver.tap([(100, 100)], 1)
