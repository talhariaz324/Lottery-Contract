//* These are the layout from the solidity docs for readability.

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
// Imports

import {VRFConsumerBaseV2Plus} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/* 
    @title A Raffle Contract
    @author Talha Riaz
    @notice This contract is for creating a decentralized raffle
    @dev This implements chainlink VRFv2.5 keepers to ensure the contract can be executed
*/
contract Raffle is VRFConsumerBaseV2Plus {
    // errors
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState); //* Here we are parsing the raffle state as num, 0 open and 1 calculating
    //CONSTANTS

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // Type Declarations
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    //State Variables
    uint256 private immutable i_entranceFee;
    address payable[] private s_players; //* storage variable and it keep change and payable because any address can send eth
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyhash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable private s_recentWinner;
    uint256 private s_lastTimeStamp;
    RaffleState private s_raffleState;

    //Events ---> //* For migration from 1 contract to another, just listen and even helpful on the frontend
    event RaffleEnter(address indexed player); //* indexed is used to make the query better on the player address. EVM log --> Event --> index make topic in that event
    event WinnerPicked(address indexed winner);
    event RequestForRandomWordsForWinner(uint256 indexed requestId);
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinatorV2,
        uint256 subscriptionId,
        bytes32 keyhash,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp; //* The time when the contract is deployed
        i_keyhash = keyhash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            //* More gas efficent than require but now we can pass custom error in require as well in 0.18.26 version of solidity
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender)); //* msg.sender is the address of the sender and make it payable because we want to store the address of the sender in the array as payable
        emit RaffleEnter(msg.sender);
    }

    /*//* Picking up the winner should be auto and we can use the chainlink keepers (automation) to do this. Time based and customize logic. We will use custom */
    //* In the doc we need to implement the checkUpkeep (keep check either time to pick the winner or not) function and performUpkeep (Logic to get the random number and pick the winner using fulfillRandomWords callback function) function

    //* Keep ruuning and when the time is passed then perform the logic in performUpkeep because its kind of cron job
    function checkUpkeep(
        bytes memory /* checkData */ //* checkData is the data that we can use in performUpkeep for more customization but for now we don't need it.
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */ ) {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval); //* Here bloc.timestamp is the current time and s_lastTimeStamp is the time when the contract is deployed and if < then mean we have to wait for the interval to pass
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasPlayers && hasBalance);
        return (upkeepNeeded, "0x0"); //* 0x0 is the data that we can use in performUpkeep for more customization but for now we don't need it.
    }

    // AUTOMATICALLY RUNS WHEN THE TIME IS PASSED
    function performUpkeep(bytes calldata /* performData */ ) external {
        // Check
        (bool upkeepNeeded,) = checkUpkeep(""); // Here passing the empty string because we don't need to pass any data
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyhash, //* s_keyHash is the gas lane that you want to use. The gas price.
            subId: i_subscriptionId, //* s_subscriptionId is the subscription id of the chainlink node
            requestConfirmations: REQUEST_CONFIRMATIONS, //* requestConfirmations is the number of confirmations you want to wait for the random number, As more, more secure
            callbackGasLimit: i_callbackGasLimit, //* callbackGasLimit is the gas limit for the callback function, s_keyHash is the gas lane that you want to use and this limit of gas
            numWords: NUM_WORDS, //* numWords is the number of random words you want to request
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        //* This is reducunet becasuse requestRandomWords also emits this event and we dont need to emit it again but for testing purpose we will emit it here
        emit RequestForRandomWordsForWinner(requestId);
    }

    //* This is the abstract function we have to implement from the VRFConsumerBaseV2Plus contract, This is callback that will be called when the random number is generated by chainlink node and we will get the random number in randomWords array and can do what we want.
    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata randomWords) internal override {
        //*requestId is the id of the req that we did above
        //* What is modulo? Actually it is the remainder of the division of two numbers. so if you divide 34892375823758723857 % 10 then remainder must be between 0 to 9. That's great actually.
        //* WHat we will do is to pick the random number and length of the s_players array and get the modulo and decalre the winner without outbound
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        (bool success,) = recentWinner.call{value: address(this).balance}(""); //* This will send all the contract balance of contract (got from all players) to the winner
        if (!success) {
            revert Raffle__TransferFailed();
        }
        s_players = new address payable[](0); //* Reset the players array by reinitializing it
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);
    }

    /* GETTER FUNCTIONS */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }
}

//* Chainlink is the oracle network and we used the VRF feature of chainlink to get the random number /* Steps: 1) Make Subscription 2) Fund Subscription  3) Deploy Consumer Contract 4) Create Request 5) Chainlink Node will give the random number */
//* We have 2 methods for using VRF: 1) Subscription (Subscription contract-> Fund -> Req -> Get the Random num) 2) Direct Funding (Not Recommended Because we directly fund the contract (here Raffle) and each time we have to fund)

/*
//* CEI PATTERN --> Check, Effect, Interactions Whenever code then make sure to have this pattern. Let's see the example below:


function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
    //* Checks (No Checks here but it can be like if, require)
    

    //* Effects (Intenal Contract State Changes) --> Like accessing the state variable and changing it
    uint256 indexOfWinner = randomWords[0] % s_players.length;
    address payable recentWinner = s_players[indexOfWinner];
    s_recentWinner = recentWinner;
    s_raffleState = RaffleState.OPEN;


     //* As event and emit is the internal contract so we should place it in effects   
        emit WinnerPicked(s_recentWinner);

    //* Interactions (External Contract  State Changes) --> Like sending eth to the winner using external function
    (bool success,) = recentWinner.call{value: address(this).balance}(""); //* This will send all the contract balance of contract (got from all players) to the winner
    if (!success) {
            revert Raffle__TransferFailed();
        }
        s_players = new address payable[](0); //* Reset the players array by reinitializing it
        s_lastTimeStamp = block.timestamp;


    }


    */

/* //* Till now flow is player eenter raffle, cron job running, when time then performUpkeep and then fulfillRandomWords becuase performUpkeep is the logic to pick the winner and fulfillRandomWords is the callback that will be called when the random number is generated by chainlink node and we will get the random number in randomWords array and can do what we want. */

/*
   memory
Purpose: Used for temporary variables during the execution of a function.
Behavior:
Allocated for variables that are only needed within the scope of a function.
Automatically deleted when the function execution ends.
Typical Use Cases:
Applied to variables that may be modified within the function.
Used for input and output parameters of reference types like arrays and structs (unless explicitly marked as calldata or storage).
Key Property:
Data is modifiable within the function.


2. calldata
Purpose: Used for variables that are passed as inputs to a function but are read-only.
Behavior:
These variables are directly accessed from the calldata section of the Ethereum Virtual Machine (EVM) and are not copied to memory.
Immutable and cannot be modified within the function.
Automatically discarded after the function execution ends.
Typical Use Cases:
Primarily used for input parameters of reference types when the function only needs to read the data.
Key Property:
Data is read-only.
    */

/* //* Tests:1)) Deploy script 2) Tests: local, fork testnet and fork mainnet  */


//* forge coverage ---> is the command to check the coverage of the contract by tests, Means it tells how much lines of code are covered by tests. its not 100% accurate but its good to check the coverage of the contract. Keep test and keep improve the contract codebase. But as we write the tests we dont know which lines are covered and which are not, so we can run command: "forge coverage --report debug > coverage.txt", this will give us the coverage report in the text file and we can skim the lines in our targeted contract (file) like here Raffle.sol. We can go and check that line and write code for it if needed.