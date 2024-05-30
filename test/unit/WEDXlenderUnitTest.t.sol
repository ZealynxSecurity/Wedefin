// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {WEDXlenderSetup} from "../setup/WEDXlenderSetup.sol";


contract WEDXlenderUnitTest is WEDXlenderSetup {


    function testCollectToken() public {
        uint256 amount = 100 * 1e6; // 100 USDC

        vm.prank(owner);
        usdc.approve(address(wedxLender), amount);

        vm.prank(owner);
        wedxLender.lendToken(USDC, amount);

        vm.prank(owner);
        wedxLender.collectToken(USDC, amount);

        uint256 balance = usdc.balanceOf(owner);
        assertEq(balance, USDC_INITIAL_SUPPLY, "Owner should have the collected amount");
    }

    function testGetTokenBalance() public {
        uint256 amount = 100 * 1e6; // 100 USDC

        vm.prank(owner);
        usdc.approve(address(wedxLender), amount);

        vm.prank(owner);
        wedxLender.lendToken(USDC, amount);

        uint256 balance = wedxLender.getTokenBalance(USDC, owner);
        assertEq(balance, amount, "Token balance should match the lent amount");
    }

    function testIsLoanPossible() public {

        bool loanPossible = wedxLender.isLoanPossible(USDC);
        assertTrue(loanPossible, "Loan should be possible for USDC");
    }

}
