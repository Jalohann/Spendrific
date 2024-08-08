const express = require("express");
const { Configuration, PlaidApi, PlaidEnvironments } = require("plaid");
const dotenv = require("dotenv");

dotenv.config();

const app = express();
app.use(express.json());

const config = new Configuration({
  basePath: PlaidEnvironments[process.env.PLAID_ENV],
  baseOptions: {
    headers: {
      "PLAID-CLIENT-ID": process.env.PLAID_CLIENT_ID,
      "PLAID-SECRET": process.env.PLAID_SECRET,
    },
  },
});

const client = new PlaidApi(config);

// Endpoint to create a Link token
app.post("/api/create_link_token", async (req, res) => {
  console.log("Create link token endpoint hit");
  try {
    const response = await client.linkTokenCreate({
      user: {
        client_user_id: "user-id",
      },
      client_name: "Spendrific",
      products: ["auth", "transactions"],
      country_codes: ["US"],
      language: "en",
    });
    res.json(response.data);
  } catch (error) {
    console.error(error);
    res.status(500).send(error);
  }
});

// Endpoint to exchange public token for access token
app.post("/api/exchange_public_token", async (req, res) => {
  const { public_token } = req.body;
  console.log("Public Token:", public_token);
  try {
    const response = await client.itemPublicTokenExchange({
      public_token: public_token,
    });
    res.json(response.data);
  } catch (error) {
    console.error("Error exchanging public token:", error);
    res.status(500).send(error.response ? error.response.data : error.message);
  }
});

// Endpoint to fetch transactions
app.post("/api/transactions", async (req, res) => {
  const { access_token, start_date, end_date } = req.body;
  try {
    const response = await client.transactionsGet({
      access_token,
      start_date,
      end_date,
    });
    res.json(response.data);
  } catch (error) {
    res.status(500).send(error);
  }
});

// Endpoint to authorize a transfer
app.post("/api/authorize_transfer", async (req, res) => {
  const { access_token, account_id, amount } = req.body;
  try {
    const response = await client.transferAuthorizationCreate({
      access_token,
      account_id,
      type: "debit",
      network: "ach",
      amount,
      ach_class: "ppd",
      user: {
        legal_name: "User Legal Name",
      },
    });
    res.json(response.data);
  } catch (error) {
    res.status(500).send(error);
  }
});

// Endpoint to create a transfer
app.post("/api/create_transfer", async (req, res) => {
  const { authorization_id, access_token, account_id, amount } = req.body;
  try {
    const response = await client.transferCreate({
      authorization_id,
      access_token,
      account_id,
      amount,
      description: "Bill pay for credit card transaction",
    });
    res.json(response.data);
  } catch (error) {
    res.status(500).send(error);
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
