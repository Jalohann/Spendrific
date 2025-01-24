from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from dotenv import load_dotenv
import os
import time
import csv
from datetime import datetime
import sys

class DatcuBillPay:
    def __init__(self):
        options = Options()
        options.add_argument("--user-data-dir=selenium_profile")
        options.add_argument("--page-load-strategy=eager")
        
        # Use ARM64 ChromeDriver with full path
        service = Service("/Users/johannrajadurai/.wdm/drivers/chromedriver/mac64/114.0.5735.90/chromedriver-mac-arm64/chromedriver")
        self.driver = webdriver.Chrome(service=service, options=options)
        self.driver.set_window_size(1800, 1089)  # Set window size as per test
        
        # Load environment variables
        load_dotenv()
        self.username = os.getenv('DATCU_USERNAME')
        self.password = os.getenv('DATCU_PASSWORD')
        if not self.username or not self.password:
            raise ValueError("DATCU_USERNAME and DATCU_PASSWORD must be set in .env file")

    def login(self):
        """Log into DATCU account"""
        try:
            print("Navigating to DATCU website...")
            self.driver.get("https://www.datcu.org/")
            time.sleep(3)  # Wait for page load
            
            print("Opening login window...")
            # Click login toggle to bring up login window
            login_toggle = WebDriverWait(self.driver, 10).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, ".login-toggle"))
            )
            login_toggle.click()
            time.sleep(3)  # Give more time for login form to appear
            
            print("Looking for login form...")
            # Try to switch to potential login iframe
            iframes = self.driver.find_elements(By.TAG_NAME, "iframe")
            if iframes:
                print(f"Found {len(iframes)} iframes, attempting to switch...")
                for iframe in iframes:
                    try:
                        self.driver.switch_to.frame(iframe)
                        print("Switched to iframe")
                        break
                    except:
                        self.driver.switch_to.default_content()
                        continue
            
            print("Attempting to find username field...")
            # Try different possible selectors for username field
            username_selectors = [
                (By.ID, "username-input-input"),
                (By.NAME, "username"),
                (By.CSS_SELECTOR, "input[type='text']"),
                (By.CSS_SELECTOR, "input[autocomplete='username']")
            ]
            
            username_field = None
            for selector_type, selector in username_selectors:
                try:
                    username_field = WebDriverWait(self.driver, 5).until(
                        EC.presence_of_element_located((selector_type, selector))
                    )
                    print(f"Found username field with selector: {selector}")
                    break
                except:
                    continue
            
            if not username_field:
                print("Could not find username field. Saving page source for debugging...")
                with open("loginPageSource.html", "w") as f:
                    f.write(self.driver.page_source)
                raise Exception("Username field not found")
            
            print("Entering credentials...")
            username_field.click()
            username_field.send_keys(self.username)
            
            # Try different possible selectors for password field
            password_selectors = [
                (By.ID, "password-input-input"),
                (By.NAME, "password"),
                (By.CSS_SELECTOR, "input[type='password']")
            ]
            
            password_field = None
            for selector_type, selector in password_selectors:
                try:
                    password_field = WebDriverWait(self.driver, 5).until(
                        EC.presence_of_element_located((selector_type, selector))
                    )
                    print(f"Found password field with selector: {selector}")
                    break
                except:
                    continue
            
            if not password_field:
                raise Exception("Password field not found")
            
            password_field.click()
            password_field.send_keys(self.password)
            
            # Try different possible selectors for login button
            login_button_selectors = [
                # Primary selectors based on the actual HTML
                (By.CSS_SELECTOR, "div[aria-label='Sign in button']"),
                (By.XPATH, "//div[@aria-label='Sign in button']"),
                (By.XPATH, "//div[contains(@class, 'css-175oi2r')]//div[text()='Sign In']"),
                # Backup selectors
                (By.CSS_SELECTOR, ".r-1otgn73.r-1awozwy.r-1fj26u4"),
                (By.XPATH, "//div[contains(@class, 'r-1otgn73') and contains(@class, 'r-1awozwy')]//div[contains(text(), 'Sign In')]"),
                (By.CSS_SELECTOR, "div[role='button'][tabindex='0']"),
            ]
            
            print("Looking for login button...")
            login_button = None
            for selector_type, selector in login_button_selectors:
                try:
                    print(f"Trying selector: {selector}")
                    login_button = WebDriverWait(self.driver, 5).until(
                        EC.element_to_be_clickable((selector_type, selector))
                    )
                    print(f"Found login button with selector: {selector}")
                    break
                except Exception as e:
                    print(f"Selector {selector} failed: {str(e)}")
                    continue
            
            if not login_button:
                print("Could not find login button. Saving page source...")
                with open("loginButtonDebug.html", "w") as f:
                    f.write(self.driver.page_source)
                self.driver.save_screenshot("login_button_error.png")
                raise Exception("Login button not found")
            
            print("Clicking login button...")
            try:
                # Try to click the button in different ways
                try:
                    login_button.click()
                    print("Regular click successful")
                except:
                    print("Regular click failed, trying JavaScript click...")
                    self.driver.execute_script("arguments[0].click();", login_button)
                    print("JavaScript click successful")
            except Exception as e:
                print(f"All click attempts failed: {str(e)}")
                # Try one last time with a more specific selector
                try:
                    print("Attempting final click with direct JavaScript...")
                    self.driver.execute_script("""
                        document.querySelector("div[aria-label='Sign in button']").click();
                    """)
                    print("Direct JavaScript click successful")
                except Exception as js_e:
                    print(f"Direct JavaScript click also failed: {str(js_e)}")
                    raise
            
            print("Waiting for login to complete...")
            time.sleep(5)  # Wait for login to complete
            
        except Exception as e:
            print(f"Error during login: {e}")
            self.driver.save_screenshot("login_error.png")
            raise

    def navigate_to_bill_pay(self):
        """Navigate to bill pay section"""
        try:
            print("Waiting for accounts page...")
            # Wait for URL to be on accounts page
            WebDriverWait(self.driver, 20).until(  # Increased timeout
                lambda driver: "online.datcu.org/accounts" in driver.current_url
            )
            print(f"Current URL: {self.driver.current_url}")
            
            print("Navigating to move-money page...")
            self.driver.get("https://online.datcu.org/move-money")
            time.sleep(3)  # Wait for page to load
            
            print("Navigating to bill pay screen...")
            self.driver.get("https://online.datcu.org/move-money/pay-bills")
            time.sleep(3)  # Wait for bill pay page to load
            
            print("Successfully navigated to bill pay screen")
            
        except Exception as e:
            print(f"Error navigating to bill pay: {e}")
            print(f"Current URL: {self.driver.current_url}")
            self.driver.save_screenshot("navigation_error.png")
            raise

    def initiate_payment(self, amount="1.00"):
        """Initiate a bill payment"""
        try:
            print(f"Initiating payment for ${amount}...")
            
            # Switch to the bill pay iframe
            print("Switching to bill pay iframe...")
            self.driver.switch_to.frame(0)
            
            # Enter payment amount
            print("Looking for amount field...")
            amount_field = WebDriverWait(self.driver, 10).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "input.form-control.pmtAmount.singlePaymentAmount.amount"))
            )
            amount_field.click()
            amount_field.clear()  # Clear any existing value
            amount_field.send_keys(amount)
            
            print("Clicking continue button...")
            continue_button = WebDriverWait(self.driver, 10).until(
                EC.element_to_be_clickable((By.CSS_SELECTOR, ".hidden-xs > .btn > .fa"))
            )
            continue_button.click()
            time.sleep(2)  # Wait for next screen
            
            print("Clicking submit payment button...")
            submit_button = WebDriverWait(self.driver, 10).until(
                EC.element_to_be_clickable((By.ID, "btnSubmitPayment"))
            )
            submit_button.click()
            time.sleep(2)  # Wait for confirmation modal
            
            print("Confirming payment...")
            confirm_button = WebDriverWait(self.driver, 10).until(
                EC.element_to_be_clickable((By.CSS_SELECTOR, ".modal-footer > .pull-left:nth-child(2)"))
            )
            confirm_button.click()
            
            # Switch back to default content
            self.driver.switch_to.default_content()
            
            print("Payment submitted successfully!")
            
        except Exception as e:
            print(f"Error during payment: {e}")
            print(f"Current URL: {self.driver.current_url}")
            self.driver.save_screenshot("payment_error.png")
            raise

    def close(self):
        self.driver.quit()

def main():
    """
    This main function is for testing purposes only.
    The actual bill pay functionality is called from the Flask server.
    """
    try:
        test_amount = "1.00"  # Test amount
        print(f"Testing bill pay with amount: ${test_amount}")
        
        datcu = DatcuBillPay()
        try:
            datcu.login()
            datcu.navigate_to_bill_pay()
            datcu.initiate_payment(test_amount)
            print("Test payment completed successfully")
        finally:
            datcu.close()
            
    except Exception as e:
        print(f"Error during test: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()