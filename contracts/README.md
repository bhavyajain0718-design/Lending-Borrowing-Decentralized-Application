# Contracts (Foundry)

This folder contains the core DeFi protocol contracts for a decentralized bank supporting:

- Collateral deposits/withdrawals
- Borrowing against collateral
- Repayment
- Staking for rewards
- Liquidation when health factor drops

## Setup

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
cd contracts
forge install
forge test
```

## Deploy

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
```
