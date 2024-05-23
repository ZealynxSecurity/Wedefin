// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/WEDXDeployerPro.sol";
import "../contracts/WEDXDeployerIndex.sol";
import "../contracts/WEDXProPortfolio.sol";
import "../contracts/WEDXIndexPortfolio.sol";
import "../contracts/WEDXGroup.sol";
import "../contracts/WEDXswap.sol";
import "../contracts/WEDXlender.sol";
import "../contracts/WEDXManager.sol";
import "../contracts/WEDXRanker.sol";
import "../contracts/WEDXTreasury.sol";
import "../contracts/WEDXConstants.sol";

contract WEDXIndexPortfolioTest is Test {
    WEDXDeployerPro deployerPro;
    WEDXDeployerIndex deployerIndex;
    WEDXGroup wedxGroup;
    WEDXswap wedxSwap;
    WEDXlender wedxLender;
    WEDXManager wedxManager;
    WEDXRanker wedxRanker;
    WEDXTreasury wedxTreasury;
    WEDXConstants wedxConstants;
    address proPortfolioAddress;
    address indexPortfolioAddress;
    // MaliciousContract maliciousPro;
    // MaliciousContract maliciousIndex;
    address owner = address(this);

    function setUp() public {
        // Deploy the WEDXGroup contract
        wedxGroup = new WEDXGroup(owner);
        address wedxGroupAddress = address(wedxGroup);

        // Deploy the other necessary contracts
        wedxSwap = new WEDXswap();
        wedxLender = new WEDXlender();
        wedxManager = new WEDXManager();
        wedxRanker = new WEDXRanker();
        wedxTreasury = new WEDXTreasury();

        // Update WEDXGroup with the addresses of the deployed contracts
        wedxGroup.changeManagerAddress(address(wedxManager));
        wedxGroup.changeSwapContractAddress(address(wedxSwap));
        wedxGroup.changeLenderContractAddress(address(wedxLender));
        wedxGroup.changeRankAddress(address(wedxRanker));
        wedxGroup.changeTreasuryAddress(address(wedxTreasury));

        deployerIndex = new WEDXDeployerIndex();

        wedxGroup.changeDeployerIndexAddress(address(deployerIndex));

 
        // Create the index portfolio using the deployerIndex
        vm.startPrank(owner);
        deployerIndex.createIndexPortfolio();
        indexPortfolioAddress = deployerIndex.getUserIndexPortfolioAddress(owner);
        vm.stopPrank();


        // Deploy the malicious contracts
        // maliciousPro = new MaliciousContract(WEDXProPortfolio(payable(proPortfolioAddress)));
        // maliciousIndex = new MaliciousContract(WEDXIndexPortfolio(payable(indexPortfolioAddress)));

        // Deal Ether to the portfolios and malicious contracts for testing
        vm.deal(indexPortfolioAddress, 10 ether);
        // vm.deal(address(maliciousPro), 1 ether);
        // vm.deal(address(maliciousIndex), 1 ether);
    }



    // function testProDeposit() public {
    //     uint256 initialBalance = address(proPortfolioAddress).balance;
    //     uint256 depositAmount = 1 ether;

    //     // Deposit into the pro portfolio
    //     vm.prank(owner);
    //     WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();
    //     uint256 finalBalance = address(proPortfolioAddress).balance;

    //     assertEq(finalBalance, initialBalance + depositAmount);
    // }

    function testIndexDeposit() public {
        uint256 initialBalance = address(indexPortfolioAddress).balance;
        uint256 depositAmount = 1 ether;

        // Deposit into the index portfolio
        vm.prank(owner);
        WEDXIndexPortfolio(payable(indexPortfolioAddress)).deposit{value: depositAmount}();
        uint256 finalBalance = address(indexPortfolioAddress).balance;

        assertEq(finalBalance, initialBalance + depositAmount);
    }

    // function testProWithdrawBruteForcedReentrancy() public {
    //     uint256 depositAmount = 1 ether;

    //     // Attempt to exploit reentrancy in pro portfolio
    //     vm.expectRevert("Withdrawal failed");
    //     vm.prank(owner);
    //     maliciousPro.attack{value: depositAmount}();

    //     // Ensure the balance is not drained
    //     uint256 finalBalance = address(proPortfolioAddress).balance;
    //     assertEq(finalBalance, 10 ether);  // Ensure the balance is not drained
    // }

    // function testIndexWithdrawBruteForcedReentrancy() public {
    //     uint256 depositAmount = 1 ether;

    //     // Attempt to exploit reentrancy in index portfolio
    //     vm.expectRevert("Withdrawal failed");
    //     vm.prank(owner);
    //     maliciousIndex.attack{value: depositAmount}();

    //     // Ensure the balance is not drained
    //     uint256 finalBalance = address(indexPortfolioAddress).balance;
    //     assertEq(finalBalance, 10 ether);  // Ensure the balance is not drained
    // }
}

// contract MaliciousContract {
//     WEDXProPortfolio public proPortfolio;
//     WEDXIndexPortfolio public indexPortfolio;
//     uint256 public reentrancyCount;

//     constructor(WEDXProPortfolio _proPortfolio) {
//         proPortfolio = _proPortfolio;
//     }

//     // constructor(WEDXIndexPortfolio _indexPortfolio) {
//     //     indexPortfolio = _indexPortfolio;
//     // }

//     receive() external payable {
//         if (reentrancyCount < 1) {
//             reentrancyCount++;
//             proPortfolio.withdrawBruteForced();
//         }
//     }

//     function attack() external payable {
//         require(msg.value > 0, "Must send Ether to attack");
//         proPortfolio.deposit{value: msg.value}();
//         proPortfolio.withdrawBruteForced();
//     }
// }
