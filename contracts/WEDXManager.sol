// SPDX-License-Identifier: MIT
/*
    This contract keeps track of the traders performances on the Pro smart contract.
    It also trigger the rebalancing of the Index token when it is needed.
*/
pragma solidity ^0.8.20;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./IWEDXInterfaces.sol";
import "./WEDXConstants.sol";
import "./library/distroMath.sol";

contract WEDXManager is WEDXConstants {

    struct trader {
        uint256[] currentPortfolio;
        uint256[] currentDistro;
        address[] currentTokenAddresses;
        uint256[] performances;
        uint256[] timestamps;
        uint256[] minLiquidity;
        uint256 initTimestamp;
    }

    struct rank {
        uint256[] preValue;
        address[] commonAddresses;
        uint256 postValue;
    }

    using SafeMath for uint256;
    IWETH9 private cWNATIVE;
    uint256 private constant initCapital = 1000000 gwei;
    uint256 public initialBlock = 0;
    uint256 public lastTimestamp;

    uint private _nPoints = 5;
    uint256 private _timeWindow = 30 days;
    uint256 public minRanking = type(uint256).max;
    uint256 public maxRanking = type(uint256).min;
    uint public rankingListMaxSize = 50;
    address[] public rankingList;
    uint256 public totalRankSum = 0;
    address public rebalanceActor;

    //Allowance measured on based 10**6
    uint256 public minPercIndexAllowance = 20000;
    uint256 public similarityPerc = 100000;

    //Fees are measured on based 10**6
    uint256 public rewardsFee = 10000;
    uint256 public transactionsFee = 500;
    uint256 public depositWithdrawFee = 5000;
    uint256 public rebalanceActorFee = 100000;

    mapping(address => trader) private traderData;
    mapping(address => trader) private traderDataScreenshot;
    mapping(address => rank) private addressToRank;
    mapping(address => uint256) private tokenToWeight;

    address[] private uniqueAssetAddresses;
    uint256[] private newPortfolio;

    event TraderUpdate(address indexed from, uint256 indexed timestamp, uint256 indexed performance);

    constructor() {
        cWNATIVE = IWETH9(WNATIVE);
        initialBlock = block.number;
    }

    //Every time traders rebalalance their portfolio, or deposit or withdraw, we mirror the changes in the portfolio.
    function updateTraderData(address traderId, uint256[] memory distro, address[] memory assets) external onlyWEDXpro(traderId) {

        uint256 sum = 0;
        for( uint i = 0; i < distro.length; i++ ){
            sum += distro[i];
        }

        if ( traderData[traderId].performances.length == 0 ) {

            if ( sum == distroMath.distroNorm ) {
                uint256[] memory capitals = new uint256[](1);
                uint256[] memory times = new uint256[](1);
                uint256[] memory liquidities = new uint256[](1);
                capitals[0] = initCapital;
                times[0] = block.timestamp;
                liquidities[0] = _getMinLiquidity(assets);
                traderData[traderId] = trader( _getPortfolio( distro, assets, initCapital ), distro, assets, capitals, times, liquidities, block.timestamp );

                emit TraderUpdate(traderId, block.timestamp, initCapital);
            }    

        } else {

            if ( sum == distroMath.distroNorm ) {
                require( block.timestamp > traderData[traderId].timestamps[traderData[traderId].timestamps.length-1], "Timestamp invalid or wait longer" );
                uint256 capital = _getCapital( traderData[traderId].currentPortfolio, traderData[traderId].currentTokenAddresses );
                traderData[traderId].performances.push(capital);
                traderData[traderId].timestamps.push(block.timestamp);
                traderData[traderId].minLiquidity.push(_getMinLiquidity(assets));
                if (traderData[traderId].performances.length > _nPoints) {
                    for( uint i = 0; i < _nPoints; i++ ){
                        traderData[traderId].performances[i] = traderData[traderId].performances[i+1];
                        traderData[traderId].timestamps[i] = traderData[traderId].timestamps[i+1];
                        traderData[traderId].minLiquidity[i] = traderData[traderId].minLiquidity[i+1];
                    }
                    traderData[traderId].performances.pop();
                    traderData[traderId].timestamps.pop();
                    traderData[traderId].minLiquidity.pop();
                }
                traderData[traderId].currentTokenAddresses = assets;
                traderData[traderId].currentPortfolio = _getPortfolio( distro, assets, capital );
                traderData[traderId].currentDistro = distro;

                emit TraderUpdate(traderId, block.timestamp, capital);
            } else {
                trader memory defaultTrader;
                rank memory defaultRank;
                traderData[traderId] = defaultTrader;
                addressToRank[traderId] = defaultRank;
                _recomputeMinMaxRanking();
            }

        }

    }

    //Compute ranking of a specific trader and also clean the list of traders from dormants.
    function computeRanking( address traderId ) external onlyWEDXpro(traderId) returns (uint256) {

        bool changed = false;
        for (uint i = 0; i < rankingList.length; i++) {
            if ( ( block.timestamp > _timeWindow + traderData[rankingList[i]].timestamps[traderData[rankingList[i]].timestamps.length-1] || traderData[rankingList[i]].timestamps.length < _nPoints ) && addressToRank[rankingList[i]].postValue > type(uint256).min ) {
                rank memory defaultRank;
                addressToRank[rankingList[i]] = defaultRank;
                changed = true;
            }
        }
        if( changed == true ) {
            _recomputeMinMaxRanking();
        }

        if ( traderData[traderId].performances.length == _nPoints ) { 
            addressToRank[traderId].preValue = IWEDXrank(IWEDXGroup(_wedxGroupAddress).getRankAddress()).getRanking(traderData[traderId].timestamps, traderData[traderId].performances, traderData[traderId].minLiquidity);
            for (uint i = 0; i < rankingList.length; i++) {
                if ( rankingList[i] != traderId ) {
                    uint isSimilar = 0;
                    for(uint j = 1; j < 4; j++){
                        uint256 absDiff = addressToRank[rankingList[i]].preValue[j] > addressToRank[traderId].preValue[j] ? addressToRank[rankingList[i]].preValue[j] - addressToRank[traderId].preValue[j] : addressToRank[traderId].preValue[j] - addressToRank[rankingList[i]].preValue[j];
                        if ( absDiff < addressToRank[traderId].preValue[j] * similarityPerc / distroMath.distroNorm ) { 
                            isSimilar++;
                        }
                    }
                    if ( isSimilar == 3 ) { 
                        if ( !distroMath.isInNewAssets(rankingList[i], addressToRank[traderId].commonAddresses ) ) {
                            addressToRank[traderId].commonAddresses.push( rankingList[i] );
                        }
                        if ( !distroMath.isInNewAssets(traderId, addressToRank[rankingList[i]].commonAddresses ) ) {
                            addressToRank[rankingList[i]].commonAddresses.push( traderId );
                            addressToRank[rankingList[i]].postValue = addressToRank[rankingList[i]].preValue[0] / ( addressToRank[rankingList[i]].commonAddresses.length + 1 );
                        }
                    }

                }
            }
            addressToRank[traderId].postValue = addressToRank[traderId].preValue[0] / ( addressToRank[traderId].commonAddresses.length + 1 );

            bool isThere = false;
            for (uint i = 0; i < rankingList.length; i++) {
                if ( rankingList[i] == traderId ) {
                    isThere = true;
                    break;
                }
            }
            
            if ( rankingList.length < rankingListMaxSize ) {
                if (isThere == false) {
                    rankingList.push( traderId );
                }
            } else {
                if ( addressToRank[traderId].postValue >= minRanking && isThere == false ) {
                    for (uint i = 0; i < rankingList.length; i++) {
                        if( addressToRank[rankingList[i]].postValue == minRanking ) {
                            rankingList[i] = traderId;
                            break;
                        }
                    }
                }
            }
            _recomputeMinMaxRanking();
        }

        traderDataScreenshot[traderId] = traderData[traderId];

        return addressToRank[traderId].postValue;

    }

    //This function triggers the rebalancing on the Index token. TODO: No time or portfolio change constrains
    function setFinalWeights() public {
        require( rankingList.length > 0, "There is no ranking of traders" );
        delete uniqueAssetAddresses;
        
        uint256 totalWeights = 0;
        tokenToWeight[WNATIVE] = 0;
        for(uint i = 0; i < rankingList.length; i++) {
            if ( addressToRank[rankingList[i]].postValue > 0 ) {
                for(uint j = 0; j < traderDataScreenshot[rankingList[i]].currentDistro.length-1; j++) {
                    address assetAddress = traderDataScreenshot[rankingList[i]].currentTokenAddresses[j];
                    if( !distroMath.isInNewAssets(assetAddress, uniqueAssetAddresses) ) {
                        uniqueAssetAddresses.push( assetAddress );
                        tokenToWeight[assetAddress] = 0; 
                    }
                    tokenToWeight[assetAddress] += addressToRank[rankingList[i]].postValue * traderDataScreenshot[rankingList[i]].currentDistro[j];
                }
                tokenToWeight[WNATIVE] += addressToRank[rankingList[i]].postValue * traderDataScreenshot[rankingList[i]].currentDistro[traderDataScreenshot[rankingList[i]].currentDistro.length-1]; 
                totalWeights += addressToRank[rankingList[i]].postValue;
            }
        }
        
        totalRankSum = totalWeights;
        newPortfolio = new uint256[](uniqueAssetAddresses.length+1);

        newPortfolio[newPortfolio.length-1] = tokenToWeight[WNATIVE];
        uint256 sum = newPortfolio[newPortfolio.length-1];
        for( uint i=0; i < uniqueAssetAddresses.length; i++) {
            newPortfolio[i] = tokenToWeight[uniqueAssetAddresses[i]];
            sum += newPortfolio[i];
        }
        require( sum > 0, "New portfolio is invalid" );        
        newPortfolio = distroMath.normalize( newPortfolio );
        lastTimestamp = block.timestamp;
        rebalanceActor = msg.sender;
    }

    //Set the min. percentage allocation mismatch needed to allow rebalancing of the final asset allocation
    function setMinPercAllowance(uint256 newPerc) public onlyOwner {
        require( newPerc > 0, "For safety reasons, we avoid zero tolerance for rebalancing a portfolio" );
        minPercIndexAllowance = newPerc;
    }

    //Set the percentage below which two traders are considered similar
    function setSimilirityPerc(uint256 newPerc) public onlyOwner {
        similarityPerc = newPerc;
    }

    //Recompute the min and max values of rankings
    function _recomputeMinMaxRanking() private {
        uint256 newMin = type(uint256).max;
        uint256 newMax = type(uint256).min;
        for (uint i = 0; i < rankingList.length; i++) {
            if( addressToRank[rankingList[i]].postValue < newMin ) {
                newMin = addressToRank[rankingList[i]].postValue;
            }
            if( addressToRank[rankingList[i]].postValue > newMax ) {
                newMax = addressToRank[rankingList[i]].postValue;
            }
        }
        minRanking = newMin;
        maxRanking = newMax;
    }

    //Get the portfolio of on the original assets given the total capital in native tokens, the assets in the portfolio, and the percentage allocation
    function _getPortfolio( uint256[] memory distro, address[] memory assets, uint256 capital ) private view returns (uint256[] memory) {
        require( distro.length == assets.length, "Arrays do not have the correct sizes to get Portfolio" );
        uint256[] memory portfolio = new uint256[](distro.length);
        uint256 quoteCapital = ( distro[distro.length-1] * capital ) / distroMath.distroNorm;

        for (uint256 i = 0; i < distro.length-1; i++) {
            uint256 distroCapital = ( distro[i] * capital ) / distroMath.distroNorm;
            portfolio[i] = IWEDXswap(IWEDXGroup(_wedxGroupAddress).getSwapContractAddress()).getTokenAmount( WNATIVE, assets[i], distroCapital );
        }
        portfolio[portfolio.length-1] = quoteCapital;
        return portfolio;
    }

    //Get the minimum liquidity from all assets in the portfolio
    function _getMinLiquidity( address[] memory assets ) private view returns (uint256) {
        uint256 minValue = IERC20(WNATIVE).totalSupply();
        for (uint256 i = 0; i < assets.length-1; i++) {
            uint128 result = IWEDXswap(IWEDXGroup(_wedxGroupAddress).getSwapContractAddress()).getAssetPoolLiquidity( assets[i] ); 
            if ( result < minValue ) {
                minValue = result;
            }
        }
        return minValue;
    }

    //Get total capital in native tokens given the distribution and the asset addresses.
    function _getCapital( uint256[] memory distroCapital, address[] memory assets) private view returns (uint256) {
        require( distroCapital.length == assets.length, "Arrays do not have the correct sizes to get Capital" );
        uint256 totalCapital = distroCapital[distroCapital.length-1];
        for (uint256 i = 0; i < distroCapital.length-1; i++) {
            totalCapital += IWEDXswap(IWEDXGroup(_wedxGroupAddress).getSwapContractAddress()).getTokenAmount( assets[i], WNATIVE, distroCapital[i] );
        }
        return totalCapital;
    }

    //Provides the final portfolio after computing the compeition results
    function getFinalPortfolio() view public returns (address[] memory, uint256[] memory) {
        return ( uniqueAssetAddresses, newPortfolio );
    }

    //Get all traders data according to the structure trader
    function getTraderData(address user) public view returns (trader memory) {
        return traderData[user];
    }

    //Get the total ranking list
    function getRankingList() public view returns (address[] memory) {
        return rankingList;
    }

    //Get the trader score
    function getTraderScore(address user) public view returns (uint256) {
        return addressToRank[user].postValue;
    }

    //Get the number of minimum points to be considered eligible for the competition between traders
    function getNPoints() public view returns (uint256) {
        return _nPoints;
    }

    //Get the current timestamp
    function getCurrentTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    //Change the number of minimum points to be consider in the ranking competition
    function changeNPoints(uint newNPoint) public onlyOwner {
        require( newNPoint > 2 && newNPoint <= 10, "Due to gas limits, newPoints are constrained between 3 - 10" );
        _nPoints = newNPoint;
    }

    //_timeWindow determines after how long an user is considered non eligible for the competition given their last trade update
    function changeTimeWindow(uint256 newTimeWindow) public onlyOwner {
        require( newTimeWindow > 1 days, "Minimum time window is 1 day" );
        _timeWindow = newTimeWindow;
    }

    //Change the number of top traders considered for the ranking
    function changeRankingListMaxSize(uint newSize) public onlyOwner {
        require( newSize > 0, "Ranking list must be larger than zero" );
        if ( newSize < rankingList.length ) {                        
            address[] memory rankingListTemp = rankingList;
            for (uint256 i = 0; i < rankingListTemp.length - 1; i++) {
                for (uint256 j = 0; j < rankingListTemp.length - i - 1; j++) {
                    if ( addressToRank[rankingListTemp[j]].postValue < addressToRank[rankingListTemp[j + 1]].postValue ) {
                        address temp = rankingListTemp[j];
                        rankingListTemp[j] = rankingListTemp[j + 1];
                        rankingListTemp[j + 1] = temp;
                    }
                }
            }
            rankingList = new address[](newSize);
            for (uint i = 0; i < newSize; i++) {
                rankingList[i] = rankingListTemp[i];
            }
            _recomputeMinMaxRanking();
        }
        rankingListMaxSize = newSize;
    }

    //It changes the rewards percentage given to the top traders
    function changeFees(uint256 newRewardsFee, uint256 newTransactionsFee, uint256 newDepositWithdrawFee, uint256 newRebalanceActorFee) public onlyOwner {
        require( newRewardsFee < distroMath.distroNorm && newTransactionsFee < distroMath.distroNorm && newDepositWithdrawFee < distroMath.distroNorm, "Fees are invalid" );
        rewardsFee = newRewardsFee;
        transactionsFee = newTransactionsFee;
        depositWithdrawFee = newDepositWithdrawFee;
        rebalanceActorFee = newRebalanceActorFee;
    }

    modifier onlyOwner {
        require( msg.sender == IWEDXGroup(_wedxGroupAddress).owner(), "Only the owner can trigger this function" );
        _;
    }

    modifier onlyWEDXpro( address user ) {
        require( IWEDXDeployerPro(IWEDXGroup(_wedxGroupAddress).getDeployerProAddress()).isProPortfolioActive(msg.sender) && IWEDXDeployerPro(IWEDXGroup(_wedxGroupAddress).getDeployerProAddress()).getUserFromProPortfolioAddress( msg.sender ) == user, "Only the WEDX pro smart contract of the respective user can trigger this function" );
        _;
    }

}
