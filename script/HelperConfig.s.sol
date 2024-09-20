// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error HelperConfig__InvalidChainId();

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/
    struct NetworkConfig {
        address entryPoint;
        address usdc;
        address account;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 constant LOCAL_CHAIN_ID = 31337;
    // Update the BURNER_WALLET to your burner wallet!
    address constant BURNER_WALLET = 0x55e78D16fb0b4eD96A0F69bE247DDa8C6405A694;
    uint256 constant ARBITRUM_MAINNET_CHAIN_ID = 42_161;
    uint256 constant ZKSYNC_MAINNET_CHAIN_ID = 324;
    // address constant FOUNDRY_DEFAULT_WALLET = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    NetworkConfig public localNetworkConfig;
    mapping(uint256 => NetworkConfig) public networkConfigs;

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor() {
        // Initialize the network configurations for different chain IDs
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getEthMainnetConfig();
        networkConfigs[ZKSYNC_MAINNET_CHAIN_ID] = getZkSyncConfig();
        networkConfigs[ARBITRUM_MAINNET_CHAIN_ID] = getArbMainnetConfig();
    }

    /**
     * @dev Get the current network configuration based on the current chain ID.
     * @return The network configuration for the current chain ID.
     */
    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    /**
     * @dev Get the network configuration for a specific chain ID.
     * @param chainId The chain ID for which to retrieve the network configuration.
     * @return The network configuration for the specified chain ID.
     */
    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else if (networkConfigs[chainId].account != address(0)) {
            return networkConfigs[chainId];
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    /*//////////////////////////////////////////////////////////////
                                CONFIGS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Get the network configuration for the Ethereum mainnet.
     * @return The network configuration for the Ethereum mainnet.
     */
    function getEthMainnetConfig() public pure returns (NetworkConfig memory) {
        // This is v7
        return NetworkConfig({
            entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032,
            usdc: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            account: BURNER_WALLET
        });
        // https://blockscan.com/address/0x0000000071727De22E5E9d8BAf0edAc6f37da032
    }

    /**
     * @dev Get the network configuration for the Ethereum Sepolia testnet.
     * @return The network configuration for the Ethereum Sepolia testnet.
     */
    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789,
            usdc: 0x53844F9577C2334e541Aec7Df7174ECe5dF1fCf0, // Update with your own mock token
            account: BURNER_WALLET
        });
    }

    /**
     * @dev Get the network configuration for the Arbitrum mainnet.
     * @return The network configuration for the Arbitrum mainnet.
     */
    function getArbMainnetConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032,
            usdc: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
            account: BURNER_WALLET
        });
    }

    /**
     * @dev Get the network configuration for the zkSync Sepolia testnet.
     * @return The network configuration for the zkSync Sepolia testnet.
     */
    function getZkSyncSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: address(0), // There is no entrypoint in zkSync!
            usdc: 0x5A7d6b2F92C77FAD6CCaBd7EE0624E64907Eaf3E, // not the real USDC on zksync sepolia
            account: BURNER_WALLET
        });
    }

    /**
     * @dev Get the network configuration for the zkSync mainnet.
     * @return The network configuration for the zkSync mainnet.
     */
    function getZkSyncConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: address(0), // supports native AA, so no entry point needed
            usdc: 0x1d17CBcF0D6D143135aE902365D2E5e2A16538D4,
            account: BURNER_WALLET
        });
    }

    /**
     * @dev Get or create the network configuration for the Anvil Ethereum testnet.
     * @return The network configuration for the Anvil Ethereum testnet.
     */
    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }

        // deploy mocks
        console2.log("Deploying mocks...");
        vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
        EntryPoint entryPoint = new EntryPoint();
        ERC20Mock erc20Mock = new ERC20Mock();
        vm.stopBroadcast();
        console2.log("Mocks deployed!");

        localNetworkConfig =
            NetworkConfig({entryPoint: address(entryPoint), usdc: address(erc20Mock), account: ANVIL_DEFAULT_ACCOUNT});
        return localNetworkConfig;
    }
}