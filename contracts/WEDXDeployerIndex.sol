// SPDX-License-Identifier: MIT
/*
    This smart contract handles the index app for the users
*/
pragma solidity ^0.8.20;
pragma abicoder v2;

import "./IWEDXInterfaces.sol";
import "./WEDXConstants.sol";
import "./WEDXIndexPortfolio.sol";

contract WEDXDeployerIndex is WEDXConstants {
    
    mapping(address => address) public userIndexPortfolio;
    mapping(address => address) public indexPortfolioUser;
    mapping(address => bool) public activeIndexPortfolio;

    constructor() {}

    function createIndexPortfolio() public {
        require( userIndexPortfolio[msg.sender] == address(0), "User already has a portfolio" );
        address deployedContract = address( new WEDXIndexPortfolio( msg.sender ) );
        userIndexPortfolio[msg.sender] = deployedContract;
        indexPortfolioUser[deployedContract] = msg.sender;
        activeIndexPortfolio[deployedContract] = true;
    }

    function isIndexPortfolioActive( address portfolioAddress ) public view returns (bool) {
        return activeIndexPortfolio[portfolioAddress];
    }

    function getUserIndexPortfolioAddress( address user ) public view returns (address) {
        return userIndexPortfolio[user];
    }

    function getUserFromIndexPortfolioAddress( address portfolio ) public view returns (address) {
        return indexPortfolioUser[portfolio];
    }

}
