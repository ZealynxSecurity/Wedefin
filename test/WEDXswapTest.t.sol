// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/WEDXswap.sol"; 
import "./mocks/MockERC20.sol"; 

contract WEDXswapTest is Test {
    WEDXswap swapContract;
    MockERC20 tokenA;
    MockERC20 tokenB;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;



    function setUp() public {
        // Deploy mock tokens
        tokenA = new MockERC20("Token A", "TKA", 18);
        tokenB = new MockERC20("Token B", "TKB", 18);

        // Deploy the swap contract
        swapContract = new WEDXswap();
    }

    function testValidatePoolWithSameTokens() public {
        // Attempt to validate pool with the same token for both input and output
        try swapContract.validatePool(address(tokenA), address(tokenA)) {
            fail(); // Expected validatePool to revert with identical tokens
        } catch Error(string memory reason) {
            assertEq(reason, "Tokens must be different");
        } catch (bytes memory /*lowLevelData*/) {
            fail(); // Expected validatePool to revert with 'Tokens must be different' error
        }
    }
    function testValidatePoolOnchainWithSameTokens() public {
        // Attempt to validate pool with the same token for both input and output
        try swapContract.validatePool((USDC), (USDC)) {
            fail(); // Expected validatePool to revert with identical tokens
        } catch Error(string memory reason) {
            assertEq(reason, "Tokens must be different");
        } catch (bytes memory /*lowLevelData*/) {
            fail(); // Expected validatePool to revert with 'Tokens must be different' error
        }
    }

    function testValidatePoolWithDifferentTokens() public {
        // Validate pool with different tokens
        try swapContract.validatePool(address(tokenA), address(tokenB)) {
            // Expected to pass as tokens are different
            assertTrue(true);
        } catch {
            fail(); // validatePool should not revert with different tokens
        }
    }
    function testValidatePoolOnchainWithDifferentTokens() public {
        exInfo memory result = swapContract.validatePool(USDC, WETH);

        assertTrue(result.exId >= 0);
        assertTrue(result.feeUniswap >= 0);
        assertTrue(result.liquidity >= 0);
    }
    function testSwapNative() public {
        swapContract.swapNative(WETH, 10);


    }
}

//forge test --fork-url https://eth-mainnet.g.alchemy.com/v2/Se-CTmWnCJVhHI6Sz_-rWeu5xUuJ81t- --mc WEDXswapTest --mt testValidatePoolOnchainWithDifferentTokens -vvvv