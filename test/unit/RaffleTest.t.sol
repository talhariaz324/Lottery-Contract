// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s..sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";


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

/* //* This test fails because there is no consumer for the subscription of random number in performupkeep function in contract. 
    //* VRF uses subscription to get random number and we need to set up a consumer for the subscription. So that who pays for the subscription can get the random number only using that consumer.
    //* We have to make the subscription in the script while deploying the contract based on the block.chainid
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

    */


   //* After making subs and funds and consumer we need to test again the dontAllowPlayersToEnterWhileRaffleIsCalculating function (same as  above)
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
        raffle.performUpkeep(""); //* Function of the raffle contract that uses the vrf to get the random number and vrf need subscription and consumer to get the random number

        // Expect the next transaction to revert with the specific error Raffle__RaffleNotOpen
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        // Set the sender of the next transaction to PLAYER
        vm.prank(PLAYER);
        // Attempt to enter the raffle while it is in the CALCULATING state, which should revert
        raffle.enterRaffle{value: entranceFee}();
    }

    // CHECKUPKEEP
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        //* Arrange
        // SKIP ENNTRANCE OF PLAYER
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //* Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //* Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public {
        //* Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        //* Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //* Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasNotPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        
        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        
        // Assert
        assert(upkeepNeeded);
    }

    // PERFORMUPKEEP

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        // parmas for checkUpkeep returns true
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act / Assert
        raffle.performUpkeep(""); //* This will revert if checkUpkeep returns false but it also sends true means assert is true (success)
    }
    
    function testPerformUpkeepRevertsIfCheckUpkeepReturnsFalse() public {
        // Arrange
        // parmas for the revert function in performUpkeep
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // Miss the checkupkeep params so return false
        //*Update params of performUpkeep reverts function with player data
        currentBalance = currentBalance + entranceFee;
        numPlayers = numPlayers + 1;
        // SKIP RAFFLE STATE intentionally, no need to update it

        // Act / Assert and this expectRevert with params so we need to pass the params in the expectRevert syntax known as "abi.encodeWithSelector"
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, raffleState));
        raffle.performUpkeep("");
    }
    
    modifier raffleEntered{
         // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _; //* This make sure that the modifier is executed before the test
    }

    // What if we need to get data from emitted events in our tests?   
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
       //* As Arrange is too much same in most of tests so make its modifier is good practice
    
        // Act
        vm.recordLogs(); //* This is a cheat to record the events emitted in the next function which is here performUpkeep
        raffle.performUpkeep("");
        //* For getting the events we need to use the logs and we need to decode the logs using array
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // Logs  Strucute:
        
         /*  
         struct Log {
        //* The topics of the log, including the signature, if any. means params of events
        bytes32[] topics;
        //* The raw data of the log.
        bytes data;
        //* The address of the log's emitter.
        address emitter;
    }
         */
        bytes32 requestId = entries[1].topics[1]; // here entries is using index 1 because 0 index event is released by the VRF itself and topics is 1 also becuase 0 index is fixed by foundry for some other purpose. In short enteris[1] pick the log emit by your contract and topics[1] pick the requestId from the log that you emitt with event

        //* Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0); //* This is to check if the requestId is greater than 0 mean requestId is exists
        assert(uint256(raffleState) == uint256(Raffle.RaffleState.CALCULATING)); //* This is to check if the raffleState is CALCULATING
    }


//fuzz test: in which we can test the function with random values by giving just params to the function and foundry will test the function with random values


    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 requestId) public raffleEntered {
        // Expect a revert with the specific error selector from VRFCoordinatorV2_5Mock
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        // Call fulfillRandomWords on the VRFCoordinator, passing in the correct arguments
        // Ensure that `requestId` is properly passed instead of hardcoding 0.
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoneyToWinner() public raffleEntered {
        // Arrange
        uint256 additionalEntrants = 3; // 4 total
        uint256 startingIndex = 1;
        address expectedWinner = address(1);
        
        for(uint256 i = startingIndex; i < startingIndex + additionalEntrants ; i++){
            address player = address(uint160(i));
            hoax(player, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }
        
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act  
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 recentWinnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(recentWinnerBalance > winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}

 



//* units tests -> integration tests -> fork tests -> staging tests on maininet or seploia */


