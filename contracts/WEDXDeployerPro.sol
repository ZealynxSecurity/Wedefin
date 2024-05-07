// SPDX-License-Identifier: MIT
/*
    This smart contract handles the pro app for the traders
*/
pragma solidity ^0.8.20;
pragma abicoder v2;

import "./IWEDXInterfaces.sol";
import "./WEDXConstants.sol";
import "./WEDXProPortfolio.sol";

contract WEDXDeployerPro is WEDXConstants {
    
    mapping(address => address) public userProPortfolio;
    mapping(address => address) public proPortfolioUser;
    mapping(address => bool) public activeProPortfolio;

    constructor() {}

    function createProPortfolio() public {
        require( userProPortfolio[msg.sender] == address(0), "User already has a portfolio" );
        address deployedContract = address( new WEDXProPortfolio( msg.sender ) );
        userProPortfolio[msg.sender] = deployedContract;
        proPortfolioUser[deployedContract] = msg.sender;
        activeProPortfolio[deployedContract] = true;
    }

    function isProPortfolioActive( address portfolioAddress ) public view returns (bool) {
        return activeProPortfolio[portfolioAddress];
    }

    function getUserProPortfolioAddress( address user ) public view returns (address) {
        return userProPortfolio[user];
    }

    function getUserFromProPortfolioAddress( address portfolio ) public view returns (address) {
        return proPortfolioUser[portfolio];
    }

}
