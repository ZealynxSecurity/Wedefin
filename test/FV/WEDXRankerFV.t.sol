// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import "forge-std/Test.sol";
import "../../contracts/WEDXRanker.sol";

contract WEDXRankerFV is SymTest, Test {
    WEDXRanker public ranker;

    function setUp() public {
        ranker = new WEDXRanker();
    }

    function check_RankingWithEqualLengthSeries(uint256 len) public {
        vm.assume(len >= 3 && len <= 10); 

        uint256[] memory timeSeries = new uint256[](len);
        uint256[] memory performanceSeries = new uint256[](len);
        uint256[] memory liquiditySeries = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            timeSeries[i] = i + 1; 
            performanceSeries[i] = uint256(keccak256(abi.encodePacked(i))) % 10**6 + 1;
            liquiditySeries[i] = uint256(keccak256(abi.encodePacked(i))) % 10**6 + 1;
        }

        uint256[] memory results = ranker.getRanking(timeSeries, performanceSeries, liquiditySeries);

        assertEq(results.length, 4, "Results should have length 4");
    }

    function check_RankingNoDivisionByZero(uint256 len) public {
        vm.assume(len >= 3 && len <= 10);

        uint256[] memory timeSeries = new uint256[](len);
        uint256[] memory performanceSeries = new uint256[](len);
        uint256[] memory liquiditySeries = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            timeSeries[i] = i + 1; 
            performanceSeries[i] = uint256(keccak256(abi.encodePacked(i))) % 10**6 + 1;
            liquiditySeries[i] = uint256(keccak256(abi.encodePacked(i))) % 10**6 + 1;
        }

        uint256[] memory results = ranker.getRanking(timeSeries, performanceSeries, liquiditySeries);

        assertEq(results.length, 4, "Results should have length 4");
    }
    function check_RankingSigmaCalculation(uint256 len) public {
        vm.assume(len >= 3 && len <= 10);

        uint256[] memory timeSeries = new uint256[](len);
        uint256[] memory performanceSeries = new uint256[](len);
        uint256[] memory liquiditySeries = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            timeSeries[i] = i + 1; 
            performanceSeries[i] = uint256(keccak256(abi.encodePacked(i))) % 10**6 + 1;
            liquiditySeries[i] = uint256(keccak256(abi.encodePacked(i))) % 10**6 + 1;
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

    function check_RankingCalculation(uint256 len) public {
        vm.assume(len >= 3 && len <= 10);

        uint256[] memory timeSeries = new uint256[](len);
        uint256[] memory performanceSeries = new uint256[](len);
        uint256[] memory liquiditySeries = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            timeSeries[i] = i + 1;
            performanceSeries[i] = uint256(keccak256(abi.encodePacked(i))) % 10**6 + 1;
            liquiditySeries[i] = uint256(keccak256(abi.encodePacked(i))) % 10**6 + 1;
        }

        uint256[] memory results = ranker.getRanking(timeSeries, performanceSeries, liquiditySeries);

        assertTrue(results[0] > 0, "Rank should be positive");
    }


}
