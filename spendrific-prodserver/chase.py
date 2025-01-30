from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from webdriver_manager.chrome import ChromeDriverManager
import csv
from datetime import datetime
import os
from dotenv import load_dotenv
import time
import platform
import sys

# Define the profile directory path
CHROME_PROFILE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "chrome_profile")

class Browser:
    def __init__(self):
        options = Options()
        # Use specific profile directory
        options.add_argument(f"--user-data-dir={CHROME_PROFILE_DIR}")
        options.add_argument("--page-load-strategy=eager")  # Don't wait for all resources
        
        # Add Windows-specific options
        if platform.system() == 'Windows':
            options.add_argument('--no-sandbox')
            options.add_argument('--disable-dev-shm-usage')
        
        try:
            # Create and start browser with automatic ChromeDriver installation
            driver_manager = ChromeDriverManager()
            driver_path = driver_manager.install()
            service = Service(executable_path=driver_path)
            self.driver = webdriver.Chrome(service=service, options=options)
        except Exception as e:
            print(f"Error initializing Chrome WebDriver: {str(e)}")
            print(f"Python Version: {sys.version}")
            print(f"Platform: {platform.platform()}")
            print(f"Architecture: {platform.architecture()}")
            raise
        
        # Load environment variables from .env file
        load_dotenv()
        
        # Get credentials from environment variables
        self.username = os.getenv('CHASE_USERNAME')
        self.password = os.getenv('CHASE_PASSWORD')
        if not self.username or not self.password:
            raise ValueError("CHASE_USERNAME and CHASE_PASSWORD must be set in .env file")

    def login(self):
        """Log into Chase account"""
        try:
            print("Waiting for login page to load...")
            time.sleep(5)  # Give page time to fully load
            
            # Switch to the login iframe
            print("\nSwitching to login iframe...")
            self.driver.switch_to.frame(0)
            
            # Handle password field directly by ID
            print("\nLooking for password field...")
            password_field = WebDriverWait(self.driver, 10).until(
                EC.presence_of_element_located((By.ID, "password"))
            )
            
            print("Found password field, clicking and entering password...")
            password_field.click()
            password_field.send_keys(self.password)
            
            # Handle sign in button
            print("\nLooking for sign in button...")
            sign_in_button = WebDriverWait(self.driver, 10).until(
                EC.element_to_be_clickable((By.ID, "signin-button"))
            )
            
            print("Found sign in button, clicking...")
            sign_in_button.click()
            
            # Switch back to default content
            self.driver.switch_to.default_content()
            
            print("\nWaiting for login to complete...")
            # Wait for redirect to dashboard
            WebDriverWait(self.driver, 20).until(
                lambda driver: "secure.chase.com/web/auth/dashboard" in driver.current_url
            )
            print("Login successful!")
            
        except Exception as e:
            print(f"\nERROR during login process: {e}")
            print("Current URL:", self.driver.current_url)
            
            # Try to get screenshot for debugging
            try:
                self.driver.save_screenshot("debug_screenshot.png")
                print("Saved debug screenshot to debug_screenshot.png")
            except:
                print("Could not save screenshot")
            raise

    def get_card_info(self):
        """Get and store card name and last digits"""
        try:
            print("\nGetting card information...")
            # Wait for dashboard to load
            time.sleep(5)
            
            # Find the container element first
            print("Looking for card info container...")
            container = WebDriverWait(self.driver, 10).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, ".mds-mt-6"))
            )
            
            # Get the text content which should include the card info
            card_info = container.text
            print(f"Found container text: {card_info}")
            
            # Save to file
            with open('cardInfo', 'w', encoding='utf-8') as f:
                f.write(card_info)
            print(f"Card information saved to cardInfo file")
            
        except Exception as e:
            print(f"Error getting card information: {e}")
            self.driver.save_screenshot("card_info_error.png")
            print("Saved error screenshot to card_info_error.png")
            raise

    def open(self, url="https://secure.chase.com"):
        """Open Chase website and handle initial loading"""
        self.driver.get(url)
        print("Loaded initial page, waiting 5 seconds...")
        time.sleep(5)  # Delay for page to stabilize
        self.login()
        time.sleep(5)
        self.get_card_info()  # Get card info after login
        print("Navigating to transactions page...")
        self.navigate_to_transactions()
        print("Waiting for page to load...")
        time.sleep(3)  # Give transactions page time to load

    def navigate_to_transactions(self):
        # Direct URL to transactions page
        transactions_url = "https://secure.chase.com/web/auth/dashboard#/dashboard/transactions/1124076097/CARD/BAC"
        print("\nNavigating to transactions page...")
        self.driver.get(transactions_url)
        
        # Wait and verify we're on the transactions page
        try:
            print("Waiting for transactions page to load...")
            WebDriverWait(self.driver, 10).until(
                lambda driver: "transactions" in driver.current_url
            )
            
            # Double check we're on the right page
            if "transactions" not in self.driver.current_url:
                print("Not on transactions page, retrying navigation...")
                time.sleep(2)  # Brief pause before retry
                self.driver.get(transactions_url)
                WebDriverWait(self.driver, 10).until(
                    lambda driver: "transactions" in driver.current_url
                )
            
            # Wait for transactions table to load
            print("Waiting for transactions table...")
            WebDriverWait(self.driver, 10).until(
                EC.presence_of_element_located((By.CLASS_NAME, "mds-activity-table__row"))
            )
            print("Successfully loaded transactions page")
            
        except Exception as e:
            print(f"Error navigating to transactions: {e}")
            print(f"Current URL: {self.driver.current_url}")
            self.driver.save_screenshot("navigation_error.png")
            raise

    def get_latest_transactions(self):
        """Get latest transactions from the transactions page"""
        try:
            print("Looking for pending transactions table...")
            # Wait for the pending transactions table to load
            WebDriverWait(self.driver, 10).until(
                EC.presence_of_element_located((By.ID, "PENDING-dataTableId-mds-diy-data-table"))
            )
            
            print("Getting pending transactions...")
            pending_transactions = []
            
            # Look for pending transactions rows
            for i in range(10):  # Check first 10 possible pending transactions
                try:
                    # Get date from row header
                    date_element = self.driver.find_element(
                        By.CSS_SELECTOR, 
                        f"#PENDING-dataTableId-row-header-row{i}-columnundefined .mds-activity-table__row-value--text"
                    )
                    
                    # Get description from column 1
                    name_element = self.driver.find_element(
                        By.CSS_SELECTOR,
                        f"#PENDING-dataTableId-value-row{i}-column1 .mds-activity-table__row-value--text"
                    )
                    
                    # Get amount from column 2
                    amount_element = self.driver.find_element(
                        By.CSS_SELECTOR,
                        f"#PENDING-dataTableId-value-row{i}-column2 .mds-activity-table__row-value--text"
                    )
                    
                    # Clean up merchant name by taking only the first instance before newline
                    merchant_name = name_element.text.split('\n')[0].strip()
                    
                    # Normalize date format
                    date_str = date_element.text
                    try:
                        # Try parsing numerical format (MM/DD/YYYY)
                        date_obj = datetime.strptime(date_str, '%m/%d/%Y')
                    except ValueError:
                        try:
                            # Try parsing written format (MMM DD, YYYY)
                            date_obj = datetime.strptime(date_str, '%b %d, %Y')
                        except ValueError:
                            print(f"Warning: Could not parse date format: {date_str}")
                            date_obj = None
                    
                    # Format date consistently as "MMM DD, YYYY"
                    formatted_date = date_obj.strftime('%b %d, %Y') if date_obj else date_str
                    
                    transaction = {
                        'date': formatted_date,
                        'name': merchant_name,
                        'amount': amount_element.text
                    }
                    pending_transactions.append(transaction)
                    
                except:
                    break  # No more pending transactions found
                
            print(f"Found {len(pending_transactions)} pending transactions")
            return pending_transactions
            
        except Exception as e:
            print(f"Error getting transactions: {e}")
            self.driver.save_screenshot("transactions_error.png")
            print("Saved error screenshot to transactions_error.png")
            raise

    def save_to_csv(self, transactions, filename='chase_transactions.csv'):
        """Save transactions to CSV file"""
        print(f"\nSaving {len(transactions)} transactions to {filename}")
        
        with open(filename, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['Date', 'Name', 'Amount'])  # Header row
            
            for t in transactions:
                writer.writerow([t['date'], t['name'], t['amount']])
        
        print("Transactions saved successfully")

    def close(self):
        self.driver.quit()

def main():
    browser = Browser()
    try:
        browser.open()
        transactions = browser.get_latest_transactions()
        browser.save_to_csv(transactions)
        
    finally:
        browser.close()

if __name__ == "__main__":
    main()