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

contract WEDXlenderTest is Test {
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

    IWETH9 weth;
    IERC20 usdc;
    IWETH9 wnative;

    address private constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address private constant WETH = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe;
    address constant WNATIVE = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    uint256 constant USDC_INITIAL_SUPPLY = 1000 * 1e6; // 1,000 USDC
    uint256 constant WETH_INITIAL_SUPPLY = 1 * 1e18; // 1 WETH

    function setUp() public {
        weth = IWETH9(WETH);
        usdc = IERC20(USDC);
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
        vm.deal(proPortfolioAddress, 10 ether);
        vm.deal(address(wedxLender), 10 ether);
        deal(USDC, owner, 100000 * 1e6);
    }



    function testCollectToken() public {
        uint256 amount = 100 * 1e6; // 100 USDC

        // Approve the WEDXlender contract to spend USDC
        vm.prank(owner);
        usdc.approve(address(wedxLender), amount);

        // Call lendToken function
        vm.prank(owner);
        wedxLender.lendToken(USDC, amount);

        // Call collectToken function
        vm.prank(owner);
        wedxLender.collectToken(USDC, amount);

        // Check the balance of the owner
        uint256 balance = usdc.balanceOf(owner);
        assertEq(balance, USDC_INITIAL_SUPPLY, "Owner should have the collected amount");
    }

    function testGetTokenBalance() public {
        uint256 amount = 100 * 1e6; // 100 USDC

        // Approve the WEDXlender contract to spend USDC
        vm.prank(owner);
        usdc.approve(address(wedxLender), amount);

        // Call lendToken function
        vm.prank(owner);
        wedxLender.lendToken(USDC, amount);

        // Call getTokenBalance function
        uint256 balance = wedxLender.getTokenBalance(USDC, owner);
        assertEq(balance, amount, "Token balance should match the lent amount");
    }

    function testIsLoanPossible() public {
        // Check if loan is possible for USDC
        bool loanPossible = wedxLender.isLoanPossible(USDC);
        assertTrue(loanPossible, "Loan should be possible for USDC");
    }


function testFuzzCollectToken(uint256 amount) public {
    // Bound the amount to a reasonable range to prevent excessive values
    amount = bound(amount, 1 * 1e6, 100 * 1e6); // Bound between 1 USDC and 100 USDC

    // Approve the WEDXlender contract to spend USDC
    vm.prank(owner);
    usdc.approve(address(wedxLender), amount);

    // Call lendToken function
    vm.prank(owner);
    wedxLender.lendToken(USDC, amount);

    // Capture the initial balance of the owner before collecting
    uint256 initialBalance = usdc.balanceOf(owner);

    // Call getTokenBalance to ensure the amount lent is correct
    uint256 lentBalance = wedxLender.getTokenBalance(USDC, owner);
    console.log("Lent balance:", lentBalance);

    // Calculate the amount to collect (half of the lent amount)
    uint256 collectAmount = amount / 2;

    // Call collectToken function
    vm.prank(owner);
    wedxLender.collectToken(USDC, collectAmount);

    // Check the balance of the owner after collecting
    uint256 finalBalance = usdc.balanceOf(owner);
    assertEq(finalBalance, initialBalance + collectAmount, "Owner should have the collected amount");
}



function testFuzzGetTokenBalance(uint256 amount) public {
    // Bound the amount to a reasonable range to prevent excessive values
    amount = bound(amount, 1 * 1e6, 500 * 1e6); // Bound between 1 USDC and 500 USDC

    // Ensure the owner has enough USDC for the test
    deal(USDC, owner, 1000 * 1e6);

    // Approve the WEDXlender contract to spend USDC
    vm.prank(owner);
    usdc.approve(address(wedxLender), 1000 * 1e6); // Approve more than the maximum bound amount

    // Call lendToken function
    vm.prank(owner);
    wedxLender.lendToken(USDC, amount);

    // Call getTokenBalance function
    uint256 balance = wedxLender.getTokenBalance(USDC, owner);

    // Allow a small tolerance due to possible interest accrual
    uint256 tolerance = 1; // 1 unit of USDC for tolerance
    bool isBalanceWithinTolerance = balance >= amount - tolerance && balance <= amount + tolerance;
    assertTrue(isBalanceWithinTolerance, "Token balance should match the lent amount within a small tolerance");
}


function testFuzzIsLoanPossible(address tokenAddress) public {
    // Ensure tokenAddress is not zero address
    vm.assume(tokenAddress != address(0));

    // Check if loan is possible for the given token address
    vm.expectRevert();
    bool loanPossible = wedxLender.isLoanPossible(tokenAddress);

    // Log the result for debugging purposes
    console.log("Loan possible for token:", tokenAddress, "is", loanPossible);
}

function testIsLoanPossibleForKnownTokens() public {
    // Example of a known token address that should be supported
    address knownToken = USDC;
    bool loanPossible = wedxLender.isLoanPossible(knownToken);
    assertTrue(loanPossible, "Loan should be possible for a known supported token");

}



}
