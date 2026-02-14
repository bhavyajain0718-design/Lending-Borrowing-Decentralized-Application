import "dotenv/config";
import express from "express";
import cors from "cors";
import { ethers } from "ethers";

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 8080;
const RPC_URL = process.env.RPC_URL || "http://127.0.0.1:8545";
const BANK_ADDRESS = process.env.BANK_ADDRESS || "";

const bankAbi = [
  "function getPosition(address user) view returns (uint256 collateralAmount,uint256 debtAmount,uint256 stakedAmount,uint256 pendingRewards)",
  "function getHealthFactor(address user) view returns (uint256)",
  "function totalStaked() view returns (uint256)",
  "function rewardPerSecond() view returns (uint256)",
  "function collateralPriceInUsd() view returns (uint256)",
  "function borrowTokenPriceInUsd() view returns (uint256)",
  "function maxLtvBps() view returns (uint256)"
];

let provider;
let bank;

if (BANK_ADDRESS) {
  provider = new ethers.JsonRpcProvider(RPC_URL);
  bank = new ethers.Contract(BANK_ADDRESS, bankAbi, provider);
}

function ensureConfigured(req, res, next) {
  if (!bank) {
    return res.status(500).json({
      error: "Backend not configured. Set BANK_ADDRESS and RPC_URL."
    });
  }
  return next();
}

app.get("/health", (_req, res) => {
  res.json({ status: "ok", service: "defi-bank-api" });
});

app.get("/api/protocol", ensureConfigured, async (_req, res) => {
  try {
    const [totalStaked, rewardPerSecond, collateralPriceInUsd, borrowTokenPriceInUsd, maxLtvBps] =
      await Promise.all([
        bank.totalStaked(),
        bank.rewardPerSecond(),
        bank.collateralPriceInUsd(),
        bank.borrowTokenPriceInUsd(),
        bank.maxLtvBps()
      ]);

    res.json({
      totalStaked: totalStaked.toString(),
      rewardPerSecond: rewardPerSecond.toString(),
      collateralPriceInUsd: collateralPriceInUsd.toString(),
      borrowTokenPriceInUsd: borrowTokenPriceInUsd.toString(),
      maxLtvBps: Number(maxLtvBps)
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/api/users/:address", ensureConfigured, async (req, res) => {
  try {
    const user = req.params.address;
    if (!ethers.isAddress(user)) {
      return res.status(400).json({ error: "Invalid wallet address" });
    }

    const [position, healthFactor] = await Promise.all([
      bank.getPosition(user),
      bank.getHealthFactor(user)
    ]);

    res.json({
      user,
      collateralAmount: position.collateralAmount.toString(),
      debtAmount: position.debtAmount.toString(),
      stakedAmount: position.stakedAmount.toString(),
      pendingRewards: position.pendingRewards.toString(),
      healthFactor: healthFactor.toString()
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`DeFi bank backend running on http://localhost:${PORT}`);
});
