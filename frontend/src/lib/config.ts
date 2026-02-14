export const CONFIG = {
  rpcUrl: import.meta.env.VITE_RPC_URL || "http://127.0.0.1:8545",
  backendUrl: import.meta.env.VITE_BACKEND_URL || "http://localhost:8080",
  bankAddress: import.meta.env.VITE_BANK_ADDRESS || "",
  collateralAddress: import.meta.env.VITE_COLLATERAL_ADDRESS || "",
  borrowAddress: import.meta.env.VITE_BORROW_ADDRESS || ""
};
