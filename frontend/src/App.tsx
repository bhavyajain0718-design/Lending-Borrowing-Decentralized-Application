import { useEffect, useMemo, useState } from "react";
import { ethers } from "ethers";
import ActionCard from "./components/ActionCard";
import { CONFIG } from "./lib/config";
import { bankAbi, erc20Abi } from "./lib/bankAbi";

type Position = {
  collateralAmount: string;
  debtAmount: string;
  stakedAmount: string;
  pendingRewards: string;
  healthFactor: string;
};

export default function App() {
  const [wallet, setWallet] = useState("");
  const [position, setPosition] = useState<Position | null>(null);
  const [status, setStatus] = useState("Ready");

  const provider = useMemo(() => {
    if ((window as any).ethereum) {
      return new ethers.BrowserProvider((window as any).ethereum);
    }
    return new ethers.JsonRpcProvider(CONFIG.rpcUrl);
  }, []);

  const connectWallet = async () => {
    if (!(window as any).ethereum) {
      setStatus("No wallet extension found. Install MetaMask.");
      return;
    }
    const signer = await provider.getSigner();
    setWallet(await signer.getAddress());
  };

  const refreshPosition = async (address?: string) => {
    const user = address || wallet;
    if (!user || !CONFIG.backendUrl) return;
    const response = await fetch(`${CONFIG.backendUrl}/api/users/${user}`);
    const data = await response.json();
    if (!response.ok) {
      setStatus(data.error || "Failed to load position");
      return;
    }
    setPosition(data);
  };

  useEffect(() => {
    if (wallet) {
      void refreshPosition(wallet);
    }
  }, [wallet]);

  const execute = async (fn: (signer: ethers.Signer) => Promise<ethers.TransactionResponse>) => {
    try {
      if (!wallet) {
        setStatus("Connect wallet first.");
        return;
      }
      const signer = await provider.getSigner();
      const tx = await fn(signer);
      setStatus(`Pending tx: ${tx.hash}`);
      await tx.wait();
      setStatus("Transaction confirmed");
      await refreshPosition();
    } catch (error: any) {
      setStatus(error.shortMessage || error.message || "Transaction failed");
    }
  };

  const parse = (value: string) => ethers.parseUnits(value || "0", 18);

  const approveToken = async (tokenAddress: string, signer: ethers.Signer, amount: bigint) => {
    const token = new ethers.Contract(tokenAddress, erc20Abi, signer);
    const tx = await token.approve(CONFIG.bankAddress, amount);
    await tx.wait();
  };

  return (
    <main className="layout">
      <header>
        <h1>DeFi Bank — Lending, Borrowing & Staking</h1>
        <p>Deposit collateral, borrow stablecoins, and earn protocol rewards with staking.</p>
        <button onClick={connectWallet}>{wallet ? `Connected: ${wallet.slice(0, 6)}...${wallet.slice(-4)}` : "Connect Wallet"}</button>
      </header>

      <section className="stats">
        <div className="stat"><span>Collateral</span><strong>{position ? ethers.formatUnits(position.collateralAmount, 18) : "0"}</strong></div>
        <div className="stat"><span>Debt</span><strong>{position ? ethers.formatUnits(position.debtAmount, 18) : "0"}</strong></div>
        <div className="stat"><span>Staked</span><strong>{position ? ethers.formatUnits(position.stakedAmount, 18) : "0"}</strong></div>
        <div className="stat"><span>Rewards</span><strong>{position ? ethers.formatUnits(position.pendingRewards, 18) : "0"}</strong></div>
        <div className="stat"><span>Health Factor</span><strong>{position ? ethers.formatUnits(position.healthFactor, 18) : "-"}</strong></div>
      </section>

      <section className="grid">
        <ActionCard
          title="Deposit Collateral"
          cta="Approve + Deposit"
          onSubmit={(amount) =>
            execute(async (signer) => {
              const value = parse(amount);
              await approveToken(CONFIG.collateralAddress, signer, value);
              const bank = new ethers.Contract(CONFIG.bankAddress, bankAbi, signer);
              return bank.depositCollateral(value);
            })
          }
        />
        <ActionCard
          title="Withdraw Collateral"
          cta="Withdraw"
          onSubmit={(amount) =>
            execute(async (signer) => {
              const bank = new ethers.Contract(CONFIG.bankAddress, bankAbi, signer);
              return bank.withdrawCollateral(parse(amount));
            })
          }
        />
        <ActionCard
          title="Borrow Stable"
          cta="Borrow"
          onSubmit={(amount) =>
            execute(async (signer) => {
              const bank = new ethers.Contract(CONFIG.bankAddress, bankAbi, signer);
              return bank.borrow(parse(amount));
            })
          }
        />
        <ActionCard
          title="Repay Stable"
          cta="Approve + Repay"
          onSubmit={(amount) =>
            execute(async (signer) => {
              const value = parse(amount);
              await approveToken(CONFIG.borrowAddress, signer, value);
              const bank = new ethers.Contract(CONFIG.bankAddress, bankAbi, signer);
              return bank.repay(value);
            })
          }
        />
        <ActionCard
          title="Stake Collateral"
          cta="Approve + Stake"
          onSubmit={(amount) =>
            execute(async (signer) => {
              const value = parse(amount);
              await approveToken(CONFIG.collateralAddress, signer, value);
              const bank = new ethers.Contract(CONFIG.bankAddress, bankAbi, signer);
              return bank.stake(value);
            })
          }
        />
        <ActionCard
          title="Unstake"
          cta="Unstake"
          onSubmit={(amount) =>
            execute(async (signer) => {
              const bank = new ethers.Contract(CONFIG.bankAddress, bankAbi, signer);
              return bank.unstake(parse(amount));
            })
          }
        />
      </section>

      <div className="claim-card">
        <button
          onClick={() =>
            execute(async (signer) => {
              const bank = new ethers.Contract(CONFIG.bankAddress, bankAbi, signer);
              return bank.claimRewards();
            })
          }
        >
          Claim Rewards
        </button>
      </div>

      <footer>{status}</footer>
    </main>
  );
}
