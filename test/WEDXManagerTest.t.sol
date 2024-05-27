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

import "./interfaces/interface.sol";


contract WEDXManagerTest is Test {
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
    address owner = address(this);

    address private constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address private constant WETH = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe;
    address constant WNATIVE = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

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

        // Deploy the WEDXDeployerPro contract
        deployerPro = new WEDXDeployerPro();

        // Update WEDXGroup with the addresses of the deployer contracts
        wedxGroup.changeDeployerProAddress(address(deployerPro));

        // Create the pro portfolio using the deployerPro
        vm.startPrank(owner);
        deployerPro.createProPortfolio();
        proPortfolioAddress = deployerPro.getUserProPortfolioAddress(owner);
        vm.stopPrank();

        // Deal Ether to the portfolios and malicious contracts for testing
        vm.deal(address(wedxManager), 10 ether);
        vm.deal(address(proPortfolioAddress), 10 ether);

    }

   function testFuzzUpdateTraderData(
        address traderId,
        uint256 distroLength,
        uint256 assetLength
    ) public {
        // Bound the lengths to a reasonable number to prevent excessive gas usage
        distroLength = bound(distroLength, 1, 10);
        assetLength = bound(assetLength, 1, 10);

        // Ensure the lengths match for a valid test case
        if (distroLength != assetLength) return;

        // Generate random distribution values and asset addresses
        uint256[] memory distro = new uint256[](distroLength);
        address[] memory assets = new address[](assetLength);

        for (uint256 i = 0; i < distroLength; i++) {
            distro[i] = uint256(keccak256(abi.encodePacked(i, block.timestamp))) % 1000000;
            assets[i] = address(uint160(uint256(keccak256(abi.encodePacked(i, block.timestamp)))));
        }

        // Ensure the traderId matches the owner
        traderId = owner;

        // Ensure the pro portfolio is correctly funded
        vm.prank(proPortfolioAddress);
        wedxTreasury.depositGeneralFee{value: 0.05 ether}();

        // Call the deposit function on the pro portfolio to initialize it
        vm.prank(owner);
        uint256 result = WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: 0.05 ether}();
        console.log("result", result);

        // Call the updateTraderData function using the proPortfolioAddress
        vm.prank(proPortfolioAddress);
        wedxManager.updateTraderData(traderId, distro, assets);

        // Retrieve the trader data to validate the update
        WEDXManager.trader memory traderData = wedxManager.getTraderData(traderId);

        // Simplified asserts to verify the lengths of the arrays
        assertEq(traderData.currentTokenAddresses.length, assets.length, "Assets length mismatch");
        assertEq(traderData.currentDistro.length, distro.length, "Distribution length mismatch");

        // Simple asserts to verify the contents of the arrays
        for (uint256 i = 0; i < assets.length; i++) {
            assertEq(traderData.currentTokenAddresses[i], assets[i], "Asset address mismatch");
            assertEq(traderData.currentDistro[i], distro[i], "Distribution value mismatch");
        }
    }


    function testFuzzComputeRanking(
        address traderId,
        uint256 distroLength,
        uint256 assetLength
    ) public {
        // Bound the lengths to a reasonable number to prevent excessive gas usage
        distroLength = bound(distroLength, 1, 10);
        assetLength = bound(assetLength, 1, 10);

        // Ensure the lengths match for a valid test case
        if (distroLength != assetLength) return;

        // Generate random distribution values and asset addresses
        uint256[] memory distro = new uint256[](distroLength);
        address[] memory assets = new address[](assetLength);

        for (uint256 i = 0; i < distroLength; i++) {
            distro[i] = uint256(keccak256(abi.encodePacked(i, block.timestamp))) % 1000000;
            assets[i] = address(uint160(uint256(keccak256(abi.encodePacked(i, block.timestamp)))));
        }

        // Ensure the traderId matches the owner
        traderId = owner;

        // Ensure the pro portfolio is correctly funded
        vm.prank(proPortfolioAddress);
        wedxTreasury.depositGeneralFee{value: 0.05 ether}();

        // Call the deposit function on the pro portfolio to initialize it
        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: 0.05 ether}();

        // Call the updateTraderData function using the proPortfolioAddress
        vm.prank(proPortfolioAddress);
        wedxManager.updateTraderData(traderId, distro, assets);

        // Advance time to ensure the ranking computation can occur
        vm.warp(block.timestamp + 31 days);

        // Call the computeRanking function using the proPortfolioAddress
        vm.prank(proPortfolioAddress);
        uint256 ranking = wedxManager.computeRanking(traderId);

        // Retrieve the trader data to validate the update
        WEDXManager.trader memory traderData = wedxManager.getTraderData(traderId);

        // Simplified asserts to verify the lengths of the arrays
        assertEq(traderData.currentTokenAddresses.length, assets.length, "Assets length mismatch");
        assertEq(traderData.currentDistro.length, distro.length, "Distribution length mismatch");

        // Simple asserts to verify the contents of the arrays
        for (uint256 i = 0; i < assets.length; i++) {
            assertEq(traderData.currentTokenAddresses[i], assets[i], "Asset address mismatch");
            assertEq(traderData.currentDistro[i], distro[i], "Distribution value mismatch");
        }

        // Assert that the ranking is computed
        assertGt(ranking, 0, "Ranking should be greater than zero");
    }
}



