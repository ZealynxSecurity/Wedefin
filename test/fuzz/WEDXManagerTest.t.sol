// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/WEDXDeployerPro.sol";
import "../../contracts/WEDXDeployerIndex.sol";
import "../../contracts/WEDXProPortfolio.sol";
import "../../contracts/WEDXIndexPortfolio.sol";
import "../../contracts/WEDXGroup.sol";
import "../../contracts/WEDXswap.sol";
import "../../contracts/WEDXlender.sol";
import "../../contracts/WEDXManager.sol";
import "../../contracts/WEDXRanker.sol";
import "../../contracts/WEDXTreasury.sol";
import "../../contracts/WEDXConstants.sol";
// import "../interfaces/interface.sol";


contract WEDXManagerFuzzTest is Test {
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

    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant WETH = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe;
    address public constant WNATIVE = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

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
        distroLength = bound(distroLength, 1, 10);
        assetLength = bound(assetLength, 1, 10);

        if (distroLength != assetLength) return;

        uint256[] memory distro = new uint256[](distroLength);
        address[] memory assets = new address[](assetLength);

        for (uint256 i = 0; i < distroLength; i++) {
            distro[i] = uint256(keccak256(abi.encodePacked(i, block.timestamp))) % 1000000;
            assets[i] = address(uint160(uint256(keccak256(abi.encodePacked(i, block.timestamp)))));
        }

        traderId = owner;

        vm.prank(proPortfolioAddress);
        wedxTreasury.depositGeneralFee{value: 0.05 ether}();

        vm.prank(owner);
        uint256 result = WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: 0.05 ether}();
        console.log("result", result);

        vm.prank(proPortfolioAddress);
        wedxManager.updateTraderData(traderId, distro, assets);

        WEDXManager.trader memory traderData = wedxManager.getTraderData(traderId);

        assertEq(traderData.currentTokenAddresses.length, assets.length, "Assets length mismatch");
        assertEq(traderData.currentDistro.length, distro.length, "Distribution length mismatch");

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

        distroLength = bound(distroLength, 1, 10);
        assetLength = bound(assetLength, 1, 10);

        if (distroLength != assetLength) return;

        uint256[] memory distro = new uint256[](distroLength);
        address[] memory assets = new address[](assetLength);

        for (uint256 i = 0; i < distroLength; i++) {
            distro[i] = uint256(keccak256(abi.encodePacked(i, block.timestamp))) % 1000000;
            assets[i] = address(uint160(uint256(keccak256(abi.encodePacked(i, block.timestamp)))));
        }

        traderId = owner;

        vm.prank(proPortfolioAddress);
        wedxTreasury.depositGeneralFee{value: 0.05 ether}();

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: 0.05 ether}();

        vm.prank(proPortfolioAddress);
        wedxManager.updateTraderData(traderId, distro, assets);

        vm.warp(block.timestamp + 31 days);

        vm.prank(proPortfolioAddress);
        uint256 ranking = wedxManager.computeRanking(traderId);

        WEDXManager.trader memory traderData = wedxManager.getTraderData(traderId);

        assertEq(traderData.currentTokenAddresses.length, assets.length, "Assets length mismatch");
        assertEq(traderData.currentDistro.length, distro.length, "Distribution length mismatch");

        for (uint256 i = 0; i < assets.length; i++) {
            assertEq(traderData.currentTokenAddresses[i], assets[i], "Asset address mismatch");
            assertEq(traderData.currentDistro[i], distro[i], "Distribution value mismatch");
        }

        assertGt(ranking, 0, "Ranking should be greater than zero");
    }
}



