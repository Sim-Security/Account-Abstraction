// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

/**
 * @title DeployMinimal
 * @dev A contract for deploying a minimal account using a script.
 */
contract DeployMinimal is Script {
    /**
     * @dev Executes the script to deploy a minimal account.
     */
    function run() public {
        deployMinimalAccount();
    }

    /**
     * @dev Deploys a minimal account and returns the helper config and the deployed minimal account.
     * @return The helper config and the deployed minimal account.
     */
    function deployMinimalAccount() public returns (HelperConfig, MinimalAccount) {
        // Create a new instance of the HelperConfig contract
        HelperConfig helperConfig = new HelperConfig();
        // Get the network configuration from the HelperConfig contract
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // Start the broadcast using the account from the network configuration
        vm.startBroadcast(config.account);
        // Deploy a new instance of the MinimalAccount contract with the entry point from the network configuration
        MinimalAccount minimalAccount = new MinimalAccount(config.entryPoint);
        // Transfer ownership of the minimal account to the account from the network configuration
        minimalAccount.transferOwnership(config.account);
        // Stop the broadcast
        vm.stopBroadcast();

        // Return the helper config and the deployed minimal account
        return (helperConfig, minimalAccount);
    }
}
