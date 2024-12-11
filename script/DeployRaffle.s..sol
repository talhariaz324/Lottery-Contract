// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Raffle} from "../src/Raffle.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";
/* //* Flow: 1) Deploy the contract on Sepolia or local network 2) Use the deployment for testing */

contract DeployRaffle is Script {
    //* Entry point for the script;
    function run() external {
        deployContract();
    }

    //* Script for deploying the contract
    function deployContract() public returns (Raffle, HelperConfig) {
        //* HelperConfig provides network-specific configurations, such as mocks for local or specific settings for testnets (e.g., Sepolia) or mainnet.
        HelperConfig helperConfig = new HelperConfig();
        /* //* Retrieves the appropriate configuration based on the target chain uses block.chainid and this would be based on which chain the script is running on --> definately we need to deply script to seploia in order to get the sepolia config
       //* If local, it deploys mocks (e.g., mock VRFCoordinator). 
       //* If Sepolia, it uses pre-defined Sepolia configurations. */

        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

        if(networkConfig.subscriptionId == 0) {
            //* If subscription id is 0 (default), then we need to create a subscription
            CreateSubscription createSubscription = new CreateSubscription();
            (networkConfig.subscriptionId, networkConfig.vrfCoordinator) = createSubscription.createSubscriptionUsingConfig();
            //* Equilent to
            // (uint2566 subId, address vrfCoordinator) = createSubscription.createSubscriptionUsingConfig();
            // networkConfig.subscriptionId = subId;
            // networkConfig.vrfCoordinator = vrfCoordinator;

            //* We created the subs and now need to fund the subscription and then add consumer to the subscription in order to get the random number

            // FUNDS IT!
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(networkConfig.vrfCoordinator, networkConfig.subscriptionId, networkConfig.link);
            
        }

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

        //* After deployment of the contract we need to add it as a consumer to the vrf coordinator

        AddConsumer addConsumer = new AddConsumer();
        //* Dont need to broadcast as the addConsumer function have vm.startBroadcast() and vm.stopBroadcast()
        addConsumer.addConsumer(address(raffle), networkConfig.vrfCoordinator, networkConfig.subscriptionId);
        return (raffle, helperConfig);
    }
}
