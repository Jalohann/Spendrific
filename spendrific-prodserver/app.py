import os
import ssl
import logging
from dotenv import load_dotenv
from flask import Flask, jsonify, request
from cheroot.wsgi import Server as WSGIServer
from cheroot.ssl.builtin import BuiltinSSLAdapter
from chase import Browser as ChaseBrowser
from bill_pay import DatcuBillPay
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_talisman import Talisman
import csv
import traceback
import sys
from datetime import datetime
import re
from logging.handlers import RotatingFileHandler

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__)

# SSL certificate paths
cert_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'cert')
certfile = os.path.join(cert_dir, 'server.crt')
keyfile = os.path.join(cert_dir, 'server.key')

# Security configurations
Talisman(app, 
         force_https=True,
         strict_transport_security=True,
         session_cookie_secure=True)

# Configure CORS
CORS(app, resources={
    r"/*": {
        "origins": ["https://spendrific.com", "https://app.spendrific.com"],
        "methods": ["GET", "POST"],
        "allow_headers": ["Content-Type"]
    }
})

# Rate limiting
limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)

# Enhanced logging configuration
if not os.path.exists('logs'):
    os.makedirs('logs')

file_handler = RotatingFileHandler(
    'logs/app.log',
    maxBytes=1024 * 1024,  # 1MB
    backupCount=10
)
file_handler.setFormatter(logging.Formatter(
    '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
))

logging.basicConfig(
    level=logging.INFO,
    handlers=[file_handler, logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

def run_https_server():
    """Run HTTPS server"""
    host = os.getenv('HOST', '0.0.0.0')
    port = int(os.getenv('PORT', 8000))
    
    # Configure SSL with basic security settings for development
    ssl_adapter = BuiltinSSLAdapter(certfile, keyfile)
    ssl_adapter.context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    
    # Load certificate
    ssl_adapter.context.load_cert_chain(certfile, keyfile)
    
    # Set basic cipher suites that iOS definitely supports
    ssl_adapter.context.set_ciphers(
        'ECDHE-RSA-AES256-SHA:AES256-SHA:HIGH:!RC4:!DH:!MD5:!aNULL:!eNULL:!NULL:!DES:!EDH:!EXP:!SEED'
    )
    
    # Security options with basic compatibility
    ssl_adapter.context.options = (
        ssl.OP_NO_SSLv2 | 
        ssl.OP_NO_SSLv3 |
        ssl.OP_NO_COMPRESSION
    )
    
    # Allow TLS 1.2 (removing 1.3 temporarily for testing)
    ssl_adapter.context.minimum_version = ssl.TLSVersion.TLSv1_2
    ssl_adapter.context.maximum_version = ssl.TLSVersion.TLSv1_2
    
    # Development settings - accept self-signed certificates
    ssl_adapter.context.verify_mode = ssl.CERT_NONE
    ssl_adapter.context.check_hostname = False
    
    # Enable SSL debugging through logging
    logging.getLogger('ssl').setLevel(logging.DEBUG)
    
    # Create HTTPS server
    https_server = WSGIServer((host, port), app)
    https_server.ssl_adapter = ssl_adapter
    
    try:
        logger.info(f'Starting HTTPS server on {host}:{port}')
        logger.info('TLS Configuration:')
        logger.info(f' - Minimum TLS version: {ssl_adapter.context.minimum_version.name}')
        logger.info(f' - Maximum TLS version: {ssl_adapter.context.maximum_version.name}')
        logger.info(' - Cipher suite configuration:')
        for cipher in ssl_adapter.context.get_ciphers():
            logger.info(f'   - {cipher["name"]}')
        https_server.start()
    except (KeyboardInterrupt, SystemExit):
        https_server.stop()
    except ssl.SSLError as e:
        logger.error(f"SSL Error: {e}")
        logger.error(f"SSL Error Code: {e.reason}")
        raise
    except Exception as e:
        logger.error(f"HTTPS Server error: {e}")
        raise

@app.route('/health', methods=['GET'])
@limiter.exempt
def health_check():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat()
    })

@app.route('/fetch-transactions', methods=['POST'])
@limiter.limit("10 per hour")
def fetch_transactions():
    logger.info("Starting fetch-transactions endpoint")
    browser = None
    try:
        logger.info("Initializing Chrome browser...")
        browser = ChaseBrowser()
        
        logger.info("Opening Chase website and logging in...")
        browser.open()
        
        logger.info("Getting latest transactions...")
        transactions = browser.get_latest_transactions()
        logger.info(f"Found {len(transactions)} transactions")
        
        logger.info("Saving transactions to CSV...")
        browser.save_to_csv(transactions)
        
        logger.info("Operation completed successfully")
        return jsonify({
            'status': 'success',
            'message': 'Transactions fetched',
            'count': len(transactions)
        })
    except Exception as e:
        logger.error(f"Error in fetch-transactions: {str(e)}")
        logger.error(traceback.format_exc())
        return jsonify({
            'status': 'error',
            'message': str(e),
            'traceback': traceback.format_exc()
        }), 500
    finally:
        if browser:
            logger.info("Closing browser...")
            try:
                browser.close()
            except Exception as e:
                logger.error(f"Error closing browser: {str(e)}")

@app.route('/transactions', methods=['GET'])
@limiter.limit("30 per minute")
def get_transactions():
    logger.info("Received request to get transactions")
    try:
        transactions = []
        with open('chase_transactions.csv', 'r') as file:
            reader = csv.DictReader(file)
            transactions = list(reader)
        logger.info(f"Retrieved {len(transactions)} transactions from CSV")
        return jsonify(transactions)
    except Exception as e:
        logger.error(f"Error reading transactions: {str(e)}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/pay-bill', methods=['POST'])
@limiter.limit("5 per hour")
def pay_bill():
    bill_pay = None
    try:
        # Get the modified CSV data from request
        transactions = request.json.get('transactions', [])
        
        if not transactions:
            return jsonify({
                'status': 'error',
                'message': 'No transactions provided'
            }), 400
        
        # Save to CSV
        with open('chase_transactions.csv', 'w') as file:
            writer = csv.DictWriter(file, fieldnames=['Date', 'Name', 'Amount'])
            writer.writeheader()
            writer.writerows(transactions)
        
        # Calculate total amount from transactions with better error handling
        total = 0
        for t in transactions:
            amount_str = t.get('Amount', '').strip()
            if not amount_str:
                logger.warning(f"Skipping transaction with empty amount: {t}")
                continue
                
            try:
                # Remove $ and any other non-numeric characters except decimal point and negative sign
                amount_str = amount_str.replace('$', '').replace(',', '').strip()
                amount = float(amount_str)
                total += amount
            except ValueError:
                logger.error(f"Invalid amount format in transaction: {t}")
                return jsonify({
                    'status': 'error',
                    'message': f'Invalid amount format: {amount_str}'
                }), 400
        
        if total <= 0:
            return jsonify({
                'status': 'error',
                'message': 'Total amount must be greater than 0'
            }), 400
            
        logger.info(f"Calculated total amount for bill pay: ${total:.2f}")
        
        # Initialize and execute bill pay
        bill_pay = DatcuBillPay()
        logger.info("Logging into DATCU...")
        bill_pay.login()
        
        logger.info("Navigating to bill pay section...")
        bill_pay.navigate_to_bill_pay()
        
        logger.info(f"Initiating payment for ${total:.2f}...")
        bill_pay.initiate_payment(f"{total:.2f}")
        
        logger.info("Bill pay completed successfully")
        return jsonify({
            'status': 'success', 
            'message': 'Bill pay completed',
            'amount': f"${total:.2f}"
        })
        
    except Exception as e:
        logger.error(f"Error in bill pay: {str(e)}")
        logger.error(traceback.format_exc())
        return jsonify({
            'status': 'error',
            'message': str(e),
            'traceback': traceback.format_exc()
        }), 500
        
    finally:
        if bill_pay:
            logger.info("Closing browser...")
            try:
                bill_pay.close()
            except Exception as e:
                logger.error(f"Error closing browser: {str(e)}")

def parse_card_info():
    try:
        with open('cardInfo', 'r') as file:
            content = file.read()
            
            # Extract card name and last 4 digits
            card_match = re.search(r'(.*?)\s*\(...(\d{4})\)', content)
            card_name = card_match.group(1) if card_match else "Unknown Card"
            last_four = card_match.group(2) if card_match else "0000"
            
            # Extract current balance
            balance_match = re.search(r'Current balance\s*\$([0-9,.]+)', content)
            current_balance = float(balance_match.group(1).replace(',', '')) if balance_match else 0.0
            
            return {
                "cardName": card_name,
                "lastFourDigits": last_four,
                "currentBalance": current_balance
            }
    except Exception as e:
        logger.error(f"Error parsing card info: {str(e)}")
        return None

@app.route('/cardInfo', methods=['GET'])
@limiter.limit("30 per minute")
def get_card_info():
    try:
        card_info = parse_card_info()
        if card_info:
            return jsonify(card_info)
        else:
            return jsonify({'status': 'error', 'message': 'Failed to parse card information'}), 500
    except Exception as e:
        logger.error(f"Error in get_card_info: {str(e)}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

if __name__ == '__main__':
    # Load SSL certificate and key
    cert_path = os.path.join(os.path.dirname(__file__), 'cert.pem')
    key_path = os.path.join(os.path.dirname(__file__), 'key.pem')
    
    if not (os.path.exists(cert_path) and os.path.exists(key_path)):
        logger.warning("SSL certificate files not found. Generating new ones...")
        os.system('python generate_cert.py')
    
    logger.info("Starting Flask application in production mode...")
    run_https_server()