// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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


    event RaffleEnter(address indexed player); //* indexed is used to make the query better on the player address. EVM log --> Event --> index make topic in that event
    event WinnerPicked(address indexed winner);

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

        //* Cheat to give funds to player
        vm.deal(PLAYER, STARTING_USER_BALANCE); //* This is a cheat to give funds to player
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontSendEnoughEth() public {
        //* Arrange -->>> Set up the environment for the test by making PLAYER the sender of the next transaction using vm.prank(PLAYER).
        // Sets msg.sender to be PLAYER for the next transaction
        vm.prank(PLAYER);

        //* Act & Assert -->>> Expects the next transaction to revert with the specific error using vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector).
        // Expects the next transaction to revert with the specific error
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector); //*ASSERT
        // Attempts to enter raffle without sending any ETH
        raffle.enterRaffle(); //*ACT
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        //* Arrange --> Set up the environment for the test by making PLAYER the sender of the next transaction using vm.prank(PLAYER).
        vm.prank(PLAYER);

        //* Act --> what we are doing
        raffle.enterRaffle{value: entranceFee}();

        //* Assert --> Verify
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        //*Arrange
        vm.prank(PLAYER);

        //*Assert ,,, Here we need to set the expectEmit before because we need to check if the event is emitted or not but for normal we have arrange, act and assert
        vm.expectEmit(true, false, false, false, address(raffle)); //* first 3 are for topics of event (params), last one is for address and the 4th one is for additonal data

        //*Act
        emit RaffleEnter(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }


    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Set the sender of the next transaction to PLAYER
        vm.prank(PLAYER);
        // PLAYER enters the raffle by sending the entrance fee
        raffle.enterRaffle{value: entranceFee}();
        
        // Fast forward the blockchain's timestamp by the interval plus 1 second using vm.warp cheat
        vm.warp(block.timestamp + interval + 1);
        // Move the blockchain's block number forward by 1 using vm.roll cheat as time passed so need to update the block number as well
        vm.roll(block.number + 1);
        
        // Perform upkeep to transition the raffle state to CALCULATING and for this function we need to set time and block number as well as it has if when it starts
        raffle.performUpkeep("");

        // Expect the next transaction to revert with the specific error Raffle__RaffleNotOpen
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        // Set the sender of the next transaction to PLAYER
        vm.prank(PLAYER);
        // Attempt to enter the raffle while it is in the CALCULATING state, which should revert
        raffle.enterRaffle{value: entranceFee}();
    }
}
