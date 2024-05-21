// SPDX-License-Identifier: MIT
/*
    Just the ranking function. It should be possible to upgrade this function and therefore it has its own smart contract
*/
pragma solidity ^0.8.20;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {console2} from "forge-std/Test.sol";


contract WEDXRanker {
    using SafeMath for uint256;
    
    constructor() {}

    function getRanking(uint256[] memory timeSeries, uint256[] memory performanceSeries, uint256[] memory liquiditySeries) external pure returns (uint256[] memory) {
        uint256 _nPoints = timeSeries.length;
        require( _nPoints == performanceSeries.length, "Time and data should have the same size" );
        require( _nPoints == liquiditySeries.length, "Time and liquidity series should have the same size" );
        uint256 rank = 0;

        int256 y1 = int256(performanceSeries[_nPoints - 1]);
        int256 y0 = int256(performanceSeries[0]);
        int256 x1 = int256(timeSeries[_nPoints - 1]);
        int256 x0 = int256(timeSeries[0]);
        int256 sigma = 0;
        uint256 minLiquidity = liquiditySeries[0];
        for (uint256 i = 0; i < _nPoints; i++) { // @audit Gas Griefing due to run out of gas??
            int256 y = int256(performanceSeries[i]);
            int256 x = int256(timeSeries[i]);
            int256 absD = y - ((((y1 - y0) * (x - x0)) / (x1 - x0)) + y0);
            sigma += absD >= 0 ? absD : -absD;
            if ( liquiditySeries[i] < minLiquidity ) {
                minLiquidity = liquiditySeries[i];
            }
        }
        sigma = sigma / int256(_nPoints - 2);
        console2.log("Final sigma in contracts:", sigma);


        //I need to make positive the Rank, solving for y1-y0.
        if (sigma > 0) {
            int256 scale = 10**3;
            int256 v = ((y1 - y0) * scale) / sigma;
            int256 sqrtDt = int256(Math.sqrt(uint256(x1 - x0)));
            rank = uint256( sqrtDt + ( ( v * sqrtDt ) / int256( Math.sqrt(uint256(scale * scale) + uint256(v * v)) ) ) ) * Math.sqrt(minLiquidity) / 2;
        } else {
            rank = 0;
        }

        uint256[] memory results = new uint256[](4);

        uint256 absP = performanceSeries[_nPoints - 1] > performanceSeries[0] ? performanceSeries[_nPoints - 1] - performanceSeries[0] : performanceSeries[0] - performanceSeries[_nPoints - 1];
    
        //TODO: output rank, abs(performance change), std, and liquidity
        results[0] = rank > 0 ? rank : 1; results[1] = absP; results[2] = uint256(sigma); results[3] = minLiquidity; 
        
        return results;

    }

}
