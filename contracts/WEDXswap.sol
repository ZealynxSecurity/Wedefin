// SPDX-License-Identifier: MIT
/*
    This smart contract manage all swaps with Uniswap. If in the future another DEX is used, here is where will be implemented.
    Therefore, it has its own smart contract.
*/
pragma solidity ^0.8.20;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "./WEDXConstants.sol";
import "./library/distroMath.sol";
import "./IWEDXInterfaces.sol";

import {console} from "forge-std/Test.sol";


contract WEDXswap is uniV3Constants {
    using SafeMath for uint256;
    ISwapRouter[] private router;
    IUniswapV3Factory[] private poolFactory;

    uint24[] private uniAllowedFees = [100, 500, 3000, 10000];

constructor() {
    for (uint16 i = 0; i < _uniswapRouterAddress.length; i++) {
        require(_uniswapRouterAddress[i] != address(0), "Invalid router address");
        require(_uniswapPoolFactoryAddress[i] != address(0), "Invalid factory address");
        router.push(ISwapRouter(_uniswapRouterAddress[i]));
        poolFactory.push(IUniswapV3Factory(_uniswapPoolFactoryAddress[i]));
        console.log("Configured poolFactory[%s]: %s", i, _uniswapPoolFactoryAddress[i]);
    }
}


    //Swap native tokens for another token using a pool.
    function swapNative( address tokenOut, uint256 maxSlippage ) public payable returns (uint256) {
        exInfo memory ex = validatePool( WNATIVE, tokenOut );
        require( ex.liquidity > 0, "No valid pool to perform the swap" );

        uint24 fee = ex.feeUniswap;
        uint16 exId = ex.exId;

        uint256 amountInAfterFees = msg.value * ( distroMath.distroNorm - fee ) / distroMath.distroNorm;
        uint256 minAmountOut = ( getTokenAmount(WNATIVE, tokenOut, amountInAfterFees) * ( distroMath.distroNorm - maxSlippage ) ) / distroMath.distroNorm;

        if ( minAmountOut > 0 && msg.value > 0 ) {
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                .ExactInputSingleParams(
                    WNATIVE,
                    tokenOut,
                    fee,
                    address(this),
                    block.timestamp,
                    msg.value,
                    minAmountOut,
                    0
                );

            uint256 amountOut = router[exId].exactInputSingle{value: msg.value}(params);
            TransferHelper.safeTransfer( tokenOut, msg.sender, amountOut );
            return amountOut;
        } else {
            return 0;
        }

    }

    //Swap ERC20 tokens to another token using a pool.
    function swapERC20( address tokenIn, address tokenOut, uint256 amountIn, uint256 maxSlippage ) public returns (uint256) {
        require( IERC20(tokenIn).allowance(msg.sender, address(this)) >= amountIn, "Not enough allowance to smart contract" );

        exInfo memory ex = validatePool( tokenIn, tokenOut );
        require( ex.liquidity > 0, "No valid pool to perform the swap" );

        uint24 fee = ex.feeUniswap;
        uint16 exId = ex.exId;

        uint256 amountInAfterFees = amountIn * ( distroMath.distroNorm - fee ) / distroMath.distroNorm;
        uint256 minAmountOut = ( getTokenAmount(tokenIn, tokenOut, amountInAfterFees) * ( distroMath.distroNorm - maxSlippage ) ) / distroMath.distroNorm;

        if ( minAmountOut > 0 && amountIn > 0 ) {
            TransferHelper.safeTransferFrom( tokenIn, msg.sender, address(this), amountIn );
            TransferHelper.safeApprove( tokenIn, address(router[exId]), amountIn );
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                .ExactInputSingleParams(
                    tokenIn,
                    tokenOut,
                    fee,
                    address(this),
                    block.timestamp,
                    amountIn,
                    minAmountOut,
                    0
                );

            uint256 amountOut = router[exId].exactInputSingle(params);
            TransferHelper.safeTransfer( tokenOut, msg.sender, amountOut );
            return amountOut;
        } else {
            return 0;
        }

    }

    //Compute the conversion between two ERC20 tokens. Useful to calculate prices.
    //Note that assumes there is enough liquidity so there is no slippage (spot price)
    function getTokenAmount(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256) {
        exInfo memory ex = validatePool( tokenIn, tokenOut );
        require( ex.liquidity > 0, "No valid pool to perform the compute amount" );

        uint256 value = 0;        
        if (amountIn > 0) {
            address poolAddress = poolFactory[ex.exId].getPool( tokenIn, tokenOut, ex.feeUniswap);
            IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
            (uint160 s96, , , , , , ) = pool.slot0();
            address token0 = pool.token0();
            if (token0 == tokenOut) {
                uint256 value1 = Math.mulDiv(amountIn, 2**96, s96);
                value = Math.mulDiv(value1, 2**96, s96);
            } else {
                uint256 value1 = Math.mulDiv(amountIn, s96, 2**96);
                value = Math.mulDiv(value1, s96, 2**96);
            }
        }
        return value;
    }

    //Check if there is an existing pool for that pair and if exists, then record it
function validatePool(address tokenIn, address tokenOut) public view returns (exInfo memory) {
    require(tokenIn != tokenOut, "Tokens must be different");

    exInfo memory result;
    uint128 refLiquidity = 0;

    for (uint16 j = 0; j < poolFactory.length; j++) {
        for (uint16 i = 0; i < uniAllowedFees.length; i++) {
            console.log("Checking poolFactory[%s] and uniAllowedFees[%s]", j, i);
            address poolAddress = poolFactory[j].getPool(tokenIn, tokenOut, uniAllowedFees[i]);
            console.log("Pool address: %s", poolAddress);

            if (poolAddress != address(0)) {
                try IUniswapV3Pool(poolAddress).liquidity() returns (uint128 liquidity) {
                    console.log("Liquidity: %s", liquidity);
                    if (liquidity > refLiquidity) {
                        refLiquidity = liquidity;
                        result = exInfo(j, uniAllowedFees[i], refLiquidity);
                    }
                } catch Error(string memory reason) {
                    console.log("Error accessing liquidity for pool: %s with reason: %s", poolAddress, reason);
                } catch (bytes memory /* lowLevelData */) {
                    console.log("Low-level error accessing liquidity for pool: %s", poolAddress);
                }
            } else {
                console.log("No pool found for poolFactory[%s] and uniAllowedFees[%s]", j, i);
            }
        }
    }
    require(result.liquidity > 0, "No valid pool found");
    return result;
}


    function getAssetPoolLiquidity( address tokenAddress ) public view returns (uint128) {
        exInfo memory ex = validatePool( tokenAddress, WNATIVE );
        return ex.liquidity;
    }

    receive() external payable {}

}