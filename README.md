# ✈️ Blockchain-based Travel Insurance

Welcome to a revolutionary way to handle travel insurance on the blockchain! This project automates travel insurance policies, claims, and payouts using the Stacks blockchain and Clarity smart contracts. It solves real-world problems like slow claim processing, high administrative costs, fraud, and lack of transparency in traditional insurance by leveraging oracles for real-time event verification (e.g., flight delays, medical incidents) and automatic, trustless payouts.

## ✨ Features

🔒 Purchase customizable insurance policies on-chain  
⏱️ Real-time oracle integration for event triggers (e.g., flight data, weather APIs)  
💸 Automatic claim payouts without manual reviews  
📊 Transparent audit trails for all transactions and claims  
🚨 Dispute resolution mechanism for edge cases  
✅ Fraud prevention through immutable records and verification  
💼 Support for multiple coverage types (e.g., flight delay, lost luggage, medical emergencies)  
🔄 Refund options for unused policies  

## 🛠 How It Works

This project uses 8 Clarity smart contracts to create a decentralized travel insurance ecosystem. Premiums are paid in STX (Stacks' native token), and payouts are automated via oracles that feed external data (like flight status from trusted APIs) into the blockchain.

### Smart Contracts Overview
1. **PolicyFactory.clar**: Creates new insurance policies with customizable parameters (e.g., coverage amount, duration, type).  
2. **OracleIntegrator.clar**: Interfaces with external oracles to fetch and verify real-world data (e.g., flight delays via API calls triggered on Stacks).  
3. **ClaimProcessor.clar**: Handles claim initiation, validation against policy terms, and triggers payouts.  
4. **PayoutManager.clar**: Manages the distribution of funds from the insurance pool to claimants.  
5. **CoverageRegistry.clar**: Defines and stores different insurance coverage types and their rules (e.g., minimum delay thresholds).  
6. **UserProfile.clar**: Stores user details, policy history, and verification data to prevent fraud.  
7. **DisputeResolver.clar**: Allows for human-oracle hybrid resolution in disputed claims, with voting or arbitration logic.  
8. **AuditLogger.clar**: Logs all events immutably for transparency and compliance audits.

### For Travelers (Policy Buyers)
- Connect your Stacks wallet and call the `PolicyFactory` contract to create a policy.  
- Provide details: trip dates, coverage type (e.g., flight delay > 2 hours), premium amount.  
- Pay the premium in STX – it's escrowed in the contract.  
- If an insured event occurs (e.g., flight delayed), the oracle reports it via `OracleIntegrator`.  
- `ClaimProcessor` automatically verifies and triggers `PayoutManager` to send STX back to your wallet. Boom! Instant payout.

### For Verifiers/Insurers
- Use `AuditLogger` to view transaction history and policy details.  
- Call functions in `ClaimProcessor` or `DisputeResolver` to review or intervene in claims.  
- Oracles ensure data integrity – no more fake claims!

That's it! Secure, automated travel insurance at your fingertips.