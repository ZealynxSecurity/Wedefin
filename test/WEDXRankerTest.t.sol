// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/WEDXRanker.sol";

contract WEDXRankerTest is Test {
    WEDXRanker public ranker;

    function setUp() public {
        ranker = new WEDXRanker();
    }

    function testRankingWithValidInput() public {
        uint256[] memory timeSeries = new uint256[](3);
        uint256[] memory performanceSeries = new uint256[](3);
        uint256[] memory liquiditySeries = new uint256[](3);

        timeSeries[0] = 1;
        timeSeries[1] = 2;
        timeSeries[2] = 3;

        performanceSeries[0] = 100;
        performanceSeries[1] = 150; 
        performanceSeries[2] = 300;

        liquiditySeries[0] = 1000;
        liquiditySeries[1] = 900;
        liquiditySeries[2] = 1100;

        uint256[] memory result = ranker.getRanking(timeSeries, performanceSeries, liquiditySeries);

        // Add more debugging messages
        console.log("Rank:", result[0]);
        console.log("Absolute performance change:", result[1]);
        console.log("Sigma:", result[2]);
        console.log("Minimum liquidity:", result[3]);

        // Asserts with detailed messages
        assertGt(result[0], 0, "Rank should be positive");
        assertEq(result[1], 200, "Absolute performance change should be 200");
        assertGt(result[2], 0, "Sigma should be greater than 0");
        assertEq(result[3], 900, "Minimum liquidity should be 900");
    }

    function testRankingWithZeroSigma() public {
        uint256[] memory timeSeries = new uint256[](3);
        uint256[] memory performanceSeries = new uint256[](3);
        uint256[] memory liquiditySeries = new uint256[](3);

        timeSeries[0] = 1;
        timeSeries[1] = 2;
        timeSeries[2] = 3;

        performanceSeries[0] = 100;
        performanceSeries[1] = 200;
        performanceSeries[2] = 300;

        liquiditySeries[0] = 1000;
        liquiditySeries[1] = 1000;
        liquiditySeries[2] = 1000;

        uint256[] memory result = ranker.getRanking(timeSeries, performanceSeries, liquiditySeries);

        // Logs for debugging
        console2.log("Inputs:");
        for (uint256 i = 0; i < timeSeries.length; i++) {
            console2.log("Time:", timeSeries[i]);
            console2.log("Performance:", performanceSeries[i]);
            console2.log("Liquidity:", liquiditySeries[i]);
        }
        console2.log("Outputs:");
        console2.log("Rank:", result[0]);
        console2.log("Absolute performance change:", result[1]);
        console2.log("Sigma:", result[2]);
        console2.log("Minimum liquidity:", result[3]);

        // Asserts with detailed messages
        assertEq(result[0], 0, "Rank should be 0 if sigma is 0");
        assertEq(result[1], 200, "Absolute performance change should be 200");
        assertEq(result[2], 0, "Sigma should be 0 if performance follows a perfect linear trend");
        assertEq(result[3], 1000, "Minimum liquidity should be 1000");
    }

    function testRankingWithSingleDataPoint() public {
        uint256[] memory timeSeries = new uint256[](1);
        uint256[] memory performanceSeries = new uint256[](1);
        uint256[] memory liquiditySeries = new uint256[](1);

        timeSeries[0] = 1;
        performanceSeries[0] = 100;
        liquiditySeries[0] = 1000;

        vm.expectRevert("At least three data points are required");

        console.log("Time Series Length:", timeSeries.length);
        console.log("Performance Series Length:", performanceSeries.length);
        console.log("Liquidity Series Length:", liquiditySeries.length);
        console.log("Time Series[0]:", timeSeries[0]);
        console.log("Performance Series[0]:", performanceSeries[0]);
        console.log("Liquidity Series[0]:", liquiditySeries[0]);

        ranker.getRanking(timeSeries, performanceSeries, liquiditySeries);
    }
}
