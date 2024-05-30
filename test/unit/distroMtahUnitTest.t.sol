// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/library/distroMath.sol"; 

contract distroMathUnitTest is Test {

    using distroMath for uint256[];

    uint256 constant DISTRO_NORM = 10 ** 6;
    uint256 constant TOLERANCE = 10; 


    function testNormalizeWithZeroSum() public {
        uint256[] memory distro = new uint256[](3);

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertEq(sum, 0, "Sum should be zero");
    }

    function testNormalizeWithLargeValues() public {
        uint256[] memory distro = new uint256[](2);
        distro[0] = 2**128;
        distro[1] = 2**128;

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");
    }

    function testNormalizeWithEdgeCaseValues() public {
        uint256[] memory distro = new uint256[](3);
        distro[0] = DISTRO_NORM;
        distro[1] = 0;
        distro[2] = 0;

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");
        assertEq(normalizedDistro[0], DISTRO_NORM, "First element should be DISTRO_NORM");
        assertEq(normalizedDistro[1], 0, "Second element should be 0");
        assertEq(normalizedDistro[2], 0, "Third element should be 0");
    }

    function testNormalizeDistributionPrecision() public {
        uint256[] memory distro = new uint256[](3);
        distro[0] = 1;
        distro[1] = 2;
        distro[2] = 3;

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");

        uint256 expectedFirst = DISTRO_NORM * distro[0] / (distro[0] + distro[1] + distro[2]);
        uint256 expectedSecond = DISTRO_NORM * distro[1] / (distro[0] + distro[1] + distro[2]);
        uint256 expectedThird = DISTRO_NORM * distro[2] / (distro[0] + distro[1] + distro[2]);

        assertEq(normalizedDistro[0], expectedFirst, "First element should be correctly normalized");
        assertEq(normalizedDistro[1], expectedSecond, "Second element should be correctly normalized");
        assertEq(normalizedDistro[2], expectedThird, "Third element should be correctly normalized");
    }

    function testNormalizeWithMixedValues() public { //@audit
        uint256[] memory distro = new uint256[](5);
        distro[0] = 1;
        distro[1] = 2;
        distro[2] = 3;
        distro[3] = 4;
        distro[4] = 5;

        uint256 originalSum = 1 + 2 + 3 + 4 + 5;

        // Normalize the values
        uint256[] memory normalizedDistro = distro.normalize();

        // Calculate the total sum after normalization
        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        emit log_named_uint("Total Sum After Normalization", sum);
        assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");

        // Verify that each normalized element is approximately correct
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            // Calculate the expected value based on the normalized distribution
            uint256 expected = Math.mulDiv(distro[i], DISTRO_NORM, originalSum);
            emit log_named_uint("Original Value", distro[i]);
            emit log_named_uint("Normalized Value", normalizedDistro[i]);
            emit log_named_uint("Expected Value", expected);
            assertApproxEqAbs(normalizedDistro[i], expected, 1, "Each element should be approximately normalized");
        }
    }


    function testNormalizeWithLargeAndSmallValues() public {
        uint256[] memory distro = new uint256[](4);
        distro[0] = type(uint256).max / 2;
        distro[1] = 1;
        distro[2] = 1;
        distro[3] = 1;

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");
    }

    function testNormalizeWithUnequalValuesAndZero() public {
        uint256[] memory distro = new uint256[](4);
        distro[0] = 10;
        distro[1] = 0;
        distro[2] = 20;
        distro[3] = 70;

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");
    }

    function testNormalizeWithValuesNearDistroNorm() public {
        uint256[] memory distro = new uint256[](3);
        distro[0] = DISTRO_NORM / 2;
        distro[1] = DISTRO_NORM / 3;
        distro[2] = DISTRO_NORM / 6;

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");
    }

    function testNormalizeWithExactDistroNormValues() public {
        uint256[] memory distro = new uint256[](2);
        distro[0] = DISTRO_NORM / 2;
        distro[1] = DISTRO_NORM / 2;

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");
    }

    function testNormalizeWithAllOnes() public {
        uint256[] memory distro = new uint256[](5);
        distro[0] = 1;
        distro[1] = 1;
        distro[2] = 1;
        distro[3] = 1;
        distro[4] = 1;

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertEq(sum, DISTRO_NORM, "Sum should be equal to DISTRO_NORM");
    }



    function testNormalizeWithSingleValue() public {
        uint256[] memory distro = new uint256[](1);
        distro[0] = 42;

        uint256[] memory normalizedDistro = distro.normalize();

        assertEq(normalizedDistro[0], DISTRO_NORM, "Single element should be normalized to DISTRO_NORM");
    }



    function testVerifyNormalization() public {
        uint256[] memory distro = new uint256[](3);
        distro[0] = 100;
        distro[1] = 200;
        distro[2] = 700;

        uint256 totalOriginal = 100 + 200 + 700; // 1000
        uint256[] memory normalizedDistro = distro.normalize();

        uint256 expected0 = Math.mulDiv(100, DISTRO_NORM, totalOriginal); // 100 * 1000000 / 1000 = 100000
        uint256 expected1 = Math.mulDiv(200, DISTRO_NORM, totalOriginal); // 200 * 1000000 / 1000 = 200000
        uint256 expected2 = Math.mulDiv(700, DISTRO_NORM, totalOriginal); // 700 * 1000000 / 1000 = 700000

        emit log_named_uint("Expected 0", expected0);
        emit log_named_uint("Expected 1", expected1);
        emit log_named_uint("Expected 2", expected2);

        assertApproxEqAbs(normalizedDistro[0], expected0, 1, "Value 0 should be normalized correctly");
        assertApproxEqAbs(normalizedDistro[1], expected1, 1, "Value 1 should be normalized correctly");
        assertApproxEqAbs(normalizedDistro[2], expected2, 1, "Value 2 should be normalized correctly");
    }


    function testNormalizationWithZeros() public {
        uint256[] memory distro = new uint256[](4);
        distro[0] = 0;
        distro[1] = 50;
        distro[2] = 50;
        distro[3] = 0;

        uint256[] memory normalizedDistro = distro.normalize();

        uint256 sum = 0;
        for (uint256 i = 0; i < normalizedDistro.length; i++) {
            sum += normalizedDistro[i];
        }

        assertEq(sum, DISTRO_NORM, "Sum of normalized values should be equal to DISTRO_NORM");
    }
}