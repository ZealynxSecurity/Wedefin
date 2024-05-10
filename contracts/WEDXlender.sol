// SPDX-License-Identifier: MIT
/*
    This smart contract takes care of the lending feature. So that the users can lend the assets and collect yield. So far AAVE is implemented.
    This contract deploys a child lender per user specifically for AAVE.
*/
pragma solidity ^0.8.20;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

import "./IWEDXInterfaces.sol";
import "./WEDXConstants.sol";
import "./WEDXlenderSingle.sol";

contract WEDXlender {
    using SafeMath for uint256;
    IPoolAddressesProvider private immutable poolAddressProvider;
    address aaveAddress;
    IPool poolAave;

    // Define the masks for ACTIVE, FROZEN, and PAUSED states
    uint256 constant ACTIVE_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF;
    uint256 constant FROZEN_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF;
    uint256 constant PAUSED_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFF;

    mapping(address => address) private lenderSingle;

    constructor() {            
        poolAddressProvider = IPoolAddressesProvider(_poolAddressProviderAAVE);
        aaveAddress = poolAddressProvider.getPool();
        poolAave = IPool(aaveAddress);
    }

    //Lend a token defined by the address and the amount. This function can only be executed by the Pro or Transactions contracts.
    function lendToken(address tokenAddress, uint256 amount) public { // @audit-issue No Restricted Access Control to the Pro or Transactions contracts
        require( IERC20(tokenAddress).allowance(msg.sender, address(this)) >= amount, "Not enough allowance to smart contract" );
        if ( lenderSingle[msg.sender] == address(0) ) {
            address deployedContract = address( new WEDXlenderSingle( address(this) ) );  
            lenderSingle[msg.sender] = deployedContract;                  
        }
        TransferHelper.safeTransferFrom( tokenAddress, msg.sender, address(this), amount ); // @audit CEI Pattern? Reentrancy?
        TransferHelper.safeTransfer( tokenAddress, lenderSingle[msg.sender], amount ); 
        IWEDXlenderSingle(lenderSingle[msg.sender]).lendToken(tokenAddress, amount);
    }

    //Withdrawing the token from AAVE
    function collectToken(address tokenAddress, uint256 amount) public {
        require( lenderSingle[msg.sender] != address(0), "User doesn't have a contract with us" );
        IWEDXlenderSingle(lenderSingle[msg.sender]).collectToken(tokenAddress, amount);
        require( IERC20(tokenAddress).balanceOf(address(this)) >= amount, "Not enough balance in smart contract" );
        TransferHelper.safeTransfer(tokenAddress, msg.sender, amount);
    }

    //Get balance lend + yield
    function getTokenBalance(address tokenAddress, address account) public view returns (uint256) {
        if ( lenderSingle[account] == address(0) ) {
            return 0;
        } else {
            return IWEDXlenderSingle(lenderSingle[msg.sender]).getTokenBalance(tokenAddress);
        }
    }

    //Seek if the token is available for lending in AAVE
    function isLoanPossible(address tokenAddress) public view returns (bool) {
        uint256 configuration = poolAave.getReserveData(tokenAddress).configuration.data;
        // Check if the pool is active, not frozen, and not paused
        bool isActive = (configuration & ~ACTIVE_MASK) != 0;
        bool isFrozen = (configuration & ~FROZEN_MASK) != 0;
        bool isPaused = (configuration & ~PAUSED_MASK) != 0;
        // Ensure the token address is valid (non-zero aTokenAddress) and the pool is active, not frozen, and not paused
        return poolAave.getReserveData(tokenAddress).aTokenAddress != address(0) && isActive && !isFrozen && !isPaused;
    }

}