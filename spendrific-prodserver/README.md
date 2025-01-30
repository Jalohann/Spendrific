# Spendrific Production Server

This is the production configuration for the Spendrific server, optimized for Windows deployment.

## Setup Instructions

1. **Python Installation**
   - Install Python 3.x on your Windows machine
   - Ensure Python is added to your system PATH

2. **Virtual Environment Setup**
   ```bash
   # Create a virtual environment
   python -m venv venv
   
   # Activate the virtual environment
   .\venv\Scripts\activate
   
   # Install dependencies
   pip install -r requirements.txt
   ```

3. **Environment Configuration**
   - Create a `.env` file in the root directory
   - Copy your existing environment variables
   - Update any system-specific paths or configurations

4. **Chrome/Selenium Setup**
   - Install Google Chrome
   - Download the appropriate ChromeDriver version matching your Chrome installation
   - Add ChromeDriver to your system PATH or place it in the application directory

5. **Directory Structure**
   - Ensure the following files exist in your deployment directory:
     - `app.py`
     - `requirements.txt`
     - `.env`
     - `chase.py`
     - `bill_pay.py`
     - `cardInfo` (if needed)

## Running the Server

1. **Manual Start**
   ```bash
   python app.py
   ```
   The server will start on port 8000 by default (configurable via PORT environment variable)

2. **Running as a Windows Service (Recommended)**
   - Install NSSM (Non-Sucking Service Manager)
   - Create a service:
     ```bash
     nssm install Spendrific "path\to\venv\Scripts\python.exe" "path\to\app.py"
     ```
   - Start the service:
     ```bash
     nssm start Spendrific
     ```

## Logging

- Logs are stored in the `logs` directory
- The main log file is `logs/app.log`
- Logs rotate automatically (max 10 files, 10KB each)

## Environment Variables

- `HOST`: Server host (default: 0.0.0.0)
- `PORT`: Server port (default: 8000)
- `FLASK_ENV`: Environment name (default: production)
- Add any other environment-specific variables

## Security Notes

- Ensure proper firewall rules are configured
- Keep your `.env` file secure and never commit it to version control
- Regularly update dependencies for security patches
- Monitor logs for any suspicious activity

## Troubleshooting

1. **Selenium/Chrome Issues**
   - Verify ChromeDriver version matches Chrome version
   - Ensure proper PATH configuration
   - Check logs for detailed error messages

2. **Permission Issues**
   - Run the service with appropriate user permissions
   - Ensure write access to the logs directory
   - Verify file permissions for all data files

3. **Network Issues**
   - Check firewall configurations
   - Verify port availability
   - Ensure proper network access for external services 