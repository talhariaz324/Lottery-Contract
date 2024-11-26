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
pragma solidity ^0.8.19;


// imports


// errors
error Raffle__NotEnoughEthSent();

/* 
    @title A Raffle Contract
    @author Talha Riaz
    @notice This contract is for creating a decentralized raffle
    @dev This implements chainlink VRFv2.5 keepers to ensure the contract can be executed
*/
contract Raffle {

    //State Variables
    uint256 private immutable i_entranceFee;
    address payable[] private s_players; //* storage variable and it keep change and payable because any address can send eth

    //Events ---> //* For migration from 1 contract to another, just listen and even helpful on the frontend
    event RaffleEnter(address indexed player); //* indexed is used to make the query better on the player address. EVM log --> Event --> index make topic in that event
        
    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    function enterRaffle() public payable {
        if(msg.value < i_entranceFee) { //* More gas efficent than require but now we can pass custom error in require as well in 0.18.26 version of solidity
            revert Raffle__NotEnoughEthSent();
        }
        s_players.push(payable(msg.sender)); //* msg.sender is the address of the sender and make it payable because we want to store the address of the sender in the array as payable
        emit RaffleEnter(msg.sender);
    }

    function pickWinner() public {}

    /* GETTER FUNCTIONS */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
