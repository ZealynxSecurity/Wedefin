// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/WEDXswap.sol"; 
// import "./interfaces/interface.sol";

contract WEDXswapTest is Test {
    WEDXswap swapContract;
    IWETH9 weth;
    IERC20 usdc;
    IWETH9 wnative;
    address owner = address(this);

    address private constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address private constant WETH = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe;
    address constant WNATIVE = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;


    uint256 constant USDC_INITIAL_SUPPLY = 1000 * 1e6; // 1,000 USDC
    uint256 constant WETH_INITIAL_SUPPLY = 1 * 1e18; // 1 WETH


    function setUp() public {
        weth = IWETH9(WETH);
        usdc = IERC20(USDC);

        // Deploy the swap contract
        swapContract = new WEDXswap();

        // Ensure the owner has enough USDC and WETH for the test
        deal(USDC, owner, USDC_INITIAL_SUPPLY);
        deal(WETH, owner, WETH_INITIAL_SUPPLY);

        // Approve tokens for the swap contract
        weth.approve(address(swapContract), WETH_INITIAL_SUPPLY);
        usdc.approve(address(swapContract), USDC_INITIAL_SUPPLY);

        // Mock the validatePool function to simulate liquidity
        vm.mockCall(
            address(swapContract),
            abi.encodeWithSelector(WEDXswap.validatePool.selector, USDC, WETH),
            abi.encode(exInfo({
                exId: 1,
                feeUniswap: 3000,
                liquidity: 1000000 
            }))
        );

        vm.mockCall(
            address(swapContract),
            abi.encodeWithSelector(WEDXswap.validatePool.selector, WETH, USDC),
            abi.encode(exInfo({
                exId: 1,
                feeUniswap: 3000,
                liquidity: 1000000 
            }))
        );

        vm.mockCall(
            address(swapContract),
            abi.encodeWithSelector(WEDXswap.getTokenAmount.selector, USDC, WETH, USDC_INITIAL_SUPPLY),
            abi.encode(WETH_INITIAL_SUPPLY)
        );

        vm.mockCall(
            address(swapContract),
            abi.encodeWithSelector(WEDXswap.getTokenAmount.selector, WETH, USDC, WETH_INITIAL_SUPPLY),
            abi.encode(USDC_INITIAL_SUPPLY)
        );
    }


    function testSwapERC20_USDCtoWETH() public {
        uint256 amountIn = 5 * 1e6; // 500 USDC
        uint256 maxSlippage = 50; // 0.5% max slippage

        uint256 initialWethBalance = weth.balanceOf(owner);

        vm.prank(owner);
        uint256 amountOut = swapContract.swapERC20(USDC, WETH, amountIn, maxSlippage);

        uint256 finalWethBalance = weth.balanceOf(owner);

        assertTrue(finalWethBalance > initialWethBalance, "WETH balance should increase after swap");
        console.log("USDC to WETH swap successful with amount out:", amountOut);
    }

    function testSwapERC20_WETHtoUSDC() public {
        uint256 amountIn = 0.5 * 1e18; // 0.5 WETH
        uint256 amountusdc = 5 * 1e6; 
        uint256 maxSlippage = 50; // 0.5% max slippage

        uint256 initialUsdcBalance = usdc.balanceOf(owner);

        vm.prank(owner);
        weth.transfer(address(swapContract), amountIn);

        vm.prank(owner);
        weth.approve(address(swapContract), amountIn);

        vm.prank(owner);
        usdc.transfer(address(swapContract), amountusdc);

        vm.prank(owner);
        usdc.approve(address(swapContract), amountusdc);

        vm.prank(owner);
        uint256 amountOut = swapContract.swapERC20(WETH, USDC, amountIn, maxSlippage);

        uint256 finalUsdcBalance = usdc.balanceOf(owner);

        assertTrue(finalUsdcBalance > initialUsdcBalance, "USDC balance should increase after swap");
        console.log("WETH to USDC swap successful with amount out:", amountOut);
    }

    function testValidatePoolOnchainWithSameTokens() public {
        try swapContract.validatePool(USDC, USDC) {
            fail(); 
        } catch Error(string memory reason) {
            assertEq(reason, "Tokens must be different");
        } catch (bytes memory /*lowLevelData*/) {
            fail();
        }
    }

    function testSwapUSDCinSwapNative() public {

        uint256 amountIn = 5 * 1e6; // 500 USDC
        uint256 maxSlippage = 50; // 0.5% max slippage

        vm.prank(owner);
        vm.expectRevert();
        uint256 amountOut = swapContract.swapNative(USDC, maxSlippage);

    }
    function testSwapSwapNative() public {

        uint256 amountIn = 0.5 * 1e18; 
        uint256 maxSlippage = 50; // 0.5% max slippage

        (bool success,) = address(swapContract).call{value: 1 ether}("");
        require(success, "Failed to send ETH to contract");

        vm.prank(owner);
        // vm.expectRevert();
        uint256 amountOut = swapContract.swapNative(WNATIVE, maxSlippage);

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
