# app.py
from flask import Flask, jsonify, request
from chase import Browser as ChaseBrowser
from bill_pay import DatcuBillPay
import csv
import os
import logging
import traceback
import sys
from datetime import datetime
app = Flask(__name__)
# Enhanced logging configuration
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat()
    })

@app.route('/fetch-transactions', methods=['POST'])
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
        logger.error(traceback.format_exc())  # Log full stack trace
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
def get_transactions():
    app.logger.info("Received request to get transactions")
    try:
        transactions = []
        with open('chase_transactions.csv', 'r') as file:
            reader = csv.DictReader(file)
            transactions = list(reader)
        app.logger.info(f"Retrieved {len(transactions)} transactions from CSV")
        return jsonify(transactions)
    except Exception as e:
        app.logger.error(f"Error reading transactions: {str(e)}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/pay-bill', methods=['POST'])
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

if __name__ == '__main__':
    logger.info("Starting Flask application...")
    app.run(host='0.0.0.0', port=5001, debug=True)