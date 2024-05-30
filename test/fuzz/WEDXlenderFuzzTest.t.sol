// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {WEDXlenderSetup} from "../setup/WEDXlenderSetup.sol";
import {console} from "forge-std/console.sol";


contract WEDXlenderFuzzTest is WEDXlenderSetup {

    function testFuzzCollectToken(uint256 amount) public {
       
        amount = bound(amount, 1 * 1e6, 100 * 1e6); 

        vm.prank(owner);
        usdc.approve(address(wedxLender), amount);

        vm.prank(owner);
        wedxLender.lendToken(USDC, amount);

        uint256 initialBalance = usdc.balanceOf(owner);

        uint256 lentBalance = wedxLender.getTokenBalance(USDC, owner);
        console.log("Lent balance:", lentBalance);

        uint256 collectAmount = amount / 2;

        vm.prank(owner);
        wedxLender.collectToken(USDC, collectAmount);

        uint256 finalBalance = usdc.balanceOf(owner);
        assertEq(finalBalance, initialBalance + collectAmount, "Owner should have the collected amount");
    }

    function testFuzzGetTokenBalance(uint256 amount) public {

        amount = bound(amount, 1 * 1e6, 500 * 1e6); 

        deal(USDC, owner, 1000 * 1e6);

        vm.prank(owner);
        usdc.approve(address(wedxLender), 1000 * 1e6); 

        vm.prank(owner);
        wedxLender.lendToken(USDC, amount);

        uint256 balance = wedxLender.getTokenBalance(USDC, owner);

        uint256 tolerance = 1; 
        bool isBalanceWithinTolerance = balance >= amount - tolerance && balance <= amount + tolerance;
        assertTrue(isBalanceWithinTolerance, "Token balance should match the lent amount within a small tolerance");
    }


    function testFuzzIsLoanPossible(address tokenAddress) public {

        vm.assume(tokenAddress != address(0));

        vm.expectRevert();
        bool loanPossible = wedxLender.isLoanPossible(tokenAddress);

        console.log("Loan possible for token:", tokenAddress, "is", loanPossible);
    }

    function testIsLoanPossibleForKnownTokens() public {

        address knownToken = USDC;
        bool loanPossible = wedxLender.isLoanPossible(knownToken);
        assertTrue(loanPossible, "Loan should be possible for a known supported token");

    }



}
