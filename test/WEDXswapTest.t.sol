// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/WEDXswap.sol"; 
import "./interfaces/interface.sol";

contract WEDXswapTest is Test {
    WEDXswap swapContract;
    IWETH9 weth;
    IERC20 usdc;
    address owner = address(this);

    address private constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address private constant WETH = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe;

    uint256 constant USDC_INITIAL_SUPPLY = 1000 * 1e6; // 1,000 USDC
    uint256 constant WETH_INITIAL_SUPPLY = 1 * 1e18; // 1 WETH

    function setUp() public {
        weth = IWETH9(WETH);
        usdc = IERC20(USDC);

        // Deploy the swap contract
        swapContract = new WEDXswap();

        // Deal some WETH to the contract
        deal(WETH, address(this), WETH_INITIAL_SUPPLY);
        weth.deposit{value: WETH_INITIAL_SUPPLY}();

        // Ensure the owner has enough USDC for the test
        deal(USDC, owner, USDC_INITIAL_SUPPLY);

        // Approve tokens for the swap contract
        weth.approve(address(swapContract), WETH_INITIAL_SUPPLY);
        usdc.approve(address(swapContract), USDC_INITIAL_SUPPLY);
    }

    function testSwapERC20_USDCtoWETH() public {
        uint256 amountIn = 500 * 1e6; // 500 USDC
        uint256 maxSlippage = 50; // 0.5% max slippage

        uint256 initialWethBalance = weth.balanceOf(owner);

        // Perform the swap
        vm.prank(owner);
        uint256 amountOut = swapContract.swapERC20(USDC, WETH, amountIn, maxSlippage);

        uint256 finalWethBalance = weth.balanceOf(owner);

        // Check the results
        assertTrue(finalWethBalance > initialWethBalance, "WETH balance should increase after swap");
        console.log("USDC to WETH swap successful with amount out:", amountOut);
    }

    function testSwapERC20_WETHtoUSDC() public {
        uint256 amountIn = 0.5 * 1e18; // 0.5 WETH
        uint256 maxSlippage = 50; // 0.5% max slippage

        uint256 initialUsdcBalance = usdc.balanceOf(owner);

        // Perform the swap
        vm.prank(owner);
        uint256 amountOut = swapContract.swapERC20(WETH, USDC, amountIn, maxSlippage);

        uint256 finalUsdcBalance = usdc.balanceOf(owner);

        // Check the results
        assertTrue(finalUsdcBalance > initialUsdcBalance, "USDC balance should increase after swap");
        console.log("WETH to USDC swap successful with amount out:", amountOut);
    }

    function testValidatePoolOnchainWithSameTokens() public {
        // Attempt to validate pool with the same token for both input and output
        try swapContract.validatePool(USDC, USDC) {
            fail(); // Expected validatePool to revert with identical tokens
        } catch Error(string memory reason) {
            assertEq(reason, "Tokens must be different");
        } catch (bytes memory /*lowLevelData*/) {
            fail(); // Expected validatePool to revert with 'Tokens must be different' error
        }
    }

    function testValidatePoolOnchainWithDifferentTokens() public {
        exInfo memory result = swapContract.validatePool(USDC, WETH);

        assertTrue(result.exId >= 0);
        assertTrue(result.feeUniswap >= 0);
        assertTrue(result.liquidity >= 0);
    }

    function testValidatePPoolOnchainWithSameTokens() public {
        exInfo memory result = swapContract.validatePool(USDC, USDC);

        assertTrue(result.exId >= 0);
        assertTrue(result.feeUniswap >= 0);
        assertTrue(result.liquidity >= 0);
    }
}
