
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {WEDXTreasurySetup} from "../setup/WEDXTreasurySetup.sol";
import {console} from "forge-std/console.sol";
import "../../contracts/WEDXManager.sol";



contract WEDXTreasuryFuzzTest is WEDXTreasurySetup {


    function testFuzzDepositGeneralFee(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1 wei, 1000 ether);

        uint256 initialBalance = wedxTreasury.balanceOf(owner);

        vm.prank(owner);
        wedxTreasury.depositGeneralFee{value: depositAmount}();

        uint256 finalBalance = wedxTreasury.balanceOf(owner);
        assertEq(finalBalance, initialBalance + depositAmount, "Balance should increase by deposit amount");
    }


    function testFuzzDepositRewardFee(uint256 depositAmount, uint256 rank1, uint256 rank2) public {
        depositAmount = bound(depositAmount, 1 wei, 1000 ether);
        rank1 = bound(rank1, 1, 1000);
        rank2 = bound(rank2, 1, 1000);

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
        depositAmount = bound(depositAmount, 1 wei, 1 ether); // Using smaller amounts for safety
        redeemAmount = bound(redeemAmount, 1 wei, depositAmount);

        vm.prank(owner);
        wedxTreasury.depositGeneralFee{value: depositAmount}();

        uint256 initialOwnerBalance = owner.balance;

        vm.prank(owner);
        uint256 redeemed = wedxTreasury.redeem(redeemAmount);

        assertEq(redeemed, redeemAmount, "Redeemed amount should match the requested amount");
        assertEq(wedxTreasury.balanceOf(owner), depositAmount - redeemAmount, "Treasury balance should decrease by the redeemed amount");
        assertEq(owner.balance, initialOwnerBalance + redeemAmount, "Owner balance should increase by the redeemed amount");
    }



    function testFuzzMultipleDepositsAndRedeems(uint256 depositAmount, uint256 redeemAmount) public {
        depositAmount = bound(depositAmount, 1 wei, 1000 ether);

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

