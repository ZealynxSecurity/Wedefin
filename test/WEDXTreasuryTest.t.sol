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

contract WEDXTreasuryest is Test {

    address payable thirdParty;
    address payable alice = payable(vm.addr(1));
    
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

        // Deploy the malicious contracts
        thirdParty = payable(address(0x1234)); // Third party address
        // Deal Ether to the portfolios and malicious contracts for testing
        vm.deal(proPortfolioAddress, 10 ether);
        vm.deal(address(wedxTreasury), 10 ether);
        deal(USDC, owner, 1000 * 1e6);

    }


////////////////////////////

//          UNIT

////////////////////////////
    function testDepositGeneralFee() public {
        uint256 initialBalance = wedxTreasury.balanceOf(owner);
        uint256 depositAmount = 1 ether;

        // Deposit general fee
        vm.prank(owner);
        wedxTreasury.depositGeneralFee{value: depositAmount}();

        uint256 finalBalance = wedxTreasury.balanceOf(owner);
        assertEq(finalBalance, initialBalance + depositAmount, "Balance should increase by deposit amount");
    }

    function testDepositRewardFee() public {
        uint256 depositAmount = 1 ether;

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
            abi.encode(1000)
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
            abi.encode(600)
        );
        vm.mockCall(
            address(wedxManager),
            abi.encodeWithSelector(wedxManager.getTraderScore.selector, rankingList[1]),
            abi.encode(400)
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

        uint256 totalRankSum = 1000;
        uint256 rank1 = 600;
        uint256 rank2 = 400;

        uint256 expectedAmount1 = (depositAmount * rank1) / totalRankSum;
        uint256 expectedAmount2 = (depositAmount * rank2) / totalRankSum;
        uint256 expectedOwnerAmount = depositAmount - (expectedAmount1 + expectedAmount2);

        assertEq(finalOwnerBalance, initialOwnerBalance + expectedOwnerAmount, "Owner balance should increase by the remaining amount");
        assertEq(finalBalanceAddress1, initialBalanceAddress1 + expectedAmount1, "Address 1 balance should increase by expected amount");
        assertEq(finalBalanceAddress2, initialBalanceAddress2 + expectedAmount2, "Address 2 balance should increase by expected amount");
    }
    function testRedeem() public {
        uint256 depositAmount = 1 ether;

        // Deposit some funds first to redeem
        vm.prank(owner);
        wedxTreasury.depositGeneralFee{value: depositAmount}();

        uint256 redeemAmount = 0.5 ether;
        uint256 initialOwnerBalance = owner.balance;

        // Redeem the balance
        vm.prank(owner);
        uint256 redeemed = wedxTreasury.redeem(redeemAmount);

        assertEq(redeemed, redeemAmount, "Redeemed amount should match the requested amount");
        assertEq(wedxTreasury.balanceOf(owner), depositAmount - redeemAmount, "Treasury balance should decrease by the redeemed amount");
        assertEq(owner.balance, initialOwnerBalance + redeemAmount, "Owner balance should increase by the redeemed amount");
    }

    function testRedeemByDifferentUser() public {
        uint256 depositAmount = 1 ether;
        address nonOwnerUser = vm.addr(2);

        // Deal some ether to nonOwnerUser
        vm.deal(nonOwnerUser, depositAmount);

        // Deposit some funds first to redeem
        vm.prank(nonOwnerUser);
        wedxTreasury.depositGeneralFee{value: depositAmount}();

        // Ensure owner transfers WEDT tokens to nonOwnerUser
        vm.prank(owner);
        wedxTreasury.transfer(nonOwnerUser, depositAmount);

        // Ensure nonOwnerUser has the minted WEDT tokens
        uint256 initialWEDTBalance = wedxTreasury.balanceOf(nonOwnerUser);
        assertEq(initialWEDTBalance, depositAmount, "Initial WEDT balance should be equal to deposit amount");

        uint256 redeemAmount = 0.5 ether;
        uint256 initialUserBalance = nonOwnerUser.balance;

        // Deal some ether to the contract to ensure it can send the redeem amount
        vm.deal(address(wedxTreasury), depositAmount);

        // Redeem the balance
        vm.prank(nonOwnerUser);
        uint256 redeemed = wedxTreasury.redeem(redeemAmount);

        assertEq(redeemed, redeemAmount, "Redeemed amount should match the requested amount");
        assertEq(wedxTreasury.balanceOf(nonOwnerUser), depositAmount - redeemAmount, "Treasury balance should decrease by the redeemed amount");
        assertEq(nonOwnerUser.balance, initialUserBalance + redeemAmount, "Non-owner user balance should increase by the redeemed amount");
    }





////////////////////////////

//          FUZZ

////////////////////////////

    function testFuzzDepositGeneralFee(uint256 depositAmount) public {
        // Ensure deposit amount is within reasonable range
        depositAmount = bound(depositAmount, 1 wei, 1000 ether);

        uint256 initialBalance = wedxTreasury.balanceOf(owner);

        // Deposit general fee
        vm.prank(owner);
        wedxTreasury.depositGeneralFee{value: depositAmount}();

        uint256 finalBalance = wedxTreasury.balanceOf(owner);
        assertEq(finalBalance, initialBalance + depositAmount, "Balance should increase by deposit amount");
    }


    function testFuzzDepositRewardFee(uint256 depositAmount, uint256 rank1, uint256 rank2) public {
        // Ensure deposit amount and ranks are within reasonable range
        depositAmount = bound(depositAmount, 1 wei, 1000 ether);
        rank1 = bound(rank1, 1, 1000);
        rank2 = bound(rank2, 1, 1000);

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

    function testFuzzRedeem(uint256 depositAmount, uint256 redeemAmount) public {
        // Ensure deposit and redeem amounts are within reasonable range
        depositAmount = bound(depositAmount, 1 wei, 1 ether); // Using smaller amounts for safety
        redeemAmount = bound(redeemAmount, 1 wei, depositAmount);

        // Deposit some funds first to redeem
        vm.prank(owner);
        wedxTreasury.depositGeneralFee{value: depositAmount}();

        uint256 initialOwnerBalance = owner.balance;

        // Redeem the balance
        vm.prank(owner);
        uint256 redeemed = wedxTreasury.redeem(redeemAmount);

        assertEq(redeemed, redeemAmount, "Redeemed amount should match the requested amount");
        assertEq(wedxTreasury.balanceOf(owner), depositAmount - redeemAmount, "Treasury balance should decrease by the redeemed amount");
        assertEq(owner.balance, initialOwnerBalance + redeemAmount, "Owner balance should increase by the redeemed amount");
    }



    function testFuzzMultipleDepositsAndRedeems(uint256 depositAmount, uint256 redeemAmount) public {
        // Bound the deposit amount to avoid overflow issues
        depositAmount = bound(depositAmount, 1 wei, 1000 ether);

        // Ensure that redeem amount does not exceed deposit amount
        redeemAmount = bound(redeemAmount, 1 wei, depositAmount);

        vm.prank(owner);
        wedxTreasury.depositGeneralFee{value: depositAmount}();
        wedxTreasury.depositGeneralFee{value: depositAmount}();

        uint256 initialBalance = address(owner).balance;

        vm.prank(owner);
        uint256 amountRedeemed = wedxTreasury.redeem(redeemAmount);

        assertEq(amountRedeemed, redeemAmount, "Redeemed amount should match the requested amount");
        assertEq(address(owner).balance, initialBalance + redeemAmount, "Owner's balance should be updated correctly after redeem");
    }

    function testFuzzRankRewardDistribution(uint256 rewardAmount) public {
        address[] memory addresses = new address[](3);
        addresses[0] = address(0x1);
        addresses[1] = address(0x2);
        addresses[2] = address(0x3);

        uint256[] memory ranks = new uint256[](3);
        ranks[0] = 1;
        ranks[1] = 2;
        ranks[2] = 3;

        uint256 totalRankSum = 6;

        // Mock the ranking list and total rank sum
        vm.mockCall(
            address(wedxManager),
            abi.encodeWithSelector(IWEDXManager.getRankingList.selector),
            abi.encode(addresses)
        );
        vm.mockCall(
            address(wedxManager),
            abi.encodeWithSelector(IWEDXManager.totalRankSum.selector),
            abi.encode(totalRankSum)
        );
        for (uint256 i = 0; i < addresses.length; i++) {
            vm.mockCall(
                address(wedxManager),
                abi.encodeWithSelector(IWEDXManager.getTraderScore.selector, addresses[i]),
                abi.encode(ranks[i])
            );
        }

        rewardAmount = bound(rewardAmount, 1 wei, 1000 ether);

        vm.prank(owner);
        wedxTreasury.depositRewardFee{value: rewardAmount}();

        for (uint256 i = 0; i < addresses.length; i++) {
            uint256 expectedReward = (rewardAmount * ranks[i]) / totalRankSum;
            uint256 balance = wedxTreasury.balanceOf(addresses[i]);
            assertEq(balance, expectedReward, "Reward distribution is incorrect");
        }
    }

    function testFuzzMinimumDeposit(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1 wei, 1 wei);

        vm.prank(owner);
        wedxTreasury.depositGeneralFee{value: depositAmount}();

        assertEq(wedxTreasury.balanceOf(owner), depositAmount, "Minimum deposit amount is not handled correctly");
    }

    function testFuzzMaximumDeposit(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1 ether, type(uint256).max);

        vm.prank(owner);
        wedxTreasury.depositGeneralFee{value: depositAmount}();

        assertEq(wedxTreasury.balanceOf(owner), depositAmount, "Maximum deposit amount is not handled correctly");
    }



    receive() external payable {
    }

}

