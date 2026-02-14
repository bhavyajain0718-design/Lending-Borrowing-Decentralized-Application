# Lending-Borrowing-Decentralized-Application

A full-stack decentralized banking application with:

- **Solidity + Foundry contracts** for lending/borrowing/staking
- **Node.js backend** for protocol/user read APIs
- **React + Vite frontend** for wallet-based UX

## Architecture

```text
frontend (React + ethers)
   |
backend API (Express + ethers)
   |
EVM Network <-> DecentralizedBank.sol + ERC20 tokens
```

## 1) Smart contracts (Foundry)

```bash
cd contracts
forge build
forge test
forge script script/Deploy.s.sol:Deploy --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

Core features in `DecentralizedBank.sol`:

- Deposit / withdraw collateral
- Borrow / repay stable asset
- Stake collateral and earn continuous rewards
- Health factor, LTV checks, and liquidation support

## 2) Backend API

```bash
cd backend
npm install
cp .env.example .env
npm run dev
```

### Endpoints

- `GET /health`
- `GET /api/protocol`
- `GET /api/users/:address`

## 3) Frontend dApp

```bash
cd frontend
npm install
cp .env.example .env
npm run dev
```

The UI supports wallet connection and all major user flows:

- Deposit collateral
- Withdraw collateral
- Borrow
- Repay
- Stake / unstake
- Claim rewards

## Suggested production upgrades

- Replace internal price configuration with Chainlink oracles
- Add access control (Ownable/Roles)
- Add interest rate model and debt index
- Add subgraph/event indexer and analytics dashboard
- Add formal test suite and invariant/fuzz tests in Foundry
