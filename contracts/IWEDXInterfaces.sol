// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWEDXManager {
    function updateTraderData(address traderId, uint256[] memory distro, address[] memory assets) external;
    function computeRanking( address traderId ) external;
    function getFinalPortfolio() view external returns (address[] memory, uint256[] memory);
    function rewardsFee() view external returns (uint256);
    function transactionsFee() view external returns (uint256);
    function depositWithdrawFee() view external returns (uint256);
    function totalRankSum() view external returns (uint256);
    function minPercIndexAllowance() view external returns (uint256);
    function getRankingList() external view returns (address[] memory);
    function getTraderScore(address user) external view returns (uint256);
    function rebalanceActor() external view returns (address);
    function rebalanceActorFee() external view returns (uint256);
}

interface IWEDXTreasury {
    function depositGeneralFee() external payable;
    function depositRewardFee() external payable;
}

interface IWETH9 is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

interface IWEDXrank {
    function getRanking(uint256[] memory timeSeries, uint256[] memory performanceSeries, uint256[] memory liquiditySeries) external pure returns (uint256[] memory);
}

interface IWEDXDeployerPro {
    function isProPortfolioActive( address portfolioAddress ) external view returns (bool);
    function getUserFromProPortfolioAddress( address portfolio ) external view returns (address);
}

struct exInfo {
    uint16 exId;
    uint24 feeUniswap;
    uint128 liquidity;
}

interface IWEDXswap {
    function swapNative( address tokenOut, uint256 maxSlippage ) external payable returns (uint256);        
    function swapERC20( address tokenIn, address tokenOut, uint256 amountIn, uint256 maxSlippage ) external returns (uint256);     
    function getTokenAmount(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256);
    function validatePool( address tokenIn, address tokenOut ) external returns (exInfo memory);
    function getAssetPoolLiquidity( address tokenAddress ) external view returns (uint128);
}

interface IWEDXlender {
    function lendToken(address tokenAddress, uint256 amount) external;
    function collectToken(address tokenAddress, uint256 amount) external;
    function getTokenBalance(address tokenAddress, address account) external view returns (uint256);
    function isLoanPossible(address tokenAddress) external view returns (bool);
}

interface IWEDXlenderSingle {
    function lendToken(address tokenAddress, uint256 amount) external;
    function collectToken(address tokenAddress, uint256 amount) external;
    function getTokenBalance(address tokenAddress) external view returns (uint256);
}

interface IWEDXGroup {
    function getTreasuryAddress() external view returns (address);
    function getDeployerProAddress() external view returns (address);
    function getAssetManagerAddress() external view returns (address);
    function getRankAddress() external view returns (address);
    function getSwapContractAddress() external view returns (address);
    function getLenderContractAddress() external view returns (address);
    function owner() external view returns (address);
}