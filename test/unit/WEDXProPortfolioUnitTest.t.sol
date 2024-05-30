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

contract WEDXProPortfolioUnitTest is Test {
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
    address constant cWNATIVEAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;


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

        vm.deal(proPortfolioAddress, 10 ether);
    }


    function testBasicDepositReflectsInCWETH() public {

        uint256 initialBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);
        uint256 depositAmount = 1 ether;

        console.log("Initial Balance in cWNATIVE:", initialBalance);

        vm.prank(owner);
        uint256 result = WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();
        console.log("result",result);

        uint256 finalBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

        console.log("Final Balance in cWNATIVE:", finalBalance);

        assertTrue(finalBalance > initialBalance, "Final balance in cWNATIVE should be greater than initial balance after deposit");
    }


    function testDepositWithSimpleFee() public {

        uint256 initialBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);
        uint256 depositAmount = 1 ether;

        console.log("Initial Balance in cWNATIVE:", initialBalance);

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

        vm.prank(owner);
        uint256 result = WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();
        console.log("result", result);

        uint256 finalBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

        console.log("Final Balance in cWNATIVE:", finalBalance);

        assertApproxEqRel(result, expectedDepositAmount, 1e16);

        assertTrue(finalBalance > initialBalance, "Final balance in cWNATIVE should be greater than initial balance after deposit");
    }


    function testBasicWithdraw() public {

        uint256 depositAmount = 2 ether;
        uint256 withdrawAmount = 1 ether;

        vm.prank(owner);
        uint256 result = WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();
        console.log("result", result);
        
        uint256 initialBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

        console.log("Initial Balance in cWNATIVE:", initialBalance);

        uint256 feePercentage = 100; 
        uint256 distroNorm = 10000; 
        vm.mockCall(
            IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress(),
            abi.encodeWithSelector(IWEDXManager(IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress()).depositWithdrawFee.selector),
            abi.encode(feePercentage)
        );

        vm.mockCall(
            IWEDXGroup(_wedxGroupAddress).getTreasuryAddress(),
            abi.encodeWithSelector(IWEDXTreasury(IWEDXGroup(_wedxGroupAddress).getTreasuryAddress()).depositGeneralFee.selector),
            abi.encode()
        );

        vm.warp(block.timestamp + 30 days);
        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).withdraw(withdrawAmount);

        uint256 fee = (withdrawAmount * feePercentage) / distroNorm;
        uint256 expectedWithdrawAmount = withdrawAmount - fee;

        uint256 finalBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

        console.log("Final Balance in cWNATIVE:", finalBalance);

        assertTrue(finalBalance < initialBalance, "Final balance in cWNATIVE should be less than initial balance after withdrawal");

        assertApproxEqRel(finalBalance, initialBalance - withdrawAmount, 1e16); 
    }


    function testBasicWithdrawBruteForcedReflectsInCWETH() public {

        uint256 depositAmount = 2 ether; 

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();

        uint256 initialBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

        console.log("Initial Balance in cWNATIVE after deposit:", initialBalance);

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).withdrawBruteForced();

        uint256 finalBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

        console.log("Final Balance in cWNATIVE after withdrawBruteForced:", finalBalance);

        assertTrue(finalBalance < initialBalance, "Final balance in cWNATIVE should be less than initial balance after withdrawBruteForced");
    }


    function testSimpleSetPortfolio() public {

        address[] memory newAssets = new address[](4);
        newAssets[0] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDC
        newAssets[1] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // DAI
        newAssets[2] = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe; // WETH
        newAssets[3] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDT

        uint256[] memory newDistribution = new uint256[](5);
        newDistribution[0] = 250000; // 25% USDC
        newDistribution[1] = 250000; // 25% DAI
        newDistribution[2] = 250000; // 25% WETH
        newDistribution[3] = 250000; // 25% USDT
        // newDistribution[4] = 0;      // 0% Native asset

        uint256[] memory normalizedDistribution = distroMath.normalize(newDistribution);

        for (uint i = 0; i < newAssets.length; i++) {
            console.log("Asset", i, ":", newAssets[i]);
        }
        for (uint i = 0; i < normalizedDistribution.length; i++) {
            console.log("Distribution", i, ":", normalizedDistribution[i]);
        }

        vm.prank(owner);
        uint256 result = WEDXProPortfolio(payable(proPortfolioAddress)).setPortfolio(newAssets, normalizedDistribution);

        console.log("setPortfolio result:", result);

    }


    // Not found => revert: User does not have this token
    function testSupplyLendToken() public {
        address tokenAddress = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe; 
        uint256 depositAmount = 1 ether; // 1 WETH deposit
        uint256 lendAmount = depositAmount;

        address[] memory newAssets = new address[](4);
        newAssets[0] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDC
        newAssets[1] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // DAI
        newAssets[2] = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe; // WETH
        newAssets[3] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDT

        uint256[] memory newDistribution = new uint256[](5);
        newDistribution[0] = 250000; // 25% USDC
        newDistribution[1] = 250000; // 25% DAI
        newDistribution[2] = 250000; // 25% WETH
        newDistribution[3] = 250000; // 25% USDT
        newDistribution[4] = 0;      // 0% Native asset

        uint256[] memory normalizedDistribution = distroMath.normalize(newDistribution);

        vm.prank(owner);
        uint256 result = WEDXProPortfolio(payable(proPortfolioAddress)).setPortfolio(newAssets, normalizedDistribution);
        console.log("setPortfolio result:", result);

        uint256 initialBalance = IWETH9(tokenAddress).balanceOf(proPortfolioAddress);
        console.log("Initial Balance in proPortfolioAddress:", initialBalance);

        vm.prank(owner);
        uint256 depositResult = WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();
        console.log("Deposit result:", depositResult);

        uint256 balanceAfterDeposit = IWETH9(tokenAddress).balanceOf(proPortfolioAddress);
        console.log("Balance after deposit in proPortfolioAddress:", balanceAfterDeposit);

        address lenderContractAddress = wedxGroup.getLenderContractAddress();

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).supplyLendToken(tokenAddress);

        uint256 finalBalance = IWETH9(tokenAddress).balanceOf(proPortfolioAddress);
        console.log("Final Balance in proPortfolioAddress:", finalBalance);

        assertEq(finalBalance, 0, "Token balance should be 0 after lending");

    }


    // Not found => revert: User does not have this token
    function testWithdrawLendToken() public {
        address tokenAddress = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe; 
        uint256 depositAmount = 1 ether; // 1 WETH deposit
        uint256 lendAmount = depositAmount;

        uint256 initialBalance = IWETH9(tokenAddress).balanceOf(proPortfolioAddress);
        console.log("Initial Balance in proPortfolioAddress:", initialBalance);

        vm.prank(owner);
        uint256 depositResult = WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();
        console.log("Deposit result:", depositResult);

        uint256 balanceAfterDeposit = IWETH9(tokenAddress).balanceOf(proPortfolioAddress);
        console.log("Balance after deposit in proPortfolioAddress:", balanceAfterDeposit);

        address lenderContractAddress = wedxGroup.getLenderContractAddress();

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).supplyLendToken(tokenAddress);

        uint256 balanceAfterLending = IWETH9(tokenAddress).balanceOf(proPortfolioAddress);
        console.log("Balance after lending in proPortfolioAddress:", balanceAfterLending);
        assertEq(balanceAfterLending, 0, "Token balance should be 0 after lending");

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).withdrawLendToken(tokenAddress);

        uint256 finalBalance = IWETH9(tokenAddress).balanceOf(proPortfolioAddress);
        console.log("Final Balance in proPortfolioAddress:", finalBalance);

        uint256 tolerance = 0.01 ether; 
        assertApproxEqRel(finalBalance, depositAmount, tolerance);

    }


    function testRankMe() public {

        address assetManagerAddress = wedxGroup.getAssetManagerAddress();
        vm.mockCall(
            assetManagerAddress,
            abi.encodeWithSelector(IWEDXManager.computeRanking.selector, owner),
            abi.encode()
        );

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).rankMe();

    }


    function testSetMinPercAllowance() public {
        uint256 newPerc = 5000; 

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).setMinPercAllowance(newPerc);

    }


    function testGetActualDistribution() public {

        address[] memory newAssets = new address[](1);
        newAssets[0] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC

        uint256 initialAmount = 250000 * 1e6; // 250,000 USDC

        uint256 depositAmount = 1 ether;

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();

        bytes32 slot = keccak256(abi.encode(newAssets[0], uint256(2)));
        vm.store(proPortfolioAddress, slot, bytes32(initialAmount));

        vm.mockCall(
            wedxGroup.getLenderContractAddress(),
            abi.encodeWithSelector(IWEDXlender.getTokenBalance.selector, newAssets[0], proPortfolioAddress),
            abi.encode(initialAmount)
        );
        vm.mockCall(
            wedxGroup.getSwapContractAddress(),
            abi.encodeWithSelector(IWEDXswap.getTokenAmount.selector, newAssets[0], WNATIVE, initialAmount),
            abi.encode(initialAmount)
        );

        vm.prank(owner);
        uint256[] memory actualDistribution = WEDXProPortfolio(payable(proPortfolioAddress)).getActualDistribution();

        assertEq(actualDistribution.length, 1, "Distribution array length mismatch");

        assertTrue(actualDistribution[0] > 0, "Distribution value should be non-zero");
    }


    function testGetAssetsExtended() public {

        address[] memory newAssets = new address[](3);
        newAssets[0] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1; // cWNATIVEAddress


        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1000 * 1e6; // 1000 USDC
        amounts[1] = 2000 * 1e18; // 2000 DAI
        amounts[2] = 3 * 1e18; // 3 WETH

        uint256 depositAmount = 1 ether;

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();

        vm.prank(owner);
        uint256[] memory extendedAssets = WEDXProPortfolio(payable(proPortfolioAddress)).getAssetsExtended();

        for (uint256 i = 0; i < amounts.length; i++) {
            assertEq(extendedAssets[i], amounts[i], "Extended asset value mismatch");
        }
    }


    function testGetAmountLendToken() public {

        address tokenAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        uint256 lendAmount = 1000 * 1e6; // 1000 USDC

        uint256 depositAmount = 1 ether;

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();

        vm.mockCall(
            wedxGroup.getLenderContractAddress(),
            abi.encodeWithSelector(IWEDXlender.getTokenBalance.selector, tokenAddress, proPortfolioAddress),
            abi.encode(lendAmount)
        );

        vm.prank(owner);
        uint256 amountLendToken = WEDXProPortfolio(payable(proPortfolioAddress)).getAmountLendToken(tokenAddress);

        assertEq(amountLendToken, lendAmount, "Lend amount value mismatch");
    }


}