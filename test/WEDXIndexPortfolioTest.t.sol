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


function testIndexDepositWithSimpleFee() public {
    address cWNATIVEAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    uint256 initialBalance = IWETH9(cWNATIVEAddress).balanceOf(indexPortfolioAddress);
    uint256 depositAmount = 1 ether;

    console.log("Initial Balance in cWNATIVE:", initialBalance);

    // Mock the fee percentage
    uint256 feePercentage = 100; 
    uint256 distroNorm = 10000;  

    vm.mockCall(
        IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress(),
        abi.encodeWithSelector(IWEDXManager(IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress()).depositWithdrawFee.selector),
        abi.encode(feePercentage)
    );

    uint256 fee = (depositAmount * feePercentage) / distroNorm;
    uint256 expectedDepositAmount = depositAmount - fee;

    vm.mockCall(
        IWEDXGroup(_wedxGroupAddress).getTreasuryAddress(),
        abi.encodeWithSelector(IWEDXTreasury(IWEDXGroup(_wedxGroupAddress).getTreasuryAddress()).depositGeneralFee.selector),
        abi.encode()
    );

    // Perform the deposit
    vm.prank(owner);
    uint256 result = WEDXIndexPortfolio(payable(indexPortfolioAddress)).deposit{value: depositAmount}();
    console.log("Deposit result:", result);

    // Verify the final balance in cWNATIVE
    uint256 finalBalance = IWETH9(cWNATIVEAddress).balanceOf(indexPortfolioAddress);
    console.log("Final Balance in cWNATIVE:", finalBalance);

    // Assertions
    assertApproxEqRel(result, expectedDepositAmount, 1e16); // 1% tolerance
    assertTrue(finalBalance > initialBalance, "Final balance in cWNATIVE should be greater than initial balance after deposit");

    // Verifying balances after potential lending
    for (uint i = 0; i < WEDXIndexPortfolio(payable(indexPortfolioAddress)).getAddresses().length; i++) {
        address token = WEDXIndexPortfolio(payable(indexPortfolioAddress)).getAddresses()[i];
        uint256 balance = IWETH9(token).balanceOf(indexPortfolioAddress);
        console.log("Token balance after lending in cWNATIVE for token:", balance);
    }
}







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
