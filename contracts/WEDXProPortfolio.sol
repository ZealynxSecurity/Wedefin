// SPDX-License-Identifier: MIT
/*
    This smart contract handles all transactions on the index token. It is separated from the ERC20 token to be more modular
*/
pragma solidity ^0.8.20;
pragma abicoder v2;

import "./WEDXBasePortfolio.sol";

contract WEDXProPortfolio is WEDXBasePortfolio {

    constructor(address initialOwner) WEDXBasePortfolio(initialOwner) {}

    function deposit() public override onlyOwner payable returns (uint256) {
        uint256 result = super.deposit();
        IWEDXManager(IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress()).updateTraderData(msg.sender, getActualDistribution(), getAddresses());  //change the rights in the manager function from onlyWEDXpro...
        return result;
    }

    function withdraw(uint256 amount) override onlyOwner public {
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            require( IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).getTokenBalance(tokenAddresses[i], address(this)) == 0, "To withdraw, all loans need to be withdrawn first" );
        }
        super.withdraw(amount);
        IWEDXManager(IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress()).updateTraderData(msg.sender, getActualDistribution(), getAddresses());  //change the rights in the manager function from onlyWEDXpro...
    }

    function withdrawBruteForced() override onlyOwner public {
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            if ( IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).getTokenBalance(tokenAddresses[i], address(this)) > 0 ) {
                withdrawLendToken( tokenAddresses[i] );
            }
        }
        super.withdrawBruteForced();
    }

    function setPortfolio(address[] memory newAssets, uint256[] memory newDistribution) public onlyAllowed returns (uint256) {
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            require( IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).getTokenBalance(tokenAddresses[i], address(this)) == 0, "To set portfolio, all loans need to be withdrawn first" );
        }
        uint256 fee = IWEDXManager(IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress()).transactionsFee();
        uint256 result = _setPortfolio(newAssets, newDistribution, fee);
        IWEDXManager(IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress()).updateTraderData(msg.sender, getActualDistribution(), getAddresses());  //change the rights in the manager function from onlyWEDXpro...
        return result;
    }

    //Supply lending for a single token 
    function supplyLendToken(address tokenAddress) public onlyAllowed {
        require(totalAssets[tokenAddress] > 0, "User does not have this token");
        uint256 amount = totalAssets[tokenAddress];
        require( IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).isLoanPossible(tokenAddress), "Token is not available for lending" );

        TransferHelper.safeApprove(tokenAddress, IWEDXGroup(_wedxGroupAddress).getLenderContractAddress(), amount );
        IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).lendToken(tokenAddress, amount);

        totalAssets[tokenAddress] -= amount;
    }

    //Withdraw from lending a single token 
    function withdrawLendToken(address tokenAddress) public onlyAllowed {
        require( IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).isLoanPossible(tokenAddress), "Token is not available for lending" );
        require( IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).getTokenBalance(tokenAddress, address(this)) > 0, "Token has not been lent" );

        uint256 amount = IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).getTokenBalance(tokenAddress, address(this));
        IWEDXlender(IWEDXGroup(_wedxGroupAddress).getLenderContractAddress()).collectToken(tokenAddress, amount);

        totalAssets[tokenAddress] += amount;
    }

    //Request from the manager smart contract the ranking for the user
    function rankMe() public onlyAllowed {
        IWEDXManager(IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress()).computeRanking(msg.sender);
    }

    function setMinPercAllowance(uint256 newPerc) public onlyAllowed {
        super._setMinPercAllowance(newPerc);
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

    modifier onlyAllowed {
        require( msg.sender == owner() || ( msg.sender == delegatedAddress && delegatedAddress != address(0) ), "Only the allowed addresses can trigger this function" );
        _;
    }

}