// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/library/distroMath.sol"; 

contract distroMtahFuzzTest is Test {

    using distroMath for uint256[];

    uint256 constant DISTRO_NORM = 10 ** 6;
    uint256 constant TOLERANCE = 10; 

    function testFuzzNormalizeWithNonZeroSum(uint256 a, uint256 b, uint256 c) public {

        vm.assume(a > 0 && a < 10 ** 18);
        vm.assume(b > 0 && b < 10 ** 18);
        vm.assume(c > 0 && c < 10 ** 18);

        uint256[] memory distro = new uint256[](3);
        distro[0] = a;
        distro[1] = b;
        distro[2] = c;

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }


        assertTrue(sum >= DISTRO_NORM - 10 && sum <= DISTRO_NORM + 10, "Sum should be close to DISTRO_NORM");
    }

    
    function testFuzzNormalizeWithVariousNonZeroValues(uint256[] memory distro) public {

        vm.assume(distro.length > 0 && distro.length <= 10); 
        
        uint256 nonZeroCount = 0;
        uint256 maxValue = type(uint256).max / DISTRO_NORM;
        for (uint256 i = 0; i < distro.length; i++) {
            vm.assume(distro[i] > 0 && distro[i] < maxValue);
            if (distro[i] > 0) {
                nonZeroCount++;
            }
        }
        vm.assume(nonZeroCount > 0);

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertTrue(
            sum >= DISTRO_NORM - TOLERANCE && sum <= DISTRO_NORM + TOLERANCE,
            "Sum should be close to DISTRO_NORM"
        );
    }

        function testFuzzNormalizeWithZeroArray(uint256[] memory distro) public {
        vm.assume(distro.length > 0 && distro.length <= 10); 
        for (uint256 i = 0; i < distro.length; i++) {
            vm.assume(distro[i] == 0);
        }

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertEq(sum, 0, "Sum should be zero");
    }

    function testFuzzNormalizeWithLargeValues(uint256 a, uint256 b, uint256 c) public {

        a = bound(a, 1, 10 ** 18);
        b = bound(b, 1, 10 ** 18);
        c = bound(c, 1, 10 ** 18);

        uint256[] memory distro = new uint256[](3);
        distro[0] = a;
        distro[1] = b;
        distro[2] = c;

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertTrue(sum >= DISTRO_NORM - 10 && sum <= DISTRO_NORM + 10, "Sum should be close to DISTRO_NORM");
    }


    function testFuzzNormalizeWithSmallValues(uint256 a, uint256 b, uint256 c) public {

        a = bound(a, 1, 10 ** 6);
        b = bound(b, 1, 10 ** 6);
        c = bound(c, 1, 10 ** 6);

        uint256[] memory distro = new uint256[](3);
        distro[0] = a;
        distro[1] = b;
        distro[2] = c;

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertTrue(sum >= DISTRO_NORM - 10 && sum <= DISTRO_NORM + 10, "Sum should be close to DISTRO_NORM");
    }

    function testFuzzIsInNewAssets(address asset, uint256 len) public {

        len = bound(len, 1, 10);

        address[] memory newAssets = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            newAssets[i] = address(uint160(bound(uint256(keccak256(abi.encodePacked(i))), 1, type(uint160).max)));
        }

        bool result = distroMath.isInNewAssets(asset, newAssets);

        bool expectedResult = false;
        for (uint256 i = 0; i < len; i++) {
            if (newAssets[i] == asset) {
                expectedResult = true;
                break;
            }
        }

        assertEq(result, expectedResult, "Result should match the expected result");
    }


    function testNormalizeProportionality(uint256 len, uint256[] memory distro) public {

        len = bound(len, 1, 10);
        distro = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            distro[i] = bound(distro[i], 0, type(uint256).max / DISTRO_NORM);
        }

        uint256 sum = 0;
        for (uint256 i = 0; i < len; i++) {
            sum += distro[i];
        }

        if (sum == 0) {
            return;
        }

        uint256[] memory normalizedDistro = distro.normalize();

        for (uint256 i = 0; i < len; i++) {

            assertEq(normalizedDistro[i], Math.mulDiv(distro[i], DISTRO_NORM, sum), "Each value should be proportional to the original");
        }
    }

    function testNormalizeNoModificationWithZeroSum(uint256 len) public {

        len = bound(len, 1, 10);

        uint256[] memory distro = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            distro[i] = 0;
        }

        uint256[] memory normalizedDistro = distro.normalize();

        for (uint256 i = 0; i < len; i++) {

            assertEq(normalizedDistro[i], 0, "Each value should be zero if the original sum is zero");
        }
    }


    function testNormalizeDistribution(uint256 len, uint256[] memory distro) public {

        len = bound(len, 1, 10);
        distro = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            distro[i] = bound(distro[i], 0, type(uint256).max / DISTRO_NORM);
        }

        uint256 sum = 0;
        for (uint256 i = 0; i < len; i++) {
            sum += distro[i];
        }

        if (sum == 0) {
            return;
        }

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 newSum = 0;
        for (uint256 i = 0; i < len; i++) {
            newSum += normalizedDistro[i];
        }

        if (sum < DISTRO_NORM) {

            assertEq(newSum, DISTRO_NORM, "The sum should be adjusted to distroNorm");
        } else if (sum > DISTRO_NORM) {

            assertEq(newSum, DISTRO_NORM, "The sum should be adjusted to distroNorm");
        }
    }



}