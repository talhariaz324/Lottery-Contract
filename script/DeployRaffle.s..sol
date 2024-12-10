// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Raffle} from "../src/Raffle.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/* //* Flow: 1) Deploy the contract on Sepolia or local network 2) Use the deployment for testing */

contract DeployRaffle is Script {
    //* Entry point for the script;
    function run() external {
        vm.startBroadcast();
    }

    //* Script for deploying the contract
    function deployContract() public returns (Raffle, HelperConfig) {
        //* HelperConfig provides network-specific configurations, such as mocks for local or specific settings for testnets (e.g., Sepolia) or mainnet.
        HelperConfig helperConfig = new HelperConfig();
        /* //* Retrieves the appropriate configuration based on the target chain uses block.chainid and this would be based on which chain the script is running on --> definately we need to deply script to seploia in order to get the sepolia config
       //* If local, it deploys mocks (e.g., mock VRFCoordinator). 
       //* If Sepolia, it uses pre-defined Sepolia configurations. */

        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

        //* Deploys the Raffle contract using the network-specific configuration.

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.subscriptionId,
            networkConfig.gasLane,
            networkConfig.callbackGasLimit
        );
        vm.stopBroadcast();

        return (raffle, helperConfig);
    }
}
