// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/WEDXRanker.sol";

contract WEDXRankerFuzzTest is Test {
    WEDXRanker public ranker;

    function setUp() public {
        ranker = new WEDXRanker();
    }


    function testRankingWithEqualLengthSeries(uint256 len) public {
        len = bound(len, 3, 10); 

        uint256[] memory timeSeries = new uint256[](len);
        uint256[] memory performanceSeries = new uint256[](len);
        uint256[] memory liquiditySeries = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            timeSeries[i] = i + 1; 
            performanceSeries[i] = bound(uint256(keccak256(abi.encodePacked(i))), 1, 10**6);
            liquiditySeries[i] = bound(uint256(keccak256(abi.encodePacked(i))), 1, 10**6);
        }

        uint256[] memory results = ranker.getRanking(timeSeries, performanceSeries, liquiditySeries);

        assertEq(results.length, 4, "Results should have length 4");
    }


    function testRankingNoDivisionByZero(uint256 len) public {
        len = bound(len, 3, 10); 

        uint256[] memory timeSeries = new uint256[](len);
        uint256[] memory performanceSeries = new uint256[](len);
        uint256[] memory liquiditySeries = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            timeSeries[i] = i + 1; 
            performanceSeries[i] = bound(uint256(keccak256(abi.encodePacked(i))), 1, 10**6);
            liquiditySeries[i] = bound(uint256(keccak256(abi.encodePacked(i))), 1, 10**6);
        }

        uint256[] memory results = ranker.getRanking(timeSeries, performanceSeries, liquiditySeries);

        assertEq(results.length, 4, "Results should have length 4");
    }




    function testRankingSigmaCalculation(uint256 len) public {
        len = bound(len, 3, 10);

        uint256[] memory timeSeries = new uint256[](len);
        uint256[] memory performanceSeries = new uint256[](len);
        uint256[] memory liquiditySeries = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            timeSeries[i] = i + 1; 
            performanceSeries[i] = bound(uint256(keccak256(abi.encodePacked(i))), 1, 10**6);
            liquiditySeries[i] = bound(uint256(keccak256(abi.encodePacked(i))), 1, 10**6);
        }

        uint256[] memory results = ranker.getRanking(timeSeries, performanceSeries, liquiditySeries);

        int256 y1 = int256(performanceSeries[len - 1]);
        int256 y0 = int256(performanceSeries[0]);
        int256 x1 = int256(timeSeries[len - 1]);
        int256 x0 = int256(timeSeries[0]);
        int256 sigma = 0;
        for (uint256 i = 0; i < len; i++) {
            int256 y = int256(performanceSeries[i]);
            int256 x = int256(timeSeries[i]);
            int256 absD = y - ((((y1 - y0) * (x - x0)) / (x1 - x0)) + y0);
            sigma += absD >= 0 ? absD : -absD;
        }
        sigma = sigma / int256(len - 2);

        assertEq(results[2], uint256(sigma), "Sigma should match the calculated value");
    }


    function testRankingCalculation(uint256 len) public {
        len = bound(len, 3, 10); 

        uint256[] memory timeSeries = new uint256[](len);
        uint256[] memory performanceSeries = new uint256[](len);
        uint256[] memory liquiditySeries = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            timeSeries[i] = i + 1; 
            performanceSeries[i] = bound(uint256(keccak256(abi.encodePacked(i))), 1, 10**6);
            liquiditySeries[i] = bound(uint256(keccak256(abi.encodePacked(i))), 1, 10**6);
        }

        uint256[] memory results = ranker.getRanking(timeSeries, performanceSeries, liquiditySeries);

        assertTrue(results[0] > 0, "Rank should be positive");
    }


}
