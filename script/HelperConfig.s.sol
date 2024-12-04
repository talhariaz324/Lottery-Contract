// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";

import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

//* Chainids are constants and you can get them from the internet

abstract contract CodConstants {
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant DEFAULT_ANVIL_CHAIN_ID = 31337;
    uint96 public constant DEFAULT_ANVIL_BASE_FEE = 0.25 ether;
    uint96 public constant DEFAULT_ANVIL_GAS_PRICE = 1000000000;
    uint256 public constant DEFAULT_ANVIL_LINK_PER_ETH = 10 ether;
}

contract HelperConfig is Script, CodConstants {

    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint256 subscriptionId;
    }

    NetworkConfig public localNetworkConfig;

    mapping(uint256 chainId => NetworkConfig) public networkConfigs; //* Mapping of chainId (chainId is the chainId of the chain sepolia, mainnet, etc) to NetworkConfig

    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    //* This is the function that will be called to get the sepolia eth config
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) { /* //* pure: Cannot read or modify the state. view: Can read but not modify the state. */
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a,
            gasLane: 0x8077df514608a09f83e4e8d300645594e5d7234665448ba83f51a50f842bd3d9,
            callbackGasLimit: 500000,
            subscriptionId: 0 //* Auto increment by the script 
        });
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if(networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        }else if(chainId == DEFAULT_ANVIL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        }else{

        revert HelperConfig__InvalidChainId() ;

        }
    }

    function getConfig() public view returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid); //* block.chainid is the chain id of the chain that the contract is deployed on, If local then retrun local config
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // check if the config already exists
        if(localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        //* IF not, then make the config. But if we are deploying locally then we need to have mock vrf coordinator and it comes from the chainlink brownie contracts, GREAT
        // Deploy mocks vrfCoordinatior and such
        // vrfCoordinator is the node on the chain that will be responsible for coordinating the random number generation and the payment
        vm.startBroadcast(); //* For sending transactions to blockchain from contract and make the blockchain feels as sends by the eth address (some sender)
    // Deploying mock vrfcoordinator to anvil
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
            DEFAULT_ANVIL_BASE_FEE,
            DEFAULT_ANVIL_GAS_PRICE,
            DEFAULT_ANVIL_LINK_PER_ETH
        );  //* This requries  base fee, gas price, and link per eth

        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorMock),
            /* does not matter for anvil */
            gasLane: 0x8077df514608a09f83e4e8d300645594e5d7234665448ba83f51a50f842bd3d9,
            callbackGasLimit: 500000,
            subscriptionId: 0 // might to fix
        });

        return localNetworkConfig;
    }
}



//* LINK is the native cryptocurrency token used to pay for the services provided by the Chainlink decentralized oracle network. Link per eth is the ratio that how much links u need to pay for your tx.