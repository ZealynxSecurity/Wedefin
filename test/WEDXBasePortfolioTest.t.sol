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

contract WEDXBasePortfolioTest is Test {
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

        // Deploy the malicious contracts

        // Deal Ether to the portfolios and malicious contracts for testing
        vm.deal(proPortfolioAddress, 10 ether);
    }



    function testGetAssets() public {
        // Step 1: Set up initial assets and their amounts
        address[] memory newAssets = new address[](3);
        newAssets[0] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        newAssets[1] = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI
        newAssets[2] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1000 * 1e6; // 1000 USDC
        amounts[1] = 2000 * 1e18; // 2000 DAI
        amounts[2] = 3 * 1e18; // 3 WETH

        // Step 2: Deposit ETH to the pro portfolio to simulate asset acquisition
        uint256 depositAmount = 1 ether;

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();

        // Step 3: Mock the getTokenBalance calls
        for (uint256 i = 0; i < newAssets.length; i++) {
            vm.mockCall(
                wedxGroup.getLenderContractAddress(),
                abi.encodeWithSelector(IWEDXlender.getTokenBalance.selector, newAssets[i], proPortfolioAddress),
                abi.encode(amounts[i])
            );
        }

        // Step 4: Call getAssetsExtended
        vm.prank(owner);
        uint256[] memory extendedAssets = WEDXProPortfolio(payable(proPortfolioAddress)).getAssetsExtended();

        // Step 5: Print the results
        console.log("Extended assets:");
        for (uint256 i = 0; i < extendedAssets.length; i++) {
            console.log("Asset", i, "amount:", extendedAssets[i]);
        }

        console.log("Test getAssetsExtended completed successfully.");
    }


    function testGetAddresses() public {
        // Mocking token addresses
        address[] memory tokenAddresses = new address[](3);
        tokenAddresses[0] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // cWNATIVEAddress


        // Step 2: Deposit ETH to the pro portfolio to simulate asset acquisition
        uint256 depositAmount = 1 ether;

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();

        WEDXProPortfolio proPortfolio = WEDXProPortfolio(payable(proPortfolioAddress));
        address[] memory addresses = proPortfolio.getAddresses();

        for (uint i = 0; i < addresses.length; i++) {
            assertEq(addresses[i], tokenAddresses[i], "Token address should match");
        }

        console.log("Test getAddresses completed successfully.");
    }

    function testGetLastTimestamp() public {
        // Mocking lastTimestamp
        uint256 expectedTimestamp = block.timestamp;

        vm.mockCall(
            proPortfolioAddress,
            abi.encodeWithSelector(bytes4(keccak256("lastTimestamp()"))),
            abi.encode(expectedTimestamp)
        );

        WEDXProPortfolio proPortfolio = WEDXProPortfolio(payable(proPortfolioAddress));
        uint256 lastTimestamp = proPortfolio.getLastTimestamp();

        assertEq(lastTimestamp, expectedTimestamp, "Last timestamp should match");
    }

    function testGetMinPercAllowance() public {

        WEDXProPortfolio proPortfolio = WEDXProPortfolio(payable(proPortfolioAddress));
        uint256 minPercAllowance = proPortfolio.getMinPercAllowance();

        assertEq(minPercAllowance, 20000, "Min perc allowance should match");
    }



    function testGetDelegatedAddress() public {
        // Mocking delegatedAddress
        address expectedDelegatedAddress = address(0); 

        WEDXProPortfolio proPortfolio = WEDXProPortfolio(payable(proPortfolioAddress));
        address delegatedAddress = proPortfolio.getDelegatedAddress();

        assertEq(delegatedAddress, expectedDelegatedAddress, "Delegated address should match");
    }

}
