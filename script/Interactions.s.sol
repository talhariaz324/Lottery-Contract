//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Raffle} from "../src/Raffle.sol";
import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {


    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator; //* Get the address of the vrf coordinator because we need to call the createSubscription function of the vrf coordinator
        (uint256 subId, ) = createSubscription(vrfCoordinator);
        return (subId, vrfCoordinator);
    }

    function  createSubscription (address vrfCoordinator) public  returns (uint256, address) {
        console.log("Creating subscription on chainId: ", block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription(); //* Use the mock contract to create the subscription by passing the address of the vrf coordinator
        vm.stopBroadcast();
        console.log("Subscription created successfully with id: ", subId);
        return (subId, vrfCoordinator);
    }


    function run() external {
        createSubscriptionUsingConfig();
    }
}


contract FundSubscription is Script,  CodConstants{

    uint256 public constant AMOUNT_TO_FUND = 1 ether; // 1 LINK (18 decimals)
    
    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address link = helperConfig.getConfig().link;
        fundSubscription(vrfCoordinator, subId, link);
    }

    function fundSubscription(address vrfCoordinator, uint256 subId, address link) public {
        console.log("Funding subscription: ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("Using chainId: ", block.chainid);

        if(block.chainid == DEFAULT_ANVIL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId, AMOUNT_TO_FUND);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(vrfCoordinator, AMOUNT_TO_FUND, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}


//* We need to pass the address of latest depolyed raffle contract to add it as a consumer, for this purpose we use the DevOpsTools to get the address of the latest deployed raffle contract and give permissions to it in toml file
contract AddConsumer is Script {

    function addConsumerUsingConfig(address mostRecentRaffle) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        addConsumer(mostRecentRaffle, vrfCoordinator, subId);
    }

    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId) public {
        console.log("Adding consumer to raffle: ", contractToAddToVrf);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("block.chainid: ", block.chainid);

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf); // add consumer is a function of the vrf coordinator mock contract and it takes the subscription id and the address of the contract to add as a consumer
        vm.stopBroadcast();
    }
    
    function run() external {
        address latestRaffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid); // For testing we need to get the address of the latest deployed raffle contract
        addConsumerUsingConfig(latestRaffle);
    }
}