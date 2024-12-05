// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s..sol";


contract RaffleTest is Test {

    Raffle public raffle;
    HelperConfig public helperConfig;
     uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint256 subscriptionId;

    address public PLAYER;
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        PLAYER = makeAddr("player"); //* Make a fake address based on the string. makeAddr is a function from std library
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract(); //* Directly storing raffle in raffle and config in helperConfig

        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        entranceFee = networkConfig.entranceFee;
        interval = networkConfig.interval;
        vrfCoordinator = networkConfig.vrfCoordinator;
        gasLane = networkConfig.gasLane;
        callbackGasLimit = networkConfig.callbackGasLimit;
        subscriptionId = networkConfig.subscriptionId;

    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

}