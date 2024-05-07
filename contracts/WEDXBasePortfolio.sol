// SPDX-License-Identifier: MIT
/*
    This smart contract handles all features of a given portfolio. It will be used for the index token and the pro portfolio builder
*/
pragma solidity ^0.8.20;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./IWEDXInterfaces.sol";
import "./WEDXConstants.sol";
import "./distroMath.sol";

contract WEDXBasePortfolio is WEDXConstants, Ownable {
    using SafeMath for uint256;

    IWETH9 internal cWNATIVE;
    uint256 internal lastTimestamp;
    uint256 internal minPercAllowance = 20000;
    address internal delegatedAddress = address(0);
    uint256 public maxSlippage = 5000;

    address[] internal tokenAddresses = tokenAddressesInit; 
    mapping(address => uint256) internal totalAssets; 

    uint256 internal _supply = distroMath.distroNorm;

    constructor(address initialOwner) Ownable(initialOwner) {
        cWNATIVE = IWETH9(WNATIVE);
        lastTimestamp = block.timestamp;
    }

    //Receive native cryptocurrency and deposit it into the portfolio.
    function deposit() public virtual payable onlyOwner returns(uint256) {
        require( msg.value > 0, "Native assets must be paid" );
        uint256 fee = ( msg.value * IWEDXManager(IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress()).depositWithdrawFee() ) / distroMath.distroNorm;
        IWEDXTreasury(IWEDXGroup(_wedxGroupAddress).getTreasuryAddress()).depositGeneralFee{value: fee}();

        uint256 ethAmount = msg.value - fee;
        uint256 amountReturn = 0;
        uint256 supply = getSupply();
        uint256[] memory distribution = getActualDistribution();

        uint256 sum = 0;
        for (uint256 i = 0; i < distribution.length; i++) {
            sum += distribution[i];
        }

        if ( sum == 0 || supply == 0 ) {
            totalAssets[WNATIVE] = ethAmount;
            amountReturn = ethAmount;
            cWNATIVE.deposit{value: ethAmount}();
        } else {
            uint256[] memory assetsExtended = getAssetsExtended();
            for (uint256 i = 0; i < distribution.length; i++) {
                if ( distribution[i] > 0 ) {
                    uint256 amountIn = ( ethAmount * distribution[i] ) / distroMath.distroNorm;
                    if ( tokenAddresses[i] != WNATIVE ) {
                        uint256 amountOut = IWEDXswap(IWEDXGroup(_wedxGroupAddress).getSwapContractAddress()).swapNative{value: amountIn}(tokenAddresses[i], maxSlippage);
                        amountReturn += Math.mulDiv( amountOut, supply * distribution[i], assetsExtended[i] * distroMath.distroNorm );
                        totalAssets[tokenAddresses[i]] += amountOut;
                    } else {
                        cWNATIVE.deposit{value: amountIn}();
                        amountReturn += Math.mulDiv( amountIn, supply * distribution[i], assetsExtended[i] * distroMath.distroNorm );
                        totalAssets[tokenAddresses[i]] += amountIn;
                    }
                }
            }
        } 

        return amountReturn;
    }

    //Sells a given amount of the portfolio and send back to the user native cryptocurrencies according to the conversion
    function withdraw(uint256 amount) virtual public onlyOwner {
        require( amount > 0, "You must provide a positive amount" );
        uint256 supply = getSupply();
        require( supply > 0, "Supply variable is zero" );

        uint256 total_wnative = 0;
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            uint256 tokenAmount =  Math.mulDiv( totalAssets[tokenAddresses[i]], amount, supply );
            if (tokenAmount > 0) {
                if ( tokenAddresses[i] != WNATIVE ) {
                    TransferHelper.safeApprove( tokenAddresses[i], IWEDXGroup(_wedxGroupAddress).getSwapContractAddress(), tokenAmount );
                    uint256 amountOut = IWEDXswap(IWEDXGroup(_wedxGroupAddress).getSwapContractAddress()).swapERC20(tokenAddresses[i], WNATIVE, tokenAmount, maxSlippage);
                    totalAssets[tokenAddresses[i]] -= tokenAmount;
                    total_wnative += amountOut;
                } else {
                    total_wnative += tokenAmount;
                    totalAssets[tokenAddresses[i]] -= tokenAmount;
                }
            }
        }

        require( cWNATIVE.balanceOf(address(this)) >= total_wnative, "Smart contract does not have enough tokens" );
        if (total_wnative > 0) {
            cWNATIVE.withdraw(total_wnative);
        }

        require( address(this).balance >= total_wnative, "Smart contract does not have enough funds" );
        uint256 fee = ( total_wnative * IWEDXManager(IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress()).depositWithdrawFee() ) / distroMath.distroNorm;
        IWEDXTreasury(IWEDXGroup(_wedxGroupAddress).getTreasuryAddress()).depositGeneralFee{value: fee}();
        total_wnative = total_wnative - fee;

        if (total_wnative > 0 && address(this).balance >= total_wnative) {
            address payable sender = payable(msg.sender);
            (bool success, ) = sender.call{value: total_wnative}("");
            require(success, "Withdrawal failed");
        }

    }

    //Send the current portfolio without swapping. It is supposed to be a red button in case there are issues on swapping
    function withdrawBruteForced() virtual public onlyOwner {
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            uint256 tokenAmount = IERC20(tokenAddresses[i]).balanceOf(address(this));
            if (tokenAmount > 0) {
                if ( tokenAddresses[i] != WNATIVE ) {
                    TransferHelper.safeTransfer( tokenAddresses[i], msg.sender, tokenAmount );
                    totalAssets[tokenAddresses[i]] -= tokenAmount;
                } else {
                    cWNATIVE.withdraw(tokenAmount);
                    totalAssets[tokenAddresses[i]] -= tokenAmount;
                    uint256 newAmount = address(this).balance;
                    address payable sender = payable(msg.sender);
                    (bool success, ) = sender.call{value: newAmount}("");
                    require(success, "Withdrawal failed");
                }
            }
        }
    }

    function _setMinPercAllowance(uint256 newPerc) internal virtual {
        minPercAllowance = newPerc;
    }

    //Change the tokens and distribution in the portfolio 
    function _setPortfolio(address[] memory newAssets, uint256[] memory newDistribution, uint256 fee) internal virtual returns (uint256) {
        require( newDistribution.length == newAssets.length+1, "The distribution array length must equal the number of new assets + native asset");
        uint256 totalNewDistribution = 0;
        for (uint256 i = 0; i < newDistribution.length; i++) {
            totalNewDistribution += newDistribution[i];
        }
        require( totalNewDistribution == distroMath.distroNorm, "Distribution must be normalized");

        bool validArrays = true;
        for (uint256 i = 0; i < newAssets.length; i++) {
            if ( WNATIVE == newAssets[i] || IWEDXswap(IWEDXGroup(_wedxGroupAddress).getSwapContractAddress()).validatePool( newAssets[i], WNATIVE ).liquidity == 0 ) {
                validArrays = false;
            }
        }
        require( validArrays, "Arrays and Fees are not valid" );

        if ( tokenAddresses.length > 0 ) {
            for(uint256 i = 0; i < tokenAddresses.length; i++) {
                if ( !distroMath.isInNewAssets(tokenAddresses[i], newAssets) && totalAssets[tokenAddresses[i]] > 0 && tokenAddresses[i] != WNATIVE ){
                    TransferHelper.safeApprove( tokenAddresses[i], IWEDXGroup(_wedxGroupAddress).getSwapContractAddress(), totalAssets[tokenAddresses[i]] );
                    uint256 amountOut = IWEDXswap(IWEDXGroup(_wedxGroupAddress).getSwapContractAddress()).swapERC20(tokenAddresses[i], WNATIVE, totalAssets[tokenAddresses[i]], maxSlippage);
                    totalAssets[tokenAddresses[i]] = 0;
                    totalAssets[WNATIVE] += amountOut;
                }
            }
        }

        tokenAddresses = new address[]( newAssets.length + 1 );
        for(uint256 i = 0; i < newAssets.length; i++) {
            tokenAddresses[i] = newAssets[i];
        }
        tokenAddresses[newAssets.length] = WNATIVE; 

        uint256 result = _changeDistribution(newDistribution, fee);
        lastTimestamp = block.timestamp;

        return result;

    }

    //Change the distribution of the portfolio.
    function _changeDistribution(uint256[] memory newDistribution, uint256 fee) internal returns (uint256) {
        uint256[] memory actualDistro = getActualDistribution();

        uint256 sum = 0;
        for (uint256 i = 0; i < actualDistro.length; i++) {
            sum += actualDistro[i];
        }
        if ( sum == 0 ) {
            return 0;
        }

        uint256 totalDelta = 0;
        for (uint256 i = 0; i < newDistribution.length; i++) {
            if (actualDistro[i] > newDistribution[i]) {
                totalDelta += actualDistro[i] - newDistribution[i];
            } else {
                totalDelta +=  newDistribution[i] - actualDistro[i];
            }
        }
        if ( totalDelta < 2 * getMinPercAllowance() ) {
            return 0;
        }

        uint256 prop_wnative = actualDistro[actualDistro.length-1];
        uint256 nativeAmountFee = Math.mulDiv( totalAssets[WNATIVE], fee,  distroMath.distroNorm );
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            if ( actualDistro[i] > newDistribution[i] && tokenAddresses[i] != WNATIVE ) {

                uint256 amountInFee = Math.mulDiv( totalAssets[tokenAddresses[i]], fee,  distroMath.distroNorm );

                uint256 delta_sell = actualDistro[i] - newDistribution[i];
                uint256 amountIn = Math.mulDiv( totalAssets[tokenAddresses[i]] - amountInFee, delta_sell,  actualDistro[i] );

                TransferHelper.safeApprove( tokenAddresses[i], IWEDXGroup(_wedxGroupAddress).getSwapContractAddress(), amountIn + amountInFee );
                uint256 amountOut = IWEDXswap(IWEDXGroup(_wedxGroupAddress).getSwapContractAddress()).swapERC20(tokenAddresses[i], WNATIVE, amountIn, maxSlippage);

                if ( amountInFee + amountIn > 0 ) {
                    nativeAmountFee += amountOut * amountInFee / ( amountInFee + amountIn );
                }

                totalAssets[WNATIVE] += amountOut;
                totalAssets[tokenAddresses[i]] -= ( amountIn + amountInFee );
                prop_wnative += delta_sell;
            }
        }

        uint256 totalAssetsNative = totalAssets[WNATIVE] - nativeAmountFee;
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            if ( newDistribution[i] > actualDistro[i] && tokenAddresses[i] != WNATIVE ) {
                uint256 delta_buy = newDistribution[i] - actualDistro[i];
                uint256 amountIn = Math.mulDiv( totalAssetsNative, delta_buy, prop_wnative );

                TransferHelper.safeApprove( WNATIVE, IWEDXGroup(_wedxGroupAddress).getSwapContractAddress(), amountIn );
                uint256 amountOut = IWEDXswap(IWEDXGroup(_wedxGroupAddress).getSwapContractAddress()).swapERC20(WNATIVE, tokenAddresses[i], amountIn, maxSlippage);

                totalAssets[WNATIVE] -= amountIn;
                totalAssets[tokenAddresses[i]] += amountOut;
            }
        }

        if ( nativeAmountFee > 0 ) {
            totalAssets[WNATIVE] -= nativeAmountFee;
            cWNATIVE.withdraw(nativeAmountFee);
            if ( fee == IWEDXManager(IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress()).rewardsFee() ) {
                IWEDXTreasury(IWEDXGroup(_wedxGroupAddress).getTreasuryAddress()).depositRewardFee{value: nativeAmountFee}();
            } else if ( fee == IWEDXManager(IWEDXGroup(_wedxGroupAddress).getAssetManagerAddress()).transactionsFee() ) {
                IWEDXTreasury(IWEDXGroup(_wedxGroupAddress).getTreasuryAddress()).depositGeneralFee{value: nativeAmountFee}();
            }
        }

        return ( getSupply() * fee ) / distroMath.distroNorm;

    }

    function getAssets() public view returns (uint256[] memory) {
        uint256[] memory totalAssetsResult = new uint256[]( tokenAddresses.length ); 
        for(uint256 i = 0; i < tokenAddresses.length; i++) {
            totalAssetsResult[i] = totalAssets[tokenAddresses[i]];
        }
        return totalAssetsResult;
    }

    function getAssetsExtended() virtual public view returns (uint256[] memory) {
        return getAssets();
    }

    function getAddresses() public view returns (address[] memory) {
        return tokenAddresses;
    }

    function getLastTimestamp() public view returns (uint256) {
        return lastTimestamp;
    }

    function getMinPercAllowance() virtual public view returns (uint256) {
        return minPercAllowance;
    }

    function getDelegatedAddress() virtual public view returns (address) {
        return delegatedAddress;
    }

    //Get the actual distribution in percentages
    function getActualDistribution() public virtual view returns (uint256[] memory) {
        uint256[] memory distro = new uint256[](tokenAddresses.length);
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            uint256 amount = totalAssets[tokenAddresses[i]];
            if ( tokenAddresses[i] != WNATIVE ) {
                distro[i] = IWEDXswap(IWEDXGroup(_wedxGroupAddress).getSwapContractAddress()).getTokenAmount( tokenAddresses[i], WNATIVE, amount );
            } else {
                distro[i] = amount;
            }
        }
        distro = distroMath.normalize(distro);
        return distro;
    }

    function getSupply() public view virtual returns (uint256) {
        return _supply;
    }

    function changeDelegatedAddress(address newAddress) public onlyOwner {
        delegatedAddress = newAddress;
    }

    function changeMaxSlippage(uint256 newValue) public onlyOwner {
        require( newValue <= distroMath.distroNorm, "Invalid max slippage" );
        maxSlippage = newValue;
    }

    receive() external payable {}
}