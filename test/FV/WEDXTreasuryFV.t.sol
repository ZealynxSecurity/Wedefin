// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SymTest} from "halmos-cheatcodes/SymTest.sol";
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


contract WEDXTreasuryFV is SymTest, Test {

    address payable thirdParty;
    // address payable alice = payable(vm.addr(1));
    
    WEDXDeployerPro deployerPro;
    WEDXDeployerIndex deployerIndex;
    WEDXGroup wedxGroup;
    WEDXswap wedxSwap;
    // WEDXlender wedxLender;
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
        // wedxLender = new WEDXlender();
        wedxManager = new WEDXManager();
        wedxRanker = new WEDXRanker();
        wedxTreasury = new WEDXTreasury();

        // Update WEDXGroup with the addresses of the deployed contracts
        wedxGroup.changeManagerAddress(address(wedxManager));
        wedxGroup.changeSwapContractAddress(address(wedxSwap));
        // wedxGroup.changeLenderContractAddress(address(wedxLender));
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
        vm.deal(proPortfolioAddress, 10 ether);
    }


    function check_testBasicDepositReflectsInCWETH() public {
        uint256 depositAmount = 1 ether;

        vm.prank(owner);
        uint256 result = WEDXProPortfolio(payable(proPortfolioAddress)).deposit{value: depositAmount}();
        console.log("result",result);

    }

    function check_FuzzDepositGeneralFee(uint256 depositAmount) public {
        // Ensure deposit amount is within reasonable range
        vm.assume(depositAmount > 0 && depositAmount <= 1000 ether);

        uint256 initialBalance = wedxTreasury.balanceOf(owner);

        // Deposit general fee
        vm.prank(owner);
        wedxTreasury.depositGeneralFee{value: depositAmount}();

        uint256 finalBalance = wedxTreasury.balanceOf(owner);
        assertEq(finalBalance, initialBalance + depositAmount, "Balance should increase by deposit amount");
    }

    function check_FuzzDepositRewardFee(uint256 depositAmount, uint256 rank1, uint256 rank2) public {
        // Ensure deposit amount and ranks are within reasonable range
        vm.assume(depositAmount > 0 && depositAmount <= 1000 ether);
        vm.assume(rank1 > 0 && rank1 <= 1000);
        vm.assume(rank2 > 0 && rank2 <= 1000);

        // Mock functions for ranking and actor fee
        address[] memory rankingList = new address[](2);
        rankingList[0] = address(0x123);
        rankingList[1] = address(0x456);

        vm.mockCall(
            address(wedxManager),
            abi.encodeWithSelector(wedxManager.getRankingList.selector),
            abi.encode(rankingList)
        );
        vm.mockCall(
            address(wedxManager),
            abi.encodeWithSelector(wedxManager.totalRankSum.selector),
            abi.encode(rank1 + rank2)
        );
        vm.mockCall(
            address(wedxManager),
            abi.encodeWithSelector(wedxManager.rebalanceActor.selector),
            abi.encode(address(0))
        );
        vm.mockCall(
            address(wedxManager),
            abi.encodeWithSelector(wedxManager.rebalanceActorFee.selector),
            abi.encode(0)
        );
        vm.mockCall(
            address(wedxManager),
            abi.encodeWithSelector(wedxManager.getTraderScore.selector, rankingList[0]),
            abi.encode(rank1)
        );
        vm.mockCall(
            address(wedxManager),
            abi.encodeWithSelector(wedxManager.getTraderScore.selector, rankingList[1]),
            abi.encode(rank2)
        );

        uint256 initialOwnerBalance = wedxTreasury.balanceOf(owner);
        uint256 initialBalanceAddress1 = wedxTreasury.balanceOf(rankingList[0]);
        uint256 initialBalanceAddress2 = wedxTreasury.balanceOf(rankingList[1]);

        // Deposit reward fee
        vm.prank(owner);
        wedxTreasury.depositRewardFee{value: depositAmount}();

        uint256 finalOwnerBalance = wedxTreasury.balanceOf(owner);
        uint256 finalBalanceAddress1 = wedxTreasury.balanceOf(rankingList[0]);
        uint256 finalBalanceAddress2 = wedxTreasury.balanceOf(rankingList[1]);

        uint256 totalRankSum = rank1 + rank2;
        uint256 expectedAmount1 = (depositAmount * rank1) / totalRankSum;
        uint256 expectedAmount2 = (depositAmount * rank2) / totalRankSum;
        uint256 expectedOwnerAmount = depositAmount - (expectedAmount1 + expectedAmount2);

        assertEq(finalOwnerBalance, initialOwnerBalance + expectedOwnerAmount, "Owner balance should increase by the remaining amount");
        assertEq(finalBalanceAddress1, initialBalanceAddress1 + expectedAmount1, "Address 1 balance should increase by expected amount");
        assertEq(finalBalanceAddress2, initialBalanceAddress2 + expectedAmount2, "Address 2 balance should increase by expected amount");
    }


}