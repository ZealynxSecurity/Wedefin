
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {WEDXTreasurySetup} from "../setup/WEDXTreasurySetup.sol";
import {console} from "forge-std/console.sol";


contract WEDXTreasuryUnitTest is WEDXTreasurySetup {


   function testDepositGeneralFee() public {
        uint256 initialBalance = wedxTreasury.balanceOf(owner);
        uint256 depositAmount = 1 ether;

        vm.prank(owner);
        wedxTreasury.depositGeneralFee{value: depositAmount}();

        uint256 finalBalance = wedxTreasury.balanceOf(owner);
        assertEq(finalBalance, initialBalance + depositAmount, "Balance should increase by deposit amount");
    }

    function testDepositRewardFee() public {
        uint256 depositAmount = 1 ether;

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

        vm.prank(owner);
        wedxTreasury.depositGeneralFee{value: depositAmount}();

        uint256 redeemAmount = 0.5 ether;
        uint256 initialOwnerBalance = owner.balance;

        vm.prank(owner);
        uint256 redeemed = wedxTreasury.redeem(redeemAmount);

        assertEq(redeemed, redeemAmount, "Redeemed amount should match the requested amount");
        assertEq(wedxTreasury.balanceOf(owner), depositAmount - redeemAmount, "Treasury balance should decrease by the redeemed amount");
        assertEq(owner.balance, initialOwnerBalance + redeemAmount, "Owner balance should increase by the redeemed amount");
    }

    function testRedeemByDifferentUser() public {
        uint256 depositAmount = 1 ether;
        address nonOwnerUser = vm.addr(2);

        vm.deal(nonOwnerUser, depositAmount);

        vm.prank(nonOwnerUser);
        wedxTreasury.depositGeneralFee{value: depositAmount}();

        vm.prank(owner);
        wedxTreasury.transfer(nonOwnerUser, depositAmount);

        uint256 initialWEDTBalance = wedxTreasury.balanceOf(nonOwnerUser);
        assertEq(initialWEDTBalance, depositAmount, "Initial WEDT balance should be equal to deposit amount");

        uint256 redeemAmount = 0.5 ether;
        uint256 initialUserBalance = nonOwnerUser.balance;

        vm.deal(address(wedxTreasury), depositAmount);

        vm.prank(nonOwnerUser);
        uint256 redeemed = wedxTreasury.redeem(redeemAmount);

        assertEq(redeemed, redeemAmount, "Redeemed amount should match the requested amount");
        assertEq(wedxTreasury.balanceOf(nonOwnerUser), depositAmount - redeemAmount, "Treasury balance should decrease by the redeemed amount");
        assertEq(nonOwnerUser.balance, initialUserBalance + redeemAmount, "Non-owner user balance should increase by the redeemed amount");
    }
}