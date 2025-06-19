# import sys
# import os
# import time
# import unittest
# sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
# from utils import shared_data, config
# from appium.webdriver.common.appiumby import AppiumBy
# from selenium.webdriver.common.by import By
# from selenium.webdriver.common.keys import Keys

# from tests.base_test import BaseTest
# from tests import google_login, logout

# class OwnerAvatarCutomizeTest(BaseTest):
#     def test_owner_avatar_cutomize(self):
#         """login"""
#         google_login(self.driver, 'user_a')

#         """accpet map location permission"""
#         # if the alert is shown, allow
#         # if the alert is not shown, skip
#         try:
#             self.driver.switch_to.alert.accept()
#         except:
#             print("Map location permission not shown")
#         time.sleep(1)

#         """visit the collection National Parks"""
#         # tap right dot
#         element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'right_dot')
#         element.click()
#         time.sleep(2)
#         # tap sparkle button
#         element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'sparkle')
#         element.click()
#         time.sleep(2)
#         # tap National Parks
#         element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'National Parks')
#         element.click()
#         time.sleep(2)
#         # find the modal container
#         element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'collection_avatar_preview')
#         element.click()
#         time.sleep(5)

#         """avatar customization"""
#         # check skin color change
#         element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'color_picker_button_5')
#         element.click()
#         time.sleep(5)
#         # check the code to make sure the skin color is changed later

#         # check eye color change (the item has a second material)
#         element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'eyes')
#         element.click()
#         time.sleep(5)
#         element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'color_picker_button_3')
#         element.click()
#         time.sleep(5)
#         # check the code to make sure the eye color is changed later

#         # check hair front change (different parent tab)
#         element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'hair')
#         element.click()
#         time.sleep(5)
#         element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'front')
#         element.click()
#         time.sleep(5)
#         element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'color_picker_button_1')
#         element.click()
#         time.sleep(5)
#         # check the code to make sure the hair color is changed later

#         # save the change
#         element = self.driver.find_element(AppiumBy.ACCESSIBILITY_ID, 'Save')
#         element.click()
#         time.sleep(5)
#         # check the code to make sure the change is saved
        
#          # swipe down to close the modal
#         self.driver.swipe(300, 350, 300, 650)
#         time.sleep(2)
#         # tap somewhere on the screen to close the modal
#         self.driver.tap([(200, 200)])
#         time.sleep(2)

#         """log out"""
#         logout(self.driver)

# if __name__ == '__main__':
#     unittest.main()