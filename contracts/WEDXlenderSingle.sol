// SPDX-License-Identifier: MIT
/*
    This smart contract takes care of the lending feature for AAVE. 
*/
pragma solidity ^0.8.20;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

import "./WEDXConstants.sol";

contract WEDXlenderSingle {
    using SafeMath for uint256;
    IPoolAddressesProvider private immutable poolAddressProvider;
    address aaveAddress;
    IPool poolAave;
    address sourceAddress;

    constructor(address source) {
        poolAddressProvider = IPoolAddressesProvider(_poolAddressProviderAAVE);
        aaveAddress = poolAddressProvider.getPool();
        poolAave = IPool(aaveAddress);
        sourceAddress = source;
    }

    //Lend a token defined by the address and the amount. This function can only be executed by the Pro or Transactions contracts.
    function lendToken(address tokenAddress, uint256 amount) public onlySource {
        require( IERC20(tokenAddress).balanceOf(address(this)) >= amount, "Not enough balance in smart contract" );
        require( IERC20(tokenAddress).approve(aaveAddress, amount), "This contract has not enough tokens" );
        poolAave.supply(tokenAddress, amount, address(this), 0);
    }

    //Withdrawing the token from AAVE
    function collectToken(address tokenAddress, uint256 amount) public onlySource {
        require( getTokenBalance(tokenAddress) >= amount, "There is not sufficient tokens lent to collect" );
        require( amount > 0, "There are not lent tokens for this address" );
        poolAave.withdraw(tokenAddress, amount, address(this));
        TransferHelper.safeTransfer(tokenAddress, msg.sender, amount);
    }

    //Get balance lend + yield
    function getTokenBalance(address tokenAddress) public view returns (uint256) {
        if ( poolAave.getReserveData(tokenAddress).aTokenAddress == address(0) ) {
            return 0;
        } else {
            address aTokenAddress = (poolAave.getReserveData(tokenAddress)).aTokenAddress;
            return IERC20(aTokenAddress).balanceOf( address(this) );
        }
    }

    //Ensures that only the parent contract can call it
    modifier onlySource {
        require( msg.sender == sourceAddress, "Only the parent smart contracts can trigger this function" );
        _;
    }

}