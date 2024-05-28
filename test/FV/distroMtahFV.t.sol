// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import "forge-std/Test.sol";
import "../../contracts/library/distroMath.sol"; 

contract distroMathFVTest is SymTest, Test {

    using distroMath for uint256[];

    uint256 constant DISTRO_NORM = 10 ** 6;

    uint256 constant TOLERANCE = 10; 


    function check_FuzzNormalizeWithNonZeroSum(uint256 a, uint256 b, uint256 c) public {

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

    
    function check_FuzzNormalizeWithVariousNonZeroValues(uint256[] memory distro) public {

        vm.assume(distro.length > 0 && distro.length <= 10); // Limiting array size for safety
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

    function check_FuzzNormalizeWithZeroArray(uint256[] memory distro) public {

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


    function check_FuzzNormalizeWithMixedValues(uint256 a, uint256 b, uint256 c) public {

        vm.assume(a > 0 && a < 10 ** 6); 
        vm.assume(b > 0 && b < 10 ** 18); 
        vm.assume(c > 0 && c < 10 ** 12); 

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


    function check_FuzzNormalizeWithSmallValues(uint256 a, uint256 b, uint256 c) public {

        vm.assume(a > 0 && a < 10 ** 6);
        vm.assume(b > 0 && b < 10 ** 6);
        vm.assume(c > 0 && c < 10 ** 6);

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



    function check_FuzzIsInNewAssets(address asset, uint256 len) public {

        vm.assume(len > 0 && len <= 10);

        address[] memory newAssets = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            newAssets[i] = address(uint160(uint256(keccak256(abi.encodePacked(i))) % type(uint160).max + 1));
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

    function check_FuzzIsNotInNewAssets(address asset) public {
        address[] memory newAssets = new address[](3);
        newAssets[0] = address(0x1);
        newAssets[1] = address(0x2);
        newAssets[2] = address(0x3);

        vm.assume(asset != newAssets[0] && asset != newAssets[1] && asset != newAssets[2]);

        bool result = distroMath.isInNewAssets(asset, newAssets);

        assertFalse(result, "Result should be false when asset is not in newAssets");
    }


    function check_FuzzIsFirstAssetInNewAssets(address firstAsset, uint256 len) public {

        vm.assume(len > 0 && len <= 10);

        address[] memory newAssets = new address[](len);
        newAssets[0] = firstAsset;
        for (uint256 i = 1; i < len; i++) {
            newAssets[i] = address(uint160(uint256(keccak256(abi.encodePacked(i))) % type(uint160).max + 1));
        }

        bool result = distroMath.isInNewAssets(firstAsset, newAssets);

        assertTrue(result, "First asset should be in newAssets");
    }

    function check_FuzzIsLastAssetInNewAssets(address lastAsset, uint256 len) public {

        vm.assume(len > 0 && len <= 10);

        address[] memory newAssets = new address[](len);
        for (uint256 i = 0; i < len - 1; i++) {
            newAssets[i] = address(uint160(uint256(keccak256(abi.encodePacked(i))) % type(uint160).max + 1));
        }
        newAssets[len - 1] = lastAsset;

        bool result = distroMath.isInNewAssets(lastAsset, newAssets);

        assertTrue(result, "Last asset should be in newAssets");
    }

    function check_FuzzNormalizeWithVariableLength(uint256 len, uint256 a) public {

        vm.assume(len > 0 && len <= 10);
        vm.assume(a > 0 && a < 10 ** 18);

        uint256[] memory distro = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            distro[i] = a;
        }

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertTrue(sum >= DISTRO_NORM - 10 && sum <= DISTRO_NORM + 10, "Sum should be close to DISTRO_NORM");
    }


    function check_NormalizeProportionality(uint256 len, uint256[] memory distro) public {

        vm.assume(len > 0 && len <= 10);
        vm.assume(distro.length == len);

        uint256 maxValue = type(uint256).max / DISTRO_NORM;
        for (uint256 i = 0; i < len; i++) {
            vm.assume(distro[i] <= maxValue);
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

    function check_NormalizeNoModificationWithZeroSum(uint256 len) public {
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

    function check_NormalizeDistribution(uint256 len, uint256[] memory distro) public {

        vm.assume(len > 0 && len <= 10);
        vm.assume(distro.length == len);

        uint256 maxValue = type(uint256).max / DISTRO_NORM;
        for (uint256 i = 0; i < len; i++) {
            vm.assume(distro[i] <= maxValue);
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