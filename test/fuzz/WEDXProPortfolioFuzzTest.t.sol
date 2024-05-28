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

contract WEDXProPortfolioFuzzTest is Test {
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


    function testFuzzDepositWithSimpleFee(uint256 depositAmount, uint256 feePercentage) public {

        depositAmount = bound(depositAmount, 1 ether, 100 ether);
        feePercentage = bound(feePercentage, 0, 100);


        uint256 initialBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

        console.log("Initial Balance in cWNATIVE:", initialBalance);

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



    function testFuzzWithdraw(uint256 depositAmount, uint256 withdrawAmount, uint256 feePercentage) public {
        depositAmount = bound(depositAmount, 1 ether, 100 ether); 
        withdrawAmount = bound(withdrawAmount, 1 ether, depositAmount); 
        feePercentage = bound(feePercentage, 0, 100); 

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();

        uint256 initialBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

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

        vm.prank(owner);
        WEDXProPortfolio(payable(proPortfolioAddress)).withdraw(withdrawAmount);

        uint256 fee = (withdrawAmount * feePercentage) / distroNorm;
        uint256 expectedWithdrawAmount = withdrawAmount - fee;

        uint256 finalBalance = IWETH9(cWNATIVEAddress).balanceOf(proPortfolioAddress);

        assertTrue(finalBalance < initialBalance, "Final balance in cWNATIVE should be less than initial balance after withdrawal");

        assertApproxEqRel(finalBalance, initialBalance - expectedWithdrawAmount, 1e16);
    }
    }



