// SPDX-License-Identifier: MIT
/*
    This smart contract handles all transactions on the index token. It is separated from the ERC20 token to be more modular
*/
pragma solidity ^0.8.20;
pragma abicoder v2;

import "./WEDXBasePortfolio.sol";

contract WEDXIndexPortfolio is WEDXBasePortfolio {

    constructor(address initialOwner) WEDXBasePortfolio(initialOwner) {}

    function deposit() public override onlyOwner payable returns (uint256) {
        uint256 results = super.deposit();
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            if ( IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).isLoanPossible(tokenAddresses[i]) == true && totalAssets[tokenAddresses[i]] > 0 ) {
                supplyLendToken( tokenAddresses[i] );
            }
        }
        return results;
    }

    function withdraw(uint256 amount) override onlyOwner public {
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            if ( IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).getTokenBalance(tokenAddresses[i], address(this)) > 0 ) {
                withdrawLendToken( tokenAddresses[i] );
            }
        }
        super.withdraw(amount);
    }

    function withdrawBruteForced() override onlyOwner public {
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            if ( IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).getTokenBalance(tokenAddresses[i], address(this)) > 0 ) {
                withdrawLendToken( tokenAddresses[i] );
            }
        }
        super.withdrawBruteForced();
    }

    function setPortfolio() public onlyAllowed returns (uint256) {
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            if ( IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).getTokenBalance(tokenAddresses[i], address(this)) > 0 ) {
                withdrawLendToken( tokenAddresses[i] );
            }
        }

        (address[] memory newAssets, uint256[] memory newDistribution) = IWEDXManager(IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress()).getFinalPortfolio();
        uint256 fee = IWEDXManager(IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress()).rewardsFee();
        uint256 result = _setPortfolio(newAssets, newDistribution, fee);

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            if ( IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).isLoanPossible(tokenAddresses[i]) == true && totalAssets[tokenAddresses[i]] > 0 ) {
                supplyLendToken( tokenAddresses[i] );
            }
        }
        return result;
    }

    //Supply lending for a single token 
    function supplyLendToken(address tokenAddress) private {
        require(totalAssets[tokenAddress] > 0, "User does not have this token");
        uint256 amount = totalAssets[tokenAddress];
        require( IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).isLoanPossible(tokenAddress), "Token is not available for lending" );

        TransferHelper.safeApprove(tokenAddress, IWEDXGroup(_wedxGroupAddress).getLenderContractAddress(), amount );
        IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).lendToken(tokenAddress, amount);

        totalAssets[tokenAddress] -= amount;
    }

    //Withdraw from lending a single token 
    function withdrawLendToken(address tokenAddress) private {
        require( IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).isLoanPossible(tokenAddress), "Token is not available for lending" );
        require( IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).getTokenBalance(tokenAddress, address(this)) > 0, "Token has not been lent" );

        uint256 amount = IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).getTokenBalance(tokenAddress, address(this));
        IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).collectToken(tokenAddress, amount);

        totalAssets[tokenAddress] += amount;
    }

    //Get the actual distribution in percentages
    function getActualDistribution() public override view returns (uint256[] memory) {
        uint256[] memory distro = new uint256[](tokenAddresses.length);
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            uint256 amount = totalAssets[tokenAddresses[i]];
            if ( IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).getTokenBalance(tokenAddresses[i], address(this)) > 0 ) {
                amount += IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).getTokenBalance(tokenAddresses[i], address(this));
            }
            if ( tokenAddresses[i] != WNATIVE ) {
                distro[i] = IWEDXswap(IWEDXGroup(_wedxGroupAddress).getSwapContractAddress()).getTokenAmount( tokenAddresses[i], WNATIVE, amount );
            } else {
                distro[i] = amount;
            }
        }
        distro = distroMath.normalize(distro);
        return distro;
    }

    //Get extended assets, includeding in lending protocols
    function getAssetsExtended() public override view returns (uint256[] memory) {
        uint256[] memory assets = new uint256[](tokenAddresses.length);
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            uint256 amount = totalAssets[tokenAddresses[i]];
            if ( IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).getTokenBalance(tokenAddresses[i], address(this)) > 0 ) {
                amount += IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).getTokenBalance(tokenAddresses[i], address(this));
            }
            assets[i] = amount;
        }
        return assets;
    }

    //Get the amount of tokens that are being supplied for lending
    function getAmountLendToken(address tokenAddress) public view returns (uint256) {
        return IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).getTokenBalance(tokenAddress, address(this));
    }

    function getMinPercAllowance() public override view returns (uint256) {
        return IWEDXManager(IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress()).minPercIndexAllowance();
    }

    modifier onlyAllowed {
        require( msg.sender == owner() || ( msg.sender == delegatedAddress && delegatedAddress != address(0) ), "Only the allowed addresses can trigger this function" );
        _;
    }

}