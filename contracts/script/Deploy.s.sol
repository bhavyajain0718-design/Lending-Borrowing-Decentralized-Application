// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/MockERC20.sol";
import "../src/DecentralizedBank.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        MockERC20 collateral = new MockERC20("Collateral ETH", "cETH");
        MockERC20 stable = new MockERC20("USD Stable", "USDS");
        MockERC20 reward = new MockERC20("Protocol Reward", "PRWD");

        DecentralizedBank bank = new DecentralizedBank(address(collateral), address(stable), address(reward));

        collateral.mint(msg.sender, 1_000_000e18);
        stable.mint(address(bank), 5_000_000e18);
        reward.mint(address(bank), 10_000_000e18);

        vm.stopBroadcast();

        console2.log("Collateral:", address(collateral));
        console2.log("Stable:", address(stable));
        console2.log("Reward:", address(reward));
        console2.log("Bank:", address(bank));
    }
}
