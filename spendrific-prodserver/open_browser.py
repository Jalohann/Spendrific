from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
import os
import sys

def open_chrome_with_profile(profile_name):
    # Get the absolute path to the profile directory
    profile_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), profile_name)
    
    # Create Chrome options
    options = Options()
    options.add_argument(f"--user-data-dir={profile_dir}")
    options.add_argument("--page-load-strategy=eager")
    
    # Add debugging options to keep browser open
    options.add_experimental_option("detach", True)  # Keep browser open after script ends
    
    # Create and start browser with automatic ChromeDriver installation
    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=options)
    
    # Open the relevant website based on profile
    if profile_name == "chrome_profile":
        driver.get("https://secure.chase.com")
    elif profile_name == "chrome_profile_datcu":
        driver.get("https://www.datcu.org/")
    
    print(f"\nOpened Chrome with profile: {profile_name}")
    print("The browser will remain open for you to log in.")
    print("You can close it manually when you're done.")
    print("\nNOTE: After logging in, make sure to:")
    print("1. Check 'Remember me' if available")
    print("2. Handle any 2FA/security prompts")
    print("3. Accept any terms or conditions")
    print("4. Close the browser only after you're fully logged in")

def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ["chase", "datcu"]:
        print("Usage: python open_browser.py [chase|datcu]")
        sys.exit(1)
    
    profile_name = "chrome_profile" if sys.argv[1] == "chase" else "chrome_profile_datcu"
    open_chrome_with_profile(profile_name)

if __name__ == "__main__":
    main() 