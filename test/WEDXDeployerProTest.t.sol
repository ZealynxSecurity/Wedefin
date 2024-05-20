// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/WEDXDeployerPro.sol";
import "../contracts/WEDXProPortfolio.sol";

contract WEDXProPortfolioTest is Test {
    WEDXDeployerPro deployer;
    address portfolioAddress;
    MaliciousContract malicious;
    address owner = address(this);

    // Real on-chain contract addresses
    // address wedxGroupAddress = 0x...; // real WEDXGroup contract address
    // address assetManagerAddress = 0x...; // real AssetManager contract address
    // address treasuryAddress = 0x...; // real Treasury contract address
    // address swapContractAddress = 0x...; // real Swap contract address
    // address lenderContractAddress = 0x...; // real Lender contract address

    function setUp() public {
        // Deploy the deployer contract
        deployer = new WEDXDeployerPro();

        // Create the portfolio using the deployer
        vm.startPrank(owner);
        deployer.createProPortfolio();
        portfolioAddress = deployer.getUserProPortfolioAddress(owner);
        vm.stopPrank();

        // Perform necessary on-chain environment setup
        vm.startPrank(owner);
        // Call initial functions if necessary, e.g., initial deposits
        WEDXProPortfolio(payable(portfolioAddress)).deposit{value: 1 ether}();
        vm.stopPrank();

        // Deploy the malicious contract
        malicious = new MaliciousContract(WEDXProPortfolio(payable(portfolioAddress)));

        // Deal Ether to the portfolio and malicious contract for testing
        vm.deal(portfolioAddress, 10 ether);
        vm.deal(address(malicious), 1 ether);
    }

    function testDeposit() public {
        uint256 initialBalance = address(portfolioAddress).balance;
        uint256 depositAmount = 1 ether;

        // Deposit into the portfolio
        vm.prank(owner);
        WEDXProPortfolio(payable(portfolioAddress)).deposit{value: depositAmount}();
        uint256 finalBalance = address(portfolioAddress).balance;

        assertEq(finalBalance, initialBalance + depositAmount);
    }

    function testWithdrawBruteForcedReentrancy() public {
        uint256 depositAmount = 1 ether;

        // Attempt to exploit reentrancy
        vm.expectRevert("Withdrawal failed");
        vm.prank(owner);
        malicious.attack{value: depositAmount}();

        // Ensure the balance is not drained
        uint256 finalBalance = address(portfolioAddress).balance;
        assertEq(finalBalance, 10 ether);  // Ensure the balance is not drained
    }
}

contract MaliciousContract {
    WEDXProPortfolio public portfolio;
    uint256 public reentrancyCount;

    constructor(WEDXProPortfolio _portfolio) {
        portfolio = _portfolio;
    }

    receive() external payable {
        if (reentrancyCount < 1) {
            reentrancyCount++;
            portfolio.withdrawBruteForced();
        }
    }

    function attack() external payable {
        require(msg.value > 0, "Must send Ether to attack");
        portfolio.deposit{value: msg.value}();
        portfolio.withdrawBruteForced();
    }
}
