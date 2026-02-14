export const bankAbi = [
  "function depositCollateral(uint256 amount)",
  "function withdrawCollateral(uint256 amount)",
  "function borrow(uint256 amount)",
  "function repay(uint256 amount)",
  "function stake(uint256 amount)",
  "function unstake(uint256 amount)",
  "function claimRewards()",
  "function getPosition(address user) view returns (uint256 collateralAmount,uint256 debtAmount,uint256 stakedAmount,uint256 pendingRewards)",
  "function getHealthFactor(address user) view returns (uint256)"
];

export const erc20Abi = [
  "function approve(address spender, uint256 value) returns (bool)",
  "function balanceOf(address owner) view returns (uint256)"
];
